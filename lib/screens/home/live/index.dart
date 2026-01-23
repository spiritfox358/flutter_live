import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:my_alpha_player/my_alpha_player.dart';

// --- 引入组件 ---
import '../../../services/ai_service.dart';
import 'models/live_models.dart';
import 'widgets/pk_battle_view.dart';
import 'widgets/single_mode_view.dart';
import 'package:flutter_live/screens/home/live/widgets/build_chat_list.dart';
import 'package:flutter_live/screens/home/live/widgets/build_input_bar.dart';
import 'package:flutter_live/screens/home/live/widgets/build_top_bar.dart';
import 'package:flutter_live/screens/home/live/widgets/music_panel.dart';
import 'package:flutter_live/screens/home/live/widgets/pk_widgets.dart';
import 'animate_gift_item.dart';
import 'gift_panel.dart';

// --- 静态数据配置 ---
final List<AIBoss> _bosses = [
  const AIBoss(
    name: "机械姬·零号",
    avatarUrl: "https://cdn-icons-png.flaticon.com/512/4712/4712109.png",
    videoUrl: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/ai_avatar_1.mp4",
    difficulty: 3,
    tauntMessages: ["就这？手速太慢了", "由于分差过大，我已开启省电模式", "哔...检测到你在摆烂"],
  ),
  const AIBoss(
    name: "赛博魔王",
    avatarUrl: "https://cdn-icons-png.flaticon.com/512/6195/6195678.png",
    videoUrl: "",
    difficulty: 8,
    tauntMessages: ["这点分不够塞牙缝", "颤抖吧凡人！", "全军出击！给我碾压对面！"],
  ),
];

class LiveStreamingPage extends StatefulWidget {
  const LiveStreamingPage({super.key});

  @override
  State<LiveStreamingPage> createState() => _LiveStreamingPageState();
}

class _LiveStreamingPageState extends State<LiveStreamingPage> with TickerProviderStateMixin {
  // ==================== 状态变量区域 ====================
  final int _pkEndWaitTime = 20;

  VideoPlayerController? _bgController;
  bool _isBgInitialized = false;
  bool _isVideoBackground = false;
  String _currentBgImage = "";
  final List<String> _bgImageUrls = [
    "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/live_bg_1.png",
    "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/live_bg_2.png",
  ];

  PKStatus _pkStatus = PKStatus.idle;
  int _myPKScore = 0;
  int _opponentPKScore = 0;
  int _pkTimeLeft = 0;
  Timer? _pkTimer;
  bool _isAiRaging = false;
  AIBoss? _currentBoss;
  VideoPlayerController? _aiVideoController;
  String _opponentBgImage = "";
  bool _isAIThinking = false;

  MyAlphaPlayerController? _alphaPlayerController;
  final Queue<String> _effectQueue = Queue();
  bool _isEffectPlaying = false;
  double? _videoAspectRatio;

  final TextEditingController _textController = TextEditingController();
  List<ChatMessage> _messages = [];
  static const int _maxActiveGifts = 2;
  final List<GiftEvent> _activeGifts = [];
  final Queue<GiftEvent> _waitingQueue = Queue();

  bool _showComboButton = false;
  GiftItemData? _lastGiftSent;
  late AnimationController _comboScaleController;
  late AnimationController _countdownController;

  // 🟢 恢复 PK 开场动画变量
  bool _showPKStartAnimation = false;
  late AnimationController _pkStartAnimationController;
  late Animation<double> _pkLeftAnimation;
  late Animation<double> _pkRightAnimation;
  late Animation<double> _pkFadeAnimation;

  final List<String> _dummyNames = ["Luna", "右岸", "从此安静", "梦醒时分", "快乐小狗", "榜一大哥"];
  final List<String> _dummyContents = ["主播好美！", "这歌好听", "点赞点赞", "666", "关注了"];

