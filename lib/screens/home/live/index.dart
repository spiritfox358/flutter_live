import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_live/models/user_models.dart';
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
import 'widgets/pk_battle_view.dart';
import 'widgets/single_mode_view.dart';
import 'package:flutter_live/screens/home/live/widgets/build_chat_list.dart';
import 'package:flutter_live/screens/home/live/widgets/build_bottom_input_bar.dart';
import 'package:flutter_live/screens/home/live/widgets/build_top_bar.dart';
import 'package:flutter_live/screens/home/live/widgets/music_panel.dart';
import 'package:flutter_live/screens/home/live/widgets/pk_widgets.dart';
import 'animate_gift_item.dart';
import 'gift_panel.dart';

class EntranceEvent {
  final String userName;
  final String level;
  final String avatarUrl;
  final String? frameUrl;

  EntranceEvent({required this.userName, required this.level, required this.avatarUrl, this.frameUrl});
}

final List<AIBoss> _bosses = [
  const AIBoss(
    name: "机械姬·零号",
    avatarUrl: "https://cdn-icons-png.flaticon.com/512/4712/4712109.png",
    videoUrl: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/ai_avatar_1.mp4",
    difficulty: 3,
    tauntMessages: [],
  ),
  const AIBoss(name: "赛博魔王", avatarUrl: "https://cdn-icons-png.flaticon.com/512/6195/6195678.png", videoUrl: "", difficulty: 8, tauntMessages: []),
];

class LiveStreamingPage extends StatefulWidget {
  final String userId;
  final String userName;
  final bool isHost;
  final String roomId;

  final Map<String, dynamic>? initialRoomData;

  const LiveStreamingPage({
    super.key,
    required this.userId,
    required this.userName,
    required this.isHost,
    required this.roomId,
    this.initialRoomData,
  });

  @override
  State<LiveStreamingPage> createState() => _LiveStreamingPageState();
}

class _LiveStreamingPageState extends State<LiveStreamingPage> with TickerProviderStateMixin {
  int _punishmentDuration = 20;

  WebSocketChannel? _channel;
  late String _myUserName;
  late String _myUserId;
  late String _roomId;
  late bool _isHost;

  final String _wsUrl = "ws://192.168.0.104:8358/ws/live";

  VideoPlayerController? _bgController;
  bool _isBgInitialized = false;
  bool _isVideoBackground = false;
  String _currentBgImage = "";
  final List<String> _bgImageUrls = [
    "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/live_bg_1.jpg",
    "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/live_bg_2.jpg",
  ];

  PKStatus _pkStatus = PKStatus.idle;
  int _myPKScore = 0;
  int _opponentPKScore = 0;
  int _pkTimeLeft = 0;
  Timer? _pkTimer;
  bool _isAiRaging = false;
  AIBoss? _currentBoss;

  final List<VideoPlayerController> _allBossControllers = [];
  VideoPlayerController? _aiVideoController;
  bool _isRightVideoMode = false;

  final ValueNotifier<UserModel> _userStatusNotifier = ValueNotifier(
    UserModel(0, 0, coinsToNextLevel: 0, coinsNextLevelThreshold: 0, coinsToNextLevelText: "0", coinsCurrentLevelThreshold: 0),
  );

  String _opponentBgImage = "";
  bool _isAIThinking = false;

  bool _isFirstGiftPromoActive = false;
  int _promoTimeLeft = 30;
  Timer? _promoTimer;

  MyAlphaPlayerController? _alphaPlayerController;
  final Queue<String> _effectQueue = Queue();
  bool _isEffectPlaying = false;
  double? _videoAspectRatio;

  final TextEditingController _textController = TextEditingController();
  List<ChatMessage> _messages = [];
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
    _isHost = widget.isHost;
    _roomId = widget.roomId;

    _fetchGiftList();
    _connectWebSocket();
    _initializeBackground();
    _pickRandomImage();

    // 🟢 初始化动画控制器 (必须在 _checkInitialRoomState 之前)
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

