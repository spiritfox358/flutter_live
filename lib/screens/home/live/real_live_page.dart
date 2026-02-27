import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:convert';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_live/screens/home/live/widgets/avatar_animation.dart';
import 'package:flutter_live/screens/home/live/widgets/chat/build_chat_list.dart';
import 'package:flutter_live/screens/home/live/widgets/effect_player/gift_tray_effect_layer.dart';
import 'package:flutter_live/screens/home/live/widgets/effect_player/user_entrance_effect_layer.dart';
import 'package:flutter_live/screens/home/live/widgets/live_user_entrance.dart';
import 'package:flutter_live/screens/home/live/widgets/room_mode/video_room_content_view.dart';
import 'package:flutter_live/screens/home/live/widgets/room_mode/voice_room_content_view.dart';
import 'package:flutter_live/screens/home/live/widgets/top_bar/viewer_list.dart';
import 'package:flutter_live/store/user_store.dart';
import 'package:just_audio/just_audio.dart' hide AudioPlayer;
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// 假设你的路径结构如下，请根据实际情况调整
import '../../../models/user_models.dart';
import '../../../services/gift_api.dart';
import '../../../services/ai_music_service.dart';
import '../../../tools/HttpUtil.dart';

import '../../../tools/StringTool.dart';
import 'models/live_models.dart';
import 'widgets/view_mode/pk_real_battle_view.dart';
import 'widgets/view_mode/single_mode_view.dart';
import 'package:flutter_live/screens/home/live/widgets/build_bottom_input_bar.dart';
import 'package:flutter_live/screens/home/live/widgets/top_bar/build_top_bar.dart';
import 'package:flutter_live/screens/home/live/widgets/music_panel.dart';
import 'package:flutter_live/screens/home/live/widgets/pk_score_bar_widgets.dart';
import 'widgets/gift_panel/gift_panel.dart';

// 引入新拆分的特效层
import 'widgets/gift_effect_layer.dart';

// 引入 PK 匹配管理器
import 'widgets/pk_match_manager.dart';

// 1. 定义房间类型枚举
enum LiveRoomType {
  normal, // 普通直播
  music, // 听歌房
  voice, //语音房
  game, // 游戏房
  video, // 🟢 新增：视频放映厅
}

class RealLivePage extends StatefulWidget {
  final String userId;
  final String userName;
  final String avatarUrl;
  final int level;
  final int monthLevel;
  final bool isHost;
  final String roomId;
  final Map<String, dynamic>? initialRoomData;

  // 2. 新增房间类型参数
  final LiveRoomType roomType;

  // 🟢 核心新增：判断当前直播间是否在屏幕正中央
  final bool isCurrentView;

  // 🟢 1. 新增：接收外层的翻页控制器
  final PageController? pageController;

  const RealLivePage({
    super.key,
    required this.userId,
    required this.userName,
    required this.avatarUrl,
    required this.level,
    required this.monthLevel,
    required this.isHost,
    required this.roomId,
    this.initialRoomData,
    this.roomType = LiveRoomType.normal, // 默认为普通模式
    this.isCurrentView = true, // 🟢 默认设为 true，兼容你之前点击单个房间进来的旧逻辑
    this.pageController, // 🟢 2. 加入构造函数
  });

  @override
  State<RealLivePage> createState() => _RealLivePageState();
}

class _RealLivePageState extends State<RealLivePage> with TickerProviderStateMixin {
  // 加载状态，默认为 true
  bool _isLoadingDetail = true;

  // PK时长配置
  int _pkDuration = 90; // 默认为90秒
  final int _punishmentDuration = 20;

  // 🟢 终极跟手魔法：跨层级手势劫持变量
  Drag? _parentDrag; // 保存父级 PageView 的物理拖拽句柄
  // 🟢 终极跟手魔法：跨层级手势劫持变量
  double _parentDragDistance = 0.0; // 记录本次拖拽的真实物理距离
  bool _canForwardToParent = false; // 判断当前是否允许切房

  // ⬇️⬇️⬇️ 新增：弹幕区滑动切房的独立开关 ⬇️⬇️⬇️
  final bool _enableSwipeUpToSwitchRoom = true; // 开关：是否允许手指【往上滑】切房（默认关闭）
  final bool _enableSwipeDownToSwitchRoom = false; // 开关：是否允许手指【往下滑】切房（默认开启）
  // ⬆️⬆️⬆️ 新增：弹幕区滑动切房的独立开关 ⬆️⬆️⬆️

  WebSocketChannel? _channel;
  StreamSubscription? _socketSubscription;
  late String _myUserName;
  late String _myUserId;
  late int _myLevel;
  late int _monthLevel;
  late String _myAvatar;
  late String _roomId;
  final GlobalKey<ChatInputOverlayState> _inputOverlayKey = GlobalKey();
  final GlobalKey<VoiceRoomContentViewState> _voiceRoomKey = GlobalKey();
  final GlobalKey<UserEntranceEffectLayerState> _entranceEffectKey = GlobalKey();

  // 🟢 1. 定义一个 GlobalKey 用来控制榜单组件
  final GlobalKey<ViewerListState> _viewerListKey = GlobalKey<ViewerListState>();

  //控制进场组件的 Key
  final GlobalKey<LiveUserEntranceState> _entranceKey = GlobalKey<LiveUserEntranceState>();
  final GlobalKey<GiftTrayEffectLayerState> _trayLayerKey = GlobalKey();

  // 用于控制特效层的 Key
  final GlobalKey<GiftEffectLayerState> _giftEffectKey = GlobalKey();

  // 用于控制 PK 匹配管理器的 Key
  final GlobalKey<PkMatchManagerState> _pkMatchManagerKey = GlobalKey();

  late int _onlineCount = 0;
  late bool _isHost = false;
  final GlobalKey _chatListKey = GlobalKey();

  // 用户余额
  int _myCoins = 0;

  final String _wsUrl = "ws://${HttpUtil.getBaseIpPort}/ws/live";

  // --- 左侧（自己）视频控制 ---
  VideoPlayerController? _bgController;
  bool _isBgInitialized = false;
  bool _isVideoBackground = false;
  String _currentBgImage = "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/bg_15.jpg";
  String _leftCurrentStreamUrl = "";

  // --- 右侧（对手）视频控制 ---
  VideoPlayerController? _rightVideoController;
  bool _isRightVideoInitialized = false;
  bool _isRightVideoMode = false; // 默认开启右侧视频

  int _currentUserId = 1;
  String _currentName = "";
  Timer? _heartbeatTimer;
  bool _isDisposed = false;
  String _currentAvatar = "";
  late String _leftVideoUrl = "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/bg.MOV";
  final String _rightVideoUrl = "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/234.mp4";

  PKStatus _pkStatus = PKStatus.idle;
  int _myPKScore = 0;
  int _opponentPKScore = 0;
  int _pkTimeLeft = 0;
  Timer? _pkTimer;

  List<dynamic> _participants = [];

  // 首翻相关变量
  bool _isFirstGiftPromoActive = false;
  int _promoTimeLeft = 30;
  Timer? _promoTimer;

  // 使用 Set<String> 记录 userId，确保每人仅一次
  final Set<String> _usersWhoUsedPromo = {};

  final ChatListController _chatController = ChatListController();

  static const int _maxActiveGifts = 2;
  final List<GiftEvent> _activeGifts = [];
  final Queue<GiftEvent> _waitingQueue = Queue();
  List<GiftItemData> _giftList = [];

  bool _showComboButton = false;
  GiftItemData? _lastGiftSent;
  late AnimationController _comboScaleController;
  late AnimationController _countdownController;

  bool _showPKStartAnimation = false;
  late AnimationController _pkStartAnimationController;
  late Animation<double> _pkLeftAnimation;
  late Animation<double> _pkRightAnimation;
  late Animation<double> _pkFadeAnimation;

  final ValueNotifier<UserModel> _userStatusNotifier = ValueNotifier(
    UserModel(0, 0, coinsToNextLevel: 0, coinsNextLevelThreshold: 0, coinsToNextLevelText: "0", coinsCurrentLevelThreshold: 0, monthLevel: 0),
  );
  final AudioPlayer _ttsPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();

    _myUserId = widget.userId;
    _myUserName = widget.userName;
    _myLevel = widget.level;
    _monthLevel = widget.monthLevel;
    _myAvatar = widget.avatarUrl;
    _roomId = widget.roomId;

    // 如果 initialRoomData 存在，可以先进行简单的预填充
    if (widget.initialRoomData != null) {
      _currentName = widget.initialRoomData!['userName'] ?? widget.userName;
      _currentAvatar = widget.initialRoomData!['avatar'] ?? widget.avatarUrl;
    }

    _fetchGiftList();
    _initializeBackground(); // 初始化左侧视频

    _initPKStartAnimation();

