import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:my_alpha_player/my_alpha_player.dart';

// --- 🟢 引入你抽离的组件和模型 ---
import 'models/live_models.dart';
import 'widgets/pk_battle_view.dart';
import 'widgets/single_mode_view.dart';

// --- 引入原有的 Widget (保持不变) ---
import 'package:flutter_live/screens/home/live/widgets/build_chat_list.dart';
import 'package:flutter_live/screens/home/live/widgets/build_input_bar.dart';
import 'package:flutter_live/screens/home/live/widgets/build_top_bar.dart';
import 'package:flutter_live/screens/home/live/widgets/music_panel.dart';
import 'package:flutter_live/screens/home/live/widgets/pk_widgets.dart';
import 'animate_gift_item.dart';
import 'gift_panel.dart';

// --- 静态数据配置 (如果不想放这里，也可以抽离到 data/config.dart) ---
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

  // 背景控制
  late VideoPlayerController _bgController;
  bool _isBgInitialized = false;
  bool _isVideoBackground = false;
  String _currentBgImage = "";
  final List<String> _bgImageUrls = [
    "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/live_bg_1.png",
    "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/live_bg_2.png",
  ];

  // PK & AI 逻辑
  PKStatus _pkStatus = PKStatus.idle;
  int _myPKScore = 0;
  int _opponentPKScore = 0;
  int _pkTimeLeft = 0;
  Timer? _pkTimer;
  bool _isAiRaging = false;
  AIBoss? _currentBoss;
  VideoPlayerController? _aiVideoController;
  String _opponentBgImage = "";

  // 特效播放
  MyAlphaPlayerController? _alphaPlayerController;
  final Queue<String> _effectQueue = Queue();
  bool _isEffectPlaying = false;
  double? _videoAspectRatio;

  // 聊天与礼物
  final TextEditingController _textController = TextEditingController();
  List<ChatMessage> _messages = [];
  static const int _maxActiveGifts = 2;
  final List<GiftEvent> _activeGifts = [];
  final Queue<GiftEvent> _waitingQueue = Queue();

  // 连击逻辑
  bool _showComboButton = false;
  GiftItemData? _lastGiftSent;
  late AnimationController _comboScaleController;
  late AnimationController _countdownController;

  // 模拟数据
  final List<String> _dummyNames = ["Luna", "右岸", "从此安静", "梦醒时分", "快乐小狗", "榜一大哥"];
  final List<String> _dummyContents = ["主播好美！", "这歌好听", "点赞点赞", "666", "关注了"];

  // ==================== 生命周期 ====================

  @override
  void initState() {
    super.initState();
    _initializeBackground();
    _pickRandomImage();
    _generateDummyMessages();

    _comboScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.0,
      upperBound: 1.0,
    );

    _countdownController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

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
  }

  @override
  void dispose() {
    _bgController.dispose();
    _aiVideoController?.dispose();
    _textController.dispose();
    _comboScaleController.dispose();
    _countdownController.dispose();
    super.dispose();
  }

  // ==================== 业务逻辑区域 ====================

  // --- PK 系统 ---
  void _startAIBattle() {
    if (_pkStatus != PKStatus.idle) return;

    final boss = _bosses[Random().nextInt(_bosses.length)];
    _currentBoss = boss;
    _opponentBgImage = _bgImageUrls[Random().nextInt(_bgImageUrls.length)];
    _isAiRaging = false;

    setState(() {
      _pkStatus = PKStatus.playing;
      _myPKScore = 0;
      _opponentPKScore = 0;
      _pkTimeLeft = 90;
    });

    _addFakeMessage(boss.name, "系统连接成功...挑战开始！", Colors.redAccent);

    if (boss.videoUrl.isNotEmpty) {
      _aiVideoController = VideoPlayerController.networkUrl(Uri.parse(boss.videoUrl));
      _aiVideoController!.initialize().then((_) {
        _aiVideoController!.setLooping(true);
        _aiVideoController!.play();
        if (mounted) setState(() {});
      });
    }

    _pkTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) return;
      final random = Random();

      // AI 自动涨分逻辑
      if (random.nextDouble() < 0.6) {
        setState(() {
          int baseGrowth = boss.difficulty * 2;
          if (_opponentPKScore < _myPKScore) baseGrowth = (baseGrowth * 1.5).toInt();
          _opponentPKScore += random.nextInt(10) + baseGrowth;
        });
      }

      // 暴走模式检测
      if (_myPKScore > _opponentPKScore + 500 && !_isAiRaging) {
        _isAiRaging = true;
        _addFakeMessage(boss.name, "😡 警告：Boss进入暴走追分模式！", Colors.redAccent);
      }

      if (_isAiRaging) {
        setState(() {
          int catchUp = (_myPKScore - _opponentPKScore) ~/ 10;
          _opponentPKScore += max(catchUp, boss.difficulty * 5);
        });
      }

      // 暴击大额礼物
      double critChance = 0.02 + (boss.difficulty * 0.005);
      if (_isAiRaging) critChance *= 2.0;

      if (random.nextDouble() < critChance) {
        int bigGiftScore = random.nextBool() ? 520 : 1314;
        String giftName = bigGiftScore == 520 ? "跑车" : "火箭";
        setState(() {
          _opponentPKScore += bigGiftScore;
          if (_opponentPKScore > _myPKScore && (_opponentPKScore - bigGiftScore) < _myPKScore) {
            _addFakeMessage(boss.name, "🚀 感谢大哥送来的$giftName！实现反超！", Colors.orangeAccent);
          }
        });
      }

      // AI 嘲讽
      if (random.nextDouble() < 0.03 && boss.tauntMessages.isNotEmpty && _opponentPKScore > _myPKScore) {
        final msg = boss.tauntMessages[random.nextInt(boss.tauntMessages.length)];
        _addFakeMessage(boss.name, msg, Colors.cyanAccent);
      }

      // 倒计时
      if (timer.tick % 2 == 0) {
        setState(() => _pkTimeLeft--);
        if (_pkTimeLeft <= 0) {
          _pkTimer?.cancel();
          _enterPunishmentPhase();
        }
      }
    });
  }

  void _enterPunishmentPhase() {
    setState(() {
      _pkStatus = PKStatus.punishment;
      _pkTimeLeft = 10;
    });

    _pkTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _pkTimeLeft--);
      if (_pkTimeLeft <= 0) _stopPK();
    });
  }

  void _stopPK() {
    _pkTimer?.cancel();
    setState(() => _pkStatus = PKStatus.coHost);
    _addFakeMessage("系统", "PK结束，进入连麦模式", Colors.greenAccent);
  }

  void _disconnectCoHost() {
    _aiVideoController?.dispose();
    _aiVideoController = null;
    setState(() => _pkStatus = PKStatus.idle);
    _addFakeMessage("系统", "连麦已断开", Colors.grey);
  }

  // --- 礼物与连击逻辑 ---
  void _triggerComboMode() {
    if (!_showComboButton) {
      setState(() => _showComboButton = true);
      _comboScaleController.forward();
    }
    _countdownController.reset();
    _countdownController.forward();
  }

  void _sendGift(GiftItemData giftData) {
    const senderName = "我";
    final comboKey = "${senderName}_${giftData.name}";
    _lastGiftSent = giftData;

    setState(() {
      final existingIndex = _activeGifts.indexWhere((g) => g.comboKey == comboKey);
      if (existingIndex != -1) {
        final oldGift = _activeGifts[existingIndex];
        _activeGifts[existingIndex] = oldGift.copyWith(count: oldGift.count + 1);
      } else {
        final newGift = GiftEvent(
          senderName: senderName,
          giftName: giftData.name,
          giftIconUrl: giftData.iconUrl,
        );
        _processNewGift(newGift);
      }

      if (_pkStatus == PKStatus.playing || _pkStatus == PKStatus.punishment) {
        _myPKScore += giftData.price;
      }
    });

    _addEffectToQueue(giftData.effectAsset);
    _triggerComboMode();
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
      if (_waitingQueue.isNotEmpty) {
        _activeGifts.add(_waitingQueue.removeFirst());
      }
    });
  }

  // --- 特效播放逻辑 ---
  void _onPlayerCreated(MyAlphaPlayerController controller) {
    _alphaPlayerController = controller;
    _alphaPlayerController?.onFinish = _onEffectComplete;
    _alphaPlayerController?.onVideoSize = (width, height) {
      if (width > 0 && height > 0 && mounted) {
        final newRatio = width / height;
        if (_videoAspectRatio == null || (_videoAspectRatio! - newRatio).abs() > 0.01) {
          setState(() => _videoAspectRatio = newRatio);
        }
      }
    };
  }

  void _addEffectToQueue(String url) {
    _effectQueue.add(url);
    if (!_isEffectPlaying) _playNextEffect();
  }

  Future<void> _playNextEffect() async {
    if (_effectQueue.isEmpty || _alphaPlayerController == null) return;
    final url = _effectQueue.removeFirst();
    setState(() => _isEffectPlaying = true);
    try {
      String? localPath = await _downloadGiftFile(url);
      if (localPath != null && mounted) {
        await _alphaPlayerController!.play(localPath);
      } else {
        _onEffectComplete();
      }
    } catch (e) {
      _onEffectComplete();
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

  void _onEffectComplete() {
    if (!mounted) return;
    _alphaPlayerController?.stop();
    setState(() => _isEffectPlaying = false);
    Future.delayed(const Duration(milliseconds: 50), _playNextEffect);
  }

  // --- 辅助功能 ---
  void _initializeBackground() async {
    const String aliyunBgUrl = 'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/bg.mp4';
    _bgController = VideoPlayerController.networkUrl(
      Uri.parse(aliyunBgUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await _bgController.initialize();
      _bgController.setLooping(true);
      _bgController.setVolume(0.0);
      if (_isVideoBackground) _bgController.play();
      setState(() => _isBgInitialized = true);
    } catch (e) {
      print("背景加载失败: $e");
    }
  }

  void _toggleBackgroundMode() {
    setState(() {
      _isVideoBackground = !_isVideoBackground;
      if (_isVideoBackground) {
        if (_isBgInitialized) _bgController.play();
      } else {
        if (_isBgInitialized) _bgController.pause();
        _pickRandomImage();
      }
    });
  }

  void _pickRandomImage() {
    setState(() => _currentBgImage = _bgImageUrls[Random().nextInt(_bgImageUrls.length)]);
  }

  void _addFakeMessage(String name, String content, Color color) {
    setState(() {
      _messages.insert(0, ChatMessage(name: name, content: content, level: 99, levelColor: color));
    });
  }

  void _generateDummyMessages() {
    final random = Random();
    List<ChatMessage> temp = [];
    for (int i = 0; i < 20; i++) {
      temp.add(ChatMessage(
        name: _dummyNames[random.nextInt(_dummyNames.length)],
        content: _dummyContents[random.nextInt(_dummyContents.length)],
        level: random.nextInt(50) + 1,
        levelColor: Colors.primaries[random.nextInt(Colors.primaries.length)],
      ));
    }
    setState(() => _messages = temp.reversed.toList());
  }

  // --- 弹窗面板 ---
  void _showGiftPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => GiftPanel(onSend: (gift) {
        _sendGift(gift);
        Navigator.pop(context);
      }),
    );
  }

  void _showMusicPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const MusicPanel(),
    );
  }

  // ==================== UI 构建区域 ====================

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    const double topBarHeight = 50.0;
    const double pkBarHeight = 80.0;
    const double gap1 = 10.0;
    const double gap2 = 5.0;

    final double pkVideoHeight = size.width * 0.85;
    final double pkVideoBottomY = padding.top + topBarHeight + gap1 + pkBarHeight + gap2 + pkVideoHeight;
    final double videoRatio = _videoAspectRatio ?? (9 / 16);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ==============================
          // 层级 1: 页面主体逻辑 (根据状态切换视图)
          // ==============================
          _pkStatus == PKStatus.idle
          // 🟢 场景 1: 单人直播模式 (代码已抽离)
              ? SingleModeView(
            isVideoBackground: _isVideoBackground,
            isBgInitialized: _isBgInitialized,
            bgController: _bgController,
            currentBgImage: _currentBgImage,
            messages: _messages,
            textController: _textController,
            onTapGift: _showGiftPanel,
            onStartPK: _startAIBattle,
            onSendMessage: (text) => setState(() => _messages.insert(0, ChatMessage(name: "我", content: text, level: 99, levelColor: Colors.amber))),
          )
          // 🟢 场景 2: PK / 连麦模式
              : Column(
            children: [
              Container(
                width: double.infinity,
                color: Colors.black,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: EdgeInsets.only(top: padding.top),
                      height: topBarHeight,
                      child: const BuildTopBar(title: "直播间"),
                    ),
                    SizedBox(height: gap1),

                    // PK血条 or 连麦提示
                    if (_pkStatus == PKStatus.playing || _pkStatus == PKStatus.punishment)
                      SizedBox(
                        height: pkBarHeight,
                        child: PKScoreBar(
                          myScore: _myPKScore,
                          opponentScore: _opponentPKScore,
                          secondsLeft: _pkTimeLeft,
                          status: _pkStatus,
                        ),
                      )
                    else
                      Container(
                        height: pkBarHeight,
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [Icon(Icons.mic, color: Colors.greenAccent, size: 14), SizedBox(width: 4), Text("连麦中", style: TextStyle(color: Colors.white, fontSize: 12))],
                          ),
                        ),
                      ),

                    SizedBox(height: gap2),

                    // PK 视频区域 (左右分屏)
                    SizedBox(
                      height: pkVideoHeight,
                      width: size.width,
                      child: Stack(
                        children: [
                          // 🟢 核心分屏组件 (代码已抽离)
                          PKBattleView(
                            leftVideoController: (_isVideoBackground && _isBgInitialized) ? _bgController : null,
                            leftBgImage: _isVideoBackground ? null : _currentBgImage,
                            rightBgImage: _opponentBgImage,
                            rightVideoController: _aiVideoController,
                            currentBoss: _currentBoss,
                            isAiRaging: _isAiRaging,
                          ),

                          // 挂断按钮
                          if (_pkStatus == PKStatus.coHost)
                            Positioned(
                              top: 10, right: 10,
                              child: GestureDetector(
                                onTap: _disconnectCoHost,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                                  child: const Icon(Icons.call_end, color: Colors.white, size: 20),
                                ),
                              ),
                            ),

                          // 右下角控制按钮
                          Positioned(
                            right: 10, bottom: 10,
                            child: Column(
                              children: [
                                _buildCircleBtn(onTap: _showMusicPanel, icon: const Icon(Icons.music_note, color: Colors.white, size: 20), borderColor: Colors.purpleAccent, label: "点歌"),
                                const SizedBox(height: 10),
                                _buildCircleBtn(onTap: _toggleBackgroundMode, icon: Icon(_isVideoBackground ? Icons.videocam : Icons.image, color: Colors.white, size: 20), borderColor: Colors.cyanAccent, label: "背景"),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  color: Colors.black,
                  child: Column(
                    children: [
                      Expanded(child: BuildChatList(bottomInset: 0, messages: _messages)),
                      BuildInputBar(
                        textController: _textController,
                        onTapGift: _showGiftPanel,
                        onSend: (text) => setState(() => _messages.insert(0, ChatMessage(name: "我", content: text, level: 99, levelColor: Colors.amber))),
                      ),
                      SizedBox(height: padding.bottom > 0 ? padding.bottom : 10),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ==============================
          // 层级 2: 全屏 Alpha 特效
          // ==============================
          Positioned(
            left: 0, right: 0, bottom: -2,
            child: IgnorePointer(
              ignoring: true,
              child: Opacity(
                opacity: _isEffectPlaying ? 1.0 : 0.0,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: size.width,
                    height: size.width / videoRatio,
                    child: MyAlphaPlayerView(onCreated: _onPlayerCreated),
                  ),
                ),
              ),
            ),
          ),

          // ==============================
          // 层级 3: 礼物横幅
          // ==============================
          Positioned(
            left: 0, width: size.width,
            top: _pkStatus == PKStatus.idle ? null : pkVideoBottomY - 160,
            height: 160,
            bottom: _pkStatus == PKStatus.idle ? (220.0 + (bottomInset > 0 ? 0 : 0)) : null,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: _activeGifts.map((giftEvent) => AnimatedGiftItem(
                    key: ValueKey(giftEvent.id),
                    giftEvent: giftEvent,
                    onFinished: () => _onGiftFinished(giftEvent.id),
                  )).toList(),
                ),
              ),
            ),
          ),

          // ==============================
          // 层级 4: 连击按钮
          // ==============================
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
                        width: 76, height: 76,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(width: 76, height: 76, child: CircularProgressIndicator(value: 1.0 - _countdownController.value, strokeWidth: 4, backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation(Colors.amber))),
                            Container(
                              width: 64, height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(colors: [Color(0xFFFF0080), Color(0xFFFF8C00)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                boxShadow: [BoxShadow(color: const Color(0xFFFF0080).withOpacity(0.6), blurRadius: 15, offset: const Offset(0, 4))],
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              alignment: const Alignment(0, -0.15),
                              child: const Text("连击", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, shadows: [Shadow(color: Colors.black26, offset: Offset(1, 1), blurRadius: 2)])),
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
    );
  }

  // 小组件保留在这里比较方便
  Widget _buildCircleBtn({required VoidCallback onTap, required Widget icon, required Color borderColor, String? label}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle, border: Border.all(color: borderColor.withOpacity(0.5), width: 1.5)),
            alignment: Alignment.center,
            child: icon,
          ),
          if (label != null) ...[const SizedBox(height: 2), Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, shadows: [Shadow(blurRadius: 2, color: Colors.black)]))]
        ],
      ),
    );
  }
}