  @override
  void initState() {
    super.initState();
    _initializeBackground();
    _pickRandomImage();
    _generateDummyMessages();

    _comboScaleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150), lowerBound: 0.0, upperBound: 1.0);
    _countdownController = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _countdownController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _comboScaleController.reverse().then((_) {
          setState(() { _showComboButton = false; _lastGiftSent = null; });
        });
      }
    });

    // 🟢 初始化 PK 开场动画
    _initPKStartAnimation();
  }

  // 🟢 PK 动画初始化逻辑
  void _initPKStartAnimation() {
    _pkStartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800), // 快速进场
    );

    const Curve moveCurve = Curves.easeOutExpo;

    // 左侧 P 飞入
    _pkLeftAnimation = Tween<double>(begin: -300, end: 0).animate(
      CurvedAnimation(parent: _pkStartAnimationController, curve: const Interval(0.0, 0.6, curve: moveCurve)),
    );

    // 右侧 K 飞入
    _pkRightAnimation = Tween<double>(begin: 300, end: 0).animate(
      CurvedAnimation(parent: _pkStartAnimationController, curve: const Interval(0.0, 0.6, curve: moveCurve)),
    );

    // 整体淡出
    _pkFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _pkStartAnimationController, curve: const Interval(0.8, 1.0, curve: Curves.easeIn)),
    );

    _pkStartAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        // 动画播完后隐藏层
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

  @override
  void dispose() {
    _bgController?.dispose();
    _aiVideoController?.dispose();
    _textController.dispose();
    _comboScaleController.dispose();
    _countdownController.dispose();
    _pkStartAnimationController.dispose(); // 🟢 释放动画控制器
    _pkTimer?.cancel();
    super.dispose();
  }

  // 辅助方法：安全收起键盘
  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  void _handleCloseButton() {
    _dismissKeyboard();

    if (_pkStatus != PKStatus.idle) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (BuildContext ctx) {
          return Container(
            decoration: const BoxDecoration(color: Color(0xFF1A1A1A), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(child: Container(margin: const EdgeInsets.only(top: 12, bottom: 20), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                ListTile(leading: const Icon(Icons.link_off, color: Colors.redAccent), title: const Text("断开连线/PK", style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(ctx); _disconnectCoHost(); }),
                const Divider(color: Colors.white10, height: 1),
                ListTile(leading: const Icon(Icons.exit_to_app, color: Colors.white70), title: const Text("退出直播间", style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(ctx); Navigator.of(context).pop(); }),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
              ],
            ),
          );
        },
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _startAIBattle() {
    _dismissKeyboard();
    if (_pkStatus != PKStatus.idle) return;

    // 🟢 1. 播放开场动画
    _playPKStartAnimation();

    // 🟢 2. 延迟 800ms 后正式开始逻辑（等待动画播放完）
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;

      final boss = _bosses[Random().nextInt(_bosses.length)];
      _currentBoss = boss;
      _opponentBgImage = _bgImageUrls[Random().nextInt(_bgImageUrls.length)]; // 恢复随机图逻辑

      setState(() {
        _pkStatus = PKStatus.playing;
        _myPKScore = 0;
        _opponentPKScore = 0;
        _pkTimeLeft = 90;
      });

      if (boss.videoUrl.isNotEmpty) {
        _aiVideoController = VideoPlayerController.networkUrl(Uri.parse(boss.videoUrl));
        _aiVideoController!.initialize().then((_) {
          _aiVideoController!.setLooping(true);
          _aiVideoController!.play();
          if (mounted) setState(() {});
        });
      }
      _pkTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() => _pkTimeLeft--);
        if (_pkTimeLeft <= 0) { _pkTimer?.cancel(); _enterPunishmentPhase(); return; }
        if (!_isAIThinking && (_pkTimeLeft % 3 == 0 || _pkTimeLeft <= 10)) { _triggerAIResponse(context: "periodic_check"); }
      });
    });
  }

  void _enterPunishmentPhase() { setState(() { _pkStatus = PKStatus.punishment; _pkTimeLeft = _pkEndWaitTime; }); _pkTimer = Timer.periodic(const Duration(seconds: 1), (timer) { if (!mounted) return; setState(() => _pkTimeLeft--); if (_pkTimeLeft <= 0) _stopPK(); }); }
  void _stopPK() { _pkTimer?.cancel(); setState(() { _pkStatus = PKStatus.coHost; _pkTimeLeft = 0; }); _pkTimer = Timer.periodic(const Duration(seconds: 1), (timer) { if (!mounted) return; setState(() => _pkTimeLeft++); }); }
  void _disconnectCoHost() { _aiVideoController?.dispose(); _aiVideoController = null; _pkTimer?.cancel(); setState(() { _pkStatus = PKStatus.idle; _myPKScore = 0; _opponentPKScore = 0; }); }

  Future<void> _triggerAIResponse({required String context, String? customPrompt}) async {
    if (_currentBoss == null || _pkStatus != PKStatus.playing) return;
    if (_isAIThinking && context == "periodic_check") return;
    _isAIThinking = true;
    try {
      final decision = await AIService.analyzeSituation(bossName: _currentBoss!.name, bossPersona: "难度等级${_currentBoss!.difficulty}", myScore: _myPKScore, opponentScore: _opponentPKScore, timeLeft: _pkTimeLeft, userAction: context == "gift" ? customPrompt : null, userChat: context == "chat" ? customPrompt : null);
      if (!mounted) return;
      if (decision.addScore > 0) { setState(() { _opponentPKScore += decision.addScore.toInt(); }); }
      if (decision.message.isNotEmpty) { _addFakeMessage(_currentBoss!.name, decision.message, Colors.cyanAccent); }
    } catch (e) { debugPrint("AI error: $e"); } finally { _isAIThinking = false; }
  }

  void _addGiftMessage(String senderName, String giftName, int count) {
    setState(() {
      _messages.insert(0, ChatMessage(name: senderName, content: '送出了 $giftName x$count', level: 99, levelColor: Colors.yellow, isGift: true));
    });
  }

  void _sendGift(GiftItemData giftData) {
    _dismissKeyboard();

    const senderName = "我"; final comboKey = "${senderName}_${giftData.name}"; _lastGiftSent = giftData;
    setState(() {
      final existingIndex = _activeGifts.indexWhere((g) => g.comboKey == comboKey);
      int giftCount = 1;
      if (existingIndex != -1) {
        final updatedGift = _activeGifts[existingIndex];
        giftCount = updatedGift.count + 1;
        _activeGifts[existingIndex] = updatedGift.copyWith(count: giftCount);
      } else {
        _processNewGift(GiftEvent(senderName: senderName, giftName: giftData.name, giftIconUrl: giftData.iconUrl, count: giftCount));
      }
      _addGiftMessage(senderName, giftData.name, giftCount);
      if (_pkStatus == PKStatus.playing || _pkStatus == PKStatus.punishment) { _myPKScore += giftData.price; }
    });

    if (giftData.effectAsset != null && giftData.effectAsset!.isNotEmpty) { _addEffectToQueue(giftData.effectAsset!); }
    _triggerComboMode();
    if (_pkStatus == PKStatus.playing) { Future.delayed(const Duration(milliseconds: 1000), () { _triggerAIResponse(context: "gift", customPrompt: "玩家送了${giftData.name}"); }); }
  }

  void _processNewGift(GiftEvent gift) { if (_activeGifts.length < _maxActiveGifts) { _activeGifts.add(gift); } else { _waitingQueue.add(gift); } }
  void _onGiftFinished(String giftId) { setState(() { _activeGifts.removeWhere((element) => element.id == giftId); if (_waitingQueue.isNotEmpty) { _activeGifts.add(_waitingQueue.removeFirst()); } }); }
  void _triggerComboMode() { if (!_showComboButton) { setState(() => _showComboButton = true); _comboScaleController.forward(); } _countdownController.reset(); _countdownController.forward(); }

  void _onPlayerCreated(MyAlphaPlayerController controller) { _alphaPlayerController = controller; _alphaPlayerController?.onFinish = _onEffectComplete; _alphaPlayerController?.onVideoSize = (width, height) { if (width > 0 && height > 0 && mounted) { final newRatio = width / height; if (_videoAspectRatio == null || (_videoAspectRatio! - newRatio).abs() > 0.01) { setState(() => _videoAspectRatio = newRatio); } } }; }
  void _onEffectComplete() { if (!mounted) return; _alphaPlayerController?.stop(); setState(() => _isEffectPlaying = false); Future.delayed(const Duration(milliseconds: 50), _playNextEffect); }
  void _playNextEffect() async { if (_effectQueue.isEmpty || _alphaPlayerController == null) return; final url = _effectQueue.removeFirst(); setState(() => _isEffectPlaying = true); try { String? localPath = await _downloadGiftFile(url); if (localPath != null && mounted) { await _alphaPlayerController!.play(localPath); } else _onEffectComplete(); } catch (e) { _onEffectComplete(); } }
  void _addEffectToQueue(String url) { _effectQueue.add(url); if (!_isEffectPlaying) _playNextEffect(); }
  Future<String?> _downloadGiftFile(String url) async { try { final dir = await getApplicationDocumentsDirectory(); final fileName = url.split('/').last; final savePath = "${dir.path}/$fileName"; final file = File(savePath); if (await file.exists()) return savePath; await Dio().download(url, savePath); return savePath; } catch (e) { return null; } }

  void _initializeBackground() async {
    const String aliyunBgUrl = 'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/bg.mp4';
    _bgController = VideoPlayerController.networkUrl(Uri.parse(aliyunBgUrl));
    try { await _bgController!.initialize(); _bgController!.setLooping(true); _bgController!.setVolume(0.0); if (_isVideoBackground) _bgController!.play(); setState(() => _isBgInitialized = true); } catch (e) { print("背景失败: $e"); }
  }
  void _toggleBackgroundMode() { setState(() { _isVideoBackground = !_isVideoBackground; if (_isVideoBackground) { if (_isBgInitialized) _bgController?.play(); } else { if (_isBgInitialized) _bgController?.pause(); _pickRandomImage(); } }); }
  void _pickRandomImage() { setState(() => _currentBgImage = _bgImageUrls[Random().nextInt(_bgImageUrls.length)]); }
  void _addFakeMessage(String name, String content, Color color) { setState(() { _messages.insert(0, ChatMessage(name: name, content: content, level: 99, levelColor: color,isGift: false,)); }); }
  void _generateDummyMessages() { final random = Random(); List<ChatMessage> temp = []; for (int i = 0; i < 20; i++) { temp.add(ChatMessage(name: _dummyNames[random.nextInt(_dummyNames.length)], content: _dummyContents[random.nextInt(_dummyContents.length)], level: random.nextInt(50) + 1, levelColor: Colors.primaries[random.nextInt(Colors.primaries.length)],isGift: false)); } setState(() => _messages = temp.reversed.toList()); }

  void _showGiftPanel() {
    _dismissKeyboard();
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => GiftPanel(onSend: (gift) {
          _sendGift(gift);
          Navigator.pop(context);
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _dismissKeyboard();
          });
        })
    );
  }

  void _showMusicPanel() {
    _dismissKeyboard();
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (_) => const MusicPanel());
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

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          _dismissKeyboard();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 🟢 PK模式下的渐变底色
            if (_pkStatus != PKStatus.idle)
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF100101), // 黑色
                        Color(0xFF141E28), // 浅蓝色
                      ],
                      stops: [0.0, 0.8],
                    ),
                  ),
                ),
              ),

            // 1. 底层画面 (视频/单人模式)
            _pkStatus == PKStatus.idle
                ? SingleModeView(
              isVideoBackground: _isVideoBackground, isBgInitialized: _isBgInitialized, bgController: _bgController, currentBgImage: _currentBgImage,
              onClose: _handleCloseButton,
            )
                : Column(
              children: [
                Container(margin: EdgeInsets.only(top: padding.top), height: topBarHeight, child: BuildTopBar(title: "直播间", onClose: _handleCloseButton)),
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
                            rightVideoController: _aiVideoController,
                            currentBoss: _currentBoss,
                            isAiRaging: _isAiRaging,
                            pkStatus: _pkStatus,
                            myScore: _myPKScore,
                            opponentScore: _opponentPKScore
                        ),
                      ),
                      if (_pkStatus == PKStatus.playing || _pkStatus == PKStatus.punishment)
                        Positioned(top: 0, left: 0, right: 0, child: PKScoreBar(myScore: _myPKScore, opponentScore: _opponentPKScore, status: _pkStatus, secondsLeft: _pkTimeLeft)),
                      Positioned(
                        top: (_pkStatus == PKStatus.playing || _pkStatus == PKStatus.punishment) ? 18 : 0,
                        left: 0,
                        right: 0,
                        child: Center(child: PKTimer(secondsLeft: _pkTimeLeft, status: _pkStatus, myScore: _myPKScore, opponentScore: _opponentPKScore)),
                      ),
                      Positioned(right: 10, bottom: 10, child: Column(children: [_buildCircleBtn(onTap: _showMusicPanel, icon: const Icon(Icons.music_note, color: Colors.white, size: 20), borderColor: Colors.purpleAccent, label: "点歌"), const SizedBox(height: 10), _buildCircleBtn(onTap: _toggleBackgroundMode, icon: Icon(_isVideoBackground ? Icons.videocam : Icons.image, color: Colors.white, size: 20), borderColor: Colors.cyanAccent, label: "背景")])),
                    ],
                  ),
                ),
              ],
            ),

            // 2. 统一悬浮 UI 层
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomInset > 0 ? bottomInset : padding.bottom,
              height: _pkStatus == PKStatus.idle ? 300 : (size.height - pkVideoBottomY),
              child: Container(
                color: bottomInset > 0 ? Colors.black87 : Colors.transparent,
                child: Column(
                  children: [
                    Expanded(child: BuildChatList(bottomInset: 0, messages: _messages)),
                    BuildInputBar(
                      textController: _textController,
                      onTapGift: _showGiftPanel,
                      onSend: (text) {
                        setState(() => _messages.insert(0, ChatMessage(name: "我", content: text, level: 99, levelColor: Colors.amber,isGift: false,)));
                        if (_pkStatus == PKStatus.playing) { Future.delayed(const Duration(milliseconds: 1500), () { _triggerAIResponse(context: "chat", customPrompt: text); }); }
                      },
                    ),
                  ],
                ),
              ),
            ),

            // 3. 独立图层：发起 PK 按钮
            if (_pkStatus == PKStatus.idle)
              Positioned(
                bottom: (bottomInset > 0 ? bottomInset : padding.bottom) + 150,
                right: 20,
                child: GestureDetector(
                  onTap: _startAIBattle,
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
                        Text("发起PK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),

            // 4. 🟢 PK开场动画层 (放在顶层，遮盖一切)
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
                              // 左侧 P
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
                                    boxShadow: [
                                      BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 15, spreadRadius: 2),
                                    ],
                                  ),
                                  child: const Text("P", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 5, color: Colors.red)])),
                                ),
                              ),
                              // 右侧 K
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
                                    boxShadow: [
                                      BoxShadow(color: Colors.blue.withOpacity(0.5), blurRadius: 15, spreadRadius: 2),
                                    ],
                                  ),
                                  child: const Text("K", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 5, color: Colors.blue)])),
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

            // 5. 特效层
            Positioned(left: 0, right: 0, bottom: -2, child: IgnorePointer(child: Opacity(opacity: _isEffectPlaying ? 1.0 : 0.0, child: Align(alignment: Alignment.bottomCenter, child: SizedBox(width: size.width, height: size.width / videoRatio, child: MyAlphaPlayerView(onCreated: _onPlayerCreated)))))),

            // 6. 礼物层
            Positioned(left: 0, width: size.width, top: pkVideoBottomY - 160, height: 160, bottom: null, child: IgnorePointer(child: Align(alignment: Alignment.bottomLeft, child: Padding(padding: const EdgeInsets.only(left: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: _activeGifts.map((giftEvent) => AnimatedGiftItem(key: ValueKey(giftEvent.id), giftEvent: giftEvent, onFinished: () => _onGiftFinished(giftEvent.id))).toList()))))),

            // 7. 连击按钮
            if (_showComboButton && _lastGiftSent != null) Positioned(right: 16, bottom: bottomInset + 80, child: ScaleTransition(scale: CurvedAnimation(parent: _comboScaleController, curve: Curves.elasticOut), child: GestureDetector(onTap: () => _sendGift(_lastGiftSent!), child: AnimatedBuilder(animation: _countdownController, builder: (context, child) { return SizedBox(width: 76, height: 76, child: Stack(alignment: Alignment.center, children: [SizedBox(width: 76, height: 76, child: CircularProgressIndicator(value: 1.0 - _countdownController.value, strokeWidth: 4, backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation(Colors.amber))), Container(width: 64, height: 64, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [Color(0xFFFF0080), Color(0xFFFF8C00)], begin: Alignment.topLeft, end: Alignment.bottomRight), border: Border.all(color: Colors.white, width: 2)), alignment: const Alignment(0, -0.15), child: const Text("连击", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)))])); }))))
          ],
        ),
      ),
    );
  }

  Widget _buildCircleBtn({required VoidCallback onTap, required Widget icon, required Color borderColor, String? label}) {
    return GestureDetector(onTap: onTap, child: Column(children: [Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle, border: Border.all(color: borderColor.withOpacity(0.5), width: 1.5)), alignment: Alignment.center, child: icon), if (label != null) ...[const SizedBox(height: 2), Text(label, style: const TextStyle(color: Colors.white, fontSize: 10))]]));
  }
}