import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_live/screens/home/live/widgets/build_chat_list.dart';
import 'package:flutter_live/screens/home/live/widgets/build_input_bar.dart';
import 'package:flutter_live/screens/home/live/widgets/build_top_bar.dart';
import 'package:flutter_live/screens/home/live/widgets/music_panel.dart';
import 'package:flutter_live/screens/home/live/widgets/pk_widgets.dart';
import 'package:video_player/video_player.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'package:my_alpha_player/my_alpha_player.dart';
import 'animate_gift_item.dart';
import 'gift_panel.dart';

// --- 数据模型 ---
class ChatMessage {
  final String name;
  final String content;
  final int level;
  final Color levelColor;

  ChatMessage({
    required this.name,
    required this.content,
    this.level = 0,
    this.levelColor = Colors.blue,
  });
}

class GiftEvent {
  final String id;
  final String senderName;
  final String giftName;
  final String giftIconUrl;
  final String comboKey;
  int count;

  GiftEvent({
    required this.senderName,
    required this.giftName,
    required this.giftIconUrl,
    this.count = 1,
    String? id,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        comboKey = "${senderName}_${giftName}";

  GiftEvent copyWith({int? count}) {
    return GiftEvent(
      id: id,
      senderName: senderName,
      giftName: giftName,
      giftIconUrl: giftIconUrl,
      count: count ?? this.count,
    );
  }
}

class GiftItemData {
  final String name;
  final int price;
  final String iconUrl;
  final String effectAsset;
  final String? tag;
  final String? expireTime;

  const GiftItemData({
    required this.name,
    required this.price,
    required this.iconUrl,
    required this.effectAsset,
    this.tag,
    this.expireTime,
  });
}

// --- AI 机器人配置 ---
class AIBoss {
  final String name;
  final String avatarUrl;
  final String videoUrl;
  final int difficulty; // 难度系数 1-10
  final List<String> tauntMessages;

  const AIBoss({
    required this.name,
    required this.avatarUrl,
    required this.videoUrl,
    this.difficulty = 1,
    this.tauntMessages = const [],
  });
}

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

// --- 主页面 ---
class LiveStreamingPage extends StatefulWidget {
  const LiveStreamingPage({super.key});

  @override
  State<LiveStreamingPage> createState() => _LiveStreamingPageState();
}

class _LiveStreamingPageState extends State<LiveStreamingPage> with TickerProviderStateMixin {
  late VideoPlayerController _bgController;
  bool _isBgInitialized = false;
  bool _isVideoBackground = false;
  String _currentBgImage = "";
  String _opponentBgImage = "";

  PKStatus _pkStatus = PKStatus.idle;
  int _myPKScore = 0;
  int _opponentPKScore = 0;
  int _pkTimeLeft = 0;
  Timer? _pkTimer;

  bool _isAiRaging = false;

  AIBoss? _currentBoss;
  VideoPlayerController? _aiVideoController;

  final List<String> _bgImageUrls = [
    "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/live_bg_1.png",
    "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/live_bg_2.png",
  ];

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

  // 🟢 移除了震动控制器定义

  final List<String> _dummyNames = ["Luna", "右岸", "从此安静", "梦醒时分", "快乐小狗", "榜一大哥"];
  final List<String> _dummyContents = ["主播好美！", "这歌好听", "点赞点赞", "666", "关注了"];

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
      if (status == AnimationStatus.completed) {
        if (mounted) {
          _comboScaleController.reverse().then((_) {
            setState(() {
              _showComboButton = false;
              _lastGiftSent = null;
            });
          });
        }
      }
    });

