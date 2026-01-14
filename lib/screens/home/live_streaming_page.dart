import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'dart:collection';
import 'dart:math';

// --- 1. 数据模型 ---

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
  }) :
        id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
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

// --- 2. 主页面 ---
class LiveStreamingPage extends StatefulWidget {
  const LiveStreamingPage({super.key});

  @override
  State<LiveStreamingPage> createState() => _LiveStreamingPageState();
}

class _LiveStreamingPageState extends State<LiveStreamingPage> with TickerProviderStateMixin {
  late VideoPlayerController _bgController;

  // 特效控制器
  VideoPlayerController? _effectController;
  final Queue<String> _effectQueue = Queue();
  bool _isBgInitialized = false;
  bool _isEffectPlaying = false;

  final TextEditingController _textController = TextEditingController();
  List<ChatMessage> _messages = [];

  // 横幅管理
  static const int _maxActiveGifts = 2;
  final List<GiftEvent> _activeGifts = [];
  final Queue<GiftEvent> _waitingQueue = Queue();

  // ✨✨✨ 新增：连击系统状态 ✨✨✨
  bool _showComboButton = false;       // 是否显示连击按钮
  Timer? _comboTimer;                  // 连击倒计时定时器
  GiftItemData? _lastGiftSent;         // 记录最后送的礼物
  late AnimationController _comboAnimController; // 按钮弹出动画

  final List<String> _dummyNames = ["Luna", "右岸", "从此安静", "梦醒时分", "快乐小狗", "榜一大哥"];
  final List<String> _dummyContents = ["主播好美！", "这歌好听", "点赞点赞", "666", "关注了"];

  @override
  void initState() {
    super.initState();
    _initializeBackground();
    _generateDummyMessages();

    // 初始化连击按钮动画 (弹性缩放)
    _comboAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
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
    setState(() { _messages = temp.reversed.toList(); });
  }

  Future<void> _initializeBackground() async {
    const String aliyunBgUrl = 'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/bg.mp4';
    _bgController = VideoPlayerController.networkUrl(
        Uri.parse(aliyunBgUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true)
    );

    try {
      await _bgController.initialize();
      _bgController.setLooping(true);
      _bgController.setVolume(0.0);
      _bgController.play();
      setState(() => _isBgInitialized = true);
    } catch (e) {
      print("背景视频加载失败: $e");
    }
  }

  void _addEffectToQueue(String url) {
    _effectQueue.add(url);
    if (!_isEffectPlaying) {
      _playNextEffect();
    }
  }

