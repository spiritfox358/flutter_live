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
  final int difficulty;
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
    // 🟢 确保这里的视频地址是可用的
    videoUrl: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/ai_avatar_1.mp4",
    difficulty: 3,
    tauntMessages: ["人类的手速太慢了", "就这点分数吗？", "哔...系统检测到你弱爆了"],
  ),
  const AIBoss(
    name: "赛博魔王",
    avatarUrl: "https://cdn-icons-png.flaticon.com/512/6195/6195678.png",
    videoUrl: "",
    difficulty: 8,
    tauntMessages: ["颤抖吧凡人！", "大火箭也不过如此", "毁灭倒计时开始"],
  ),
];

// --- 主页面 ---
class LiveStreamingPage extends StatefulWidget {
  const LiveStreamingPage({super.key});

  @override
  State<LiveStreamingPage> createState() => _LiveStreamingPageState();
}

class _LiveStreamingPageState extends State<LiveStreamingPage>
    with TickerProviderStateMixin {
  late VideoPlayerController _bgController;
  bool _isBgInitialized = false;
  bool _isVideoBackground = false;
  String _currentBgImage = "";

  PKStatus _pkStatus = PKStatus.idle;
  int _myPKScore = 0;
  int _opponentPKScore = 0;
  int _pkTimeLeft = 0;
  Timer? _pkTimer;

  AIBoss? _currentBoss;
  VideoPlayerController? _aiVideoController; // AI 视频控制器

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
  }

  // 🟢 启动 AI 对战，并播放视频
  // 🟢 修复后的 AI 启动逻辑
  void _startAIBattle() {
    if (_pkStatus != PKStatus.idle) return;

    final boss = _bosses[Random().nextInt(_bosses.length)];
    _currentBoss = boss;

    // 1. 先立即更新状态，让界面切到 PK 布局 (不要 await 视频，防止卡顿)
    setState(() {
      _pkStatus = PKStatus.playing;
      _myPKScore = 0;
      _opponentPKScore = 0;
      _pkTimeLeft = 45;
    });

    _addFakeMessage(boss.name, "系统连接成功...挑战开始！", Colors.redAccent);

    // 2. 异步初始化视频，加载好后刷新界面
    if (boss.videoUrl.isNotEmpty) {
      _aiVideoController = VideoPlayerController.networkUrl(Uri.parse(boss.videoUrl));
      _aiVideoController!.initialize().then((_) {
        // 视频准备好了，开始播放并刷新 UI
        _aiVideoController!.setLooping(true);
        _aiVideoController!.play();
        if (mounted) setState(() {});
      }).catchError((e) {
        print("AI视频加载失败: $e");
      });
    }

    // 3. 启动计时器和 AI 逻辑
    _pkTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) return;

      final random = Random();
      // AI 涨分逻辑
      if (random.nextInt(100) < (boss.difficulty * 5)) {
        setState(() {
          int baseScore = 1 + random.nextInt(10);
          _opponentPKScore += baseScore * boss.difficulty;
        });
      }
      // AI 暴击
      if (random.nextDouble() < 0.02) {
        final bonus = 50 * boss.difficulty;
        setState(() => _opponentPKScore += bonus);
        _addFakeMessage(boss.name, "⚡ 能量过载！战力飙升 +$bonus", Colors.orange);
      }
      // AI 嘲讽
      if (random.nextDouble() < 0.05 && boss.tauntMessages.isNotEmpty) {
        final msg = boss.tauntMessages[random.nextInt(boss.tauntMessages.length)];
        _addFakeMessage(boss.name, msg, Colors.redAccent);
      }

      // 倒计时
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
    // 🟢 停止并销毁 AI 视频
    _aiVideoController?.dispose();
    _aiVideoController = null;

    setState(() {
      _pkStatus = PKStatus.idle;
    });
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
    setState(
          () => _currentBgImage = _bgImageUrls[random.nextInt(_bgImageUrls.length)],
    );
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
      print("背景视频加载失败: $e");
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
        if (_videoAspectRatio == null ||
            (_videoAspectRatio! - newRatio).abs() > 0.01) {
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

  Widget _buildPKHalfView({required Widget content, String? bgImageUrl}) {
    return Expanded(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(0),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bgImageUrl != null)
              Image.network(
                bgImageUrl,
                fit: BoxFit.cover,
                color: Colors.black.withOpacity(0.7),
                colorBlendMode: BlendMode.darken,
              ),
            Center(
              child: content,
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
      final existingIndex = _activeGifts.indexWhere(
            (g) => g.comboKey == comboKey,
      );
      if (existingIndex != -1) {
        final oldGift = _activeGifts[existingIndex];
        _activeGifts[existingIndex] = oldGift.copyWith(
          count: oldGift.count + 1,
        );
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final giftAreaTop = MediaQuery.of(context).size.height * 0.55;
    final screenRatio = MediaQuery.of(context).size.aspectRatio;
    final targetAspectRatio = _videoAspectRatio ?? screenRatio;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. 背景与 PK 区域
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _pkStatus == PKStatus.idle
                  ? Container(
                key: const ValueKey("Single"),
                child: _isVideoBackground
                    ? (_isBgInitialized
                    ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _bgController.value.size.width,
                    height: _bgController.value.size.height,
                    child: VideoPlayer(_bgController),
                  ),
                )
                    : Container(color: Colors.black))
                    : Image.network(_currentBgImage, fit: BoxFit.cover),
              )
                  : Row(
                key: const ValueKey("PK"),
                children: [
                  // 左边：我方
                  _buildPKHalfView(
                    content: _isVideoBackground
                        ? (_isBgInitialized
                        ? VideoPlayer(_bgController)
                        : Container(color: Colors.black))
                        : Image.network(_currentBgImage, fit: BoxFit.cover),
                    bgImageUrl: _isVideoBackground ? null : _currentBgImage,
                  ),
                  Container(width: 1, color: Colors.white24),

                  // 🟢 右边：AI Boss (支持视频播放)
                  _buildPKHalfView(
                    bgImageUrl: _currentBoss?.avatarUrl,
                    content: Stack(
                      fit: StackFit.expand,
                      children: [
                        // 优先显示视频，否则显示图片
                        _aiVideoController != null && _aiVideoController!.value.isInitialized
                            ? VideoPlayer(_aiVideoController!)
                            : (_currentBoss != null
                            ? Image.network(
                          _currentBoss!.avatarUrl,
                          fit: BoxFit.cover,
                          color: Colors.red.withOpacity(0.1),
                          colorBlendMode: BlendMode.darken,
                        )
                            : Container(color: Colors.grey[900])),

                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.6),
                              ],
                            ),
                          ),
                        ),

                        Positioned(
                          top: 10,
                          right: 10,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "BOSS LV.${_currentBoss?.difficulty ?? 1}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _currentBoss?.name ?? "未知生物",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. UI 层
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: bottomInset,
            child: SafeArea(
              child: Column(
                children: [
                  BuildTopBar(title: "直播间"),
                  if (_pkStatus != PKStatus.idle)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      // 🟢 确保宽度撑满，防止 hasSize 错误
                      child: SizedBox(
                        width: double.infinity,
                        child: PKScoreBar(
                          myScore: _myPKScore,
                          opponentScore: _opponentPKScore,
                          secondsLeft: _pkTimeLeft,
                          status: _pkStatus,
                        ),
                      ),
                    ),

                  if (_pkStatus == PKStatus.idle)
                    GestureDetector(
                      onTap: _startAIBattle,
                      child: Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Colors.purple, Colors.deepPurple]),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: const Text("⚔️ 发起PK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  const Spacer(),
                  BuildChatList(bottomInset: bottomInset, messages: _messages),
                  BuildInputBar(
                    textController: _textController,
                    onTapGift: _showGiftPanel,
                    onSend: (text) {
                      setState(() {
                        _messages.insert(
                          0,
                          ChatMessage(name: "我", content: text, level: 99, levelColor: Colors.amber),
                        );
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          // 3. 特效层
          Positioned(
            left: 0,
            right: 0,
            bottom: -1,
            child: IgnorePointer(
              child: Visibility(
                visible: _isEffectPlaying,
                maintainState: true,
                maintainAnimation: true,
                maintainSize: true,
                child: AspectRatio(
                  aspectRatio: targetAspectRatio,
                  child: Transform.scale(
                    scale: 1.02,
                    alignment: Alignment.bottomCenter,
                    child: MyAlphaPlayerView(onCreated: _onPlayerCreated),
                  ),
                ),
              ),
            ),
          ),

          // 4. 礼物动画
          Positioned(
            top: giftAreaTop,
            left: 0,
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

          // 5. 连击按钮
          if (_showComboButton && _lastGiftSent != null)
            Positioned(
              right: 16,
              bottom: bottomInset + 160,
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
                            SizedBox(
                              width: 76, height: 76,
                              child: CircularProgressIndicator(
                                value: 1.0 - _countdownController.value,
                                strokeWidth: 4,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation(Colors.amber),
                              ),
                            ),
                            Container(
                              width: 64, height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF0080), Color(0xFFFF8C00)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [BoxShadow(color: const Color(0xFFFF0080).withOpacity(0.6), blurRadius: 15, offset: const Offset(0, 4))],
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              alignment: const Alignment(0, -0.15),
                              child: const Text(
                                "连击",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                  shadows: [Shadow(color: Colors.black26, offset: Offset(1, 1), blurRadius: 2)],
                                ),
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

          // 其他按钮...
          Positioned(
            right: 10, top: 300,
            child: GestureDetector(
              onTap: _showMusicPanel,
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.purpleAccent, width: 1),
                ),
                alignment: Alignment.center,
                child: const Text("点歌", style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
          ),
          Positioned(
            right: 10, top: 250,
            child: GestureDetector(
              onTap: _toggleBackgroundMode,
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.cyanAccent, width: 1),
                ),
                alignment: Alignment.center,
                child: Icon(_isVideoBackground ? Icons.videocam : Icons.image, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}