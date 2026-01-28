import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_live/screens/home/live/widgets/level_badge_widget.dart';
import 'package:flutter_live/store/user_store.dart';
import 'package:video_player/video_player.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:my_alpha_player/my_alpha_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// 假设你的路径结构如下，请根据实际情况调整
import '../../../models/user_models.dart';
import '../../../services/gift_api.dart';
import '../../../services/ai_music_service.dart';
import '../../../tools/HttpUtil.dart';

import 'models/live_models.dart';
import 'widgets/pk_real_battle_view.dart';
import 'widgets/single_mode_view.dart';
import 'package:flutter_live/screens/home/live/widgets/build_chat_list.dart';
import 'package:flutter_live/screens/home/live/widgets/build_input_bar.dart';
import 'package:flutter_live/screens/home/live/widgets/build_top_bar.dart';
import 'package:flutter_live/screens/home/live/widgets/music_panel.dart';
import 'package:flutter_live/screens/home/live/widgets/pk_widgets.dart';
import 'animate_gift_item.dart';
import 'gift_panel.dart';

class EntranceEvent {
  final String userName;
  final int level;
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
  // PK时长配置
  int _pkDuration = 90; // 默认为90秒，后续根据选择或接口动态更新
  final int _punishmentDuration = 20;

  WebSocketChannel? _channel;
  StreamSubscription? _socketSubscription;
  late String _myUserName;
  late String _myUserId;
  late int _myLevel;
  late String _myAvatar;
  late String _roomId;
  Timer? _effectWatchdog;
  late int _onlineCount = 0;
  late bool _isHost = false;

  // 🟢 新增：用户余额（用于扣费检查）
  int _myCoins = 0;

  final String _wsUrl = "ws://${HttpUtil.getBaseIpPort}/ws/live";

  VideoPlayerController? _bgController;
  bool _isBgInitialized = false;
  bool _isVideoBackground = false;
  String _currentBgImage = "";
  int _currentUserId = 1;
  String _currentName = "";
  Timer? _heartbeatTimer;
  bool _isDisposed = false;
  String _currentAvatar = "";
  final List<String> _bgImageUrls = [
    "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/live_bg_1.jpg",
    "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/live_bg_2.jpg",
  ];

  PKStatus _pkStatus = PKStatus.idle;
  int _myPKScore = 0;
  int _opponentPKScore = 0;
  int _pkTimeLeft = 0;
  Timer? _pkTimer;

  List<dynamic> _participants = [];

  // 🟢 核心修改：首翻相关变量
  bool _isFirstGiftPromoActive = false; // 活动时间是否开启
  int _promoTimeLeft = 30; // 倒计时
  Timer? _promoTimer;

  // 🟢 使用 Set<String> 记录 userId，确保每人仅一次
  final Set<String> _usersWhoUsedPromo = {};

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
  final ValueNotifier<UserStatus> _userStatusNotifier = ValueNotifier(
    UserStatus(0, 0, coinsToNextLevel: 0, coinsNextLevelThreshold: 0, coinsToNextLevelText: "0", coinsCurrentLevelThreshold: 0),
  );

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();

    _myUserId = widget.userId;
    _myUserName = widget.userName;
    _myLevel = widget.level;
    _myAvatar = widget.avatarUrl;
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