    // 🟢 移除了震动控制器初始化
  }

  // 🟢 移除了 _triggerShake() 方法

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

      if (random.nextDouble() < 0.6) {
        setState(() {
          int baseGrowth = boss.difficulty * 2;
          if (_opponentPKScore < _myPKScore) {
            baseGrowth = (baseGrowth * 1.5).toInt();
          }
          _opponentPKScore += random.nextInt(10) + baseGrowth;
        });
      }

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

      double critChance = 0.02 + (boss.difficulty * 0.005);
      if (_isAiRaging) critChance *= 2.0;

      if (random.nextDouble() < critChance) {
        int bigGiftScore = 0;
        String giftName = "";

        if (random.nextBool()) {
          bigGiftScore = 520;
          giftName = "跑车";
        } else {
          bigGiftScore = 1314;
          giftName = "火箭";
        }

        setState(() {
          _opponentPKScore += bigGiftScore;
          if (_opponentPKScore > _myPKScore && (_opponentPKScore - bigGiftScore) < _myPKScore) {
            // 🟢 移除了震动调用
            _addFakeMessage(boss.name, "🚀 感谢大哥送来的$giftName！实现反超！", Colors.orangeAccent);
          }
        });
      }

      if (random.nextDouble() < 0.03 && boss.tauntMessages.isNotEmpty) {
        final msg = boss.tauntMessages[random.nextInt(boss.tauntMessages.length)];
        if (_opponentPKScore > _myPKScore) {
          _addFakeMessage(boss.name, msg, Colors.cyanAccent);
        }
      }

      if (timer.tick % 2 == 0) {
        setState(() {
          _pkTimeLeft--;
        });
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
      setState(() {
        _pkTimeLeft--;
      });
      if (_pkTimeLeft <= 0) {
        _stopPK();
      }
    });
  }

  void _stopPK() {
    _pkTimer?.cancel();

    setState(() {
      _pkStatus = PKStatus.coHost; // 进入连麦模式
    });

    _addFakeMessage("系统", "PK结束，进入连麦模式", Colors.greenAccent);
  }

  void _disconnectCoHost() {
    _aiVideoController?.dispose();
    _aiVideoController = null;

    setState(() {
      _pkStatus = PKStatus.idle;
    });
    _addFakeMessage("系统", "连麦已断开", Colors.grey);
  }

  void _addFakeMessage(String name, String content, Color color) {
    setState(() {
      _messages.insert(
        0,
        ChatMessage(name: name, content: content, level: 99, levelColor: color),
      );
    });
  }

  void _pickRandomImage() {
    final random = Random();
    setState(() => _currentBgImage = _bgImageUrls[random.nextInt(_bgImageUrls.length)]);
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

  Future<void> _initializeBackground() async {
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

  void _onPlayerCreated(MyAlphaPlayerController controller) {
    _alphaPlayerController = controller;
    _alphaPlayerController?.onFinish = () {
      _onEffectComplete();
    };
    _alphaPlayerController?.onVideoSize = (width, height) {
      if (width > 0 && height > 0 && mounted) {
        final newRatio = width / height;
        if (_videoAspectRatio == null || (_videoAspectRatio! - newRatio).abs() > 0.01) {
          setState(() {
            _videoAspectRatio = newRatio;
          });
        }
      }
    };
  }

  void _addEffectToQueue(String url) {
    _effectQueue.add(url);
    if (!_isEffectPlaying) {
      _playNextEffect();
    }
  }

  Future<void> _playNextEffect() async {
    if (_effectQueue.isEmpty) return;
    if (_alphaPlayerController == null) return;
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
    Future.delayed(const Duration(milliseconds: 50), () {
      _playNextEffect();
    });
  }

  Widget _buildPKHalfView({
    Widget? content,
    String? bgImageUrl,
    VideoPlayerController? videoController,
    AIBoss? bossInfo,
  }) {
    return Expanded(
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(color: Colors.black),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (videoController != null && videoController.value.isInitialized)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: videoController.value.size.width,
                    height: videoController.value.size.height,
                    child: VideoPlayer(videoController),
                  ),
                ),
              )
            else if (bgImageUrl != null)
              Image.network(
                bgImageUrl,
                fit: BoxFit.cover,
                color: Colors.black.withOpacity(0.3),
                colorBlendMode: BlendMode.darken,
              )
            else
              Container(color: Colors.grey[900]),

            if (content != null && videoController == null)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(width: 1, height: 16/9, child: content),
                ),
              ),

            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                    Colors.black.withOpacity(0.4),
                  ],
                  stops: const [0.0, 0.2, 1.0],
                ),
              ),
            ),

            if (bossInfo != null)
              Positioned(
                bottom: 10, left: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "LV.${bossInfo.difficulty}",
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bossInfo.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          shadows: [Shadow(color: Colors.black, blurRadius: 4)]
                      ),
                    ),
                  ],
                ),
              ),

            if (bossInfo != null && _isAiRaging)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red.withOpacity(0.6), width: 3),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _generateDummyMessages() {
    final random = Random();
    List<ChatMessage> temp = [];
    for (int i = 0; i < 20; i++) {
      temp.add(
        ChatMessage(
          name: _dummyNames[random.nextInt(_dummyNames.length)],
          content: _dummyContents[random.nextInt(_dummyContents.length)],
          level: random.nextInt(50) + 1,
          levelColor: Colors.primaries[random.nextInt(Colors.primaries.length)],
        ),
      );
    }
    setState(() => _messages = temp.reversed.toList());
  }

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
        // 🟢 移除了震动调用
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
        final nextGift = _waitingQueue.removeFirst();
        _activeGifts.add(nextGift);
      }
    });
  }

  void _showGiftPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return GiftPanel(
          onSend: (GiftItemData selectedGift) {
            _sendGift(selectedGift);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _showMusicPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const MusicPanel(),
    );
  }

  @override
  void dispose() {
    _bgController.dispose();
    _aiVideoController?.dispose();
    _textController.dispose();
    _comboScaleController.dispose();
    _countdownController.dispose();
    // 🟢 移除了 _shakeController.dispose();
    super.dispose();
  }

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

    // 🟢 移除了 AnimatedBuilder 和 Transform.translate
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ==============================
          // 层级 1: 页面主体
          // ==============================
          _pkStatus == PKStatus.idle
              ? _buildSingleModeLayout(size, bottomInset)
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
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.mic, color: Colors.greenAccent, size: 14),
                              SizedBox(width: 4),
                              Text("连麦中", style: TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),

                    SizedBox(height: gap2),
                    SizedBox(
                      height: pkVideoHeight,
                      width: size.width,
                      child: Stack(
                        children: [
                          Row(
                            children: [
                              _buildPKHalfView(
                                content: _isVideoBackground && _isBgInitialized ? VideoPlayer(_bgController) : null,
                                bgImageUrl: _isVideoBackground ? null : _currentBgImage,
                              ),
                              Container(width: 1.5, color: Colors.black),
                              _buildPKHalfView(
                                bgImageUrl: _opponentBgImage,
                                videoController: _aiVideoController,
                                bossInfo: _currentBoss,
                              ),
                            ],
                          ),

                          // 挂断按钮
                          if (_pkStatus == PKStatus.coHost)
                            Positioned(
                              top: 10, right: 10,
                              child: GestureDetector(
                                onTap: _disconnectCoHost,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.call_end, color: Colors.white, size: 20),
                                ),
                              ),
                            ),

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
            left: 0,
            right: 0,
            bottom: -2,
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
            left: 0,
            width: size.width,
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

  Widget _buildSingleModeLayout(Size size, double bottomInset) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _isVideoBackground
            ? (_isBgInitialized
            ? FittedBox(fit: BoxFit.cover, child: SizedBox(width: _bgController.value.size.width, height: _bgController.value.size.height, child: VideoPlayer(_bgController)))
            : Container(color: Colors.black))
            : Image.network(_currentBgImage, fit: BoxFit.cover),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.6), Colors.transparent], stops: const [0.0, 0.2],
            ),
          ),
        ),
        Positioned(top: 0, left: 0, right: 0, child: SafeArea(child: BuildTopBar(title: "直播间"))),
        Column(
          children: [
            const Spacer(),
            SizedBox(
              height: 300,
              child: BuildChatList(bottomInset: 0, messages: _messages),
            ),
            BuildInputBar(
              textController: _textController,
              onTapGift: _showGiftPanel,
              onSend: (text) => setState(() => _messages.insert(0, ChatMessage(name: "我", content: text, level: 99, levelColor: Colors.amber))),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
        Positioned(
          bottom: 120, right: 20,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              print("点击了发起PK");
              _startAIBattle();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Colors.purple, Colors.deepPurple]),
                borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white30),
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
      ],
    );
  }

  Widget _buildCircleBtn({required VoidCallback onTap, required Widget icon, required Color borderColor, String? label}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
              border: Border.all(color: borderColor.withOpacity(0.5), width: 1.5),
            ),
            alignment: Alignment.center,
            child: icon,
          ),
          if (label != null) ...[
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, shadows: [Shadow(blurRadius: 2, color: Colors.black)]))
          ]
        ],
      ),
    );
  }
}