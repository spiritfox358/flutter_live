import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_live/screens/home/live/widgets/build_chat_list.dart';
import 'package:flutter_live/screens/home/live/widgets/build_input_bar.dart';
import 'package:flutter_live/screens/home/live/widgets/build_top_bar.dart';
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
  final String iconUrl;
  final int price;
  final String effectAsset;

  const GiftItemData({
    required this.name,
    required this.iconUrl,
    required this.price,
    required this.effectAsset,
  });
}

// --- 主页面 ---
class LiveStreamingPage extends StatefulWidget {
  const LiveStreamingPage({super.key});

  @override
  State<LiveStreamingPage> createState() => _LiveStreamingPageState();
}

class _LiveStreamingPageState extends State<LiveStreamingPage> with TickerProviderStateMixin {
  // 背景控制
  late VideoPlayerController _bgController;
  bool _isBgInitialized = false;
  bool _isVideoBackground = false;
  String _currentBgImage = "";
  final List<String> _bgImageUrls = [
    // "https://images.unsplash.com/photo-1492684223066-81342ee5ff30?q=80&w=2070&auto=format&fit=crop",
    // "https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?q=80&w=2070&auto=format&fit=crop",
    "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/live_bg_1.png",
    "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/live_bg_2.png",
  ];

  // AlphaPlayer 控制
  MyAlphaPlayerController? _alphaPlayerController;
  final Queue<String> _effectQueue = Queue();
  bool _isEffectPlaying = false;

  // 🟢 关键变量：默认比例设为 null，build 时会处理
  double? _videoAspectRatio;

  // 聊天 & 礼物
  final TextEditingController _textController = TextEditingController();
  List<ChatMessage> _messages = [];
  static const int _maxActiveGifts = 2;
  final List<GiftEvent> _activeGifts = [];
  final Queue<GiftEvent> _waitingQueue = Queue();
  bool _showComboButton = false;
  Timer? _comboTimer;
  GiftItemData? _lastGiftSent;
  late AnimationController _comboAnimController;

  final List<String> _dummyNames = [
    "Luna",
    "右岸",
    "从此安静",
    "梦醒时分",
    "快乐小狗",
    "榜一大哥",
  ];
  final List<String> _dummyContents = ["主播好美！", "这歌好听", "点赞点赞", "666", "关注了"];

  @override
  void initState() {
    super.initState();
    _initializeBackground();
    _pickRandomImage();
    _generateDummyMessages();
    _comboAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
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
    const String aliyunBgUrl =
        'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/bg.mp4';
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

  // --- AlphaPlayer 逻辑 ---
  void _onPlayerCreated(MyAlphaPlayerController controller) {
    _alphaPlayerController = controller;

    _alphaPlayerController?.onFinish = () {
      _onEffectComplete();
    };

    _alphaPlayerController?.onVideoSize = (width, height) {
      if (width > 0 && height > 0 && mounted) {
        // 🟢 收到尺寸，更新比例
        // 只有当新比例和旧比例差异较大时才更新，减少刷新
        final newRatio = width / height;
        if (_videoAspectRatio == null ||
            (_videoAspectRatio! - newRatio).abs() > 0.01) {
          setState(() {
            _videoAspectRatio = newRatio;
          });
          print("📏 UI更新比例: $newRatio");
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

    // ⚠️ 注意：这里不要重置 _videoAspectRatio 为 null！
    // 保持上一次的比例或者屏幕比例，防止 Widget 树剧烈变化导致 AndroidView 重建

    try {
      String? localPath = await _downloadGiftFile(url);
      if (localPath != null && mounted) {
        print("🎁 播放: $localPath");
        await _alphaPlayerController!.play(localPath);
      } else {
        _onEffectComplete();
      }
    } catch (e) {
      print("❌ 出错: $e");
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
      print("❌ 下载失败: $e");
      return null;
    }
  }

  void _onEffectComplete() {
    if (!mounted) return;
    print("🎬 结束");

    // 🟢 1. 强制停止播放器，释放资源
    _alphaPlayerController?.stop();

    // 🟢 2. 更新状态，触发 Visibility 隐藏
    setState(() => _isEffectPlaying = false);

    Future.delayed(const Duration(milliseconds: 50), () {
      _playNextEffect();
    });
  }

  // --- 聊天/礼物/UI辅助 ---
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
      _comboAnimController.forward();
    }
    _comboTimer?.cancel();
    _comboTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _comboAnimController.reverse().then((_) {
          setState(() {
            _showComboButton = false;
            _lastGiftSent = null;
          });
        });
      }
    });
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