  Future<void> _playNextEffect() async {
    if (_effectQueue.isEmpty) return;
    final url = _effectQueue.removeFirst();

    setState(() => _isEffectPlaying = true);

    if (_effectController != null) {
      await _effectController!.dispose();
      _effectController = null;
    }

    final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true)
    );
    _effectController = controller;

    try {
      await controller.initialize();
      controller.setVolume(1.0);
      controller.setLooping(false);
      controller.addListener(() {
        if (controller.value.position >= controller.value.duration) {
          if (_isEffectPlaying && _effectController == controller) {
            _onEffectComplete();
          }
        }
      });
      if (mounted) {
        setState(() {});
        await controller.play();
      }
    } catch (e) {
      print("特效播放失败: $e");
      _onEffectComplete();
    }
  }

  void _onEffectComplete() {
    if (!mounted) return;
    Future.microtask(() {
      setState(() => _isEffectPlaying = false);
      _playNextEffect();
    });
  }

  // --- ✨✨✨ 核心：启动/重置连击倒计时 ✨✨✨
  void _triggerComboMode() {
    // 1. 如果按钮没显示，先显示出来
    if (!_showComboButton) {
      setState(() => _showComboButton = true);
      _comboAnimController.forward();
    }

    // 2. 重置倒计时 (3秒不点就消失)
    _comboTimer?.cancel();
    _comboTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        // 时间到，收起按钮
        _comboAnimController.reverse().then((_) {
          setState(() {
            _showComboButton = false;
            _lastGiftSent = null; // 清空记录
          });
        });
      }
    });
  }

  // --- 发送礼物逻辑 ---
  void _sendGift(GiftItemData giftData) {
    const senderName = "我";
    final comboKey = "${senderName}_${giftData.name}";

    // 1. 记录最后送的礼物
    _lastGiftSent = giftData;

    // 2. 处理横幅
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
    });

    // 3. 播放特效
    _addEffectToQueue(giftData.effectAsset);

    // 4. ✨ 触发连击倒计时
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

  void _handleSend({String? customContent}) {
    final text = customContent ?? _textController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.insert(0, ChatMessage(name: "我", content: text, level: 99, levelColor: Colors.amber));
    });

    if (customContent == null) {
      _textController.clear();
      FocusScope.of(context).unfocus();
    }
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
            Navigator.pop(context); // ✨ 送礼后，立刻关闭面板
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _bgController.dispose();
    _effectController?.dispose();
    _textController.dispose();
    _comboTimer?.cancel();
    _comboAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final giftAreaTop = MediaQuery.of(context).size.height * 0.55;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. 背景视频
          Positioned.fill(child: _isBgInitialized ? FittedBox(fit: BoxFit.cover, child: SizedBox(width: _bgController.value.size.width, height: _bgController.value.size.height, child: VideoPlayer(_bgController))) : Container(color: Colors.black)),

          // 2. 全屏特效层
          if (_isEffectPlaying && _effectController != null && _effectController!.value.isInitialized)
            Positioned.fill(
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.white,
                      Colors.white.withOpacity(0.2)
                    ],
                    stops: const [0.0, 0.45, 0.6, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: _effectController!.value.size.width,
                    height: _effectController!.value.size.height,
                    child: VideoPlayer(_effectController!),
                  ),
                ),
              ),
            ),

          // 3. UI 层
          Positioned(
            top: 0, left: 0, right: 0, bottom: bottomInset,
            child: SafeArea(
              child: Column(
                children: [
                  _buildTopBar(),
                  const Spacer(),
                  _buildChatList(bottomInset),
                  _buildInputBar(),
                ],
              ),
            ),
          ),

          // 4. 礼物横幅层
          Positioned(
            top: giftAreaTop,
            left: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: _activeGifts.map((giftEvent) {
                return _AnimatedGiftItem(
                  key: ValueKey(giftEvent.id),
                  giftEvent: giftEvent,
                  onFinished: () => _onGiftFinished(giftEvent.id),
                );
              }).toList(),
            ),
          ),

          // ✨✨✨ 5. 连击悬浮按钮 ✨✨✨
          // 只有当 _showComboButton 为 true 时显示
          if (_showComboButton && _lastGiftSent != null)
            Positioned(
              right: 16,
              bottom: bottomInset + 80, // 悬浮在输入框上方
              child: ScaleTransition(
                scale: CurvedAnimation(
                    parent: _comboAnimController,
                    curve: Curves.elasticOut
                ),
                child: GestureDetector(
                  onTap: () {
                    // 点击连击按钮，再次发送上次的礼物
                    _sendGift(_lastGiftSent!);
                  },
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF0080), Color(0xFFFF8C00)], // 炫酷的橙粉渐变
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
                        Text("连击", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 2, color: Colors.black26)])),
                        Text("Combo", style: TextStyle(color: Colors.white, fontSize: 10, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          Positioned(right: 10, top: 300, child: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle, border: Border.all(color: Colors.purpleAccent, width: 1),), alignment: Alignment.center, child: const Text("点歌", style: TextStyle(color: Colors.white, fontSize: 12)),),),
        ],
      ),
    );
  }

  Widget _buildTopBar() { return Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: Row(children: [const _ProfilePill(), const Spacer(), const _ViewerList(), const SizedBox(width: 8), const Icon(Icons.close, color: Colors.white, size: 28)],),); }
  Widget _buildChatList(double bottomInset) { return Container(height: bottomInset > 0 ? 150 : 250, padding: const EdgeInsets.symmetric(horizontal: 10), child: ShaderMask(shaderCallback: (Rect bounds) { return LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.white], stops: const [0.0, 0.2]).createShader(bounds); }, blendMode: BlendMode.dstIn, child: ListView.builder(padding: EdgeInsets.zero, reverse: true, itemCount: _messages.length, itemBuilder: (context, index) { return _buildChatItem(_messages[index]); },),),); }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), color: Colors.transparent,
      child: Row(
        children: [
          Expanded(child: Container(height: 40, decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(20),), child: TextField(controller: _textController, style: const TextStyle(color: Colors.white, fontSize: 14), cursorColor: Colors.pinkAccent, textInputAction: TextInputAction.send, onSubmitted: (_) => _handleSend(), decoration: InputDecoration(hintText: "说点什么...", hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), suffixIcon: IconButton(icon: const Icon(Icons.send, color: Colors.pinkAccent, size: 20), onPressed: () => _handleSend(),),),),),),
          const SizedBox(width: 10), const Icon(Icons.favorite_border, color: Colors.pinkAccent, size: 30), const SizedBox(width: 10),
          GestureDetector(onTap: _showGiftPanel, child: const Icon(Icons.card_giftcard, color: Colors.pinkAccent, size: 30),),
          const SizedBox(width: 10), const Icon(Icons.reply, color: Colors.white, size: 30),
        ],
      ),
    );
  }

  Widget _buildChatItem(ChatMessage msg) { return Padding(padding: const EdgeInsets.symmetric(vertical: 3.0),child: Row(mainAxisSize: MainAxisSize.min,crossAxisAlignment: CrossAxisAlignment.start,children: [Flexible(child: Container(decoration: BoxDecoration(color: Colors.black.withOpacity(0.3),borderRadius: BorderRadius.circular(16),),padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),child: Wrap(crossAxisAlignment: WrapCrossAlignment.center,children: [Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),decoration: BoxDecoration(gradient: LinearGradient(colors: [msg.levelColor.withOpacity(0.8), msg.levelColor],),borderRadius: BorderRadius.circular(10),),child: Row(mainAxisSize: MainAxisSize.min,children: [const Icon(Icons.pentagon, size: 10, color: Colors.white),const SizedBox(width: 2),Text("${msg.level}",style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),),],),),const SizedBox(width: 6),Text("${msg.name}: ",style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w500),),Text(msg.content,style: const TextStyle(color: Colors.white, fontSize: 13),),],),),),],),); }
}