    // 🟢 只有当该房间处于屏幕中央时，才去真实连接服务器和播放画面！
    if (widget.isCurrentView) {
      _resumeRoom();
    } else {
      // 如果不在屏幕中央，只显示封面加载中，不拉流不断连
      _isLoadingDetail = true;
    }

    _comboScaleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150), lowerBound: 0.0, upperBound: 1.0);
    _countdownController = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _countdownController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _comboScaleController.reverse().then((_) {
          setState(() {
            _showComboButton = false;
            _lastGiftSent = null;
          });
        });
      }
    });
    // _startEnterRoomSequence();
  }

  int _parseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  // 🟢 新增：监听 PageView 上下滑动带来的状态变化
  @override
  void didUpdateWidget(covariant RealLivePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当滑动状态发生改变时触发
    if (widget.isCurrentView != oldWidget.isCurrentView) {
      if (widget.isCurrentView) {
        debugPrint("👉 滑入直播间 ${widget.roomId}，开始连线拉流...");
        _resumeRoom();
      } else {
        debugPrint("👈 滑出直播间 ${widget.roomId}，断开 Socket 并暂停视频...");
        _pauseRoom();
      }
    }
  }

  // 🟢 新增：滑入房间时的恢复逻辑 (把你原来 initState 里的启动代码放进来)
  void _resumeRoom() {
    _startEnterRoomSequence();
    if (_isVideoBackground && _isBgInitialized) {
      _bgController?.play();
    }
    if (_isRightVideoMode && _isRightVideoInitialized) {
      _rightVideoController?.play();
    }
  }

  // 🟢 新增：滑出房间时的清理逻辑 (极其重要！防卡死、防串音)
  void _pauseRoom() {
    // 1. 断开 WebSocket (省流量、防后台悄悄刷礼物)
    _socketSubscription?.cancel();
    _channel?.sink.close();
    _heartbeatTimer?.cancel();
    _channel = null;

    // 2. 暂停所有视频 (防串音)
    _bgController?.pause();
    _rightVideoController?.pause();

    // 3. 停止所有 PK 和活动定时器
    _pkTimer?.cancel();
    _promoTimer?.cancel();

    // 4. 清理聊天和特效状态
    setState(() {
      _activeGifts.clear();
      _waitingQueue.clear();
      _showPKStartAnimation = false;
      // 可选：清空聊天记录 _chatController.clear();
    });
  }

  /// 确保视频在切换界面后继续播放（包括左侧和右侧）
  void _ensureVideosPlaying() {
    // 检查左侧
    if (_isVideoBackground && _isBgInitialized && _bgController != null) {
      if (!_bgController!.value.isPlaying) {
        debugPrint("▶️ 检测到左侧视频暂停，强制续播...");
        _bgController!.play();
      }
    }
    // 检查右侧
    if (_isRightVideoMode && _isRightVideoInitialized && _rightVideoController != null) {
      if (!_rightVideoController!.value.isPlaying) {
        debugPrint("▶️ 检测到右侧视频暂停，强制续播...");
        _rightVideoController!.play();
      }
    }
  }

  Future<void> _fetchGiftList() async {
    try {
      final gifts = await GiftApi.getGiftList();
      if (mounted && gifts.isNotEmpty) setState(() => _giftList = gifts);
    } catch (e) {
      debugPrint("❌ 加载礼物列表失败");
    }
  }

  Future<void> _fetchUserBalance() async {
    try {
      final res = await HttpUtil().get("/api/user/info");
      if (mounted && res != null) {
        setState(() {
          _myCoins = _parseInt(res['coin']);
          _myLevel = _parseInt(res['level']);
          Map<String, dynamic> userInfo = res;
          UserStore.to.saveProfile(userInfo);
          _monthLevel = _parseInt(res['monthLevel']);
          int coinsToNextLevel = res['coinsToNextLevel'];
          int coinsNextLevelThreshold = res['coinsNextLevelThreshold'];
          String coinsToNextLevelText = res['coinsToNextLevelText'];
          int coinsCurrentLevelThreshold = res['coinsCurrentLevelThreshold'];
          _userStatusNotifier.value = UserModel(
            _myCoins,
            _myLevel,
            monthLevel: _monthLevel,
            coinsToNextLevel: coinsToNextLevel,
            coinsNextLevelThreshold: coinsNextLevelThreshold,
            coinsToNextLevelText: coinsToNextLevelText,
            coinsCurrentLevelThreshold: coinsCurrentLevelThreshold,
          );
        });
      }
    } catch (e) {
      debugPrint("获取余额失败: $e");
    }
  }

  void _connectWebSocket() {
    try {
      _socketSubscription?.cancel();
      _channel?.sink.close();

      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));

      _socketSubscription = _channel!.stream.listen(
        (message) => _handleSocketMessage(message),
        onError: (error) {
          debugPrint("❌ WebSocket 报错: $error");
          _reconnect();
        },
        onDone: () {
          debugPrint("🔌 WebSocket 连接断开");
          _reconnect();
        },
      );

      _sendSocketMessage(
        "ENTER",
        content: "进入了直播间",
        userId: _myUserId,
        userName: _myUserName,
        avatar: _myAvatar,
        level: _myLevel,
        monthLevel: _monthLevel,
        isHost: false,
      );
      _startHeartbeat();
    } catch (e) {
      debugPrint("❌ WS连接失败");
      _reconnect();
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      try {
        _channel?.sink.add(jsonEncode({"type": "HEARTBEAT", "roomId": _roomId}));
      } catch (e) {
        _reconnect();
      }
    });
  }

  void _reconnect() {
    if (_isDisposed) return;
    _heartbeatTimer?.cancel();
    Future.delayed(const Duration(seconds: 3), () {
      if (!_isDisposed) {
        _connectWebSocket();
      }
    });
  }

  void _startEnterRoomSequence() async {
    try {
      final res = await HttpUtil().post("/api/room/join", data: {"roomId": int.parse(_roomId), "userId": _myUserId});

      if (mounted && res != null && res['onlineCount'] != null) {
        setState(() {
          _onlineCount = _parseInt(res['onlineCount']);
        });
      }

      await _fetchUserBalance();

      if (!mounted || _isDisposed) return;
      _connectWebSocket();
      if (!mounted || _isDisposed) return;
      _fetchRoomDetailAndSyncState();
    } catch (e) {
      debugPrint("进房初始化失败: $e");
    }
  }

  void _fetchRoomDetailAndSyncState() async {
    // 开启 Loading 状态
    if (mounted) setState(() => _isLoadingDetail = true);

    try {
      final res = await HttpUtil().get("/api/pk/detail", params: {"roomId": int.parse(_roomId), "userId": _myUserId, "userName": _myUserName});
      final data = res;

      if (data['pkInfo'] != null) {
        final pkInfo = data['pkInfo'];
        final int status = _parseInt(pkInfo['status']);
        final String startTimeStr = pkInfo['startTime'];

        _pkDuration = _parseInt(pkInfo['duration'], defaultValue: 90);
        setState(() {
          _participants = pkInfo['participants'] as List;
          if (_participants.length >= 2) {
            String opponentStream = _participants[1]['streamUrl'] ?? _rightVideoUrl;
            if (_isVideoBackground) {
              _ensureRightVideoInitialized(opponentStream);
            }
          }
          if (_participants.isNotEmpty) {
            _currentName = _participants[0]['name'] ?? _currentName;
            _currentAvatar = _participants[0]['avatar'] ?? _currentAvatar;
            _currentBgImage = _participants[0]['personalPkBg'] ?? _currentBgImage;
            _leftCurrentStreamUrl = _participants[0]['streamUrl'] ?? _leftCurrentStreamUrl;
            if (_participants.length >= 2) {
              _myPKScore = _parseInt(_participants[0]['score']);
              _opponentPKScore = _parseInt(_participants[1]['score']);
            }
          }
        });

        DateTime startTime = DateTime.parse(startTimeStr);
        int elapsedSeconds = DateTime.now().difference(startTime).inSeconds;
        if (elapsedSeconds < 0) {
          elapsedSeconds = 0; // 如果还没到开始时间，视为已开始0秒
        }

        if (status == 1) {
          final int remaining = _pkDuration - elapsedSeconds;
          if (remaining > 0) {
            _startPKRound(initialTimeLeft: remaining);
            const int promoDuration = 30;
            if (elapsedSeconds < promoDuration) {
              setState(() {
                _isFirstGiftPromoActive = true;
                _promoTimeLeft = promoDuration - elapsedSeconds;
                _usersWhoUsedPromo.clear();
              });
              _startPromoTimer();
            } else {
              setState(() {
                _isFirstGiftPromoActive = false;
              });
            }
          } else {
            _enterPunishmentPhase();
          }
        } else if (status == 2) {
          final int remainingPunishment = _punishmentDuration - (elapsedSeconds - _pkDuration);
          if (remainingPunishment > 0) {
            _enterPunishmentPhase(timeLeft: remainingPunishment);
          }
        } else if (status == 3) {
          DateTime startTime = DateTime.parse(startTimeStr);
          int totalElapsed = DateTime.now().difference(startTime).inSeconds;
          int coHostElapsed = totalElapsed - _pkDuration - _punishmentDuration;
          _enterCoHostPhase(initialElapsedTime: coHostElapsed > 0 ? coHostElapsed : 0, serverStartTime: startTime);
        }
      } else {
        setState(() {
          _currentName = data['title'] ?? _currentName;
          _currentAvatar = data['coverImg'] ?? _currentAvatar;
          _leftVideoUrl = data['streamUrl'] ?? _leftVideoUrl;
          _currentBgImage = data['personalPkBg'] ?? _currentBgImage;
        });
      }

      setState(() {
        _currentUserId = data['anchorId'] ?? _currentUserId;
        _isHost = _currentUserId.toString() == UserStore.to.userId;
      });
    } catch (e) {
      debugPrint("❌ 同步房间详情失败: $e");
    } finally {
      // 无论成功失败，关闭 Loading 状态
      if (mounted) setState(() => _isLoadingDetail = false);
    }
  }

  Future<void> _ensureRightVideoInitialized(String url) async {
    // 如果已经初始化过，且地址没变，就不管了
    if (_isRightVideoInitialized && _rightVideoController != null) return;

    debugPrint("📺 开始加载右侧 PK 视频...");
    _rightVideoController = VideoPlayerController.networkUrl(Uri.parse(url), videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));

    try {
      await _rightVideoController!.initialize();
      _rightVideoController!.setLooping(true);
      if (_isRightVideoMode) _rightVideoController!.play();
      if (mounted) setState(() => _isRightVideoInitialized = true);
    } catch (e) {
      debugPrint("❌ 右侧视频初始化失败: $e");
    }
  }

  void _handleSocketMessage(dynamic message) {
    if (!mounted) return;
    try {
      final Map<String, dynamic> data = jsonDecode(message);
      final String type = data['type'];
      final String roomId = data['roomId']?.toString() ?? "";
      if (roomId.isNotEmpty && roomId != _roomId) return;
      final String msgUserId = data['userId']?.toString() ?? "";
      final bool isMe = (msgUserId == _myUserId);
      final bool senderIsHost = StringTool.parseBool(data['isHost']);
      final String joinerId = data['userId'] ?? "神秘人";
      final String joinerName = data['userName'] ?? "神秘人";
      final String joinerAvatar = data['avatar'] ?? "";
      final int joinerLevel = int.tryParse(data['level']?.toString() ?? '') ?? 0;
      final int joinerMonthLevel = int.tryParse(data['monthLevel']?.toString() ?? '') ?? 0;
      switch (type) {
        case "ENTER":
          if ([2, 6, 163].contains(int.parse(joinerId))) {
            _entranceEffectKey.currentState?.addEntrance(EntranceModel(userName: joinerName, avatar: joinerAvatar));
          } else {
            _simulateVipEnter(
              overrideUserId: joinerId,
              overrideName: joinerName,
              overrideAvatar: joinerAvatar,
              overrideLevel: joinerLevel,
              overrideMonthLevel: joinerMonthLevel,
              isHost: senderIsHost,
            );
          }
          break;
        case "CHAT":
          _addSocketChatMessage(
            joinerName,
            data['content'] ?? "",
            isMe ? Colors.amber : Colors.white,
            level: joinerLevel,
            monthLevel: joinerMonthLevel,
            isHost: senderIsHost,
            userId: msgUserId,
          );
          break;
        case "ONLINE_COUNT":
          final int newCount = data['onlineCount'] ?? 0;
          if (mounted) setState(() => _onlineCount = newCount);
          _viewerListKey.currentState?.refresh();
          break;
        case "GIFT":
          final String giftId = data['giftId']?.toString() ?? "";
          GiftItemData? targetGift;
          try {
            if (_giftList.isNotEmpty) {
              targetGift = _giftList.firstWhere((g) => g.id.toString() == giftId);
            }
          } catch (e) {}
          targetGift ??= GiftItemData(id: giftId, name: "未知礼物", price: 0, iconUrl: "...");

          _processGiftEvent(
            targetGift,
            joinerName,
            joinerAvatar,
            senderLevel: joinerLevel,
            senderMonthLevel: joinerMonthLevel,
            isMe,
            isHost: senderIsHost,
            senderId: msgUserId,
            count: int.tryParse(data['giftCount']?.toString() ?? '') ?? 1,
          );
          _viewerListKey.currentState?.refresh();
          break;
        // 处理 PK 邀请
        case "PK_INVITE":
          if (_isHost && _pkStatus == PKStatus.idle) {
            _pkMatchManagerKey.currentState?.showInviteDialog(
              context,
              inviterName: data['inviterName'] ?? "未知主播",
              inviterAvatar: data['inviterAvatar'] ?? "",
              inviterRoomId: data['inviterRoomId']?.toString() ?? "",
            );
          }
          break;
        // 处理对方拒绝 PK
        case "PK_REJECTED":
          _pkMatchManagerKey.currentState?.onMatchRejected();
          break;
        case "PK_START":
          _pkMatchManagerKey.currentState?.stopMatching();
          if (data['duration'] != null) {
            _pkDuration = _parseInt(data['duration'].toString());
          }
          _startPKRound();
          _fetchRoomDetailAndSyncState();
          break;
        case "PK_PUNISHMENT":
          if (!isMe) _enterPunishmentPhase();
          break;
        case "PK_COHOST":
          if (!isMe) _enterCoHostPhase(initialElapsedTime: 0);
          break;
        case "PK_UPDATE":
          final List<dynamic> scoreList = data['data'] as List<dynamic>;
          setState(() {
            for (var item in scoreList) {
              String roomId = item['roomId'].toString();
              int score = int.tryParse(item['score'].toString() ?? '') ?? 0;
              if (roomId == _roomId) {
                _myPKScore = score;
              } else {
                _opponentPKScore = score;
              }
            }
          });
          break;
        case "PK_END":
          _disconnectCoHost();
          break;
        // 处理直播间关闭通知
        case "ROOM_CLOSE":
          if (!_isHost) {
            _showRoomClosedDialog();
          }
          break;
        case "AI_REPLY":
          final content = data['content'];
          final audioData = data['audio'];

          _chatController.addMessage(
            ChatMessage(
              name: joinerName,
              content: content,
              level: 17,
              monthLevel: _monthLevel,
              levelColor: Colors.purpleAccent,
              isAnchor: _isHost,
              userId: msgUserId,
            ),
          );

          if (audioData != null && audioData.toString().isNotEmpty) {
            _playBase64Audio(audioData);
          }
          break;
        // 🟢 新增：处理主播语音消息
        case "HOST_SPEAK":
          // 只有在语音房模式下才处理，或者你希望任何模式都播放也可以
          // 这里通过 Key 直接调用子组件的方法
          if (_voiceRoomKey.currentState != null) {
            _voiceRoomKey.currentState?.speakFromSocket(data);
          } else {
            // 如果当前不是 VoiceRoomContentView (例如在看 PK)，
            // 你可以选择忽略，或者在这里直接用 _ttsPlayer 播放音频（但不显示动画）
            // 简单的做法是只在语音房处理
            debugPrint("收到语音消息，但当前不在语音房视图，跳过动画");

            // 如果你希望在任何房间都能听到声音（只是没动画），可以解开下面这行：
            // _playBase64Audio(data['audioData']);
          }
          break;
      }
    } catch (e) {
      debugPrint("❌ 解析消息失败: $e");
    }
  }

  void _sendSocketMessage(
    String type, {
    String? content,
    String? giftId,
    int giftCount = 1,
    String? userId,
    String? userName,
    bool? isHost,
    String? avatar,
    int? level,
    int? monthLevel,
    int? score,
  }) {
    if (_channel == null) return;
    final Map<String, dynamic> msg = {
      "type": type,
      "roomId": _roomId,
      "userId": _myUserId,
      "userName": userName,
      "avatar": avatar,
      "level": level,
      "monthLevel": monthLevel,
      "isHost": isHost,
      "score": score,
      "content": content,
      "giftId": giftId,
      "giftCount": giftCount,
    };
    try {
      _channel!.sink.add(jsonEncode(msg));
    } catch (e) {}
  }

  Future<void> _playBase64Audio(String dataUri) async {
    if (dataUri.contains(',')) {
      dataUri = dataUri.split(',').last;
    }
    Uint8List audioBytes = base64Decode(dataUri);
    await _ttsPlayer.play(BytesSource(audioBytes));
  }

  void _onTapStartPK() {
    _dismissKeyboard();
    if (_pkStatus != PKStatus.idle || !_isHost) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 20, left: 20, right: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                child: const Text(
                  "选择PK方式",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(color: Colors.white10, height: 1),

              // 随机匹配按钮
              ListTile(
                leading: const Icon(Icons.shuffle, color: Colors.cyanAccent),
                title: const Text("随机匹配在线主播", style: TextStyle(color: Colors.white)),
                subtitle: const Text("系统自动连线空闲主播", style: TextStyle(color: Colors.white38, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _pkMatchManagerKey.currentState?.startRandomMatch(context);
                },
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("取消", style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDurationOption(String label, int seconds) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      title: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      trailing: null,
      onTap: () {
        Navigator.pop(context);
        _startPKWithDuration(seconds);
      },
    );
  }

  void _showInputSheet() {
    _inputOverlayKey.currentState?.showInput();
  }

  void _startPKWithDuration(int duration) async {
    setState(() {
      _pkDuration = duration;
    });
    try {
      await HttpUtil().post("/api/pk/start", data: {"roomId": int.parse(_roomId), "duration": duration});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("开启失败: $e")));
    }
  }

  void _startPKRound({int? initialTimeLeft}) {
    _pkTimer?.cancel();
    _pkTimer = null;
    if (_pkStatus == PKStatus.playing && initialTimeLeft == null) return;
    if (initialTimeLeft == null) _playPKStartAnimation();

    setState(() {
      _pkStatus = PKStatus.playing;
      _pkTimeLeft = initialTimeLeft ?? _pkDuration;

      if (initialTimeLeft == null) {
        _myPKScore = 0;
        _opponentPKScore = 0;

        _isFirstGiftPromoActive = true;
        _promoTimeLeft = 30;
        _usersWhoUsedPromo.clear();

        _startPromoTimer();
      }
    });

    // 修复：确保所有视频恢复播放
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureVideosPlaying();
    });

    _pkTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _pkTimeLeft--);
      if (_pkTimeLeft <= 0) {
        _pkTimer?.cancel();
        _enterPunishmentPhase();
      }
    });
  }

  void _enterPunishmentPhase({int? timeLeft}) async {
    _pkTimer?.cancel();
    _pkTimer = null;
    setState(() {
      _pkStatus = PKStatus.punishment;
      _pkTimeLeft = (timeLeft != null && timeLeft > 0) ? timeLeft : _punishmentDuration;
      _isFirstGiftPromoActive = false;
      _promoTimer?.cancel();
    });
    if (_isHost && timeLeft == null) {
      try {
        // await HttpUtil().post("/api/room/enter_punishment", data: {"roomId": int.parse(_roomId)});
        // _sendSocketMessage("PK_PUNISHMENT");
      } catch (e) {}
    }
    _pkTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _pkTimeLeft--);
      if (_pkTimeLeft <= 0) _stopPK();
    });
  }

  void _stopPK() async {
    _pkTimer?.cancel();
    _enterCoHostPhase(initialElapsedTime: 0);
    try {
      await HttpUtil().post("/api/pk/to_cohost", data: {"roomId": int.parse(_roomId)});
    } catch (e) {}
  }

  void _enterCoHostPhase({required int initialElapsedTime, DateTime? serverStartTime}) {
    _pkTimer?.cancel();
    _pkTimer = null;

    setState(() {
      _pkStatus = PKStatus.coHost;
      _pkTimeLeft = initialElapsedTime;
      _isFirstGiftPromoActive = false;
      _promoTimer?.cancel();
    });

    DateTime anchorTime;
    if (serverStartTime != null) {
      anchorTime = serverStartTime.add(Duration(seconds: _pkDuration + _punishmentDuration));
    } else {
      anchorTime = DateTime.now().subtract(Duration(seconds: initialElapsedTime));
    }

    _pkTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_pkStatus == PKStatus.coHost) {
        setState(() {
          _pkTimeLeft = DateTime.now().difference(anchorTime).inSeconds;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _disconnectCoHost() {
    _pkTimer?.cancel();
    _promoTimer?.cancel();
    _rightVideoController?.pause(); // 暂停对手视频

    if (mounted) {
      setState(() {
        _pkStatus = PKStatus.idle;
        _myPKScore = 0;
        _opponentPKScore = 0;
        _isFirstGiftPromoActive = false;
        _participants = [];
      });
    }

    // 修复：界面切换回普通模式后，强制恢复左侧视频
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureVideosPlaying();
    });
  }

  void _dismissKeyboard() {
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _startPromoTimer() {
    _promoTimer?.cancel();
    _promoTimer = null;
    _promoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_promoTimeLeft > 0) {
          _promoTimeLeft--;
        } else {
          _isFirstGiftPromoActive = false;
          timer.cancel();
        }
      });
    });
  }

  void _initPKStartAnimation() {
    _pkStartAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _pkLeftAnimation = Tween<double>(begin: -300, end: 0).animate(CurvedAnimation(parent: _pkStartAnimationController, curve: Curves.easeOutExpo));
    _pkRightAnimation = Tween<double>(begin: 300, end: 0).animate(CurvedAnimation(parent: _pkStartAnimationController, curve: Curves.easeOutExpo));
    _pkFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _pkStartAnimationController,
        curve: const Interval(0.8, 1.0, curve: Curves.easeIn),
      ),
    );
    _pkStartAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) setState(() => _showPKStartAnimation = false);
        });
      }
    });
  }

  void _playPKStartAnimation() {
    if (mounted) {
      setState(() => _showPKStartAnimation = true);
      _pkStartAnimationController.reset();
      _pkStartAnimationController.forward();
    }
  }

  // 统一处理退出逻辑（物理返回 or 点击按钮）
  void _handleExitLogic() {
    _dismissKeyboard();

    // 1. 如果是观众：直接退出
    if (!_isHost) {
      Navigator.of(context).pop();
      return;
    }

    // 2. 如果是主播：根据状态决定行为
    if (_pkStatus != PKStatus.idle) {
      // A. 如果正在 PK/连麦中 -> 弹出断开连接选项（不关播）
      _showDisconnectDialog();
    } else {
      // B. 如果是单人闲置状态 -> 弹出结束直播确认框（关播）
      _showCloseRoomDialog();
    }
  }

  // 显示断开连接的弹窗（原 PK 结束逻辑）
  void _showDisconnectDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.link_off, color: Colors.redAccent),
              title: const Text("断开连线/PK", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _requestEndPk(); // 调用接口断开 PK
              },
            ),
            const Divider(color: Colors.white10, height: 1),
            ListTile(
              leading: const Icon(Icons.close, color: Colors.white70),
              title: const Text("取消", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
          ],
        ),
      ),
    );
  }

  // 显示结束直播的确认框
  void _showCloseRoomDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        title: const Text("结束直播", style: TextStyle(color: Colors.white)),
        content: const Text("确定要结束当前直播吗？直播间将立即关闭。", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("取消", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx); // 关闭弹窗
              _closeRoomAsHost(); // 执行下播操作
            },
            child: const Text("结束直播", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 主播执行下播操作
  void _closeRoomAsHost() async {
    try {
      // 调用后端接口关闭房间，后端会广播 ROOM_CLOSE
      await HttpUtil().post("/api/room/close", data: {"roomId": int.parse(_roomId)});
    } catch (e) {
      debugPrint("下播请求失败: $e");
    } finally {
      // 无论接口成功与否，主播自己必须退出
      if (mounted) {
        if (_pkStatus != PKStatus.idle) {
          _disconnectCoHost();
        }
        Navigator.of(context).pop();
      }
    }
  }

  // 原有的关闭按钮事件，指向统一逻辑
  void _handleCloseButton() {
    _handleExitLogic();
  }

  // 观众收到直播结束通知
  void _showRoomClosedDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF222222),
          title: const Text("直播已结束", style: TextStyle(color: Colors.white)),
          content: const Text("主播已下播，感谢观看。", style: TextStyle(color: Colors.white70)),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).pop();
              },
              child: const Text("退出直播间", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _requestEndPk() async {
    try {
      await HttpUtil().post("/api/pk/pk_end", data: {"roomId": int.parse(_roomId)});
    } catch (e) {
      debugPrint("断开失败: $e");
    }
  }

  void _switchToOpponentRoom() {
    if (_isHost) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("主播不能离开自己的直播间"), backgroundColor: Colors.orange, duration: Duration(seconds: 2)));
      return;
    }
    if (_participants.length < 2) return;
    final opponent = _participants[1];
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => RealLivePage(
          userId: widget.userId,
          userName: widget.userName,
          avatarUrl: widget.avatarUrl,
          level: widget.level,
          isHost: false,
          roomId: opponent['roomId'].toString(),
          monthLevel: _monthLevel,
        ),
      ),
    );
  }

  void _addSocketChatMessage(
    String name,
    String content,
    Color color, {
    required int level,
    required String userId,
    required int monthLevel,
    required bool isHost,
  }) {
    _chatController.addMessage(
      ChatMessage(
        name: name,
        content: content,
        level: level,
        monthLevel: monthLevel,
        levelColor: color,
        isGift: false,
        isAnchor: isHost,
        userId: userId,
      ),
    );
  }

  void _addGiftMessage(
    String senderName,
    String giftName,
    int count, {
    String senderId = "",
    String senderAvatar = "",
    required int senderLevel,
    required int senderMonthLevel,
    required bool isHost,
  }) {
    _chatController.addMessage(
      ChatMessage(
        name: senderName,
        content: '送出了 $giftName x$count',
        level: senderLevel,
        monthLevel: senderMonthLevel,
        levelColor: Colors.yellow,
        isGift: true,
        isAnchor: isHost,
        userId: senderId,
      ),
    );
  }

  void _processGiftEvent(
    GiftItemData giftData,
    String senderName,
    String senderAvatar,
    bool isMe, {
    required String senderId,
    int count = 1,
    bool isHost = false,
    int senderLevel = 1,
    int senderMonthLevel = 0,
  }) {
    final comboKey = "${senderName}_${giftData.name}";
    if (isMe) _lastGiftSent = giftData;

    setState(() {
      final existingIndex = _activeGifts.indexWhere((g) => g.comboKey == comboKey);
      if (existingIndex != -1) {
        _activeGifts[existingIndex] = _activeGifts[existingIndex].copyWith(count: _activeGifts[existingIndex].count + count);
      } else {
        _processNewGift(
          GiftEvent(
            senderName: senderName,
            senderAvatar: senderAvatar,
            giftName: giftData.name,
            giftIconUrl: giftData.iconUrl,
            trayEffectUrl:
                "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/adornment/banner_tray/%E5%BE%A1%E9%BE%99%E6%B8%B8%E4%BE%A0%E7%A4%BC%E7%89%A9%E6%89%98%E7%9B%98.mp4",
            count: count,
            senderLevel: senderLevel,
            giftPrice: giftData.price,
            giftEffectUrl: giftData.effectAsset!,
            configJsonList: giftData.configJsonList,
          ),
        );
      }
      _addGiftMessage(
        senderName,
        giftData.name,
        count,
        senderId: senderId,
        senderLevel: senderLevel,
        senderMonthLevel: senderMonthLevel,
        isHost: isHost,
      );

      if (_pkStatus == PKStatus.playing) {
        int scoreToAdd = giftData.price * count;

        if (_isFirstGiftPromoActive && !_usersWhoUsedPromo.contains(senderId)) {
          scoreToAdd = scoreToAdd * 2;
          _usersWhoUsedPromo.add(senderId);
        }

        if (isMe) {
          _myPKScore += scoreToAdd;
          HttpUtil().post("/api/pk/update_score", data: {"roomId": int.parse(_roomId), "score": scoreToAdd});
        } else {
          _myPKScore += scoreToAdd;
        }
      }
    });

    final event = GiftEvent(
      senderName: senderName,
      senderAvatar: senderAvatar,
      giftName: giftData.name,
      giftIconUrl: giftData.iconUrl,
      trayEffectUrl:
          "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/adornment/banner_tray/%E5%BE%A1%E9%BE%99%E6%B8%B8%E4%BE%A0%E7%A4%BC%E7%89%A9%E6%89%98%E7%9B%98.mp4",
      count: count,
      senderLevel: senderLevel,
      giftPrice: giftData.price,
      giftEffectUrl: giftData.effectAsset!,
      configJsonList: giftData.configJsonList,
      // 如果 model 支持，传入 trayEffectUrl: giftData.trayEffectUrl
    );
    _trayLayerKey.currentState?.addTrayGift(event);
    // 改为调用特效层组件
    // if (giftData.effectAsset != null && giftData.effectAsset!.isNotEmpty) {
    //   _giftEffectKey.currentState?.addEffect(giftData.effectAsset!, giftData.id, giftData.configJsonList);
    // }
    if (isMe) _triggerComboMode();
  }

  Future<void> _sendGift(GiftItemData giftData) async {
    _dismissKeyboard();
    int countToSend = 1;

    int totalPrice = giftData.price * countToSend;

    if (_myCoins < totalPrice) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("余额不足，请充值"), backgroundColor: Colors.red));
      return;
    }

    try {
      final res = await HttpUtil().post("/api/gift/send", data: {"userId": int.parse(_myUserId), "giftId": giftData.id, "count": countToSend});

      if (!mounted) return;

      setState(() {
        if (res != null && res['newBalance'] != null) {
          _myCoins = _parseInt(res['newBalance']);
          _myLevel = _parseInt(res['newLevel']);
        } else {
          _myCoins -= totalPrice;
        }
        UserStore.to.updateCoin(_myCoins);
        UserStore.to.updateLevel(_myLevel);
        _userStatusNotifier.value = UserModel(
          _myCoins,
          _myLevel,
          monthLevel: _parseInt(res['monthLevel']),
          coinsToNextLevel: _parseInt(res['coinsToNextLevel']),
          coinsToNextLevelText: res['coinsToNextLevelText'],
          coinsNextLevelThreshold: _parseInt(res['coinsNextLevelThreshold']),
          coinsCurrentLevelThreshold: _parseInt(res['coinsCurrentLevelThreshold']),
        );
      });

      _sendSocketMessage(
        "GIFT",
        giftId: giftData.id,
        giftCount: countToSend,
        userName: _myUserName,
        avatar: _myAvatar,
        level: _myLevel,
        monthLevel: _monthLevel,
        score: giftData.price,
      );
    } catch (e) {
      debugPrint("❌ 送礼失败: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("发送失败: $e")));
    }
  }

  void _processNewGift(GiftEvent gift) {
    if (_activeGifts.length < _maxActiveGifts) {
      _activeGifts.add(gift);
    } else {
      _waitingQueue.add(gift);
    }
  }

  void _onGiftFinished(String giftId) {
    setState(() {
      _activeGifts.removeWhere((element) => element.id == giftId);
      if (_waitingQueue.isNotEmpty) _activeGifts.add(_waitingQueue.removeFirst());
    });
  }

  void _triggerComboMode() {
    if (!_showComboButton) {
      setState(() => _showComboButton = true);
      _comboScaleController.forward();
    }
    _countdownController.reset();
    _countdownController.forward();
  }

  // 左侧视频：必须加 mixWithOthers，防止被右侧或音乐打断
  void _initializeBackground() async {
    _bgController = VideoPlayerController.networkUrl(
      Uri.parse(_leftVideoUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true), // 关键！
    );
    try {
      await _bgController!.initialize();
      _bgController!.setLooping(true);
      if (_isVideoBackground) _bgController!.play();
      setState(() => _isBgInitialized = true);
    } catch (e) {}
  }

  // 右侧视频：同样加 mixWithOthers
  void _initializeRightVideo() async {
    _rightVideoController = VideoPlayerController.networkUrl(
      Uri.parse(_rightVideoUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true), // 关键！
    );
    try {
      await _rightVideoController!.initialize();
      _rightVideoController!.setLooping(true);
      if (_isRightVideoMode) _rightVideoController!.play();
      setState(() => _isRightVideoInitialized = true);
    } catch (e) {}
  }

  // 切换左侧（自己）的背景/视频
  void _toggleBackgroundMode() {
    setState(() {
      _isVideoBackground = !_isVideoBackground;
      if (_isVideoBackground) {
        if (_isBgInitialized) _bgController?.play();
      } else {
        if (_isBgInitialized) _bgController?.pause();
      }
    });
  }

  // 切换右侧（对手）的背景/视频
  void _toggleRightVideoMode() {
    setState(() {
      _isRightVideoMode = !_isRightVideoMode;
      if (_isRightVideoMode) {
        if (_isRightVideoInitialized) _rightVideoController?.play();
      } else {
        if (_isRightVideoInitialized) _rightVideoController?.pause();
      }
    });
  }

  void _showGiftPanel() {
    _dismissKeyboard();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => GiftPanel(
        initialGiftList: _giftList,
        myBalance: _myCoins,
        userStatusNotifier: _userStatusNotifier,
        onSend: (gift) {
          _sendGift(gift);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showMusicPanel() {
    _dismissKeyboard();
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (_) => const MusicPanel());
  }

  void _simulateVipEnter({
    required String overrideUserId,
    String? overrideName,
    String? overrideAvatar,
    required int overrideLevel,
    required int overrideMonthLevel,
    required bool isHost,
  }) {
    final names = ["顾北", "王校长", "阿特", "小柠檬"];
    final randomIdx = Random().nextInt(names.length);
    final name = overrideName ?? names[randomIdx];
    final event = EntranceEvent(
      userName: name,
      level: overrideLevel,
      monthLevel: overrideMonthLevel,
      avatarUrl: overrideAvatar ?? "https://picsum.photos/seed/${888 + randomIdx}/200",
      frameUrl: "https://cdn-icons-png.flaticon.com/512/8313/8313626.png",
    );
    _entranceKey.currentState?.addEvent(event);
    if (mounted) {
      _chatController.addMessage(
        ChatMessage(
          userId: overrideUserId,
          name: "",
          content: "$name 加入直播间！",
          level: overrideLevel,
          monthLevel: overrideMonthLevel,
          levelColor: const Color(0xFFFFD700),
          isAnchor: isHost,
        ),
      );
    }
  }

  // 简单的加载视图，替代复杂的骨架屏
  Widget _buildLoadingView() {
    String bgImage = _myAvatar; // 默认图
    String targetName = _currentName;

    if (widget.initialRoomData != null) {
      if (widget.initialRoomData!['coverImg'] != null) {
        bgImage = widget.initialRoomData!['coverImg'];
      } else if (widget.initialRoomData!['avatar'] != null) {
        bgImage = widget.initialRoomData!['avatar'];
      }
      if (widget.initialRoomData!['userName'] != null) {
        targetName = widget.initialRoomData!['userName'];
      }
    } else {
      bgImage = widget.avatarUrl;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          bgImage,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => Container(color: const Color(0xFF1A1A1A)),
        ),

        // 🟢 修改点：去掉了 BackdropFilter 和 ImageFilter.blur，只保留半透明黑底
        Positioned.fill(child: Container(color: Colors.black.withOpacity(0.6))),

        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                ),
                child: ClipOval(
                  child: Image.network(
                    bgImage,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => const Icon(Icons.person, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white70)),
              ),
              const SizedBox(height: 16),
              Text("正在进入 $targetName 的直播间...", style: const TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1)),
            ],
          ),
        ),
      ],
    );
  }

  // 🟢 核心修改：根据类型分发中间视图
  Widget _buildSingleModeContent(double topPadding) {
    // 🟢 复用 PK 模式中的 TopBar，确保统一
    final topBar = Container(
      margin: EdgeInsets.only(top: topPadding),
      height: 50, // 与 PK 模式一致
      child: BuildTopBar(
        key: const ValueKey("TopBar"),
        // 可选
        viewerListKey: _viewerListKey,
        // 🟢 传入 Key
        roomId: _roomId,
        onlineCount: _onlineCount <= 0 ? 1 : _onlineCount,
        title: "直播间",
        name: _currentName,
        avatar: _currentAvatar,
        anchorId: _currentUserId,
        onClose: _handleCloseButton,
      ),
    );

    switch (widget.roomType) {
      case LiveRoomType.video:
        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. 底层：视频内容 (背景已在内部处理)
            VideoRoomContentView(
              videoUrl:
                  "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/video/%E8%B7%A8%E4%B8%8D%E9%81%8E%E7%9A%84%E8%B7%9D%E9%9B%A2%E3%80%90DJ%E3%80%91%20-%20%E4%B8%83%E5%85%83%E3%80%8E%E6%88%91%E6%98%8E%E6%98%8E%E9%82%84%E6%98%AF%E6%9C%83%E7%AA%81%E7%84%B6%E6%83%B3%E8%B5%B7%E4%BD%A0%EF%BC%8C%E9%82%84%E6%98%AF%E6%9C%83%E5%81%B7%E5%81%B7%E9%97%9C%E5%BF%83%E4%BD%A0.mp4",
              // 使用左侧流地址作为视频源
              bgUrl: _currentBgImage,
              // 🟢 传入 personalPkBg
              isMuted: false,
              roomId: _roomId,
            ),
            // 2. 顶层：叠加 TopBar
            Positioned(top: 0, left: 0, right: 0, child: topBar),
          ],
        );
      case LiveRoomType.voice:
        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. 底层：视频内容 (背景已在内部处理)
            VoiceRoomContentView(
              key: _voiceRoomKey,
              anchorAvatar: "",
              currentBgImage: '234234',
              roomTitle: '345345',
              anchorName: 'werrwetert',
              roomId: _roomId,
            ),
            // 2. 顶层：叠加 TopBar
            Positioned(top: 0, left: 0, right: 0, child: topBar),
          ],
        );
      case LiveRoomType.music:
        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. 底层：听歌房内容
            VideoRoomContentView(
              videoUrl:
                  "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/video/%E8%B7%A8%E4%B8%8D%E9%81%8E%E7%9A%84%E8%B7%9D%E9%9B%A2%E3%80%90DJ%E3%80%91%20-%20%E4%B8%83%E5%85%83%E3%80%8E%E6%88%91%E6%98%8E%E6%98%8E%E9%82%84%E6%98%AF%E6%9C%83%E7%AA%81%E7%84%B6%E6%83%B3%E8%B5%B7%E4%BD%A0%EF%BC%8C%E9%82%84%E6%98%AF%E6%9C%83%E5%81%B7%E5%81%B7%E9%97%9C%E5%BF%83%E4%BD%A0.mp4",
              // 使用左侧流地址作为视频源
              bgUrl: _currentBgImage,
              // 🟢 传入 personalPkBg
              isMuted: false,
              roomId: _roomId,
            ),
            // 2. 顶层：强行叠加顶部栏（因为 MusicRoomContentView 是纯净的）
            Positioned(top: 0, left: 0, right: 0, child: topBar),
          ],
        );
      case LiveRoomType.normal:
      default:
        // 普通模式下，SingleModeView 通常自带了顶部栏或背景处理
        return Stack(
          children: [
            SingleModeView(
              roomId: _roomId,
              onlineCount: _onlineCount,
              isVideoBackground: _isVideoBackground,
              isBgInitialized: _isBgInitialized,
              bgController: _bgController,
              currentBgImage: _currentBgImage,
              title: "直播间",
              name: _currentName,
              avatar: _currentAvatar,
              onClose: _handleCloseButton,
              anchorId: _currentUserId,
            ),
            Positioned(
              top: MediaQuery.of(context).size.height * 0.2,
              left: 0,
              right: 0,
              child: Center(
                child: AvatarAnimation(avatarUrl: _currentAvatar, name: _currentName, isSpeaking: true, isRotating: true),
              ),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    const double topBarHeight = 50.0;

    double chatListHeight = 460.0; // 默认高度 (普通单人模式)
    final double safeBottom = MediaQuery.of(context).viewPadding.bottom;

    // 🟢 1. 重新规划弹幕区域的“基础高度”
    double baseChatListHeight = 460.0;

    if (_pkStatus != PKStatus.idle) {
      final double pkVideoHeight = size.width * 0.85;
      final double pkVideoBottomY = padding.top + topBarHeight + 105.0 + pkVideoHeight + 18;
      // 🟢 修复：减去 safeBottom，保证弹幕区完美顶在 PK 视频的下边缘！
      baseChatListHeight = size.height - pkVideoBottomY - safeBottom - 3;
    } else {
      switch (widget.roomType) {
        case LiveRoomType.music:
          baseChatListHeight = 320.0;
          break;
        case LiveRoomType.video:
          const double myVideoHeight = 240.0;
          const double headerHeight = 8;
          double topContentEndY = padding.top + topBarHeight + headerHeight + myVideoHeight;
          // 🟢 修复：同样减去 safeBottom
          baseChatListHeight = size.height - topContentEndY - safeBottom;
          break;
        case LiveRoomType.game:
          baseChatListHeight = 200.0;
          break;
        case LiveRoomType.normal:
        default:
          baseChatListHeight = 460.0;
          break;
      }
    }

    // 🟢 2. 神级动画平滑计算：底座锁定 + 顶部锚定，防止回弹“掉坑”
    final double safeBottomOffset = safeBottom > 0 ? safeBottom : 0;
    final double fixedBottomOffset = safeBottomOffset + 54; // 底部操作栏的绝对高度

    // 💡 绝对底部：键盘高度 和 操作栏高度，谁高听谁的！杜绝动画过程中的“掉坑现象”
    final double currentBottom = max(bottomInset, fixedBottomOffset);

    // 💡 动态高度：保证弹幕区【顶部边缘】在键盘动画起伏时纹丝不动！
    double currentHeight = (baseChatListHeight + safeBottomOffset) - currentBottom;
    if (currentHeight < 150) currentHeight = 150.0; // 极限防挤压保底

    const double gap1 = 105.0;
    final double pkVideoHeight = size.width * 0.85;
    final double pkVideoBottomY = padding.top + topBarHeight + gap1 + pkVideoHeight + 18;
    double entranceTop = pkVideoBottomY + 4;
    if (_pkStatus == PKStatus.idle) {
      // entranceTop = padding.top + topBarHeight + 20;
    }
    final bool showPromoBanner = _isFirstGiftPromoActive && _pkStatus == PKStatus.playing;
    final bool iHaveUsedPromo = _usersWhoUsedPromo.contains(_myUserId);
    if (showPromoBanner) entranceTop += 22 + 4;
    // 1. 使用 PopScope 包裹 Scaffold 拦截物理返回
    return PopScope(
      canPop: false, // 禁止直接退出
      onPopInvoked: (didPop) async {
        if (didPop) return;
        _handleExitLogic(); // 触发统一退出逻辑
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              child: _isLoadingDetail
                  ? _buildLoadingView()
                  : GestureDetector(
                      key: ValueKey(_roomId), // 切换房间时触发动画
                      behavior: HitTestBehavior.translucent,
                      onTap: _dismissKeyboard,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Positioned.fill(
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      image: DecorationImage(
                                        image: NetworkImage(_currentBgImage),
                                        fit: BoxFit.cover, // 铺满全屏
                                      ),
                                      gradient: const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [Color(0xFF100101), Color(0xFF141E28)],
                                      ),
                                    ),
                                  ),
                                ),

                                // 🟢 核心：根据 PK 状态决定显示 单人模式(分发) 还是 PK 模式
                                _pkStatus == PKStatus.idle
                                    ? _buildSingleModeContent(padding.top) // 传入 padding.top
                                    : Column(
                                        children: [
                                          Container(
                                            margin: EdgeInsets.only(top: padding.top),
                                            height: topBarHeight,
                                            child: BuildTopBar(
                                              key: const ValueKey("TopBar"),
                                              // 可选
                                              viewerListKey: _viewerListKey,
                                              // 🟢 传入 Key
                                              roomId: _roomId,
                                              onlineCount: _onlineCount <= 0 ? 1 : _onlineCount,
                                              title: "直播间",
                                              name: _currentName,
                                              avatar: _currentAvatar,
                                              onClose: _handleCloseButton,
                                              anchorId: _currentUserId,
                                            ),
                                          ),
                                          SizedBox(height: gap1),
                                          SizedBox(
                                            height: pkVideoHeight + 18,
                                            width: size.width,
                                            child: Stack(
                                              children: [
                                                Positioned(
                                                  top: (_pkStatus == PKStatus.playing || _pkStatus == PKStatus.punishment) ? 18 : 0,
                                                  left: 0,
                                                  right: 0,
                                                  bottom: 0,
                                                  child: PKRealBattleView(
                                                    leftVideoController: (_isVideoBackground && _isBgInitialized) ? _bgController : null,
                                                    leftBgImage: _isVideoBackground ? null : _currentBgImage,
                                                    leftName: _currentName,
                                                    leftAvatarUrl: _currentAvatar,
                                                    isRightVideoMode: _isRightVideoMode,
                                                    rightVideoController: (_isRightVideoMode && _isRightVideoInitialized)
                                                        ? _rightVideoController
                                                        : null,
                                                    isRotating: true,
                                                    rightAvatarUrl: _participants.length > 1
                                                        ? _participants[1]['avatar']
                                                        : "https://picsum.photos/200",
                                                    rightName: _participants.length > 1 ? _participants[1]['name'] : "对手主播",
                                                    rightBgImage: _participants.length > 1 ? (_participants[1]['pkBg'] ?? "") : "",
                                                    pkStatus: _pkStatus,
                                                    myScore: _myPKScore,
                                                    opponentScore: _opponentPKScore,
                                                    onTapOpponent: _switchToOpponentRoom,
                                                    isOpponentSpeaking: true,
                                                  ),
                                                ),
                                                if (_pkStatus == PKStatus.playing || _pkStatus == PKStatus.punishment)
                                                  Positioned(
                                                    top: 0,
                                                    left: 0,
                                                    right: 0,
                                                    child: PKScoreBar(
                                                      myScore: _myPKScore,
                                                      opponentScore: _opponentPKScore,
                                                      status: _pkStatus,
                                                      secondsLeft: _pkTimeLeft,
                                                    ),
                                                  ),
                                                Positioned(
                                                  top: (_pkStatus == PKStatus.playing || _pkStatus == PKStatus.punishment) ? 18 : 0,
                                                  left: 0,
                                                  right: 0,
                                                  child: Center(
                                                    child: PKTimer(
                                                      secondsLeft: _pkTimeLeft,
                                                      status: _pkStatus,
                                                      myScore: _myPKScore,
                                                      opponentScore: _opponentPKScore,
                                                    ),
                                                  ),
                                                ),
                                                Positioned(
                                                  right: 10,
                                                  bottom: 10,
                                                  child: Column(
                                                    children: [
                                                      _buildCircleBtn(
                                                        onTap: _showMusicPanel,
                                                        icon: const Icon(Icons.music_note, color: Colors.white, size: 20),
                                                        borderColor: Colors.purpleAccent,
                                                        label: "点歌",
                                                      ),
                                                      const SizedBox(height: 10),
                                                      _buildCircleBtn(
                                                        onTap: _toggleBackgroundMode,
                                                        icon: Icon(_isVideoBackground ? Icons.videocam : Icons.image, color: Colors.white, size: 20),
                                                        borderColor: Colors.cyanAccent,
                                                        label: "背景",
                                                      ),
                                                      const SizedBox(height: 10),
                                                      if (_pkStatus != PKStatus.idle)
                                                        _buildCircleBtn(
                                                          onTap: _toggleRightVideoMode,
                                                          icon: Icon(
                                                            _isRightVideoMode ? Icons.videocam : Icons.person,
                                                            color: Colors.white,
                                                            size: 20,
                                                          ),
                                                          borderColor: Colors.orangeAccent,
                                                          label: "对手",
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                // 🟢 1. 弹幕区：动态感知键盘高度！
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: currentBottom,
                                  height: currentHeight,
                                  child: RepaintBoundary(
                                    child: Column(
                                      children: [
                                        Expanded(
                                          // 🟢 神级交互：拦截边界滚动，直接驱动底层 PageView！
                                          child: NotificationListener<ScrollNotification>(
                                            onNotification: (ScrollNotification notification) {
                                              // 1. 手指刚按上去，或刚开始滑动
                                              if (notification is ScrollStartNotification) {
                                                if (_parentDrag != null) {
                                                  _parentDrag?.cancel();
                                                  _parentDrag = null;
                                                }
                                                _parentDragDistance = 0.0;

                                                // 判断手指按下瞬间，列表是否【已经】在顶部或底部边缘？
                                                final metrics = notification.metrics;
                                                if (metrics.pixels <= metrics.minScrollExtent + 2.0 ||
                                                    metrics.pixels >= metrics.maxScrollExtent - 2.0) {
                                                  _canForwardToParent = true;
                                                } else {
                                                  _canForwardToParent = false;
                                                }
                                              }
                                              // 2. 划到底部/顶部，触发了越界拖拽 (Overscroll)！
                                              else if (notification is OverscrollNotification) {
                                                if (!_canForwardToParent) return false;

                                                if (notification.dragDetails != null && widget.pageController != null) {
                                                  double dy = notification.dragDetails!.delta.dy;

                                                  // 🟢 核心修改：通过开关拦截特定方向的滑动！
                                                  // dy < 0 代表手指正在【往上滑】 (试图看下方的直播间)
                                                  if (dy < 0 && !_enableSwipeUpToSwitchRoom) return false;
                                                  // dy > 0 代表手指正在【往下滑】 (试图看上方的直播间)
                                                  if (dy > 0 && !_enableSwipeDownToSwitchRoom) return false;

                                                  if (_parentDrag == null) {
                                                    _parentDrag ??= widget.pageController!.position.drag(
                                                      DragStartDetails(globalPosition: notification.dragDetails!.globalPosition),
                                                      () {
                                                        _parentDrag = null;
                                                      },
                                                    );
                                                  }

                                                  _parentDragDistance += dy; // 累计拖拽距离

                                                  // 1:1 绝对跟手传递，没有任何死区延迟
                                                  _parentDrag?.update(
                                                    DragUpdateDetails(
                                                      sourceTimeStamp: notification.dragDetails!.sourceTimeStamp,
                                                      delta: Offset(0, dy),
                                                      primaryDelta: dy,
                                                      globalPosition: notification.dragDetails!.globalPosition,
                                                    ),
                                                  );
                                                }
                                              }
                                              // 3. 手指往回拉 (反向拉动必须跟着手指退回去)
                                              else if (notification is ScrollUpdateNotification) {
                                                if (_parentDrag != null && notification.dragDetails != null) {
                                                  double dy = notification.dragDetails!.delta.dy;
                                                  _parentDragDistance += dy;

                                                  _parentDrag?.update(
                                                    DragUpdateDetails(
                                                      sourceTimeStamp: notification.dragDetails!.sourceTimeStamp,
                                                      delta: Offset(0, dy),
                                                      primaryDelta: dy,
                                                      globalPosition: notification.dragDetails!.globalPosition,
                                                    ),
                                                  );
                                                }
                                              }
                                              // 4. 手指离开屏幕，滑动结束
                                              else if (notification is ScrollEndNotification) {
                                                if (_parentDrag != null) {
                                                  Velocity finalVelocity = notification.dragDetails?.velocity ?? Velocity.zero;

                                                  // 防止“稍微滑一下就切房” (拖拽不足60像素强制回弹)
                                                  if (_parentDragDistance.abs() < 60.0) {
                                                    finalVelocity = Velocity.zero;
                                                  }

                                                  _parentDrag?.end(
                                                    DragEndDetails(velocity: finalVelocity, primaryVelocity: finalVelocity.pixelsPerSecond.dy),
                                                  );
                                                  _parentDrag = null;
                                                }
                                                _parentDragDistance = 0.0;
                                                _canForwardToParent = false;
                                              }
                                              return false; // 不拦截，允许正常气泡冒泡
                                            },
                                            child: Align(
                                              alignment: Alignment.bottomLeft,
                                              child: SizedBox(
                                                width: size.width * 0.80, // 保持 80% 大宽屏，左手无压力
                                                height: double.infinity,
                                                child: ScrollConfiguration(
                                                  behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
                                                  child: BuildChatList(
                                                    key: _chatListKey,
                                                    bottomInset: 0,
                                                    roomId: _roomId,
                                                    controller: _chatController,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // 🟢 2. 底部操作栏：彻底独立，死死钉在屏幕最底部！
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  // 核心魔法：永远固定在 safeBottom，绝对不加 bottomInset！
                                  bottom: safeBottom > 0 ? safeBottom : 0,
                                  child: BuildBottomInputBar(
                                    onTapInput: _showInputSheet, // 点击唤起你自定义的键盘 Overlay
                                    onTapGift: _showGiftPanel,
                                    isHost: _isHost,
                                    onTapPK: _onTapStartPK,
                                  ),
                                ),

                                // 挂载 PK 匹配管理器
                                PkMatchManager(
                                  key: _pkMatchManagerKey,
                                  roomId: _roomId,
                                  currentUserId: _myUserId,
                                  currentUserName: _myUserName,
                                  currentUserAvatar: _myAvatar,
                                  onPkStarted: () {
                                    // PK 开始的逻辑通常由 PK_START 消息驱动
                                  },
                                ),

                                if (showPromoBanner)
                                  Positioned(
                                    top: pkVideoBottomY + 4,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: Container(
                                        height: 22,
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        decoration: BoxDecoration(
                                          gradient: iHaveUsedPromo
                                              ? LinearGradient(colors: [Colors.green.withOpacity(0.8), Colors.teal.withOpacity(0.8)])
                                              : LinearGradient(colors: [Colors.white.withOpacity(0.15), Colors.pinkAccent.withOpacity(0.5)]),
                                          borderRadius: BorderRadius.circular(11),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              iHaveUsedPromo ? "首翻已达成" : "首送翻倍",
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              StringTool.formatTime(_promoTimeLeft),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontFamily: "monospace",
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                Positioned(
                                  top: entranceTop,
                                  left: 0,
                                  child: LiveUserEntrance(key: _entranceKey),
                                ),
                                // if (bottomInset == 0)
                                //   Positioned(
                                //     left: 0,
                                //     width: size.width,
                                //     top: pkVideoBottomY - 160,
                                //     height: 160,
                                //     bottom: null,
                                //     child: IgnorePointer(
                                //       child: Align(
                                //         alignment: Alignment.bottomLeft,
                                //         child: Padding(
                                //           padding: const EdgeInsets.only(left: 10),
                                //           child: Column(
                                //             crossAxisAlignment: CrossAxisAlignment.start,
                                //             mainAxisSize: MainAxisSize.min,
                                //             children: _activeGifts
                                //                 .map(
                                //                   (giftEvent) => AnimatedGiftItem(
                                //                     key: ValueKey(giftEvent.id),
                                //                     giftEvent: giftEvent,
                                //                     onFinished: () => _onGiftFinished(giftEvent.id),
                                //                   ),
                                //                 )
                                //                 .toList(),
                                //           ),
                                //         ),
                                //       ),
                                //     ),
                                //   ),
                                if (_showPKStartAnimation)
                                  Positioned.fill(
                                    child: Container(
                                      color: Colors.black.withOpacity(0.7),
                                      child: AnimatedBuilder(
                                        animation: _pkStartAnimationController,
                                        builder: (context, child) {
                                          return Opacity(
                                            opacity: _pkFadeAnimation.value,
                                            child: Center(
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Transform.translate(
                                                    offset: Offset(_pkLeftAnimation.value, 0),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                      decoration: BoxDecoration(
                                                        gradient: const LinearGradient(
                                                          colors: [Color(0xFFFE4164), Color(0xFFFF7F7F)],
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                        ),
                                                        borderRadius: const BorderRadius.only(
                                                          topLeft: Radius.circular(12),
                                                          bottomLeft: Radius.circular(12),
                                                        ),
                                                        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 15, spreadRadius: 2)],
                                                      ),
                                                      child: const Text(
                                                        "P",
                                                        style: TextStyle(
                                                          fontSize: 28,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.white,
                                                          shadows: [Shadow(blurRadius: 5, color: Colors.red)],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Transform.translate(
                                                    offset: Offset(_pkRightAnimation.value, 0),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                      decoration: BoxDecoration(
                                                        gradient: const LinearGradient(
                                                          colors: [Color(0xFF3A7BD5), Color(0xFF00D2FF)],
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                        ),
                                                        borderRadius: const BorderRadius.only(
                                                          topRight: Radius.circular(12),
                                                          bottomRight: Radius.circular(12),
                                                        ),
                                                        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.5), blurRadius: 15, spreadRadius: 2)],
                                                      ),
                                                      child: const Text(
                                                        "K",
                                                        style: TextStyle(
                                                          fontSize: 28,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.white,
                                                          shadows: [Shadow(blurRadius: 5, color: Colors.blue)],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Positioned.fill(
                            child: ChatInputOverlay(
                              key: _inputOverlayKey,
                              onSend: (text) {
                                _sendSocketMessage(
                                  "CHAT",
                                  content: text,
                                  userName: _myUserName,
                                  level: _myLevel,
                                  monthLevel: _monthLevel,
                                  isHost: _isHost,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            UserEntranceEffectLayer(key: _entranceEffectKey),
            Positioned.fill(child: GiftEffectLayer(key: _giftEffectKey)),
            GiftTrayEffectLayer(
              key: _trayLayerKey,
              enableEffectDelay: false,
              onEffectTrigger: (GiftEvent event) {
                if (event.giftEffectUrl.isNotEmpty) {
                  _giftEffectKey.currentState?.addEffect(event.giftEffectUrl, event.id, event.configJsonList);
                }
              },
            ),
            if (_showComboButton && _lastGiftSent != null)
              Positioned(
                right: 16,
                bottom: bottomInset + 80,
                child: ScaleTransition(
                  scale: CurvedAnimation(parent: _comboScaleController, curve: Curves.elasticOut),
                  child: GestureDetector(
                    onTap: () => _sendGift(_lastGiftSent!),
                    child: AnimatedBuilder(
                      animation: _countdownController,
                      builder: (context, child) {
                        return SizedBox(
                          width: 76,
                          height: 76,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 76,
                                height: 76,
                                child: CircularProgressIndicator(
                                  value: 1.0 - _countdownController.value,
                                  strokeWidth: 4,
                                  backgroundColor: Colors.white24,
                                  valueColor: const AlwaysStoppedAnimation(Colors.amber),
                                ),
                              ),
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFF0080), Color(0xFFFF8C00)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                alignment: const Alignment(0, -0.15),
                                child: const Text(
                                  "连击",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleBtn({required VoidCallback onTap, required Widget icon, required Color borderColor, String? label}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
              border: Border.all(color: borderColor.withOpacity(0.5), width: 1.5),
            ),
            alignment: Alignment.center,
            child: icon,
          ),
          if (label != null) ...[const SizedBox(height: 2), Text(label, style: const TextStyle(color: Colors.white, fontSize: 10))],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    WakelockPlus.disable();
    _socketSubscription?.cancel();
    _channel?.sink.close();
    _heartbeatTimer?.cancel();
    _bgController?.dispose();
    _rightVideoController?.dispose(); // 销毁右侧视频
    try {
      AIMusicService().stopMusic();
    } catch (e) {}
    _comboScaleController.dispose();
    _countdownController.dispose();
    _pkStartAnimationController.dispose();
    _pkTimer?.cancel();
    _promoTimer?.cancel();
    super.dispose();
  }
}
