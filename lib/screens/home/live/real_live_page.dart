import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_live/screens/home/live/subpages/dynamic_pk_view/widgets/player_action_bottom_sheet.dart';
import 'package:flutter_live/screens/home/live/subpages/pk_result/pk_result.dart';
import 'package:flutter_live/screens/home/live/widgets/avatar_animation.dart';
import 'package:flutter_live/screens/home/live/widgets/chat/build_chat_list.dart';
import 'package:flutter_live/screens/home/live/widgets/effect_player/gift_tray_effect_layer.dart';
import 'package:flutter_live/screens/home/live/widgets/effect_player/user_entrance_effect_layer.dart';
import 'package:flutter_live/screens/home/live/widgets/live_user_entrance.dart';
import 'package:flutter_live/screens/home/live/widgets/profile/live_user_profile_popup.dart';
import 'package:flutter_live/screens/home/live/widgets/room_mode/video_room_content_view.dart';
import 'package:flutter_live/screens/home/live/widgets/room_mode/voice_room_content_view.dart';
import 'package:flutter_live/screens/home/live/widgets/top_bar/viewer_list.dart';
import 'package:flutter_live/screens/home/live/subpages/dynamic_pk_view/dynamic_pk_battle_view.dart';
import 'package:flutter_live/store/user_store.dart';
import 'package:flutter_live/tools/DictTool.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../bridge/hardcore_mixer.dart';
import '../../../models/user_models.dart';
import '../../../services/ai_realtime_voice_service.dart';
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
import 'widgets/effect_player/gift_effect_layer.dart';

// 引入 PK 匹配管理器
import 'widgets/pk_match_manager.dart';

// 🚀 全局资源清理锁：保证新老房间绝对不会发生算力追尾！
class LiveRoomConfig {
  static Future<void>? pendingCleanupTask;
}

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

class _RealLivePageState extends State<RealLivePage> with TickerProviderStateMixin, WidgetsBindingObserver {
  // 🟢 1. 新增：专门用于监听键盘高度的“局部刷新通知器”
  final ValueNotifier<double> _keyboardNotifier = ValueNotifier(0.0);
  bool _isSafeToPlayEffects = false; // 默认不安全
  // 加载状态，默认为 true
  bool _isLoadingDetail = true;
  bool _isRoomActive = false;
  Timer? _viewChangeTimer;
  static const MethodChannel _nativePlayer = MethodChannel('com.ai.voice/native_player');

  // PK时长配置
  int _pkDuration = 90; // 默认为90秒
  int _punishmentDuration = 20;

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
  String _myLevelHonourBuff = ""; // 定义在 State 最上面
  late int _monthLevel;
  late String _myAvatar;
  late String _roomId;

  // 🚀 新增：用来记录当前被“设为主咖(放大)”的那个人的 roomId
  String? _focusedRoomId;
  final GlobalKey<ChatInputOverlayState> _inputOverlayKey = GlobalKey();
  final GlobalKey<VoiceRoomContentViewState> _voiceRoomKey = GlobalKey();
  final GlobalKey<UserEntranceEffectLayerState> _entranceEffectKey = GlobalKey();
  final GlobalKey<PkResultPageState> _pkResultKey = GlobalKey<PkResultPageState>();

  // 🟢 1. 定义一个 GlobalKey 用来控制榜单组件
  final GlobalKey<ViewerListState> _viewerListKey = GlobalKey<ViewerListState>();

  // 🟢 1. 定义 PKScoreBar 的专属 GlobalKey
  final GlobalKey<PKScoreBarState> _pkScoreBarKey = GlobalKey<PKScoreBarState>();

  //控制进场组件的 Key
  final GlobalKey<LiveUserEntranceState> _entranceKey = GlobalKey<LiveUserEntranceState>();
  final GlobalKey<GiftTrayEffectLayerState> _trayLayerKey = GlobalKey();

  // 用于控制特效层的 Key
  final GlobalKey<GiftEffectLayerState> _giftEffectKey = GlobalKey();

  // 用于控制 PK 匹配管理器的 Key
  final GlobalKey<PkMatchManagerState> _pkMatchManagerKey = GlobalKey();

  late int _onlineCount = 0;
  late bool _isHost = false;
  late bool _isRobotActive = false;
  final GlobalKey _chatListKey = GlobalKey();

  // 用户余额
  int _myCoins = 0;

  final String _wsUrl = "ws://${HttpUtil.getBaseIpPort}/ws/live";

  final _enableGlobalBackgroundImage = false;
  final String _globalBackgroundImage = "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/bg_15.jpg";

  // --- 左侧（自己）视频控制 ---
  Player? _bgPlayer;
  VideoController? _bgController;

  // 🟢 新增：动态管理所有参与者的视频流控制器
  final Map<String, Player> _players = {};
  final Map<String, VideoController> _videoControllers = {};
  bool _isBgInitialized = false;
  bool _isVideoBackground = false;
  String _currentBgImage = "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/bg_15.jpg";
  String _leftCurrentStreamUrl = "";

  // --- 右侧（对手）视频控制 ---
  Player? _rightPlayer;
  VideoController? _rightVideoController;
  bool _isRightVideoInitialized = false;
  bool _isRightVideoMode = false; // 默认开启右侧视频
  // 🟢 错峰点火排队锁，防止多次拉取数据导致并发冲突
  bool _isIgniting = false;
  int _currentUserId = 1;
  String _currentName = "";
  Timer? _heartbeatTimer;
  bool _isDisposed = false;
  bool _isSwitchingRoom = false; // 🟢 新增：用来标记是否正在进入对手房间
  String _currentAvatar = "";
  late String _leftVideoUrl = "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/bg.MOV";
  final String _rightVideoUrl = "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/234.mp4";

  PKStatus _pkStatus = PKStatus.idle;
  int _myPKScore = 0;
  int _opponentPKScore = 0;

  // 🟢 1. 新增：专门用于 PK 分数局部刷新的触发器
  final ValueNotifier<int> _pkScoreUpdateTrigger = ValueNotifier(0);
  int _pkTimeLeft = 0;
  Timer? _pkTimer;

  // 🟢 1. 新增：记录暴击卡到期时间
  final Map<String, DateTime> _critEndTimes = {};
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
  late Animation<double> _comboScaleAnimation; // 🟢 补上这个缺失的声明！
  late AnimationController _countdownController;

  bool _showPKStartAnimation = false;
  late AnimationController _pkStartAnimationController;
  late Animation<double> _pkLeftAnimation;
  late Animation<double> _pkRightAnimation;
  late Animation<double> _pkFadeAnimation;