// ==========================================
// ✨ 礼物面板组件
// ==========================================
class GiftPanel extends StatefulWidget {
  final Function(GiftItemData) onSend;

  const GiftPanel({super.key, required this.onSend});

  @override
  State<GiftPanel> createState() => _GiftPanelState();
}

class _GiftPanelState extends State<GiftPanel> {
  int _selectedIndex = -1;
  static const String _aliyunEffectUrl = 'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/qlzy.webm';
  static const String _aliyunEffectUrl2 = 'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/ylyx.webm';

  final List<GiftItemData> _gifts = const [
    GiftItemData(name: "爱心", price: 1, iconUrl: "https://cdn-icons-png.flaticon.com/512/4525/4525672.png", effectAsset: _aliyunEffectUrl),
    GiftItemData(name: "棒棒糖", price: 9, iconUrl: "https://cdn-icons-png.flaticon.com/512/3081/3081887.png", effectAsset: _aliyunEffectUrl2),
    GiftItemData(name: "墨镜", price: 66, iconUrl: "https://cdn-icons-png.flaticon.com/512/4433/4433388.png", effectAsset: _aliyunEffectUrl2),
    GiftItemData(name: "跑车", price: 520, iconUrl: "https://cdn-icons-png.flaticon.com/512/3209/3209921.png", effectAsset: _aliyunEffectUrl2),
    GiftItemData(name: "大火箭", price: 999, iconUrl: "https://cdn-icons-png.flaticon.com/512/8432/8432757.png", effectAsset: _aliyunEffectUrl),
    GiftItemData(name: "游艇", price: 1314, iconUrl: "https://cdn-icons-png.flaticon.com/512/2932/2932356.png", effectAsset: _aliyunEffectUrl),
    GiftItemData(name: "城堡", price: 2888, iconUrl: "https://cdn-icons-png.flaticon.com/512/1018/1018573.png", effectAsset: _aliyunEffectUrl),
    GiftItemData(name: "星球", price: 8888, iconUrl: "https://cdn-icons-png.flaticon.com/512/2530/2530888.png", effectAsset: _aliyunEffectUrl),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 500,
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text("送礼物", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)), Container(margin: const EdgeInsets.only(left: 10), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)), child: Row(children: const [Icon(Icons.monetization_on, color: Colors.amber, size: 12), SizedBox(width: 4), Text("8888", style: TextStyle(color: Colors.amber, fontSize: 10))]),)]),
          ),
          const Divider(color: Colors.white10, height: 1),

          Expanded(
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.white],
                  stops: const [0.0, 0.05],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: GridView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: _gifts.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 0.60,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemBuilder: (context, index) {
                  final gift = _gifts[index];
                  final isSelected = _selectedIndex == index;

                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedIndex = index);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white.withOpacity(0.05) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: isSelected ? Colors.pinkAccent : Colors.transparent,
                            width: 1.5
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 10),
                          Image.network(gift.iconUrl, width: 50, height: 50),
                          const SizedBox(height: 6),
                          Text(gift.name, style: const TextStyle(color: Colors.white, fontSize: 12)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.monetization_on, color: Colors.amber, size: 10),
                              const SizedBox(width: 2),
                              Text("${gift.price}", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10)),
                            ],
                          ),

                          const Spacer(),

                          if (isSelected)
                            GestureDetector(
                              onTap: () => widget.onSend(gift),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Colors.pinkAccent, Colors.orangeAccent]),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Text("发送", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            )
                          else
                            const SizedBox(height: 28),
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
    );
  }
}

