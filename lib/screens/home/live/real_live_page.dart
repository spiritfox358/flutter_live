import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_live/screens/home/live/widgets/level_badge_widget.dart';
import 'package:video_player/video_player.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:my_alpha_player/my_alpha_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../services/gift_api.dart';
import '../../../services/ai_music_service.dart';
import '../../../tools/HttpUtil.dart';

import 'models/live_models.dart';

// 🟢 确保引入你复刻的真人PK视图
import 'widgets/pk_real_battle_view.dart';
import 'widgets/single_mode_view.dart';
import 'package:flutter_live/screens/home/live/widgets/build_chat_list.dart';
import 'package:flutter_live/screens/home/live/widgets/build_input_bar.dart';
import 'package:flutter_live/screens/home/live/widgets/build_top_bar.dart';
import 'package:flutter_live/screens/home/live/widgets/music_panel.dart';
import 'package:flutter_live/screens/home/live/widgets/pk_widgets.dart';
import 'animate_gift_item.dart';
import 'gift_panel.dart';

// 🟢 解决 image_06c8f4.png 报错：补全类定义
class EntranceEvent {
  final String userName;
  final String level;
  final String avatarUrl;
  final String? frameUrl;

  EntranceEvent({required this.userName, required this.level, required this.avatarUrl, this.frameUrl});
}

class RealLivePage extends StatefulWidget {
  final String userId;
  final String userName;
  final String avatarUrl;
  final int level;
  final bool isHost;
  final String roomId;
  final Map<String, dynamic>? initialRoomData;

  const RealLivePage({
    super.key,
    required this.userId,
    required this.userName,
    required this.avatarUrl,
    required this.level,
    required this.isHost,
    required this.roomId,
    this.initialRoomData,
  });

  @override
  State<RealLivePage> createState() => _RealLivePageState();
}

class _RealLivePageState extends State<RealLivePage> with TickerProviderStateMixin {
  final int _punishmentDuration = 20;

  WebSocketChannel? _channel;
  late String _myUserName;
  late String _myUserId;
  late String _myAvatar;
  late String _roomId;
  late int _onlineCount = 0;
  late bool _isHost;

  final String _wsUrl = "ws://${HttpUtil.getBaseIpPort}/ws/live";

  // 🟢 解决 image_06cfdc.png 报错：定义变量
  VideoPlayerController? _bgController;
  bool _isBgInitialized = false;
  bool _isVideoBackground = false;
  String _currentBgImage = "";
  String _currentName = "";
  Timer? _heartbeatTimer; // 心跳定时器
  bool _isDisposed = false; // 标记页面是否已销毁，防止退出后还在重连
  String _currentAvatar = "";
  final List<String> _bgImageUrls = [
    "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/live_bg_1.png",
    "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/live_bg_2.png",
  ];

  PKStatus _pkStatus = PKStatus.idle;
  int _myPKScore = 0;
  int _opponentPKScore = 0;
  int _pkTimeLeft = 0;
  Timer? _pkTimer;

  // 🟢 真人 PK 参与者数据
  List<dynamic> _participants = [];

  // 🟢 解决 image_0886d7.png 报错：定义翻倍相关变量
  bool _isFirstGiftPromoActive = false;
  int _promoTimeLeft = 30;
  Timer? _promoTimer;

  MyAlphaPlayerController? _alphaPlayerController;
  final Queue<String> _effectQueue = Queue();
  bool _isEffectPlaying = false;
  double? _videoAspectRatio;

  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  static const int _maxActiveGifts = 2;
  final List<GiftEvent> _activeGifts = [];
  final Queue<GiftEvent> _waitingQueue = Queue();
  List<GiftItemData> _giftList = [];

  // 🟢 解决 image_0740b5.png 报错：定义连击动画
  bool _showComboButton = false;
  GiftItemData? _lastGiftSent;
  late AnimationController _comboScaleController;
  late AnimationController _countdownController;