    // 🟢 最后检查进场状态
    _checkInitialRoomState();
  }

  int _parseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  // 🟢 进场状态同步
  void _checkInitialRoomState() {
    final data = widget.initialRoomData;
    if (data == null) return;

    final int roomMode = _parseInt(data['roomMode']);
    debugPrint("📡 进场同步检查: roomMode=$roomMode");

    if (data['punishmentDuration'] != null) {
      _punishmentDuration = _parseInt(data['punishmentDuration'], defaultValue: 20);
    }

    if (data['pkStartTime'] == null) return;
    final String startTimeStr = data['pkStartTime'].toString();
    DateTime startTime;
    try {
      startTime = DateTime.parse(startTimeStr);
    } catch (e) {
      debugPrint("❌ 时间解析失败: $e");
      return;
    }

    final int pkDuration = _parseInt(data['pkDuration'], defaultValue: 90);
    final DateTime now = DateTime.now();

    // 🟢 Mode 1: PK 中
    if (roomMode == 1) {
      final int elapsedSeconds = now.difference(startTime).inSeconds;
      final int remaining = pkDuration - elapsedSeconds;

      if (remaining > 0) {
        debugPrint("✅ PK 进行中，剩余 $remaining 秒");

        // 🟢 修复首送翻倍时间同步：如果已过 30 秒，直接关闭翻倍
        const int promoTotalDuration = 30;
        final int promoRemaining = promoTotalDuration - elapsedSeconds;

        Future.delayed(const Duration(milliseconds: 200), () {
          if (!mounted) return;

          // 根据剩余时间设置翻倍状态
          if (promoRemaining > 0) {
            _isFirstGiftPromoActive = true;
            _promoTimeLeft = promoRemaining;
            _startPromoTimer();
          } else {
            _isFirstGiftPromoActive = false;
            _promoTimer?.cancel();
          }

          _startPKRound(
            _parseInt(data['bossIndex']),
            _parseInt(data['bgIndex']),
            initialTimeLeft: remaining,
            initMyScore: _parseInt(data['myScore']),
            initOpScore: _parseInt(data['opScore']),
            pkTotalDuration: _parseInt(data['pkDuration'], defaultValue: 90),
            punishmentDuration: _punishmentDuration,
          );
        });
      }
    }
    // 🟢 Mode 2: 惩罚 中
    else if (roomMode == 2) {
      final DateTime punishmentStartTime = startTime.add(Duration(seconds: pkDuration));
      final int elapsedInPunishment = now.difference(punishmentStartTime).inSeconds;
      int remainingPunishment = _punishmentDuration - elapsedInPunishment;

      if (remainingPunishment < 0) remainingPunishment = 0;

      debugPrint("🔥 惩罚模式，剩余 $remainingPunishment 秒");
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        _restoreSceneData(data);
        _enterPunishmentPhase(timeLeft: remainingPunishment);
      });
    }
    // 🟢 Mode 3: 连麦中
    else if (roomMode == 3) {
      final int elapsedCoHost = now.difference(startTime).inSeconds;
      debugPrint("✅ 连麦中，已进行 $elapsedCoHost 秒");
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        _restoreSceneData(data);
        _enterCoHostPhase(initialElapsedTime: elapsedCoHost);
      });
    }
  }

  void _restoreSceneData(Map<String, dynamic> data) {
    setState(() {
      _myPKScore = _parseInt(data['myScore']);
      _opponentPKScore = _parseInt(data['opScore']);
      final int bossIdx = _parseInt(data['bossIndex']);
      final int bgIdx = _parseInt(data['bgIndex']);
      _currentBoss = _bosses[bossIdx % _bosses.length];
      _opponentBgImage = _bgImageUrls[bgIdx % _bgImageUrls.length];

      if (_currentBoss?.videoUrl.isNotEmpty == true) {
        _isRightVideoMode = true;
        _setupBossVideo(_currentBoss!.videoUrl);
      }
    });
  }

  void _setupBossVideo(String url) {
    _killAllBossVideos();
    final newController = VideoPlayerController.networkUrl(Uri.parse(url));
    _allBossControllers.add(newController);
    _aiVideoController = newController;
    newController.initialize().then((_) {
      if (!mounted || !_allBossControllers.contains(newController)) {
        newController.dispose();
        return;
      }
      newController.setLooping(true);
      newController.setVolume(1.0);
      newController.play();
      setState(() {});
    });
  }

  Future<void> _fetchGiftList() async {
    try {
      final gifts = await GiftApi.getGiftList();
      if (mounted && gifts.isNotEmpty) setState(() => _giftList = gifts);
    } catch (e) {
      debugPrint("❌ 礼物加载异常: $e");
    }
  }

  void _connectWebSocket() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      _channel!.stream.listen((message) => _handleSocketMessage(message));
      _sendSocketMessage("ENTER", content: "进入了直播间");
    } catch (e) {
      debugPrint("WebSocket 连接异常: $e");
    }
  }

  void _handleSocketMessage(dynamic message) {
    if (!mounted) return;
    try {
      final Map<String, dynamic> data = jsonDecode(message);
      final String type = data['type'];
      final String userId = data['userId'] ?? "";
      final String roomId = data['roomId']?.toString() ?? "";

      if (roomId.isNotEmpty && roomId != _roomId) return;
      final bool isMe = (userId == _myUserId);

      switch (type) {
        case "CHAT":
          _addSocketChatMessage(data['username'] ?? "神秘人", data['content'] ?? "", isMe ? Colors.amber : Colors.white);
          break;
        case "GIFT":
          final String giftId = data['giftId']?.toString() ?? "";
          GiftItemData? targetGift;
          try {
            if (_giftList.isNotEmpty) {
              targetGift = _giftList.firstWhere((g) => g.id.toString() == giftId);
            }
          } catch (e) {}
          targetGift ??= GiftItemData(
            id: giftId,
            name: "未知礼物",
            price: 0,
            iconUrl: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/1_%E5%B0%8F%E5%BF%83%E5%BF%83.png",
          );
          _processGiftEvent(targetGift, data['username'] ?? "神秘人", data['avatar'] ?? "神秘人", isMe, count: data['giftCount'] ?? 1);
          break;
        case "ENTER":
          if (!isMe) _simulateVipEnter(overrideName: data['username']);
          break;
        case "PK_START":
          _startPKRound(
            _parseInt(data['bossIndex']),
            _parseInt(data['bgIndex']),
            pkTotalDuration: _parseInt(data['pkDuration'], defaultValue: 90),
            punishmentDuration: _parseInt(data['punishmentDuration'], defaultValue: 20),
          );
          break;
        case "PK_UPDATE":
          setState(() => _opponentPKScore = _parseInt(data['opponentScore']));
          break;
        case "PK_END":
          _disconnectCoHost();
          break;
      }
    } catch (e) {
      debugPrint("解析失败: $e");
    }
  }

  void _sendSocketMessage(String type, {String? content, String? giftId, int giftCount = 1, int? bossIndex, int? bgIndex, int? opponentScore}) {
    if (_channel == null) return;
    final Map<String, dynamic> msg = {
      "type": type,
      "roomId": _roomId,
      "userId": _myUserId,
      "username": _myUserName,
      "content": content,
      "giftId": giftId,
      "giftCount": giftCount,
      if (bossIndex != null) "bossIndex": bossIndex,
      if (bgIndex != null) "bgIndex": bgIndex,
      if (opponentScore != null) "opponentScore": opponentScore,
      if (type == "PK_START") ...{"pkDuration": 90, "punishmentDuration": _punishmentDuration},
    };
    try {
      _channel!.sink.add(jsonEncode(msg));
    } catch (e) {}
  }

  void _onTapStartPK() async {
    _dismissKeyboard();
    if (_pkStatus != PKStatus.idle || !_isHost) return;

    final int randomBossIndex = Random().nextInt(_bosses.length);
    final int randomBgIndex = Random().nextInt(_bgImageUrls.length);

    try {
      await HttpUtil().post(
        "/api/room/start_pk",
        data: {
          "roomId": int.parse(_roomId),
          "bossIndex": randomBossIndex,
          "bgIndex": randomBgIndex,
          "duration": 90,
          "punishmentDuration": _punishmentDuration,
        },
      );
      _sendSocketMessage("PK_START", bossIndex: randomBossIndex, bgIndex: randomBgIndex);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("开启失败: $e")));
    }
  }

  void _startPKRound(
    int bossIndex,
    int bgIndex, {
    int? initialTimeLeft,
    int? initMyScore,
    int? initOpScore,
    int? pkTotalDuration,
    int? punishmentDuration,
  }) {
    if (_pkStatus == PKStatus.playing && initialTimeLeft == null) return;
    if (initialTimeLeft == null) _playPKStartAnimation();
    if (punishmentDuration != null) _punishmentDuration = punishmentDuration;

    Future.delayed(Duration(milliseconds: initialTimeLeft == null ? 800 : 0), () {
      if (!mounted) return;
      if (initialTimeLeft == null && _pkStatus != PKStatus.idle) return;

      final boss = _bosses[bossIndex % _bosses.length];
      _currentBoss = boss;
      _opponentBgImage = _bgImageUrls[bgIndex % _bgImageUrls.length];

      setState(() {
        _pkStatus = PKStatus.playing;
        _myPKScore = initMyScore ?? 0;
        _opponentPKScore = initOpScore ?? 0;
        _pkTimeLeft = initialTimeLeft ?? (pkTotalDuration ?? 90);

        // 🟢 只有新开启的 PK (非进场同步) 才重置翻倍倒计时
        if (initialTimeLeft == null) {
          _isFirstGiftPromoActive = true;
          _promoTimeLeft = 30;
          _startPromoTimer();
        }
      });

      if (boss.videoUrl.isNotEmpty) {
        _isRightVideoMode = true;
        _setupBossVideo(boss.videoUrl);
      } else {
        _isRightVideoMode = false;
        _killAllBossVideos();
      }

      _pkTimer?.cancel();
      _pkTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() => _pkTimeLeft--);
        if (_pkTimeLeft <= 0) {
          _pkTimer?.cancel();
          _enterPunishmentPhase();
          return;
        }
        if (!_isAIThinking && (_pkTimeLeft % 4 == 0 || _pkTimeLeft <= 10)) _triggerBossBehavior(context: "periodic_check");
      });
    });
  }

  void _enterPunishmentPhase({int? timeLeft}) async {
    setState(() {
      _pkStatus = PKStatus.punishment;
      _pkTimeLeft = timeLeft ?? _punishmentDuration;
      _isFirstGiftPromoActive = false;
      _promoTimer?.cancel();
    });

    if (_isHost && timeLeft == null) {
      try {
        await HttpUtil().post("/api/room/enter_punishment", data: {"roomId": int.parse(_roomId)});
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
        await HttpUtil().post("/api/room/enter_co_host", data: {"roomId": int.parse(_roomId)});
      } catch (e) {}
    }
  }

  void _enterCoHostPhase({required int initialElapsedTime}) {
    setState(() {
      _pkStatus = PKStatus.coHost;
      _pkTimeLeft = initialElapsedTime;
      _isFirstGiftPromoActive = false;
      _promoTimer?.cancel();
    });

    _pkTimer?.cancel();
    _pkTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _pkTimeLeft++);
    });
  }

  // 🟢 修复：断开连接时，通知后端并发送 Socket 消息
  void _disconnectCoHost() async {
    if (_isHost) {
      try {
        await HttpUtil().post("/api/room/end_pk", data: {"roomId": int.parse(_roomId)});
      } catch (e) {}
      // 🟢 关键：房主必须发送 Socket 消息，粉丝才能同步断开
      _sendSocketMessage("PK_END");
    }
    _killAllBossVideos();
    try {
      AIMusicService().stopMusic();
    } catch (e) {}
    _pkTimer?.cancel();
    _promoTimer?.cancel();
    setState(() {
      _pkStatus = PKStatus.idle;
      _myPKScore = 0;
      _opponentPKScore = 0;
      _isFirstGiftPromoActive = false;
    });
  }

  Future<void> _triggerBossBehavior({required String context, String? customPrompt}) async {
    if (_currentBoss == null || _pkStatus != PKStatus.playing || !_isHost) return;
    if (_isAIThinking && context == "periodic_check") return;
    _isAIThinking = true;
    try {
      await Future.delayed(const Duration(milliseconds: 200));
      int scoreToAdd = Random().nextBool() ? Random().nextInt(800) + 200 : 0;
      if (scoreToAdd > 0) {
        setState(() => _opponentPKScore += scoreToAdd);
        _sendSocketMessage("PK_UPDATE", opponentScore: _opponentPKScore);
        try {
          await HttpUtil().post(
            "/api/room/update_score",
            data: {"roomId": int.parse(_roomId), "myScore": _myPKScore, "opponentScore": _opponentPKScore},
          );
        } catch (e) {}
      }
    } catch (e) {
    } finally {
      _isAIThinking = false;
    }
  }

  // 🟢 补全：初始化动画控制器
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

  // 🟢 补全：播放动画
  void _playPKStartAnimation() {
    if (mounted) {
      setState(() => _showPKStartAnimation = true);
      _pkStartAnimationController.reset();
      _pkStartAnimationController.forward();
    }
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

  void _killAllBossVideos() {
    final listCopy = List<VideoPlayerController>.from(_allBossControllers);
    _allBossControllers.clear();
    _aiVideoController = null;
    for (var controller in listCopy) {
      try {
        controller.setVolume(0.0);
        controller.pause();
        controller.dispose();
      } catch (e) {}
    }
  }

  void _dismissKeyboard() {
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    FocusManager.instance.primaryFocus?.unfocus();
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
    if (_currentBoss == null) return;
    if (widget.isHost) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("房主不能离开直播间哦~")));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("前往对方直播间？"),
        content: const Text("确定要离开当前房间，去围观对方吗？"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("取消")),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => LiveStreamingPage(userId: widget.userId, userName: widget.userName, isHost: false, roomId: "1002"),
                ),
              );
            },
            child: const Text("确定"),
          ),
        ],
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
        final updatedGift = _activeGifts[existingIndex];
        finalCount = updatedGift.count + count;
        _activeGifts[existingIndex] = updatedGift.copyWith(count: finalCount);
      } else {
        _processNewGift(
          GiftEvent(senderName: senderName, senderAvatar: senderAvatar, giftName: giftData.name, giftIconUrl: giftData.iconUrl, count: finalCount, senderLevel: 0),
        );
      }
      _addGiftMessage(senderName, giftData.name, finalCount);
      if (_pkStatus == PKStatus.playing || _pkStatus == PKStatus.punishment) _myPKScore += (giftData.price * finalCount);
    });
    if (giftData.effectAsset != null && giftData.effectAsset!.isNotEmpty) _addEffectToQueue(giftData.effectAsset!);
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
    const String aliyunBgUrl = 'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/bg.mp4';
    _bgController = VideoPlayerController.networkUrl(Uri.parse(aliyunBgUrl));
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
        myBalance: 10,
        onSend: (gift) {
          _dismissKeyboard();
          _sendGift(gift);
          Navigator.pop(context);
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted) _dismissKeyboard();
          });
        },  userStatusNotifier: _userStatusNotifier,
      ),
    );
  }

  void _showMusicPanel() {
    _dismissKeyboard();
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (_) => const MusicPanel());
  }

  void _simulateVipEnter({String? overrideName}) {
    final names = ["顾北", "王校长", "阿特", "小柠檬", "榜一大哥", "神秘土豪"];
    final randomIdx = Random().nextInt(names.length);
    final name = overrideName ?? names[randomIdx];
    final level = ["玫瑰公爵", "帝皇", "君王", "公爵"][Random().nextInt(4)];
    final event = EntranceEvent(
      userName: name,
      level: level,
      avatarUrl: "https://picsum.photos/seed/${888 + randomIdx}/200",
      frameUrl: "https://cdn-icons-png.flaticon.com/512/8313/8313626.png",
    );
    _entranceQueue.add(event);
    if (!_isEntranceBannerShowing) _playNextEntrance();
    if (mounted)
      setState(() {
        _messages.insert(0, ChatMessage(name: "系统", content: "$level $name 降临直播间！", level: 100, levelColor: const Color(0xFFFFD700)));
      });
  }

  void _playNextEntrance() async {
    if (_entranceQueue.isEmpty) return;
    _isEntranceBannerShowing = true;
    final event = _entranceQueue.removeFirst();
    if (mounted)
      setState(() {
        _currentEntranceEvent = event;
        _welcomeBannerAnimation = Tween<Offset>(
          begin: const Offset(1.5, 0),
          end: const Offset(0, 0),
        ).animate(CurvedAnimation(parent: _welcomeBannerController, curve: Curves.easeOutQuart));
      });
    _welcomeBannerController.reset();
    await _welcomeBannerController.forward();
    await Future.delayed(const Duration(milliseconds: 2000));
    if (mounted)
      setState(() {
        _welcomeBannerAnimation = Tween<Offset>(
          begin: const Offset(0, 0),
          end: const Offset(-1.5, 0),
        ).animate(CurvedAnimation(parent: _welcomeBannerController, curve: Curves.easeInQuart));
      });
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
                          onlineCount: 100,
                          isVideoBackground: _isVideoBackground,
                          isBgInitialized: _isBgInitialized,
                          bgController: _bgController,
                          currentBgImage: _currentBgImage,
                          onClose: _handleCloseButton,
                          title: '',
                          name: '',
                          avatar: '',
                        )
                      : Column(
                          children: [
                            Container(
                              margin: EdgeInsets.only(top: padding.top),
                              height: topBarHeight,
                              child: BuildTopBar(
                                roomId: _roomId,
                                onlineCount: 100,
                                title: "房间:${widget.roomId}",
                                name: "房间:${widget.roomId}",
                                avatar: "${widget.roomId}",
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
                                    child: PKBattleView(
                                      leftVideoController: (_isVideoBackground && _isBgInitialized) ? _bgController : null,
                                      leftBgImage: _isVideoBackground ? null : _currentBgImage,
                                      rightBgImage: _opponentBgImage,
                                      isRightVideoMode: _isRightVideoMode,
                                      rightVideoController: _aiVideoController,
                                      currentBoss: _currentBoss,
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
                              margin: const EdgeInsets.only(left: 10),
                              height: 25,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
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
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                    child: Text(
                                      _currentEntranceEvent!.level,
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, height: 1.1),
                                    ),
                                  ),
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
}