// 辅助组件
class _ProfilePill extends StatelessWidget {const _ProfilePill();@override Widget build(BuildContext context) {return Container(padding: const EdgeInsets.all(3),decoration: BoxDecoration(color: Colors.black.withOpacity(0.3),borderRadius: BorderRadius.circular(20),),child: Row(children: [const CircleAvatar(radius: 16,backgroundImage: NetworkImage('https://picsum.photos/seed/555/200'),),const SizedBox(width: 8),Column(crossAxisAlignment: CrossAxisAlignment.start,children: const [Text("糖🍬宝...",style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),),Text("0本场点赞",style: TextStyle(color: Colors.white70, fontSize: 9),),],),const SizedBox(width: 8),Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),decoration: BoxDecoration(color: Colors.amber,borderRadius: BorderRadius.circular(12),),child: const Icon(Icons.add, size: 14, color: Colors.white),),],),);}}
class _ViewerList extends StatelessWidget {const _ViewerList();@override Widget build(BuildContext context) {return Row(children: [SizedBox(height: 32,child: ListView.builder(scrollDirection: Axis.horizontal,shrinkWrap: true,itemCount: 3,itemBuilder: (context, index) {return Padding(padding: const EdgeInsets.only(right: 4),child: CircleAvatar(radius: 14,backgroundImage: NetworkImage('https://picsum.photos/seed/${888 + index}/200'),),);},),),Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),decoration: BoxDecoration(color: Colors.black.withOpacity(0.3),borderRadius: BorderRadius.circular(16),),child: const Text("4",style: TextStyle(color: Colors.white, fontSize: 12),),),],);}}

// ==========================================
// ✨ 优化后的横幅组件 (更短、更小、更精致)
// ==========================================
class _AnimatedGiftItem extends StatefulWidget {
  final GiftEvent giftEvent;
  final VoidCallback onFinished;

  const _AnimatedGiftItem({
    required Key key,
    required this.giftEvent,
    required this.onFinished,
  }) : super(key: key);

  @override
  State<_AnimatedGiftItem> createState() => _AnimatedGiftItemState();
}

class _AnimatedGiftItemState extends State<_AnimatedGiftItem> with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _comboController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _stayTimer;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _slideAnimation = Tween<Offset>(begin: const Offset(-1.2, 0.0), end: Offset.zero).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_entryController);
    _comboController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(CurvedAnimation(parent: _comboController, curve: Curves.easeInOut));
    _comboController.addStatusListener((status) {if (status == AnimationStatus.completed) {_comboController.reverse();}});
    _entryController.forward();
    _startTimer();
  }

  @override
  void didUpdateWidget(_AnimatedGiftItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.giftEvent.count > oldWidget.giftEvent.count) {
      _startTimer();
      _comboController.forward(from: 0.0);
    }
  }

  void _startTimer() {
    _stayTimer?.cancel();
    _stayTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _entryController.reverse().then((_) => widget.onFinished());
      }
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _comboController.dispose();
    _stayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: _buildPremiumGiftBanner(widget.giftEvent),
      ),
    );
  }

  Widget _buildPremiumGiftBanner(GiftEvent gift) {
    return Container(
      margin: const EdgeInsets.only(left: 10, bottom: 10),
      height: 44,
      width: 230,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 180,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Colors.black.withOpacity(0.7), Colors.black.withOpacity(0.1)]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
              ),
              padding: const EdgeInsets.fromLTRB(4, 2, 40, 2),
              child: Row(
                children: [
                  Container(padding: const EdgeInsets.all(1), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const CircleAvatar(radius: 15, backgroundImage: NetworkImage('https://picsum.photos/seed/myAvatar/200'))),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(gift.senderName, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      Text("送出 ${gift.giftName}", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 9)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(right: 40, top: -12, child: Image.network(gift.giftIconUrl, width: 55, height: 55, fit: BoxFit.contain)),
          Positioned(
            right: 0,
            top: 0,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Transform.rotate(
                angle: -0.2,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("x", style: TextStyle(color: Colors.yellowAccent, fontSize: 16, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, shadows: [Shadow(color: Colors.orange.withOpacity(0.8), blurRadius: 8, offset: const Offset(1, 1))])),
                    Text("${gift.count}", style: TextStyle(color: Colors.yellowAccent, fontSize: 24, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 4, offset: const Offset(2, 2))])),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}