  // 🟢 新增：获取用户余额
  Future<void> _fetchUserBalance() async {
    try {
      final res = await HttpUtil().get("/api/user/info");
      if (mounted && res != null) {
        setState(() {
          _myCoins = _parseInt(res['coin']);
          _myLevel = _parseInt(res['level']);
          int coinsToNextLevel = res['coinsToNextLevel'];
          int coinsNextLevelThreshold = res['coinsNextLevelThreshold'];
          String coinsToNextLevelText = res['coinsToNextLevelText'];
          int coinsCurrentLevelThreshold = res['coinsCurrentLevelThreshold'];
          _userStatusNotifier.value = UserStatus(
            _myCoins,
            _myLevel,
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

      _sendSocketMessage("ENTER", content: "进入了直播间", userName: _myUserName, avatar: _myAvatar, level: _myLevel);
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
      await HttpUtil().post("/api/room/join", data: {"roomId": int.parse(_roomId)});

      // 🟢 顺便拉取余额
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
    try {
      final res = await HttpUtil().get("/api/pk/detail", params: {"roomId": int.parse(_roomId), "userId": _myUserId, "userName": _myUserName});
      final data = res;
      setState(() {
        // _onlineCount = _parseInt(data['onlineCount']);
      });

      if (data['pkInfo'] != null) {
        final pkInfo = data['pkInfo'];
        final int status = _parseInt(pkInfo['status']);
        final String startTimeStr = pkInfo['startTime'];

        // 🟢 同步 PK 时长 (如果没有返回则默认90)
        _pkDuration = _parseInt(pkInfo['duration'], defaultValue: 90);

        setState(() {
          _participants = pkInfo['participants'] as List;
          if (_participants.isNotEmpty) {
            _currentName = _participants[0]['name'] ?? _currentName;
            _currentAvatar = _participants[0]['avatar'] ?? _currentAvatar;
            _currentBgImage = _participants[0]['pkBg'] ?? _currentBgImage;
            if (_participants.length >= 2) {
              _myPKScore = _parseInt(_participants[0]['score']);
              _opponentPKScore = _parseInt(_participants[1]['score']);
            }
          }
        });

        DateTime startTime = DateTime.parse(startTimeStr);
        final int elapsedSeconds = DateTime.now().difference(startTime).inSeconds;

        if (status == 1) {
          // ⚠️ 使用 _pkDuration 计算剩余时间
          final int remaining = _pkDuration - elapsedSeconds;
          if (remaining > 0) {
            _startPKRound(initialTimeLeft: remaining);
            // 🟢 进房同步：如果还在30秒内，开启首翻计时
            const int promoDuration = 30;
            if (elapsedSeconds < promoDuration) {
              setState(() {
                _isFirstGiftPromoActive = true;
                _promoTimeLeft = promoDuration - elapsedSeconds;
                _usersWhoUsedPromo.clear(); // 注意：中途进房简单处理，默认清空或需从后端拉取已用列表
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
          // ⚠️ 惩罚阶段剩余时间：惩罚时长 - (经过时间 - PK时长)
          final int remainingPunishment = _punishmentDuration - (elapsedSeconds - _pkDuration);
          if (remainingPunishment > 0) {
            _enterPunishmentPhase(timeLeft: remainingPunishment);
          }
        } else if (status == 3) {
          DateTime startTime = DateTime.parse(startTimeStr);
          int totalElapsed = DateTime.now().difference(startTime).inSeconds;
          // ⚠️ 连麦阶段经过时间：总时间 - PK时长 - 惩罚时长
          int coHostElapsed = totalElapsed - _pkDuration - _punishmentDuration;
          _enterCoHostPhase(initialElapsedTime: coHostElapsed > 0 ? coHostElapsed : 0, serverStartTime: startTime);
        }
      } else {
        _currentName = data['title'] ?? _currentName;
        _currentAvatar = data['coverImg'] ?? _currentAvatar;
        _currentBgImage = data['personalPkBg'] ?? _currentBgImage;
      }
      _currentUserId = data['anchorId'] ?? _currentUserId;
      _isHost = _currentUserId.toString() == UserStore.to.userId;
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
          final String joinerName = data['userName'] ?? "神秘人";
          final String joinerAvatar = data['avatar'] ?? "";
          final int joinerLevel = data['level'] ?? 1;

          _simulateVipEnter(overrideName: joinerName, overrideAvatar: joinerAvatar, overrideLevel: joinerLevel);
          break;
        case "CHAT":
          _addSocketChatMessage(data['userName'] ?? "神秘人", data['content'] ?? "", isMe ? Colors.amber : Colors.white, level: data["level"]);
          break;
        case "ONLINE_COUNT":
          final int newCount = data['onlineCount'] ?? 0;
          if (mounted) setState(() => _onlineCount = newCount);
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

          // 🟢 关键：Socket 接收时，传入发送者的 userId
          _processGiftEvent(
            targetGift,
            data['userName'] ?? "神秘人",
            data['avatar'] ?? "神秘人",
            senderLevel: data['level'] ?? 1,
            isMe,
            senderId: msgUserId, // 👈 必须传 ID
            count: data['giftCount'] ?? 1,
          );
          break;
        case "PK_START":
        // 收到 PK 开始，如果有时长数据最好同步一下，否则可能默认90
        // 建议：Socket 消息体里也带上 duration
          if (data['duration'] != null) {
            _pkDuration = _parseInt(data['duration']);
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

  void _sendSocketMessage(String type, {String? content, String? giftId, int giftCount = 1, String? userName, String? avatar, int? level}) {
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

  // 🟢 修改点：点击发起PK，弹出时长选择
  void _onTapStartPK() {
    _dismissKeyboard();
    if (_pkStatus != PKStatus.idle || !_isHost) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 20,left: 20,right: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                child: const Text(
                  "选择PK时长",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              // 第一条分割线
              const Divider(color: Colors.white10, height: 1),

              _buildDurationOption("2分钟", 120),
              const Divider(color: Colors.white10, height: 1), // 选项间的网格线

              _buildDurationOption("5分钟", 300),
              const Divider(color: Colors.white10, height: 1), // 选项间的网格线

              _buildDurationOption("10分钟", 600),
              const Divider(color: Colors.white10, height: 1), // 选项间的网格线

              _buildDurationOption("15分钟", 900),
              const Divider(color: Colors.white10, height: 1), // 最后一条网格线

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
      // ⬇️ 增加垂直内边距，让每一项高度变高
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      title: Text(
          label,
          // ⬇️ 文字居中
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 16)
      ),
      // ⬇️ 移除右侧箭头 (trailing)
      trailing: null,
      onTap: () {
        Navigator.pop(context);
        _startPKWithDuration(seconds);
      },
    );
  }

  // 🟢 真正的发起逻辑
  void _startPKWithDuration(int duration) async {
    setState(() {
      _pkDuration = duration;
    });
    try {
      await HttpUtil().post("/api/pk/start", data: {"roomId": int.parse(_roomId), "duration": duration});
      // 成功后，_handleSocketMessage 会收到 PK_START，或者直接在这里调用 _startPKRound
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("开启失败: $e")));
    }
  }

  void _startWatchdog(int seconds) {
    _effectWatchdog?.cancel();
    _effectWatchdog = Timer(Duration(seconds: seconds), () {
      print("🐶 看门狗介入：特效播放超时或卡死，强制切歌");
      _onEffectComplete(); // 强制结束
    });
  }

  void _startPKRound({int? initialTimeLeft}) {
    _pkTimer?.cancel();
    _pkTimer = null;
    if (_pkStatus == PKStatus.playing && initialTimeLeft == null) return;
    if (initialTimeLeft == null) _playPKStartAnimation();

    setState(() {
      _pkStatus = PKStatus.playing;
      // ⚠️ 使用 _pkDuration
      _pkTimeLeft = initialTimeLeft ?? _pkDuration;

      if (initialTimeLeft == null) {
        _myPKScore = 0;
        _opponentPKScore = 0;

        // 🟢 开启首翻活动 (前30秒)
        _isFirstGiftPromoActive = true;
        _promoTimeLeft = 30;
        // 🟢 清空已使用名单，所有人获得新一轮机会
        _usersWhoUsedPromo.clear();

        _startPromoTimer();
      }
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
    setState(() {
      _pkStatus = PKStatus.punishment;
      _pkTimeLeft = (timeLeft != null && timeLeft > 0) ? timeLeft : _punishmentDuration;
      _isFirstGiftPromoActive = false; // 确保惩罚期关闭活动
      _promoTimer?.cancel();
    });
    if (_isHost && timeLeft == null) {
      try {
        await HttpUtil().post("/api/room/enter_punishment", data: {"roomId": int.parse(_roomId)});
        _sendSocketMessage("PK_PUNISHMENT");
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
      // ⚠️ 服务端开始时间 + PK时长 + 惩罚时长 = 连麦开始时间
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

  void _addSocketChatMessage(String name, String content, Color color, {required int level}) {
    setState(() {
      _messages.insert(0, ChatMessage(name: name, content: content, level: level, levelColor: color, isGift: false));
    });
  }

  void _addGiftMessage(String senderName, String giftName, int count, {String senderAvatar = "", required int senderLevel}) {
    setState(
          () => _messages.insert(
        0,
        ChatMessage(name: senderName, content: '送出了 $giftName x$count', level: senderLevel, levelColor: Colors.yellow, isGift: true),
      ),
    );
  }

  // 🟢 核心修改：处理礼物和分数 (包含 userId 逻辑)
  void _processGiftEvent(
      GiftItemData giftData,
      String senderName,
      String senderAvatar,
      bool isMe, {
        required String senderId,
        int count = 1,
        int senderLevel = 1,
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
            count: count,
            senderLevel: senderLevel,
          ),
        );
      }
      _addGiftMessage(senderName, giftData.name, count, senderLevel: senderLevel);

      // 🟢 PK 分数计算逻辑
      if (_pkStatus == PKStatus.playing) {
        int scoreToAdd = giftData.price * count;

        // 🟢 首翻判定：时间有效 且 该 userId 未使用过
        if (_isFirstGiftPromoActive && !_usersWhoUsedPromo.contains(senderId)) {
          scoreToAdd = scoreToAdd * 2; // 分数翻倍
          _usersWhoUsedPromo.add(senderId); // 记录该用户已使用，本局无效
          // ⚠️ 倒计时继续，UI 会自动变更为“已达成”
        }

        if (isMe) {
          _myPKScore += scoreToAdd;
          // 上报分数
          HttpUtil().post("/api/pk/update_score", data: {"roomId": int.parse(_roomId), "score": scoreToAdd});
        } else {
          // 如果是队友或自己主播加分逻辑，如果是PK对手则不应加到 _myPKScore
          // 假设：Socket 的 PK_UPDATE 会做最终同步，这里只是为了即时动画效果
          // 如果 _processGiftEvent 收到的是 对手 的礼物，应该加到 _opponentPKScore
          // 简单判断：如果 senderId 是对手主播ID，或者当前房间是对手房间
          // 这里简化处理：默认 socket 收到 GIFT 都是本房间的
          _myPKScore += scoreToAdd;
        }
      }
    });

    if (giftData.effectAsset != null && giftData.effectAsset!.isNotEmpty) {
      _addEffectToQueue(giftData.effectAsset!);
    }
    if (isMe) _triggerComboMode();
  }

  // 🟢 核心修改：发送礼物 + 扣费逻辑
  Future<void> _sendGift(GiftItemData giftData) async {
    _dismissKeyboard();
    int countToSend = 1;

    // 1. 本地计算价格 (永远按1倍扣费)
    int totalPrice = giftData.price * countToSend;

    // 2. 检查余额
    if (_myCoins < totalPrice) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("余额不足，请充值"), backgroundColor: Colors.red));
      return;
    }

    try {
      // 3. 调接口扣费
      final res = await HttpUtil().post("/api/gift/send", data: {"userId": int.parse(_myUserId), "giftId": giftData.id, "count": countToSend});

      if (!mounted) return;

      setState(() {
        if (res != null && res['newBalance'] != null) {
          _myCoins = _parseInt(res['newBalance']);
          _myLevel = _parseInt(res['newLevel']);
        } else {
          _myCoins -= totalPrice;
        }
        _userStatusNotifier.value = UserStatus(
          _myCoins,
          _myLevel,
          coinsToNextLevel: _parseInt(res['coinsToNextLevel']),
          coinsToNextLevelText: res['coinsToNextLevelText'],
          coinsNextLevelThreshold: _parseInt(res['coinsNextLevelThreshold']),
          coinsCurrentLevelThreshold: _parseInt(res['coinsCurrentLevelThreshold']),
        );
      });

      // 4. 发送 Socket (让所有人看到特效)
      _sendSocketMessage("GIFT", giftId: giftData.id, giftCount: countToSend, userName: _myUserName, avatar: _myAvatar, level: _myLevel);

      // 5. 本地触发特效和算分 (传入 myUserId)
      // _processGiftEvent(giftData, _myUserName, _myAvatar, true, senderId: _myUserId, count: countToSend);
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

  void _onPlayerCreated(MyAlphaPlayerController controller) {
    print("✅ 播放器视图已创建，控制器就绪"); // 建议加个日志看看有没有打印
    _alphaPlayerController = controller;

    // 绑定回调（防止你在别的地方漏了绑定）
    _alphaPlayerController?.onFinish = _onEffectComplete;
    _alphaPlayerController?.onVideoSize = (width, height) {
      if (width > 0 && height > 0 && mounted) {
        setState(() => _videoAspectRatio = width / height);
      }
    };

    // 如果队列里有堆积的特效，且当前没有在播放，立即触发
    if (_effectQueue.isNotEmpty && !_isEffectPlaying) {
      _playNextEffect();
    }
  }

  void _onEffectComplete() {
    if (!mounted) return;

    // 1. 关掉看门狗 (任务已完成，不需要狗叫了)
    _effectWatchdog?.cancel();

    // 2. 停止播放器
    try {
      _alphaPlayerController?.stop(); // 如果库支持 reset 或 stop
    } catch (e) {}

    // 3. 状态重置
    setState(() {
      _isEffectPlaying = false;
    });

    // 4. 递归播放下一个
    // 稍微延迟一点点，给 UI 喘息机会，避免死循环爆栈
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _playNextEffect();
    });
  }

  Future<void> _playNextEffect() async {
    // 1. 队列检查
    if (_effectQueue.isEmpty) return;

    // 如果已经在播放，且控制器正常，则不打断
    if (_isEffectPlaying && _alphaPlayerController != null) return;

    final url = _effectQueue.removeFirst();
    setState(() => _isEffectPlaying = true);

    // ❌❌❌ 【删除这两行】不要在这里销毁控制器！
    // try { _alphaPlayerController?.dispose(); } catch(e) {}
    // _alphaPlayerController = null;
    // ❌❌❌

    // ✅ 【改为】先停止上一个（如果有的话），确保状态干净
    try {
      await _alphaPlayerController?.stop();
    } catch (e) {}

    // 2. 启动看门狗 (防止下载或播放卡死)
    _startWatchdog(17);

    try {
      // 3. 下载文件
      String? localPath = await _downloadGiftFile(url).timeout(
          const Duration(seconds: 8),
          onTimeout: () => null
      );

      // 下载失败处理
      if (localPath == null || !mounted) {
        debugPrint("❌ 文件下载失败或页面已销毁，跳过");
        _onEffectComplete();
        return;
      }

      // 4. 播放
      if (mounted) {
        // ✅ 此时 _alphaPlayerController 应该是在 initState 之后的 onCreated 里赋值好的
        // 只要页面没销毁，它就不应该是 null
        if (_alphaPlayerController != null) {
          print("▶️ 开始播放特效: $localPath");
          await _alphaPlayerController!.play(localPath);
        } else {
          // 如果这里还是 null，说明 onCreated 从来没执行过（View 没渲染出来）
          print("⚠️ 播放器未就绪（onCreated未回调），跳过此特效");
          _onEffectComplete();
        }
      }

    } catch (e) {
      print("❌ 特效播放异常: $e");
      _onEffectComplete();
    }
  }

  void _addEffectToQueue(String url) {
    _effectQueue.add(url);
    print("➕ 加入队列，当前队列长度: ${_effectQueue.length}, 正在播放: $_isEffectPlaying");

    // 只有当前空闲时，才主动去推一下
    if (!_isEffectPlaying) {
      _playNextEffect();
    }
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
        myBalance: _myCoins, // 传递余额给面板
        userStatusNotifier: _userStatusNotifier, // 🔥 传入 Notifier
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

  void _simulateVipEnter({String? overrideName, String? overrideAvatar, required int overrideLevel}) {
    final names = ["顾北", "王校长", "阿特", "小柠檬"];
    final randomIdx = Random().nextInt(names.length);
    final name = overrideName ?? names[randomIdx];
    final event = EntranceEvent(
      userName: name,
      level: overrideLevel,
      avatarUrl: overrideAvatar ?? "https://picsum.photos/seed/${888 + randomIdx}/200",
      frameUrl: "https://cdn-icons-png.flaticon.com/512/8313/8313626.png",
    );
    _entranceQueue.add(event);
    if (!_isEntranceBannerShowing) _playNextEntrance();
    if (mounted) {
      setState(() => _messages.insert(0, ChatMessage(name: "", content: "$name 加入直播间！", level: overrideLevel, levelColor: const Color(0xFFFFD700))));
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

    // 🟢 核心修改：Banner 显示条件
    // 1. 在首翻时间内 (30s内)
    // 2. 正在 PK
    // 无论是否达成，都显示，只是文案和颜色不同
    final bool showPromoBanner = _isFirstGiftPromoActive && _pkStatus == PKStatus.playing;

    // 🟢 检查当前用户是否已达成 (使用 userId Set)
    final bool iHaveUsedPromo = _usersWhoUsedPromo.contains(_myUserId);

    if (showPromoBanner) entranceTop += 22 + 4;

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
                    height: _pkStatus == PKStatus.idle ? 230 : (size.height - pkVideoBottomY - 30),
                    child: RepaintBoundary(
                      child: Container(
                        color: Colors.transparent,
                        child: Column(
                          children: [
                            Expanded(child: BuildChatList(bottomInset: 0, messages: _messages)),
                            BuildInputBar(
                              textController: _textController,
                              onTapGift: _showGiftPanel,
                              onSend: (text) => _sendSocketMessage("CHAT", content: text, userName: _myUserName, level: _myLevel),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 🟢 核心修改：首翻横幅
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
                            // 🟢 颜色区分：已达成(绿/teal)，未达成(粉/透明)
                            gradient: iHaveUsedPromo
                                ? LinearGradient(colors: [Colors.green.withOpacity(0.8), Colors.teal.withOpacity(0.8)])
                                : LinearGradient(colors: [Colors.white.withOpacity(0.15), Colors.pinkAccent.withOpacity(0.5)]),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 🟢 文案区分
                              Text(
                                iHaveUsedPromo ? "首翻已达成" : "首送翻倍",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
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
                            LevelBadge(level: _currentEntranceEvent!.level),
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
                        opacity: _isEffectPlaying ? 1.0 : 0.01,
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
    _isDisposed = true;
    _effectWatchdog?.cancel(); // 别忘了关狗
    _alphaPlayerController?.dispose(); // ✅ 只有这里才能彻底销毁
    WakelockPlus.disable();
    _socketSubscription?.cancel();
    _channel?.sink.close();
    _heartbeatTimer?.cancel();
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