  @override
  void dispose() {
    _bgController.dispose();
    _textController.dispose();
    _comboTimer?.cancel();
    _comboAnimController.dispose();
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
          // --------------------------
          // 1. 背景层 (最底层)
          // --------------------------
          Positioned.fill(
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
                : Image.network(
              _currentBgImage,
              fit: BoxFit.cover,
              loadingBuilder: (ctx, child, progress) => progress == null
                  ? child
                  : const Center(child: CircularProgressIndicator()),
              errorBuilder: (ctx, err, stack) =>
                  Container(color: Colors.grey[900]),
            ),
          ),

          // --------------------------
          // 2. UI 层 (聊天、顶部栏等)
          // --------------------------
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: bottomInset,
            child: SafeArea(
              child: Column(
                children: [
                  BuildTopBar(title: "直播间"), // 顶部栏
                  const Spacer(),
                  // 聊天列表
                  BuildChatList(bottomInset: bottomInset, messages: _messages),
                  // 底部输入框
                  BuildInputBar(
                    textController: _textController,
                    // 点击礼物图标时，显示礼物面板
                    onTapGift: _showGiftPanel,
                    // 点击发送时，把消息加入列表
                    onSend: (text) {
                      setState(() {
                        _messages.insert(
                          0,
                          ChatMessage(
                            name: "我",
                            content: text,
                            level: 99,
                            levelColor: Colors.amber,
                          ),
                        );
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          // --------------------------
          // 3. AlphaPlayer 特效层
          // --------------------------
          Positioned(
            left: 0,
            right: 0,
            bottom: -1, // 消除缝隙
            child: IgnorePointer(
              // 🟢 核心修复：加一层 Visibility
              // 当 _isEffectPlaying 为 false 时，直接隐藏 View，强制解决画面残留问题
              child: Visibility(
                visible: _isEffectPlaying,
                maintainState: true,      // 🟢 保持状态，避免反复销毁重建导致黑屏/卡顿
                maintainAnimation: true,
                maintainSize: true,
                child: AspectRatio(
                  aspectRatio: targetAspectRatio,
                  child: Transform.scale(
                    scale: 1.02, // ✨ 整体放大 2%，专治各种 1px 缝隙和黑边
                    alignment: Alignment.bottomCenter, // ✨ 锚点定在底部：保持底部不动，向上和向两边延伸
                    child: MyAlphaPlayerView(onCreated: _onPlayerCreated),
                  ),
                ),
              ),
            ),
          ),

          // --------------------------
          // 4. 礼物横幅
          // --------------------------
          Positioned(
            top: giftAreaTop,
            left: 0,
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

          // 5. 连击按钮
          if (_showComboButton && _lastGiftSent != null)
            Positioned(
              right: 16,
              bottom: bottomInset + 80,
              child: ScaleTransition(
                scale: CurvedAnimation(
                  parent: _comboAnimController,
                  curve: Curves.elasticOut,
                ),
                child: GestureDetector(
                  onTap: () => _sendGift(_lastGiftSent!),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF0080), Color(0xFFFF8C00)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF0080).withOpacity(0.6),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          "连击",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "Combo",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 其他按钮...
          Positioned(
            right: 10,
            top: 300,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.purpleAccent, width: 1),
              ),
              alignment: Alignment.center,
              child: const Text(
                "点歌",
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
          Positioned(
            right: 10,
            top: 250,
            child: GestureDetector(
              onTap: _toggleBackgroundMode,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.cyanAccent, width: 1),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _isVideoBackground ? Icons.videocam : Icons.image,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}