  final ValueNotifier<UserModel> _userStatusNotifier = ValueNotifier(
    UserModel(0, 0, coinsToNextLevel: 0, coinsNextLevelThreshold: 0, coinsToNextLevelText: "0", coinsCurrentLevelThreshold: 0, monthLevel: 0),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      _isRoomActive = true;
      // 让页面如丝般顺滑地滑进来之后，再开始疯狂发起 HTTP 请求和拉流！
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _resumeRoom();
        }
      });
    } else {
      // 如果不在屏幕中央，只显示封面加载中，不拉流不断连
      _isLoadingDetail = true;
    }

    _comboScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.0,
      upperBound: 1.0,
      debugLabel: 'real_live_page',
    );
    // 🟢 极其重要：必须在这里把曲线动画定义好，绝不能在 build 方法里直接 new！
    _comboScaleAnimation = CurvedAnimation(parent: _comboScaleController, curve: Curves.elasticOut);
    _countdownController = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _countdownController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _comboScaleController.reverse().then((_) {
          // 🟢 终极修复 3：异步动画结束后的回调，必须再次判断 mounted！
          if (mounted) {
            setState(() {
              _showComboButton = false;
              _lastGiftSent = null;
            });
          }
        });
      }
    });
    // _startEnterRoomSequence();
    // 进房 3 秒后，视频点火结束，才允许播放高耗能特效
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _isSafeToPlayEffects = true;
    });
  }

  int _parseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  // 🟢 新增：监听 PageView 上下滑动带来的状态变化
  // 🟢 终极形态：基于物理引擎状态的智能防抖
  @override
  void didUpdateWidget(covariant RealLivePage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isCurrentView != oldWidget.isCurrentView) {
      _viewChangeTimer?.cancel();

      if (widget.isCurrentView) {
        // 滑入当前直播间：立刻点火，绝不拖泥带水
        if (mounted && !_isRoomActive) {
          _isRoomActive = true;
          debugPrint("👉 确定滑入直播间 ${widget.roomId}，立刻恢复视听...");
          _resumeRoom();
        }
      } else {
        // 尝试滑出：进入“状态巡逻”模式，防误触、防悬停
        _checkAndPause();
      }
    }
  }

  // 🟢 终极形态：加入“帧同步”时间差保护的巡逻兵
  void _checkAndPause() {
    if (!mounted || widget.isCurrentView) return;

    bool isBetweenPages = false;

    if (widget.pageController != null && widget.pageController!.hasClients) {
      double page = widget.pageController!.page ?? 0.0;
      // 只要 page 不是精确的整数（允许 0.01 的极小误差），
      // 就说明用户的手指还在屏幕上拖拽（悬停），或者页面还在做回弹/翻页动画！
      if ((page - page.round()).abs() > 0.01) {
        isBetweenPages = true;
      }
    } else {
      // 兜底：如果没传 pageController，退回到 500ms 盲猜模式
      _viewChangeTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted && !widget.isCurrentView && _isRoomActive) {
          _isRoomActive = false;
          _pauseRoom();
        }
      });
      return;
    }

    if (isBetweenPages) {
      // 🚨 页面悬停或正在滚动中！继续高频巡逻 (50ms)，死死咬住音频！
      _viewChangeTimer = Timer(const Duration(milliseconds: 50), _checkAndPause);
    } else {
      // ✅ 页面物理滚动已经完全停止，稳稳落在了一个整数页面上。
      // 🛑 致命关键点：此时它可能是落到了【下一个房间】，也可能是【反悔弹回了本房间】！
      // 此时立刻给一个 200ms 的“死缓期”。
      _viewChangeTimer = Timer(const Duration(milliseconds: 200), () {
        // 如果 200ms 后，父组件依然没有把 isCurrentView 变成 true，说明真的滑走了！
        if (mounted && !widget.isCurrentView && _isRoomActive) {
          _isRoomActive = false;
          debugPrint("👈 页面已滑出 ${widget.roomId} 且未反悔，安全清理资源...");
          _pauseRoom();
        }
      });
    }
  }

  // 🟢 新增：滑入房间时的恢复逻辑 (把你原来 initState 里的启动代码放进来)
  void _resumeRoom() {
    _players.values.forEach((p) => p.play()); // 换成 _players
    // 🚀 终极防崩修复：加上 .catchError 拦截异步异常
    _nativePlayer.invokeMethod('initPlayer', {'sampleRate': 24000, 'roomId': _roomId}).catchError((e) {
      debugPrint("忽略插件异常: $e");
    });
    _startEnterRoomSequence();
    if (_isVideoBackground && _isBgInitialized) _bgPlayer?.play();
    if (_isRightVideoMode && _isRightVideoInitialized) _rightPlayer?.play();
  }

  // 🟢 新增：滑出房间时的清理逻辑 (极其重要！防卡死、防串音)
  void _pauseRoom() {
    _players.values.forEach((p) => p.pause()); // 换成 _players
    _socketSubscription?.cancel();
    _channel?.sink.close();
    _heartbeatTimer?.cancel();
    _channel = null;

    _bgPlayer?.pause();
    _rightPlayer?.pause();

    _pkTimer?.cancel();
    _promoTimer?.cancel();

    setState(() {
      _activeGifts.clear();
      _waitingQueue.clear();
      _showPKStartAnimation = false;
    });
  }

  /// 确保视频在切换界面后继续播放（包括左侧和右侧）
  void _ensureVideosPlaying() {
    if (_isVideoBackground && _isBgInitialized && _bgPlayer != null) {
      if (!_bgPlayer!.state.playing) _bgPlayer!.play();
    }
    if (_isRightVideoMode && _isRightVideoInitialized && _rightPlayer != null) {
      if (!_rightPlayer!.state.playing) _rightPlayer!.play();
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
          final decos = res['decorations'];
          if (decos != null) {
            _myLevelHonourBuff = decos['levelHonourBuff']?.toString() ?? "";
          }
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
            levelHonourBuffUrl: _myLevelHonourBuff,
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
        levelHonourBuff: _myLevelHonourBuff, // 🚀 传下去
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
    // 🚀 核心修复 1：把 info 接口提到最前面！因为后面的长连接需要拿它的 Buff 数据
    await _fetchUserBalance();

    // 🚀 核心修复 2：把进房记录单独包起来，它就算是报错了，也绝对不影响后续的核心流程！
    try {
      final res = await HttpUtil().post(
        "/api/room/join",
        // 💡 顺手把致命的 int.parse 改成 tryParse 防崩！
        data: {"roomId": int.tryParse(_roomId) ?? 0, "userId": _myUserId},
      );

      if (mounted && res != null && res['onlineCount'] != null) {
        setState(() {
          _onlineCount = _parseInt(res['onlineCount']);
        });
      }
    } catch (e) {
      debugPrint("进房记录接口报错(可忽略，不影响主流程): $e");
    }

    if (!mounted || _isDisposed) return;
    // 此时 info 已经拿到了，去连 WebSocket 就会顺带把你正确的 Buff 传给服务器
    _connectWebSocket();

    if (!mounted || _isDisposed) return;
    _fetchRoomDetailAndSyncState();
  }

  void _fetchRoomDetailAndSyncState() async {
    // 开启 Loading 状态
    // if (mounted) setState(() => _isLoadingDetail = true);

    try {
      final res = await HttpUtil().get("/api/pk/detail", params: {"roomId": int.parse(_roomId), "userId": _myUserId, "userName": _myUserName});
      final data = res;
      String bgmUrl = data['currentResourceUrl'];
      int startTimeMs = data['bgmStartTime'];
      if (bgmUrl.isNotEmpty) {
        // 直接喂给你的智能闪避播放器，它会自动计算过去的时间并跳转！
        if (widget.roomType != LiveRoomType.video) {
          AIMusicService().syncAndPlayBgm(_roomId, bgmUrl, startTimeMs);
        }
      }

      if (data['pkInfo'] != null) {
        final pkInfo = data['pkInfo'];
        final int status = _parseInt(pkInfo['status']);
        final String startTimeStr = pkInfo['startTime'];

        _pkDuration = _parseInt(pkInfo['duration'], defaultValue: 300);
        _punishmentDuration = _parseInt(pkInfo['punishmentDuration'], defaultValue: 30);
        setState(() {
          _participants = pkInfo['participants'] as List;
          for (var p in _participants) {
            if (p['isMuted'] == null) {
              p['isMuted'] = (p['roomId'].toString() != _roomId);
            }
          }
          _pkStatus = DictTool.getPkStatus(status);
          Future.delayed(const Duration(milliseconds: 500), () async {
            if (mounted && !_isDisposed) {
              // 🚀🚀🚀 终极防撞车：检查老房间死透了没有？没死透就一直等！
              if (LiveRoomConfig.pendingCleanupTask != null) {
                debugPrint("⏳ 等待上一个房间释放底层资源...");
                await LiveRoomConfig.pendingCleanupTask;
                LiveRoomConfig.pendingCleanupTask = null;
                debugPrint("✅ 资源释放完毕，新房间开始点火！");
              }

              _syncVideoControllers();
            }
          });
          if (_participants.isNotEmpty) {
            _currentName = _participants[0]['name'] ?? _currentName;
            _currentAvatar = _participants[0]['avatar'] ?? _currentAvatar;
            _currentBgImage = _participants[0]['personalPkBg'] ?? _currentBgImage;
            _leftCurrentStreamUrl = _participants[0]['streamUrl'] ?? _leftCurrentStreamUrl;

            // 🟢 1. 找出“我方”的阵营 ID (teamId)
            int myCamp = 0;
            for (var p in _participants) {
              if (p['roomId'].toString() == _roomId) {
                myCamp = _parseInt(p['teamId']);
                break;
              }
            }

            // 🟢 2. 动态计算红蓝血条分数
            int mySum = 0;
            int enemySum = 0;
            for (var p in _participants) {
              int s = _parseInt(p['score']);
              int tId = _parseInt(p['teamId']);
              String rId = p['roomId'].toString();

              if (myCamp == 0 || tId == 0) {
                // 🔥 抢第一模式 (teamId=0)：左边只显示我自己，右边显示其他对手里的最高分
                if (rId == _roomId) {
                  mySum = s;
                } else {
                  if (s > enemySum) enemySum = s;
                }
              } else {
                // 🔥 组队/1v1模式：只要 teamId 和我一样就加到 mySum，不一样就加到 enemySum
                if (tId == myCamp) {
                  mySum += s;
                } else {
                  enemySum += s;
                }
              }
            }

            _myPKScore = mySum;
            _opponentPKScore = enemySum;

            // 🟢 新增：遍历所有参与者，不论 2个 还是 10个，全部提取到期时间
            _critEndTimes.clear();
            for (var p in _participants) {
              final String pRoomId = p['roomId'].toString();
              final int critLeft = _parseInt(p['critSecondsLeft']);
              if (critLeft > 0) {
                _critEndTimes[pRoomId] = DateTime.now().add(Duration(seconds: critLeft));
              }
            }
          }
        });

        DateTime startTime = DateTime.parse(startTimeStr);
        int elapsedSeconds = DateTime.now().difference(startTime).inSeconds;
        if (elapsedSeconds < 0) {
          elapsedSeconds = 0; // 如果还没到开始时间，视为已开始0秒
        }

        if (status == 1) {
          _pkStatus = PKStatus.playing;
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
          _pkStatus = PKStatus.coHost;
          DateTime startTime = DateTime.parse(startTimeStr);
          int totalElapsed = DateTime.now().difference(startTime).inSeconds;
          int coHostElapsed = totalElapsed - _pkDuration - _punishmentDuration;
          _enterCoHostPhase(initialElapsedTime: totalElapsed > 0 ? totalElapsed : 0, serverStartTime: startTime);
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
        _isRobotActive = data['isRobotActive'];
        _isHost = _currentUserId.toString() == UserStore.to.userId;
      });
    } catch (e) {
      debugPrint("❌ 同步房间详情失败: $e");
    } finally {
      // 无论成功失败，关闭 Loading 状态
      if (mounted) setState(() => _isLoadingDetail = false);
    }
  }

  // 🚀🚀🚀 终极改造：必须是 async 异步方法！
  Future<void> _syncVideoControllers() async {
    // if (_isIgniting) return;
    // _isIgniting = true; // 上锁
    //
    // Set<String> currentRoomIds = {};
    // List<Map<String, dynamic>> needIgnitionList = [];
    //
    // // 1. 过滤名单
    // for (var p in _participants) {
    //   String pRoomId = p['roomId'].toString();
    //   String streamUrl = p['streamUrl']?.toString().trim() ?? "";
    //   currentRoomIds.add(pRoomId);
    //
    //   if ((streamUrl.startsWith("http") || streamUrl.startsWith("rtmp")) && !_players.containsKey(pRoomId)) {
    //     needIgnitionList.add(p);
    //   }
    // }
    //
    // // 2. 清理退出连麦的人
    // final keysToRemove = _players.keys.where((k) => !currentRoomIds.contains(k)).toList();
    // for (var k in keysToRemove) {
    //   try {
    //     await _players[k]?.open(Playlist([]));
    //     _players[k]?.dispose();
    //   } catch (e) {}
    //   _players.remove(k);
    //   _videoControllers.remove(k);
    // }
    // if (keysToRemove.isNotEmpty && mounted) setState(() {});
    //
    // // 3. 🚦 真正的极限排队软解点火
    // for (var p in needIgnitionList) {
    //   if (!mounted || _isDisposed || _isSwitchingRoom) break;
    //
    //   String pRoomId = p['roomId'].toString();
    //   String streamUrl = p['streamUrl']?.toString().trim() ?? "";
    //
    //   if (!_players.containsKey(pRoomId)) {
    //     debugPrint("📺 [排队点火] 准备启动房间 $pRoomId ...");
    //
    //     final player = Player(
    //       configuration: const PlayerConfiguration(
    //         bufferSize: 1024 * 512, // 限制内存
    //       ),
    //     );
    //
    //     // 🌟 必须软解！苹果硬件最多只给 6 个，超过必报 EXC_BAD_ACCESS 闪退！
    //     final controller = VideoController(
    //       player,
    //       configuration: const VideoControllerConfiguration(
    //         enableHardwareAcceleration: false, // 👈 救命参数必须加回来！
    //       ),
    //     );
    //
    //     _players[pRoomId] = player;
    //     _videoControllers[pRoomId] = controller;
    //     player.setPlaylistMode(PlaylistMode.loop);
    //     bool initialMute = p['isMuted'] ?? (pRoomId != _roomId);
    //     player.setVolume(initialMute ? 0.0 : 100.0);
    //     // if (pRoomId != _roomId) player.setVolume(90.0);
    //
    //     // 🚀 核心魔法 1：先把空的壳子丢给 Flutter 去渲染，此时不耗费 CPU
    //     if (mounted) setState(() {});
    //
    //     // 🚀 核心魔法 2：等 UI 画完壳子后，强行休眠 100 毫秒！
    //     await Future.delayed(const Duration(milliseconds: 100));
    //
    //     // 🚀 核心魔法 3：后台静默拉流
    //     try {
    //       await player.open(Media(streamUrl), play: _pkStatus != PKStatus.idle);
    //     } catch (e) {}
    //
    //     // 🚀 核心魔法 4：拉完一路流，强行让 CPU 休息 300 毫秒，绝不让 9 路软解瞬间把主线程堵死！
    //     await Future.delayed(const Duration(milliseconds: 300));
    //   }
    // }
    //
    // _isIgniting = false; // 解锁
  }

  // 🧹 真正的错峰销毁，放在页面彻底不可见之后执行
  void _clearAllVideos() {
    final playersToDispose = _players.values.toList();
    _players.clear();
    _videoControllers.clear();

    // 开启一个独立的异步任务，每隔 150 毫秒杀一个，绝不卡主线程
    Future(() async {
      for (var p in playersToDispose) {
        try {
          p.dispose();
        } catch (e) {}
        await Future.delayed(const Duration(milliseconds: 150));
      }
    });

    // 🚀🚀🚀 核心防闪退装甲：dispose 之后必须设为 null！绝不允许后续的游离代码再次操作它！
    try {
      _bgPlayer?.dispose();
    } catch (e) {}
    _bgPlayer = null;
    _bgController = null;

    try {
      _rightPlayer?.dispose();
    } catch (e) {}
    _rightPlayer = null;
    _rightVideoController = null;
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
      final String senderBuff = data['levelHonourBuff']?.toString() ?? '';
      switch (type) {
        case "ENTER":
        // 定义执行逻辑的闭包
          void executeLogic() {
            if (!mounted) return;
            // 提取 ID 解析逻辑，避免重复调用 int.parse
            final int userId = int.parse(joinerId);

            // 🚀🚀🚀 核心改动 1：智能解析后端传来的 extraConfig
            Map<String, dynamic>? extraConfig;
            if (data['extraConfig'] != null) {
              if (data['extraConfig'] is String) {
                try {
                  extraConfig = jsonDecode(data['extraConfig']);
                } catch (e) {
                  debugPrint("解析 extraConfig 失败: $e");
                }
              } else {
                extraConfig = data['extraConfig'] as Map<String, dynamic>?;
              }
            }

            // 🚀🚀🚀 核心改动 2：判断该用户是否拥有后台动态配置的特效！
            // 只要包含了视频链接 (floatVideoUrl/resourceUrl) 或者额外配置 (extraConfig)，就说明有特权！
            bool hasCustomEntrance = data['floatVideoUrl'] != null ||
                data['resourceUrl'] != null ||
                extraConfig != null;

            // 🚀🚀🚀 核心改动 3：打破写死的 ID 限制！
            // 如果后端下发了配置，或者依然属于你们原来的 2,6,163 测试白名单，一律走尊贵特效进场！
            if (hasCustomEntrance || [2, 6, 163].contains(userId)) {

              // 完美调用我们之前在 EntranceModel 里写好的 fromJson，它会自动帮你把 Hex 颜色字符串变成 Color 对象
              final entranceModel = EntranceModel.fromJson(data, extraConfig);

              _entranceEffectKey.currentState?.addEntrance(entranceModel);

            } else {
              // 没有任何特权配置的普通用户，走普通的文字播报进场
              _simulateVipEnter(
                overrideUserId: joinerId,
                overrideName: joinerName,
                overrideAvatar: joinerAvatar,
                overrideLevel: joinerLevel,
                overrideMonthLevel: joinerMonthLevel,
                isHost: senderIsHost,
                levelHonourBuff: senderBuff, // 🚀 传下去！
              );
            }
          }

          // 判断是否需要延时
          if (UserStore.to.userId == joinerId) {
            Future.delayed(const Duration(milliseconds: 3000), executeLogic);
          } else {
            executeLogic();
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
            levelHonourBuff: senderBuff, // 🚀 传下去！
          );
          break;
        case "ONLINE_COUNT":
          final int newCount = data['onlineCount'] ?? 0;
          _onlineCount = newCount;
          _viewerListKey.currentState?.updateOnlineCount(newCount);
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
            levelHonourBuff: senderBuff, // 🚀 传下去！
          );
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
          if (![PKStatus.playing, PKStatus.coHost].contains(_pkStatus)) break;
          final List<dynamic> scoreList = data['data'] as List<dynamic>;

          bool hasChanged = false;

          // 🚀 核心修复 1：深拷贝一份全新的数组，彻底改变内存地址，逼迫子组件必须重绘！
          List<Map<String, dynamic>> newParticipants = [];
          for (var p in _participants) {
            newParticipants.add(Map<String, dynamic>.from(p));
          }

          // 纯内存静默修改
          for (var item in scoreList) {
            String updatedRoomId = item['roomId'].toString();
            int newScore = int.tryParse(item['score'].toString()) ?? 0;

            for (int i = 0; i < newParticipants.length; i++) {
              if (newParticipants[i]['roomId'].toString() == updatedRoomId) {
                int oldScore = _parseInt(newParticipants[i]['score']);
                if (oldScore != newScore) {
                  newParticipants[i]['score'] = newScore;
                  hasChanged = true;
                }
                break;
              }
            }
          }

          // 如果分数有变，重新计算红蓝总分
          if (hasChanged) {
            // 🚀 将全新地址的数组赋值回去
            _participants = newParticipants;

            int myCamp = 0;
            for (var p in _participants) {
              if (p['roomId'].toString() == _roomId) {
                myCamp = _parseInt(p['teamId']);
                break;
              }
            }

            int mySum = 0;
            int enemySum = 0;
            for (var p in _participants) {
              int s = _parseInt(p['score']);
              int tId = _parseInt(p['teamId']);
              String rId = p['roomId'].toString();

              if (myCamp == 0 || tId == 0) {
                if (rId == _roomId) {
                  mySum = s;
                } else if (s > enemySum) {
                  enemySum = s;
                }
              } else {
                if (tId == myCamp) {
                  mySum += s;
                } else {
                  enemySum += s;
                }
              }
            }
            _myPKScore = mySum;
            _opponentPKScore = enemySum;

            // 🚀 核心修复 2：放弃简单的 value++，直接塞入当前毫秒时间戳！
            // 保证每一次接收到数据，ValueNotifier 的值都是绝对唯一的，绝对能百分百触发局部刷新！
            _pkScoreUpdateTrigger.value = DateTime.now().millisecondsSinceEpoch;
          }
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
        // 🟢 新增：处理主播语音消息
        // case "HOST_SPEAK":
        //   VoicePlayerTool().playBase64Audio(data["audioData"] as String?);
        //   if (widget.roomType == LiveRoomType.voice && _voiceRoomKey.currentState != null) {
        //     _voiceRoomKey.currentState?.updateRealTimeSubtitle("$joinerName: ${data['content']}");
        //   }
        //   break;
        // 🟢 收到打断指令：紧急刹车并重新点火！
        case "INTERRUPT_AUDIO":
          debugPrint("🛑 收到打断指令，清空原生音频队列！");
          // 🟢 一行代码瞬间恢复 BGM 的 100% 音量
          AIMusicService().restoreVolumeNow(_roomId);
          // 1. 瞬间停掉当前的 AudioTrack 并清空队列
          // 🚀 终极防崩修复
          _nativePlayer
              .invokeMethod('stopPlayer', {'roomId': _roomId})
              .then((_) {
                _nativePlayer.invokeMethod('initPlayer', {'sampleRate': 24000, 'roomId': _roomId}).catchError((e) {});
              })
              .catchError((e) {});
          break;

        // 🟢 收到混流音频：直接喂给原生队列！
        case "MIXED_AUDIO_STREAM":
          String base64Data = data['audioData'];
          if (base64Data.isNotEmpty) {
            // 1. 解码出原始 PCM 字节 (完全不需要加 WAV 头了)
            Uint8List pcmBytes = base64Decode(base64Data);
            // 🟢 极简调用：算好时长，直接告诉 Service 去闪避音量！
            int durationMs = (pcmBytes.length / 48.0).ceil();
            AIMusicService().duckFor(_roomId, durationMs);
            // 2. 极速喂给 Android 原生层！你的 LinkedBlockingQueue 会自动把它们丝滑拼在一起播放！
            // 🚀 终极防崩修复
            _nativePlayer.invokeMethod('feedAudio', {'data': pcmBytes, 'roomId': _roomId}).catchError((e) {});
          }
          break;
        case "PROP_CRIT":
          final String targetRoomId = data['targetRoomId']?.toString() ?? "";
          final int secondsLeft = int.tryParse(data['secondsLeft']?.toString() ?? '0') ?? 0;

          if (targetRoomId.isNotEmpty) {
            // 默默更新集合
            if (secondsLeft > 0) {
              _critEndTimes[targetRoomId] = DateTime.now().add(Duration(seconds: secondsLeft));
            } else {
              _critEndTimes.remove(targetRoomId);
            }

            // 🟢 精准呼叫子组件，告诉它是哪个房间的卡生效了
            _pkScoreBarKey.currentState?.updateCritTime(targetRoomId, secondsLeft);
          }
          break;
        case "PK_RELOAD":
          // 这个方法会重新拉取 pkInfo，更新 _participants 数组，
          // _participants 数量一旦从 2 变成 4，你的 DynamicPKBattleView 就会瞬间从 1v1 动画裂变成 4宫格！
          _fetchRoomDetailAndSyncState();
          break;
        // 🚀 新增：处理闭麦/解麦的 WebSocket 广播
        case "MUTE_STATE_CHANGE":
          String targetRoomId = data['targetRoomId']?.toString() ?? "";
          bool isMuted = data['content'] == "1";

          try {
            setState(() {
              List<Map<String, dynamic>> newList = [];
              for (var p in _participants) {
                var newMap = Map<String, dynamic>.from(p);
                // 🚀 这里用 roomId 来精准匹配
                if (newMap['roomId'].toString() == targetRoomId) {
                  newMap['isMuted'] = isMuted;

                  String streamUrl = newMap['streamUrl'] ?? "";
                  if (streamUrl.isNotEmpty) {
                    HardcoreMixer.setMuted(streamUrl, isMuted);
                  }
                }
                newList.add(newMap);
              }
              _participants = newList;
            });

            // 🚀 判断如果被禁麦的正是当前我所在的直播间
            if (targetRoomId == _roomId) {
              AiRealTimeVoiceService().setMicMute(isMuted);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isMuted ? "本直播间已被禁麦" : "本直播间已解除禁麦")));
            }
          } catch (e) {
            print("🚨 Socket 处理闭麦时发生崩溃: $e");
          }
          break;

        // 🚀 处理一键全员闭麦 (改为用 roomId 判断例外)
        case "MUTE_ALL_EXCEPT":
          String exceptionRoomId = data['targetRoomId']?.toString() ?? "";

          setState(() {
            List<Map<String, dynamic>> newList = [];
            for (var p in _participants) {
              var newMap = Map<String, dynamic>.from(p);
              String pRoomId = newMap['roomId'].toString();

              if (pRoomId != exceptionRoomId) {
                newMap['isMuted'] = true;

                String streamUrl = newMap['streamUrl'] ?? "";
                if (streamUrl.isNotEmpty) {
                  HardcoreMixer.setMuted(streamUrl, true);
                }

                if (pRoomId == _roomId) {
                  // AiRealTimeVoiceService().setMicMute(true);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("房主已开启全员禁麦，麦克风已断开")));
                }
              }
              newList.add(newMap);
            }
            _participants = newList;
          });
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
    String? levelHonourBuff, // 🚀 1. 新增参数接收
    int? score,
    String? targetRoomId,
  }) {
    if (_channel == null) return;
    final Map<String, dynamic> msg = {
      "type": type,
      "roomId": _roomId,
      "userId": userId ?? _myUserId,
      "userName": userName,
      "avatar": avatar,
      "level": level,
      "monthLevel": monthLevel,
      "levelHonourBuff": levelHonourBuff, // 🚀 2. 塞进广播的 JSON 里
      "isHost": isHost,
      "score": score,
      "content": content,
      "giftId": giftId,
      "giftCount": giftCount,
      "targetRoomId": targetRoomId,
    };
    try {
      _channel!.sink.add(jsonEncode(msg));
    } catch (e) {}
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
    if (initialTimeLeft == null) _playPKStartAnimation();
    if (_pkStatus == PKStatus.playing && initialTimeLeft == null) return;

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
    _pkResultKey.currentState?.showResult(true);
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
    if (_isHost) {
      try {
        await HttpUtil().post("/api/pk/to_cohost", data: {"roomId": int.parse(_roomId)});
      } catch (e) {}
    }
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
      anchorTime = serverStartTime;
      // anchorTime = serverStartTime.add(Duration(seconds: _pkDuration + _punishmentDuration));
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
    _critEndTimes.clear();
    _promoTimer?.cancel();
    _rightPlayer?.pause(); // 暂停对手视频

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
    if (!_isHost || _isRobotActive) {
      _instantKillAllAudio();
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
        _instantKillAllAudio();
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
    _isSwitchingRoom = true; // 🟢 核心修复 1：标记我们要切房了，保护底层播放器！
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
          // 🟢 核心修复：1v1 切房时同样把对方的数据传过去
          initialRoomData: {
            'userName': opponent['name'],
            'avatar': opponent['avatar'],
            'coverImg': opponent['personalPkBg'], // 如果有背景也可以一并传
          },
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
    required String levelHonourBuff, // 🚀 1. 接收 Buff ID
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
        levelHonourBuff: levelHonourBuff, // 🚀 2. 塞进模型
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
    String levelHonourBuff = "", // 🚀 1. 接收 Buff ID
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
        levelHonourBuff: levelHonourBuff, // 🚀 2. 塞进模型
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
    String levelHonourBuff = "",
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
        levelHonourBuff: levelHonourBuff,
      );
      if (_pkStatus == PKStatus.playing) {
        if (_isFirstGiftPromoActive && !_usersWhoUsedPromo.contains(senderId)) {
          _usersWhoUsedPromo.add(senderId);
        }
      }

      //   // 2. 💥 暴击卡翻倍逻辑 (新增) 💥
      //   final now = DateTime.now();
      //   // 只要当前有暴击卡在生效期内，并且是我方送的（或者你要给所有人算也可以去掉 isMe 判断）
      //   if (isMe && _critEndTime != null && _critEndTime!.isAfter(now)) {
      //     // 随机生成 1.5 到 5.0 的倍数
      //     final double multiplier = 1.5 + math.Random().nextDouble() * 3.5;
      //     // 最终加分 = 原分 * 暴击倍率
      //     scoreToAdd = (scoreToAdd * multiplier).toInt();
      //
      //     debugPrint("💥 触发暴击！原分:${giftData.price * count} 倍率:${multiplier.toStringAsFixed(1)} 最终加分:$scoreToAdd");
      //   }
      //
      //   // if (isMe) {
      //   //   _myPKScore += scoreToAdd;
      //   //   HttpUtil().post("/api/pk/update_score", data: {"roomId": int.parse(_roomId), "score": scoreToAdd});
      //   // } else {
      //   //   _myPKScore += scoreToAdd;
      //   // }
      // }
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
      final res = await HttpUtil().post(
        "/api/gift/send",
        data: {"userId": int.parse(_myUserId), "giftId": giftData.id, "count": countToSend, "roomId": _roomId},
      );

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
        levelHonourBuff: _myLevelHonourBuff, // 🚀 传下去
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
    _bgPlayer = Player();
    _bgController = VideoController(_bgPlayer!);
    try {
      _bgPlayer!.setPlaylistMode(PlaylistMode.loop);
      await _bgPlayer!.open(Media(_leftVideoUrl), play: _isVideoBackground);

      _bgPlayer!.stream.duration.listen((duration) {
        if (duration > Duration.zero && _bgPlayer!.state.position == Duration.zero) {
          int positionMs = DateTime.now().millisecondsSinceEpoch % duration.inMilliseconds;
          _bgPlayer!.seek(Duration(milliseconds: positionMs));
        }
      });
      setState(() => _isBgInitialized = true);
    } catch (e) {}
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
    String levelHonourBuff = "", // 🚀 1. 接收 Buff ID
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
          levelHonourBuff: levelHonourBuff, // 🚀 2. 塞进模型
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

  // 🟢 核心改造：将后端数据组装成网格组件需要的 Model 列表
  List<LivePKPlayerModel> _buildCurrentPkPlayers() {
    List<LivePKPlayerModel> players = [];
    if (_participants.isEmpty) return players;

    DateTime now = DateTime.now();

    // 1. 先找出“我”的阵营 ID (teamId)
    int myCamp = 0;
    for (var p in _participants) {
      if (p['roomId'].toString() == _roomId) {
        myCamp = _parseInt(p['teamId']);
        break;
      }
    }

    // 🟢 2. 新增：提取所有人的分数并降序排列，用于计算真实的排名！
    List<int> allScores = _participants.map((p) => _parseInt(p['score'])).toList();
    allScores.sort((a, b) => b.compareTo(a)); // 降序排列

    for (int i = 0; i < _participants.length; i++) {
      var p = _participants[i];
      String pRoomId = p['roomId'].toString();
      bool isMe = pRoomId == _roomId; // 判断这个格子是不是我自己
      int currentScore = _parseInt(p['score']);

      // 🟢 3. 计算真实排名 (利用 indexOf，分越高排越前，同分则并列)
      int realRank = allScores.indexOf(currentScore) + 1;

      // 4. 判断这个格子是否属于“我方阵营”
      int tId = _parseInt(p['teamId']);
      bool isMyTeam = false;
      if (myCamp == 0 || tId == 0) {
        // 抢第一模式 (各自为战)：只有我自己算我方
        isMyTeam = isMe;
      } else {
        // 团队模式：只要 teamId 跟我一样，就是我方队友
        isMyTeam = (tId == myCamp);
      }

      // 处理视频流分配
      VideoController? vc = _videoControllers[pRoomId];
      // ✨✨✨ 核心修改：组装真正的 activeBuffs 数组 ✨✨✨
      List<String> currentActiveBuffs = [];
      // 处理道具状态
      if (_critEndTimes.containsKey(pRoomId)) {
        DateTime endTime = _critEndTimes[pRoomId]!;
        if (endTime.isAfter(now)) {
          int sec = endTime.difference(now).inSeconds;
          // 👇 核心修改：加入人数判断 ( _participants.length < 7 )
          if (isMe) {
            if (_participants.length <= 7) {
              // 房主自己，且总人数在 2~6 人时（格子够大），显示长文本
              currentActiveBuffs.add("暴击卡生效中 ${sec}s");
            } else {
              // 房主自己，且总人数在 2~6 人时（格子够大），显示长文本
              currentActiveBuffs.add("暴击 ${sec}s");
            }
          } else {
            // 其他所有人（或者房主在 7~9 人的拥挤模式下），统统显示短文本！
            currentActiveBuffs.add("暴击中 ${sec}s");
          }
        }
      }
      // 2. 如果后端有传单条的 propText，也塞进去（未来你可以扩展后端字段，传一个真正的数组过来）
      // String? originalPropText = p['propText']; // 假设后端原本有这个单条状态
      // if (originalPropText != null && originalPropText.isNotEmpty) {
      //   currentActiveBuffs.add(originalPropText);
      // }

      // 处理惩罚期变灰
      bool isPunished = false;
      if (_pkStatus == PKStatus.punishment) {
        // 只要不是最高分，就接受惩罚变灰
        if (allScores.isNotEmpty && currentScore < allScores.first) {
          isPunished = true;
        }
      }
      bool isMuted = p['isMuted'] ?? !isMe;
      players.add(
        LivePKPlayerModel(
          userId: p['anchorId']?.toString() ?? "",
          roomId: pRoomId,
          pkId: p['pkId'].toString(),
          name: p['name'] ?? (isMe ? _currentName : "连麦主播"),
          avatarUrl: p['avatar'] ?? (isMe ? _currentAvatar : "https://picsum.photos/200"),
          rank: realRank,
          // 🟢 5. 传入动态算出来的真实排名！
          score: currentScore,
          isInitiator: p['isInitiator'] ?? false,
          streamUrl: p['streamUrl'],
          isPunished: isPunished,
          isMuted: isMuted,
          // ✨ 不再传单条的 propText，全部通过 activeBuffs 传递
          propText: null,
          activeBuffs: currentActiveBuffs,
          isSpeaking: isMe,
          isMyTeam: isMyTeam,
          videoController: vc,
        ),
      );
    }
    return players;
  }

  // 🟢 核心改造：切房前的极限转场保护
  void _switchToTargetRoom(LivePKPlayerModel targetPlayer) {
    if (_isHost && !_isRobotActive) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("主播不能离开自己的直播间")));
      return;
    }
    _isSwitchingRoom = true;
    _instantKillAllAudio();

    final playersToDispose = _players.values.toList();
    _players.clear();
    _videoControllers.clear();

    // 1. 瞬间静音，让画面定格
    for (var p in playersToDispose) {
      p.setVolume(0.0);
      p.pause();
    }

    // 🚀🚀🚀 核心修复 1：在跳转前的一瞬间，直接拔掉底层所有音箱的电源！绝不让声音带入下一个房间！
    HardcoreMixer.dispose();
    try {
      _nativePlayer.invokeMethod('stopPlayer', {'roomId': _roomId});
    } catch (e) {}
    AIMusicService().stopMusic(_roomId);

    // 🚀 2. 终极杀招：异步排队，喂空列表，拔掉底层的电源！
    LiveRoomConfig.pendingCleanupTask = () async {
      for (var p in playersToDispose) {
        try {
          // 强制喂一个空视频，这能瞬间掐断 mpv 引擎的解码线程！
          await p.open(Playlist([]));
          await p.dispose();
        } catch (e) {}
        // 留出 50ms 给 CPU 喘息
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => RealLivePage(
          userId: widget.userId,
          userName: widget.userName,
          avatarUrl: widget.avatarUrl,
          level: widget.level,
          isHost: false,
          roomId: targetPlayer.roomId,
          monthLevel: _monthLevel,
          initialRoomData: {'userName': targetPlayer.name, 'avatar': targetPlayer.avatarUrl},
        ),
      ),
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
              anchorAvatar: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/avatar/xiaoqi.jpg",
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
              key: const ValueKey("SingleModeView"),
              // 可选
              viewerListKey: _viewerListKey,
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
                child: AvatarAnimation(avatarUrl: _currentAvatar, name: _currentName, isSpeaking: true, isRotating: false),
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
        case LiveRoomType.voice:
          const double myVideoHeight = 400.0;
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

    const double gap1 = 68.0;
    final double pkVideoHeight = size.width * 0.87;

    // 🟢 1. 终极布局法：把外层盒子的总高度彻底焊死（绝对不随状态伸缩！）
    // 计时器占据顶部 22px，血条占据 18px，所以给它们预留的最大顶部空间是 40px
    const double maxTopOffset = 40.0;
    final double fixedContainerHeight = pkVideoHeight + maxTopOffset;

    // 🟢 2. 弹幕区和各种底边计算，全部基于这个绝对固定的 fixedContainerHeight
    final double pkVideoBottomY = padding.top + topBarHeight + gap1 + fixedContainerHeight;
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
                                    decoration: _enableGlobalBackgroundImage
                                        ? BoxDecoration(
                                            image: DecorationImage(image: AssetImage('assets/background.jpg'), fit: BoxFit.cover),
                                          )
                                        : BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [const Color(0xFF310505).withOpacity(0.7), const Color(0xFF1F2445).withOpacity(0.9)],
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
                                            height: fixedContainerHeight,
                                            width: size.width,
                                            child: Stack(
                                              children: [
                                                // 1. 最底层：视频网格图层 (垫在最下面)
                                                Positioned(
                                                  top: (_pkStatus == PKStatus.playing || _pkStatus == PKStatus.punishment) ? 36.0 : 18.0,
                                                  left: 0,
                                                  right: 0,
                                                  bottom: 0,
                                                  child: ValueListenableBuilder<int>(
                                                    valueListenable: _pkScoreUpdateTrigger, // 👈 监听这里的变化
                                                    builder: (context, triggerValue, child) {
                                                      // 只有 triggerValue 变化时，这里的 builder 才会重新执行，重新调用 _buildCurrentPkPlayers()
                                                      return DynamicPKBattleView(
                                                        key: const ValueKey('steady_pk_battle_view'),
                                                        pkStatus: _pkStatus,
                                                        currentRoomId: _roomId,
                                                        players: _buildCurrentPkPlayers(),
                                                        useVideoMode: true,
                                                        focusedRoomId: _focusedRoomId,
                                                        onTapPlayer: (LivePKPlayerModel targetPlayer) {
                                                          // 🚀 新增防空保护：如果点到空座位，直接忽略！
                                                          if (targetPlayer.roomId.isEmpty || targetPlayer.roomId == "0") return;

                                                          _dismissKeyboard();

                                                          showModalBottomSheet(
                                                            context: context,
                                                            backgroundColor: Colors.transparent,
                                                            isScrollControlled: true,
                                                            builder: (ctx) {
                                                              return PlayerActionBottomSheet(
                                                                targetPlayer: targetPlayer,
                                                                // 🚀 核心：用 roomId 来判断是不是本房间
                                                                isMe: targetPlayer.roomId == _roomId,
                                                                isHost: _isHost,

                                                                onEnterRoom: () {
                                                                  if (_isHost && !_isRobotActive) {
                                                                    ScaffoldMessenger.of(
                                                                      context,
                                                                    ).showSnackBar(const SnackBar(content: Text("主播不能离开自己的直播间")));
                                                                    return;
                                                                  }
                                                                  _switchToTargetRoom(targetPlayer);
                                                                },

                                                                onToggleMute: () {
                                                                  print("🟢 1. 成功点击了按钮！开始执行闭麦逻辑...");
                                                                  try {
                                                                    bool targetMuteState = !targetPlayer.isMuted;

                                                                    // 🚀 如果点的是本房间，操作本地物理麦克风
                                                                    if (targetPlayer.roomId == _roomId) {
                                                                      AiRealTimeVoiceService().setMicMute(targetMuteState);
                                                                    }

                                                                    setState(() {
                                                                      List<Map<String, dynamic>> newList = [];

                                                                      for (var p in _participants) {
                                                                        var newMap = Map<String, dynamic>.from(p);

                                                                        // 🚀 核心：用 roomId 来匹配列表中的玩家！
                                                                        if (newMap['roomId'].toString() == targetPlayer.roomId) {
                                                                          newMap['isMuted'] = targetMuteState;

                                                                          String streamUrl = newMap['streamUrl'] ?? "";
                                                                          if (streamUrl.isNotEmpty) {
                                                                            HardcoreMixer.setMuted(streamUrl, targetMuteState);
                                                                          }
                                                                        }
                                                                        newList.add(newMap);
                                                                      }
                                                                      _participants = newList;
                                                                    });

                                                                    // 🚀 核心：通过 Socket 广播这个 roomId 的闭麦指令
                                                                    _sendSocketMessage(
                                                                      "MUTE_STATE_CHANGE",
                                                                      content: targetMuteState ? "1" : "0",
                                                                      targetRoomId: targetPlayer.roomId, // 传 roomId！
                                                                    );
                                                                  } catch (e, stackTrace) {
                                                                    print("🚨 致命崩溃！代码在这里死掉了: $e");
                                                                    print(stackTrace);
                                                                  }
                                                                },

                                                                onSetFocus: () {
                                                                  setState(() {
                                                                    if (_focusedRoomId == targetPlayer.roomId) {
                                                                      _focusedRoomId = null;
                                                                    } else {
                                                                      _focusedRoomId = targetPlayer.roomId;
                                                                    }
                                                                  });
                                                                },

                                                                onMuteAllExceptMe: () {
                                                                  // 🚀 发送全员闭麦指令时，将自己的 roomId 传进去作为例外
                                                                  _sendSocketMessage("MUTE_ALL_EXCEPT", targetRoomId: _roomId);
                                                                },

                                                                onViewProfile: () {
                                                                  Map<String, dynamic> user = {"userId": targetPlayer.userId};
                                                                  LiveUserProfilePopup.show(context, user);
                                                                },
                                                              );
                                                            },
                                                          );
                                                        },
                                                      );
                                                    },
                                                  ),
                                                ),
                                                // 3. 最顶层：计时器梯形 (盖在血条的上方，绝不被遮挡)
                                                Positioned(
                                                  top: 0,
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
                                                // 2. 中间层：血条图层 (盖在视频上方，确保暴击卡等特效悬浮在视频之上)
                                                if (_pkStatus == PKStatus.playing || _pkStatus == PKStatus.punishment)
                                                  Positioned(
                                                    top: 18,
                                                    left: 0,
                                                    right: 0,
                                                    child: ValueListenableBuilder<int>(
                                                      valueListenable: _pkScoreUpdateTrigger, // 👈 同样监听变化
                                                      builder: (context, triggerValue, child) {
                                                        // 只有这里会重绘，将内存中最新的 _myPKScore 传进去
                                                        return PKScoreBar(
                                                          key: _pkScoreBarKey,
                                                          myScore: _myPKScore,
                                                          opponentScore: _opponentPKScore,
                                                          status: _pkStatus,
                                                          secondsLeft: _pkTimeLeft,
                                                          myRoomId: _roomId,
                                                          critEndTimes: _critEndTimes,
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                if (1 == 2)
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
                                  bottom: 0, // 永远钉在 Stack 最底部
                                  child: ValueListenableBuilder<double>(
                                    valueListenable: _keyboardNotifier,
                                    builder: (context, bottomInset, child) {
                                      // 计算逻辑
                                      final double currentBottom = max(bottomInset, fixedBottomOffset);
                                      double currentHeight = (baseChatListHeight + safeBottomOffset) - currentBottom;
                                      if (currentHeight < 150) currentHeight = 150.0;

                                      return Padding(
                                        padding: EdgeInsets.only(bottom: currentBottom),
                                        child: SizedBox(
                                          height: currentHeight,
                                          child: child, // 直接使用传进来的 child，杜绝重绘！
                                        ),
                                      );
                                    },
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
                                              ? LinearGradient(colors: [Colors.green.withAlpha(100), Colors.teal.withAlpha(100)])
                                              : LinearGradient(colors: [Colors.redAccent.withAlpha(100), Colors.redAccent.withAlpha(100)]),
                                          borderRadius: BorderRadius.circular(11),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              iHaveUsedPromo ? "首翻已达成" : "首次送礼翻倍",
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
                                  levelHonourBuff: _myLevelHonourBuff, // 🚀 传下去
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
                bottom: 0, // 永远钉在最底部
                child: SafeArea(
                  // 【关键修改】把 SafeArea 移到这里，作为 Positioned 的子元素
                  top: false,
                  left: false,
                  right: false,
                  bottom: true,
                  // 只保护底部
                  maintainBottomViewPadding: false,
                  // 确保它只处理安全区，不干扰键盘逻辑
                  child: ValueListenableBuilder<double>(
                    valueListenable: _keyboardNotifier,
                    builder: (context, bottomInset, child) {
                      // 用 Padding 把按钮顶上去
                      return Padding(
                        padding: EdgeInsets.only(bottom: bottomInset + 80),
                        child: child,
                      );
                    },
                    child: ScaleTransition(
                      scale: _comboScaleAnimation,
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
                                      value: _countdownController.value,
                                      strokeWidth: 4,
                                      backgroundColor: Colors.white24,
                                      valueColor: const AlwaysStoppedAnimation(Color(0xFFFF0000)),
                                    ),
                                  ),
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFFF0000), Color(0xFFFF0000)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      border: Border.all(color: Colors.red, width: 2),
                                    ),
                                    alignment: const Alignment(0, -0.05),
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
                ),
              ),
            PkResultPage(key: _pkResultKey),
          ],
        ),
        // _buildAiVoiceBtn(),
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

  // 你可以把这个 Widget 放在 Stack 的靠上层
  Widget _buildAiVoiceBtn() {
    return Positioned(
      right: 16,
      top: 120, // 放在右上角区域
      child: GestureDetector(
        onTap: () async {
          // 如果正在连麦就挂断，没连麦就开启
          if (AiRealTimeVoiceService().isSpeaking) {
            await AiRealTimeVoiceService().stopVoiceCall();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已挂断 AI 连麦")));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("正在连接 AI...")));
            bool success = await AiRealTimeVoiceService().startVoiceCall(roomId: _roomId, userId: _myUserId);
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ 连接成功，可以直接说话了！")));
            }
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 1),
          ),
          child: Row(
            children: const [
              Icon(Icons.mic, color: Colors.white, size: 18),
              SizedBox(width: 4),
              Text("AI 连麦", style: TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  // 🚀 终极武器：瞬间物理掐断所有发声源！
  void _instantKillAllAudio() {
    // 1. 瞬间掐断 C++ 引擎 (ExoPlayer)
    HardcoreMixer.dispose();
    // 2. 瞬间掐断 media_kit 背景音
    _bgPlayer?.setVolume(0.0);
    _bgPlayer?.pause();
    _rightPlayer?.setVolume(0.0);
    _rightPlayer?.pause();
    // 3. 瞬间掐断原生语音队列和 AI 音乐
    try {
      _nativePlayer.invokeMethod('stopPlayer', {'roomId': _roomId});
    } catch (e) {}
    AIMusicService().stopMusic(_roomId);
  }

  // 🟢 4. 新增方法：绕过 MediaQuery，直接从系统底层极速获取键盘高度！
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // 从底层 Window 获取物理像素，转换为逻辑像素
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom / WidgetsBinding.instance.window.devicePixelRatio;

    // 如果高度变了，只通知局部组件刷新，绝对不重绘整个页面！
    if (_keyboardNotifier.value != bottomInset) {
      _keyboardNotifier.value = bottomInset;
    }
  }

  // 🟢 5. 新增方法：监听 App 后台/前台切换生命周期
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // 🚀 核心修复：App 从后台被重新唤醒到了前台
      print("🚀 [Lifecycle] App 回到前台，开始强制同步房间数据...");
      // 强制重新拉取最新的房间和 PK 详情（替换为你实际拉取数据的那个方法名）
      // 比如你是在 _initData() 或者 _fetchRoomDetail() 里调用的后端接口
      _fetchRoomDetailAndSyncState();
      // 如果你有断线重连逻辑，也可以在这里触发
      _reconnect();
      // liveSocketHandler.reconnect();
    } else if (state == AppLifecycleState.paused) {
      // App 退到后台
      print("⏸️ [Lifecycle] App 退到后台");
      // 可选：如果需要在后台暂停某些消耗性能的动画，可以写在这里
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clearAllVideos(); // 🟢 页面销毁时打扫战场
    _keyboardNotifier.dispose();
    // 🟢 关闭 AI 连麦通道
    try {
      AiRealTimeVoiceService().dispose();
    } catch (e) {}
    // 🚀🚀🚀 核心修复 2：彻底删掉 if (!_isSwitchingRoom) ！！！
    // 不管是按物理返回键退出，还是切去对手房间，旧引擎统统必须死！
    WakelockPlus.disable();
    if (!_isSwitchingRoom) {
      HardcoreMixer.dispose();
      try {
        _nativePlayer.invokeMethod('stopPlayer', {'roomId': _roomId});
      } catch (e) {}
      AIMusicService().stopMusic(_roomId);
    }

    _pkScoreUpdateTrigger.dispose(); // 🟢 2. 新增销毁
    _isDisposed = true;
    _socketSubscription?.cancel();
    _channel?.sink.close();
    _heartbeatTimer?.cancel();
    _bgPlayer?.dispose();
    _rightPlayer?.dispose();
    _comboScaleController.dispose();
    _countdownController.dispose();
    _pkStartAnimationController.dispose();
    _pkTimer?.cancel();
    _promoTimer?.cancel();
    super.dispose();
  }
}