  bool _showPKStartAnimation = false;
  late AnimationController _pkStartAnimationController;
  late Animation<double> _pkLeftAnimation;
  late Animation<double> _pkRightAnimation;
  late Animation<double> _pkFadeAnimation;

  late AnimationController _welcomeBannerController;
  late Animation<Offset> _welcomeBannerAnimation;
  final Queue<EntranceEvent> _entranceQueue = Queue();
  bool _isEntranceBannerShowing = false;
  EntranceEvent? _currentEntranceEvent;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();

    _myUserId = widget.userId;
    _myUserName = widget.userName;
    _myAvatar = widget.avatarUrl;
    _isHost = widget.isHost;
    _roomId = widget.roomId;

    _fetchGiftList();
    _initializeBackground();
    _pickRandomImage();

    _initPKStartAnimation();

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

    _welcomeBannerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _welcomeBannerAnimation = Tween<Offset>(begin: const Offset(1.5, 0), end: const Offset(0, 0)).animate(_welcomeBannerController);

    // 🟢 进场检查
    _startEnterRoomSequence();
  }

  int _parseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  Future<void> _fetchGiftList() async {
    try {
      final gifts = await GiftApi.getGiftList();
      if (mounted && gifts.isNotEmpty) setState(() => _giftList = gifts);
    } catch (e) {
      debugPrint("❌ 加载礼物列表失败");
    }
  }

  void _connectWebSocket() {
    try {
      _channel?.sink.close();

      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      _channel!.stream.listen(
        (message) => _handleSocketMessage(message),
        // 🟢 监听连接错误
        onError: (error) {
          debugPrint("❌ WebSocket 报错: $error");
          _reconnect();
        },
        // 🟢 监听连接断开 (服务器主动断开或网络中断)
        onDone: () {
          debugPrint("🔌 WebSocket 连接断开");
          _reconnect();
        },
      );
      _sendSocketMessage("ENTER", content: "进入了直播间", userName: _myUserName, avatar: _myAvatar, level: "10");
      _startHeartbeat();
    } catch (e) {
      debugPrint("❌ WS连接失败");
      _reconnect();
    }
  }

  // 🟢 心跳机制：每 30 秒发送一次 "HEARTBEAT"
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      // 发送一个轻量级的心跳包
      // 注意：不要用 _sendSocketMessage，因为那个会带一堆 userId 用户名，浪费流量
      // 直接发最简单的 JSON
      try {
        _channel?.sink.add(jsonEncode({"type": "HEARTBEAT", "roomId": _roomId}));
        // debugPrint("💓 发送心跳");
      } catch (e) {
        // 发送失败说明断了，触发重连
        _reconnect();
      }
    });
  }

  // 🟢 重连机制：延迟 3 秒后重试，防止死循环刷爆服务器
  void _reconnect() {
    if (_isDisposed) return;

    _heartbeatTimer?.cancel(); // 重连期间停止发心跳

    debugPrint("⏳ 3秒后尝试重连...");
    Future.delayed(const Duration(seconds: 3), () {
      if (!_isDisposed) {
        _connectWebSocket();
      }
    });
  }

  // 🟢 统一的进场启动器
  void _startEnterRoomSequence() async {
    try {
      // 第一步：调用加入接口（数据库 online_count +1）
      await HttpUtil().post("/api/room/join", data: {"roomId": int.parse(_roomId)});

      // 第二步：连接 WebSocket（建立实时监听）
      _connectWebSocket();

      // 第三步：拉取房间详情（同步当前的 PK 画面和头像）
      _fetchRoomDetailAndSyncState();
    } catch (e) {
      debugPrint("进房初始化失败: $e");
    }
  }

  void _fetchRoomDetailAndSyncState() async {
    try {
      // 1. 调用你后端的 PkController.getRoomDetail 接口
      final res = await HttpUtil().get("/api/pk/detail", params: {"roomId": int.parse(_roomId), "userId": _myUserId, "userName": _myUserName});
      final data = res;
      // 更新在线人数等基础信息
      setState(() {
        // 如果后端返回了最新的 onlineCount，在这里更新
        // _onlineCount = _parseInt(data['onlineCount']);
      });

      // 2. 检查 PK 信息并同步
      if (data['pkInfo'] != null) {
        final pkInfo = data['pkInfo'];
        final int status = _parseInt(pkInfo['status']);
        final String startTimeStr = pkInfo['startTime'];

        setState(() {
          _participants = pkInfo['participants'] as List; // 同步参与者头像和名字
          // 🟢 核心补全：进入房间时，立即从 API 返回的数据中恢复当前分数
          if (_participants.isNotEmpty) {
            // 在房间 B 中，_participants[0] 永远是房间 B 的主播
            // 将左侧背景图更新为当前房间主播的个人 PK 背景
            _currentName = _participants[0]['name'] ?? _currentName;
            _currentAvatar = _participants[0]['avatar'] ?? _currentAvatar;
            _currentBgImage = _participants[0]['pkBg'] ?? _currentBgImage;
            // 如果正在 PK，同步双方分数
            if (_participants.length >= 2) {
              _myPKScore = _parseInt(_participants[0]['score']);
              _opponentPKScore = _parseInt(_participants[1]['score']);
            }
          }
        });

        DateTime startTime = DateTime.parse(startTimeStr);
        final int elapsedSeconds = DateTime.now().difference(startTime).inSeconds;

        if (status == 1) {
          // 🟢 同步 PK 状态
          final int remaining = 90 - elapsedSeconds;
          if (remaining > 0) {
            _startPKRound(initialTimeLeft: remaining);
            // 2. 🟢 新增：检查是否还在首翻 30秒 保护期内
            // 假设首翻时间是 30 秒
            const int promoDuration = 30;

            if (elapsedSeconds < promoDuration) {
              // 还在首翻时间内，恢复状态
              setState(() {
                _isFirstGiftPromoActive = true;
                _promoTimeLeft = promoDuration - elapsedSeconds; // 算出剩下的首翻时间
              });
              // 启动首翻倒计时器
              _startPromoTimer();
            } else {
              // 超过30秒了，确保关闭
              setState(() {
                _isFirstGiftPromoActive = false;
                _promoTimeLeft = 0;
              });
            }
          } else {
            _enterPunishmentPhase();
          }
        } else if (status == 2) {
          // 🟡 同步惩罚状态
          final int remainingPunishment = 20 - (elapsedSeconds - 90);
          if (remainingPunishment > 0) {
            _enterPunishmentPhase(timeLeft: remainingPunishment);
          }
        } else if (status == 3) {
          // 🔵 补全：同步连麦状态
          // 连麦通常是持续进行的，计算从开始到现在已过去的时间
          DateTime startTime = DateTime.parse(startTimeStr);
          int totalElapsed = DateTime.now().difference(startTime).inSeconds;
          int coHostElapsed = totalElapsed - 90 - 20;
          _enterCoHostPhase(initialElapsedTime: coHostElapsed > 0 ? coHostElapsed : 0, serverStartTime: startTime);
        }
      } else {
        _currentName = data['title'] ?? _currentName;
        _currentAvatar = data['coverImg'] ?? _currentAvatar;
        _currentBgImage = data['personalPkBg'] ?? _currentBgImage;
      }
    } catch (e) {
      debugPrint("❌ 同步房间详情失败: $e");
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

      switch (type) {
        case "ENTER":
          // data 是后端 LiveSocketHandler 广播出来的 JSON
          final String joinerId = data['userId']?.toString() ?? "";
          final String joinerName = data['userName'] ?? "神秘人";
          final String joinerAvatar = data['avatar'] ?? "";
          final String joinerLevel = data['level']?.toString() ?? "1";
          // 1. 在聊天列表显示进入消息
          // _addSocketChatMessage("系统", "$joinerName 进入了直播间", Colors.grey);
          // 2. 触发进场座驾/横幅动画
          _simulateVipEnter(overrideName: joinerName, overrideAvatar: joinerAvatar, overrideLevel: joinerLevel);
          break;
        case "CHAT":
          _addSocketChatMessage(data['userName'] ?? "神秘人", data['content'] ?? "", isMe ? Colors.amber : Colors.white);
          break;
        case "ONLINE_COUNT":
          final int newCount = data['onlineCount'] ?? 0;
          if (mounted) {
            setState(() {
              _onlineCount = newCount;
            });
          }
          break;
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
          _processGiftEvent(targetGift, data['userName'] ?? "神秘人", data['avatar'] ?? "神秘人", isMe, count: data['giftCount'] ?? 1);
          break;
        case "PK_START":
          _isFirstGiftPromoActive = true;
          _promoTimeLeft = 30;
          _startPromoTimer();
          _startPKRound();
          // 重新拉取一次详情以更新参与者头像
          _fetchRoomDetailAndSyncState();
          break;
        // 🟢 新增：监听到进入惩罚阶段广播
        case "PK_PUNISHMENT":
          if (!isMe) _enterPunishmentPhase();
          break;

        // 🟢 新增：监听到进入连线阶段广播
        case "PK_COHOST":
          if (!isMe) _enterCoHostPhase(initialElapsedTime: 0);
          break;
        case "PK_UPDATE":
          final List<dynamic> scoreList = data['data'] as List<dynamic>;
          setState(() {
            for (var item in scoreList) {
              String roomId = item['roomId'].toString();
              int score = item['score'];
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
      }
    } catch (e) {
      debugPrint("❌ 解析消息失败: $e");
    }
  }

  void _sendSocketMessage(String type, {String? content, String? giftId, int giftCount = 1, String? userName, String? avatar, String? level}) {
    if (_channel == null) return;
    final Map<String, dynamic> msg = {
      "type": type,
      "roomId": _roomId,
      "userId": _myUserId,
      "userName": userName,
      "avatar": avatar,
      "level": level,
      "content": content,
      "giftId": giftId,
      "giftCount": giftCount,
    };
    try {
      _channel!.sink.add(jsonEncode(msg));
    } catch (e) {}
  }

  void _onTapStartPK() async {
    _dismissKeyboard();
    if (_pkStatus != PKStatus.idle || !_isHost) return;
    try {
      await HttpUtil().post("/api/pk/start", data: {"roomId": int.parse(_roomId), "duration": 90});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("开启失败: $e")));
    }
  }

  void _startPKRound({int? initialTimeLeft}) {
    _pkTimer?.cancel();
    _pkTimer = null;
    if (_pkStatus == PKStatus.playing && initialTimeLeft == null) return;
    if (initialTimeLeft == null) _playPKStartAnimation();
    setState(() {
      _pkStatus = PKStatus.playing;
      _pkTimeLeft = initialTimeLeft ?? 90;
      if (initialTimeLeft == null) {
        _myPKScore = 0;
        _opponentPKScore = 0;
        _isFirstGiftPromoActive = true;
        _promoTimeLeft = 30;
        _startPromoTimer();
      }
    });
    _pkTimer?.cancel();
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
    setState(() {
      _pkStatus = PKStatus.punishment;
      _pkTimeLeft = (timeLeft != null && timeLeft > 0) ? timeLeft : _punishmentDuration;
      _isFirstGiftPromoActive = false;
      _promoTimer?.cancel();
    });
    // 🟢 房主逻辑：当自然进入惩罚期（非进场同步）时，通知后端并广播
    if (_isHost && timeLeft == null) {
      try {
        // 1. 提交后端接口更新房间模式为 2 (惩罚中)
        await HttpUtil().post("/api/room/enter_punishment", data: {"roomId": int.parse(_roomId)});
        // 2. 发布 WebSocket 广播
        _sendSocketMessage("PK_PUNISHMENT");
      } catch (e) {
        debugPrint("进入惩罚阶段同步失败: $e");
      }
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
      // 1. 提交后端接口更新房间模式为 3 (连麦/连线中)
      await HttpUtil().post("/api/pk/to_cohost", data: {"roomId": int.parse(_roomId)});
      // 2. 发布 WebSocket 广播
      // _sendSocketMessage("PK_COHOST");
    } catch (e) {
      debugPrint("进入连线阶段同步失败: $e");
    }
  }

  void _enterCoHostPhase({required int initialElapsedTime, DateTime? serverStartTime}) {
    // 1. 彻底取消并清理旧计时器，防止多个计时器叠加导致数字乱跳
    _pkTimer?.cancel();
    _pkTimer = null;

    setState(() {
      _pkStatus = PKStatus.coHost;
      _pkTimeLeft = initialElapsedTime;
      _isFirstGiftPromoActive = false;
      _promoTimer?.cancel();
    });

    // 2. 🟢 核心逻辑：确定“连线开始”的那个绝对时间点（anchorTime）
    DateTime anchorTime;
    if (serverStartTime != null) {
      // 粉丝进场：连线开始时间 = PK开始时间 + 90s(PK) + 20s(惩罚)
      anchorTime = serverStartTime.add(const Duration(seconds: 90 + 20));
    } else {
      // 主播切换：连线开始时间 = 现在 - 已经流逝的时间
      anchorTime = DateTime.now().subtract(Duration(seconds: initialElapsedTime));
    }

    // 3. 开启计时器，每秒计算一次差值
    _pkTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_pkStatus == PKStatus.coHost) {
        setState(() {
          // 🟢 绝对计算：当前时间 - 锚点时间
          // difference 返回的是 Duration，.inSeconds 拿到总秒数
          _pkTimeLeft = DateTime.now().difference(anchorTime).inSeconds;
        });
      } else {
        timer.cancel(); // 如果状态变了，停止这个计时器
      }
    });
  }

  void _disconnectCoHost() async {
    _pkTimer?.cancel();
    _promoTimer?.cancel();
    setState(() {
      _pkStatus = PKStatus.idle;
      _myPKScore = 0;
      _opponentPKScore = 0;
      _isFirstGiftPromoActive = false;
      _participants = [];
    });
    HttpUtil().post("/api/pk/pk_end", data: {"roomId": int.parse(_roomId)});
  }

  // 🟢 解决 image_091d54.png 报错：补全键盘和倒计时逻辑
  void _dismissKeyboard() {
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _startPromoTimer() {
    _promoTimer?.cancel();
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

  void _handleCloseButton() {
    _dismissKeyboard();
    if (!_isHost) {
      Navigator.of(context).pop();
      return;
    }
    if (_pkStatus != PKStatus.idle) {
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
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.link_off, color: Colors.redAccent),
                title: const Text("断开连线/PK", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _disconnectCoHost();
                },
              ),
              const Divider(color: Colors.white10, height: 1),
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: Colors.white70),
                title: const Text("退出直播间", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).pop();
                },
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
            ],
          ),
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _switchToOpponentRoom() {
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
        ),
      ),
    );
  }

  void _addSocketChatMessage(String name, String content, Color color) {
    setState(() {
      _messages.insert(0, ChatMessage(name: name, content: content, level: 99, levelColor: color, isGift: false));
    });
  }

  void _addGiftMessage(String senderName, String giftName, int count) {
    setState(
      () => _messages.insert(0, ChatMessage(name: senderName, content: '送出了 $giftName x$count', level: 99, levelColor: Colors.yellow, isGift: true)),
    );
  }

  void _processGiftEvent(GiftItemData giftData, String senderName, String senderAvatar, bool isMe, {int count = 1}) {
    final comboKey = "${senderName}_${giftData.name}";
    if (isMe) _lastGiftSent = giftData;
    setState(() {
      final existingIndex = _activeGifts.indexWhere((g) => g.comboKey == comboKey);
      int finalCount = count;
      if (existingIndex != -1) {
        _activeGifts[existingIndex] = _activeGifts[existingIndex].copyWith(count: _activeGifts[existingIndex].count + count);
      } else {
        _processNewGift(
          GiftEvent(senderName: senderName, senderAvatar: senderAvatar, giftName: giftData.name, giftIconUrl: giftData.iconUrl, count: finalCount),
        );
      }
      _addGiftMessage(senderName, giftData.name, finalCount);
      if (isMe && _pkStatus == PKStatus.playing) {
        HttpUtil().post("/api/pk/update_score", data: {"roomId": int.parse(_roomId), "score": giftData.price * count});
      }
    });
    if (giftData.effectAsset != null && giftData.effectAsset!.isNotEmpty) {
      _addEffectToQueue(giftData.effectAsset!);
    }
    if (isMe) _triggerComboMode();
  }

  void _sendGift(GiftItemData giftData) {
    _dismissKeyboard();
    int countToSend = 1;
    if (_pkStatus == PKStatus.playing && _isFirstGiftPromoActive) {
      countToSend = 2;
      setState(() {
        _isFirstGiftPromoActive = false;
        _promoTimer?.cancel();
      });
    }
    _sendSocketMessage("GIFT", giftId: giftData.id, giftCount: countToSend);
  }

  void _processNewGift(GiftEvent gift) {
    if (_activeGifts.length < _maxActiveGifts)
      _activeGifts.add(gift);
    else
      _waitingQueue.add(gift);
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

  void _onPlayerCreated(MyAlphaPlayerController controller) {
    _alphaPlayerController = controller;
    _alphaPlayerController?.onFinish = _onEffectComplete;
    _alphaPlayerController?.onVideoSize = (width, height) {
      if (width > 0 && height > 0 && mounted) setState(() => _videoAspectRatio = width / height);
    };
  }

  void _onEffectComplete() {
    if (!mounted) return;
    _alphaPlayerController?.stop();
    setState(() => _isEffectPlaying = false);
    Future.delayed(const Duration(milliseconds: 50), _playNextEffect);
  }

  void _playNextEffect() async {
    if (_effectQueue.isEmpty || _alphaPlayerController == null) return;
    final url = _effectQueue.removeFirst();
    setState(() => _isEffectPlaying = true);
    try {
      String? localPath = await _downloadGiftFile(url);
      if (localPath != null && mounted)
        await _alphaPlayerController!.play(localPath);
      else
        _onEffectComplete();
    } catch (e) {
      _onEffectComplete();
    }
  }

  void _addEffectToQueue(String url) {
    _effectQueue.add(url);
    if (!_isEffectPlaying) _playNextEffect();
  }

  Future<String?> _downloadGiftFile(String url) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = url.split('/').last;
      final savePath = "${dir.path}/$fileName";
      final file = File(savePath);
      if (await file.exists()) return savePath;
      await Dio().download(url, savePath);
      return savePath;
    } catch (e) {
      return null;
    }
  }

  void _initializeBackground() async {
    _bgController = VideoPlayerController.networkUrl(Uri.parse('https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/bg.mp4'));
    try {
      await _bgController!.initialize();
      _bgController!.setLooping(true);
      _bgController!.setVolume(0.0);
      if (_isVideoBackground) _bgController!.play();
      setState(() => _isBgInitialized = true);
    } catch (e) {}
  }

  void _toggleBackgroundMode() {
    setState(() {
      _isVideoBackground = !_isVideoBackground;
      if (_isVideoBackground) {
        if (_isBgInitialized) _bgController?.play();
      } else {
        if (_isBgInitialized) _bgController?.pause();
        _pickRandomImage();
      }
    });
  }

  void _pickRandomImage() {
    setState(() => _currentBgImage = _bgImageUrls[Random().nextInt(_bgImageUrls.length)]);
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
        onSend: (gift) {
          _dismissKeyboard();
          _sendGift(gift);
          Navigator.pop(context);
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted) _dismissKeyboard();
          });
        },
      ),
    );
  }

  void _showMusicPanel() {
    _dismissKeyboard();
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (_) => const MusicPanel());
  }

  void _simulateVipEnter({String? overrideName, String? overrideAvatar, String? overrideLevel}) {
    final names = ["顾北", "王校长", "阿特", "小柠檬", "榜一大哥", "神秘土豪"];
    final randomIdx = Random().nextInt(names.length);
    final name = overrideName ?? names[randomIdx];
    final level = overrideLevel;
    final event = EntranceEvent(
      userName: overrideName ?? "安静呀",
      level: level ?? "41",
      avatarUrl: overrideAvatar ?? "https://picsum.photos/seed/${888 + randomIdx}/200",
      frameUrl: "https://cdn-icons-png.flaticon.com/512/8313/8313626.png",
    );
    _entranceQueue.add(event);
    if (!_isEntranceBannerShowing) _playNextEntrance();
    if (mounted) {
      setState(() {
        _messages.insert(0, ChatMessage(name: "", content: "$name 加入直播间！", level: 100, levelColor: const Color(0xFFFFD700)));
      });
    }
  }

  void _playNextEntrance() async {
    if (_entranceQueue.isEmpty) return;
    _isEntranceBannerShowing = true;
    final event = _entranceQueue.removeFirst();
    if (mounted) {
      setState(() {
        _currentEntranceEvent = event;
        _welcomeBannerAnimation = Tween<Offset>(
          begin: const Offset(1.5, 0),
          end: const Offset(0, 0),
        ).animate(CurvedAnimation(parent: _welcomeBannerController, curve: Curves.easeOutQuart));
      });
    }
    _welcomeBannerController.reset();
    await _welcomeBannerController.forward();
    await Future.delayed(const Duration(milliseconds: 2000));
    if (mounted) {
      setState(() {
        _welcomeBannerAnimation = Tween<Offset>(
          begin: const Offset(0, 0),
          end: const Offset(-1.5, 0),
        ).animate(CurvedAnimation(parent: _welcomeBannerController, curve: Curves.easeInQuart));
      });
    }
    _welcomeBannerController.reset();
    await _welcomeBannerController.forward();
    _isEntranceBannerShowing = false;
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) _playNextEntrance();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    const double topBarHeight = 50.0;
    const double gap1 = 105.0;
    final double pkVideoHeight = size.width * 0.85;
    final double pkVideoBottomY = padding.top + topBarHeight + gap1 + pkVideoHeight + 18;
    final double videoRatio = _videoAspectRatio ?? (9 / 16);
    double entranceTop = pkVideoBottomY + 4;
    final bool showPromo = _isFirstGiftPromoActive && _pkStatus == PKStatus.playing;
    if (showPromo) entranceTop += 22 + 4;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _dismissKeyboard,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Stack(
                children: [
                  if (_pkStatus != PKStatus.idle)
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF100101), Color(0xFF141E28)],
                          ),
                        ),
                      ),
                    ),
                  _pkStatus == PKStatus.idle
                      ? SingleModeView(
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
                        )
                      : Column(
                          children: [
                            Container(
                              margin: EdgeInsets.only(top: padding.top),
                              height: topBarHeight,
                              child: BuildTopBar(
                                roomId: _roomId,
                                onlineCount: _onlineCount,
                                title: "直播间",
                                name: _currentName,
                                avatar: _currentAvatar,
                                onClose: _handleCloseButton,
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
                                      rightAvatarUrl: _participants.length > 1 ? _participants[1]['avatar'] : "https://picsum.photos/200",
                                      rightName: _participants.length > 1 ? _participants[1]['name'] : "对手主播",
                                      rightBgImage: _participants.length > 1 ? (_participants[1]['pkBg'] ?? "") : "",
                                      pkStatus: _pkStatus,
                                      myScore: _myPKScore,
                                      opponentScore: _opponentPKScore,
                                      onTapOpponent: _switchToOpponentRoom,
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
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: bottomInset > 0 ? bottomInset : padding.bottom,
                    height: _pkStatus == PKStatus.idle ? 300 : (size.height - pkVideoBottomY),
                    child: RepaintBoundary(
                      child: Container(
                        color: bottomInset > 0 ? Colors.black87 : Colors.transparent,
                        child: Column(
                          children: [
                            Expanded(child: BuildChatList(bottomInset: 0, messages: _messages)),
                            BuildInputBar(
                              textController: _textController,
                              onTapGift: _showGiftPanel,
                              onSend: (text) => _sendSocketMessage("CHAT", content: text),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (showPromo)
                    Positioned(
                      top: pkVideoBottomY + 4,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          height: 22,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.white.withOpacity(0.15), Colors.pinkAccent.withOpacity(0.15)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                "首送翻倍",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "00:${_promoTimeLeft.toString().padLeft(2, '0')}",
                                style: const TextStyle(color: Colors.white, fontFamily: "monospace", fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: entranceTop,
                    left: 0,
                    child: SlideTransition(
                      position: _welcomeBannerAnimation,
                      child: _currentEntranceEvent != null
                          ? Container(
                              margin: const EdgeInsets.only(left: 5),
                              height: 25,
                              padding: const EdgeInsets.symmetric(horizontal: 5),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF0D47A1), Color(0xFF42A5F5)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(12.5),
                                border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  LevelBadge(level: 73),
                                  const SizedBox(width: 6),
                                  Text(
                                    "${_currentEntranceEvent!.userName} 加入了直播间",
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500, height: 1.1),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                              ),
                            )
                          : const SizedBox(),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: -2,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: _isEffectPlaying ? 1.0 : 0.0,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: SizedBox(
                            width: size.width,
                            height: size.width / videoRatio,
                            child: MyAlphaPlayerView(key: const ValueKey('AlphaPlayer'), onCreated: _onPlayerCreated),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (bottomInset == 0)
                    Positioned(
                      left: 0,
                      width: size.width,
                      top: pkVideoBottomY - 160,
                      height: 160,
                      bottom: null,
                      child: IgnorePointer(
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: _activeGifts
                                  .map(
                                    (giftEvent) => AnimatedGiftItem(
                                      key: ValueKey(giftEvent.id),
                                      giftEvent: giftEvent,
                                      onFinished: () => _onGiftFinished(giftEvent.id),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_pkStatus == PKStatus.idle && _isHost)
                    Positioned(
                      bottom: (bottomInset > 0 ? bottomInset : padding.bottom) + 150,
                      right: 20,
                      child: GestureDetector(
                        onTap: _onTapStartPK,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Colors.purple, Colors.deepPurple]),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white30),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.eighteen_mp, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text(
                                "发起PK",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
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
                                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
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
                                          borderRadius: const BorderRadius.only(topRight: Radius.circular(12), bottomRight: Radius.circular(12)),
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
    _isDisposed = true; // 🟢 必须加这行，彻底终止重连死循环
    WakelockPlus.disable();
    _channel?.sink.close();
    _heartbeatTimer?.cancel(); // 🟢 销毁心跳
    _bgController?.dispose();
    try {
      AIMusicService().stopMusic();
    } catch (e) {}
    _textController.dispose();
    _comboScaleController.dispose();
    _countdownController.dispose();
    _pkStartAnimationController.dispose();
    _welcomeBannerController.dispose();
    _pkTimer?.cancel();
    _promoTimer?.cancel();
    super.dispose();
  }
}
