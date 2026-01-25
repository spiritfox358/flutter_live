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
        id = id ?? "${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(99999)}",
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
class LiveStreamingPage3 extends StatefulWidget {
  const LiveStreamingPage3({super.key});

  @override
  State<LiveStreamingPage3> createState() => _LiveStreamingPageState();
}

class _LiveStreamingPageState extends State<LiveStreamingPage3> with TickerProviderStateMixin {
  late VideoPlayerController _bgController;

  // --- 新增：背景切换相关变量 ---
  bool _useVideoBg = false; // 默认使用视频背景
  // 使用一张适合直播背景的竖屏图片
  final String _bgImageUrl = 'https://images.unsplash.com/photo-1534351590666-13e3e96b5017?q=80&w=1920&auto=format&fit=crop';
  // --- 结束 ---

  VideoPlayerController? _effectController;
  final Queue<String> _effectQueue = Queue();
  bool _isBgInitialized = false;
  bool _isEffectPlaying = false;

  final TextEditingController _textController = TextEditingController();
  List<ChatMessage> _messages = [];

  static const int _maxActiveGifts = 2;
  final List<GiftEvent> _activeGifts = [];
  final Queue<GiftEvent> _waitingQueue = Queue();

  bool _showComboButton = false;
  GiftItemData? _lastGiftSent;
  late AnimationController _comboAnimController;
  late AnimationController _comboCountdownController;

  final List<String> _dummyNames = ["Luna", "右岸", "从此安静", "梦醒时分", "快乐小狗", "榜一大哥"];
  final List<String> _dummyContents = ["主播好美！", "这歌好听", "点赞点赞", "666", "关注了"];

  @override
  void initState() {
    super.initState();
    _initializeBackground();
    _generateDummyMessages();

    _comboAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.0,
      upperBound: 1.0,
    );

    _comboCountdownController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _comboCountdownController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _showComboButton = false;
          _lastGiftSent = null;
        });
      }
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
    setState(() { _messages = temp.reversed.toList(); });
  }

  Future<void> _initializeBackground() async {
    const String aliyunBgUrl = 'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/bg.MOV';
    _bgController = VideoPlayerController.networkUrl(
        Uri.parse(aliyunBgUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true)
    );

    try {
      await _bgController.initialize();
      _bgController.setLooping(true);
      _bgController.setVolume(0.0);

      // 如果默认是视频模式，则播放
      if (_useVideoBg) {
        _bgController.play();
      }

      setState(() => _isBgInitialized = true);
    } catch (e) {
      print("背景视频加载失败: $e");
    }
  }

  // --- 新增：切换背景模式 ---
  void _toggleBgMode() {
    setState(() {
      _useVideoBg = !_useVideoBg;

      // 优化性能：切到图片时暂停视频，切回视频时恢复播放
      if (_isBgInitialized) {
        if (_useVideoBg) {
          _bgController.play();
        } else {
          _bgController.pause();
        }
      }
    });
  }
  // --- 结束 ---

  void _addEffectToQueue(String url) {
    _effectQueue.add(url);
    if (!_isEffectPlaying) {
      _playNextEffect();
    }
  }

  Future<void> _playNextEffect() async {
    if (_effectQueue.isEmpty) return;
    final url = _effectQueue.removeFirst();

    final oldController = _effectController;
    _effectController = null;

    setState(() => _isEffectPlaying = true);

    if (oldController != null) {
      await oldController.dispose();
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

  void _triggerComboMode() {
    if (!_showComboButton) {
      setState(() => _showComboButton = true);
      _comboAnimController.forward(from: 0.0);
    } else {
      _comboAnimController.forward(from: 0.8);
    }
    _comboCountdownController.reset();
    _comboCountdownController.forward();
  }

  void _sendGift(GiftItemData giftData) {
    const senderName = "中纪委";
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
            Navigator.pop(context);
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
    _comboAnimController.dispose();
    _comboCountdownController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final giftAreaTop = MediaQuery.of(context).size.height * 0.65;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. 背景层 (修改后：支持视频与图片切换)
          Positioned.fill(
            child: _useVideoBg
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
              _bgImageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(color: Colors.black);
              },
              errorBuilder: (context, error, stack) => Container(color: Colors.grey[900]),
            ),
          ),

          // 2. 聊天列表
          Positioned(
            left: 0, right: 0,
            bottom: bottomInset + 55,
            height: 250,
            child: _buildChatList(),
          ),

          // 3. 特效层
          if (_isEffectPlaying && _effectController != null && _effectController!.value.isInitialized)
            Positioned.fill(
              child: IgnorePointer(
                child: ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent,Colors.transparent,Colors.white.withOpacity(0.9),Colors.white.withOpacity(0.8), Colors.white], // 上面透明(Alpha=0)，下面不透明(Alpha=1)
                      stops: const [0.0, 0.4, 0.65, 0.8, 1],
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
            ),

          // 4. UI: 顶部
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(child: _buildTopBar()),
          ),

          // 5. UI: 输入框
          Positioned(
            bottom: bottomInset, left: 0, right: 0,
            child: SafeArea(child: _buildInputBar()),
          ),

          // 6. UI: 礼物横幅
          Positioned(
            top: giftAreaTop,
            left: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: _activeGifts.map((giftEvent) {
                return RepaintBoundary(
                  key: ValueKey(giftEvent.id),
                  child: _AnimatedGiftItem(
                    key: ValueKey(giftEvent.id),
                    giftEvent: giftEvent,
                    onFinished: () => _onGiftFinished(giftEvent.id),
                  ),
                );
              }).toList(),
            ),
          ),

          // 7. UI: 连击按钮
          if (_showComboButton && _lastGiftSent != null)
            Positioned(
              right: 16,
              bottom: bottomInset + 80,
              child: ScaleTransition(
                scale: CurvedAnimation(parent: _comboAnimController, curve: Curves.elasticOut),
                child: GestureDetector(
                  onTap: () => _sendGift(_lastGiftSent!),
                  child: SizedBox(
                    width: 76,
                    height: 76,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 76,
                          height: 76,
                          child: AnimatedBuilder(
                            animation: _comboCountdownController,
                            builder: (context, child) {
                              return CircularProgressIndicator(
                                value: 1.0 - _comboCountdownController.value,
                                strokeWidth: 4,
                                valueColor: const AlwaysStoppedAnimation(Color(0xFFFF0080)),
                                backgroundColor: Colors.white.withOpacity(0.3),
                              );
                            },
                          ),
                        ),
                        Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(colors: [Color(0xFFFF0080), Color(0xFFFF8C00)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            boxShadow: [BoxShadow(color: const Color(0xFFFF0080).withOpacity(0.6), blurRadius: 10, offset: const Offset(0, 4))],
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [Text("连击", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), Text("Combo", style: TextStyle(color: Colors.white, fontSize: 10))]),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        children: [
          const _ProfilePill(),
          const Spacer(),
          const _ViewerList(),

          // --- 新增：切换背景按钮 ---
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _toggleBgMode,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              // 如果当前是视频，显示图片图标（表示可切换到图片）；反之显示摄像机图标
              child: Icon(
                  _useVideoBg ? Icons.image_outlined : Icons.videocam_outlined,
                  color: Colors.white,
                  size: 20
              ),
            ),
          ),
          // --- 结束 ---

          const SizedBox(width: 8),
          const Icon(Icons.close, color: Colors.white, size: 28)
        ],
      ),
    );
  }

  Widget _buildChatList() { return Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: ShaderMask(shaderCallback: (Rect bounds) { return LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.white], stops: const [0.0, 0.2]).createShader(bounds); }, blendMode: BlendMode.dstIn, child: ListView.builder(padding: EdgeInsets.zero, reverse: true, itemCount: _messages.length, itemBuilder: (context, index) { return _buildChatItem(_messages[index]); },),),); }
  Widget _buildInputBar() { return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), color: Colors.transparent, child: Row(children: [Expanded(child: Container(height: 40, decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(20),), child: TextField(controller: _textController, style: const TextStyle(color: Colors.white, fontSize: 14), cursorColor: Colors.pinkAccent, textInputAction: TextInputAction.send, onSubmitted: (_) => _handleSend(), decoration: InputDecoration(hintText: "说点什么...", hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), suffixIcon: IconButton(icon: const Icon(Icons.send, color: Colors.pinkAccent, size: 20), onPressed: () => _handleSend(),),),),),), const SizedBox(width: 10), const Icon(Icons.favorite_border, color: Colors.pinkAccent, size: 30), const SizedBox(width: 10), GestureDetector(onTap: _showGiftPanel, child: const Icon(Icons.card_giftcard, color: Colors.pinkAccent, size: 30),), const SizedBox(width: 10), const Icon(Icons.reply, color: Colors.white, size: 30),],),); }
  Widget _buildChatItem(ChatMessage msg) { return Padding(padding: const EdgeInsets.symmetric(vertical: 0.8),child: Row(mainAxisSize: MainAxisSize.min,crossAxisAlignment: CrossAxisAlignment.start,children: [Flexible(child: Container(decoration: BoxDecoration(color: Colors.black.withOpacity(0.3),borderRadius: BorderRadius.circular(16),),padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),child: Wrap(crossAxisAlignment: WrapCrossAlignment.center,children: [Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),decoration: BoxDecoration(gradient: LinearGradient(colors: [msg.levelColor.withOpacity(0.8), msg.levelColor],),borderRadius: BorderRadius.circular(10),),child: Row(mainAxisSize: MainAxisSize.min,children: [const Icon(Icons.pentagon, size: 10, color: Colors.white),const SizedBox(width: 2),Text("${msg.level}",style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),),],),),const SizedBox(width: 6),Text("${msg.name}: ",style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w500),),Text(msg.content,style: const TextStyle(color: Colors.white, fontSize: 13),),],),),),],),); }
}

class GiftPanel extends StatefulWidget {
  final Function(GiftItemData) onSend;
  const GiftPanel({super.key, required this.onSend});
  @override
  State<GiftPanel> createState() => _GiftPanelState();
}

class _GiftPanelState extends State<GiftPanel> with SingleTickerProviderStateMixin {
  int _selectedIndex = -1;
  late TabController _tabController;

  static const String _aliyunEffect_qlzy = 'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/effect_video/qlzy.webm';
  // static const String _aliyunEffect_qlzy = 'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/effect_video/%E5%BE%A1%E9%BE%99%E8%8B%B1%E8%B1%AA%E3%80%90%E9%9F%B3%E6%95%88%E7%89%88%E3%80%91%E7%B4%A0%E6%9D%90%2B.mp4';
  static const String _aliyunEffectUrl_xlyx = 'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/effect_video/%E5%AF%BB%E9%BE%99%E6%B8%B8%E4%BE%A0.webm';
  static const String _aliyunEffectUrl_ylyx = 'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/effect_video/ylyx.webm';
  static const String _aliyunEffectUrl_dsyx = 'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/effect_video/%E9%83%BD%E5%B8%82%C2%B7%E6%B8%B8%E4%BE%A0.webm';
  static const String _aliyunEffectUrl_ltjt = 'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/effect_video/%E9%BE%99%E8%85%BE%E4%B9%9D%E5%A4%A9.webm';

  final List<GiftItemData> _gifts = const [
    GiftItemData(name: "潜龙在渊", price: 1, iconUrl: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/qlzy.png", effectAsset: _aliyunEffect_qlzy),
    GiftItemData(name: "寻龙游侠", price: 9, iconUrl: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/xlyx.png", effectAsset: _aliyunEffectUrl_xlyx),
    GiftItemData(name: "御龙游侠", price: 66, iconUrl: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/ylyx.png", effectAsset: _aliyunEffectUrl_ylyx),
    GiftItemData(name: "都市游侠", price: 520, iconUrl: "https://cdn-icons-png.flaticon.com/512/3209/3209921.png", effectAsset: _aliyunEffectUrl_dsyx),
    GiftItemData(name: "龙腾九天", price: 520, iconUrl: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/ltjt.png", effectAsset: _aliyunEffectUrl_ltjt),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 380,
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.white,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                    tabs: const [Tab(text: "推荐"), Tab(text: "冬日"), Tab(text: "展馆"), Tab(text: "玩法")],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: const [
                    Icon(Icons.diamond, color: Colors.blueAccent, size: 14), SizedBox(width: 4), Text("23", style: TextStyle(color: Colors.white, fontSize: 12)),
                    SizedBox(width: 8),
                    Icon(Icons.monetization_on, color: Colors.amber, size: 14), SizedBox(width: 4), Text("58 >", style: TextStyle(color: Colors.white, fontSize: 12))
                  ]),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _gifts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.78,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final gift = _gifts[index];
                final isSelected = _selectedIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIndex = index),
                  child: Container(
                    decoration: BoxDecoration(
                      border: isSelected ? Border.all(color: Colors.white, width: 1.5) : null,
                      borderRadius: BorderRadius.circular(12),
                      color: isSelected ? Colors.white.withOpacity(0.08) : Colors.transparent,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.network(gift.iconUrl, width: 50, height: 50),
                            const SizedBox(height: 6),
                            Text(gift.name, style: const TextStyle(color: Colors.white, fontSize: 12)),
                            const SizedBox(height: 2),
                            if (!isSelected) Text("${gift.price} 钻", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)) else const SizedBox(height: 14),
                          ],
                        ),
                        if (isSelected)
                          Positioned(
                            bottom: 0, left: 0, right: 0,
                            child: GestureDetector(
                              onTap: () => widget.onSend(gift),
                              child: Container(
                                height: 26,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(colors: [Color(0xFFFF0080), Color(0xFFFF4081)]),
                                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10)),
                                ),
                                child: const Text("赠送", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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
        ],
      ),
    );
  }
}

class _AnimatedGiftItem extends StatefulWidget {
  final GiftEvent giftEvent;
  final VoidCallback onFinished;

  const _AnimatedGiftItem({
    required Key key,
    required this.giftEvent,
    required this.onFinished,
  }) : super(key: key);

  @override
  State<_AnimatedGiftItem> createState() => _AnimatedGiftBannerWidget();
}

class _AnimatedGiftBannerWidget extends State<_AnimatedGiftItem> with TickerProviderStateMixin {
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
    _slideAnimation = Tween<Offset>(begin: const Offset(-1.2, 0.0), end: Offset.zero).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutQuart));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_entryController);

    _comboController = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(CurvedAnimation(parent: _comboController, curve: Curves.easeOutBack));

    _comboController.addStatusListener((status) {if (status == AnimationStatus.completed) {_comboController.reverse();}});
    _entryController.forward();
    _startTimer();
  }

  @override
  void didUpdateWidget(_AnimatedGiftItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.giftEvent.count > oldWidget.giftEvent.count) {
      _stayTimer?.cancel();
      // 防止连击时横幅闪退：如果正在退出，强行拉回
      if (_entryController.status == AnimationStatus.reverse || _entryController.value < 1.0) {
        _entryController.forward();
      }
      _startTimer();
      _comboController.reset();
      _comboController.forward();
    }
  }

  void _startTimer() {
    _stayTimer?.cancel();
    _stayTimer = Timer(const Duration(seconds: 5), () {
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
        child: _buildCompactBanner(widget.giftEvent),
      ),
    );
  }

  Widget _buildCompactBanner(GiftEvent gift) {
    return Container(
      margin: const EdgeInsets.only(left: 10, bottom: 10),
      height: 50,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          // 1. 胶囊背景
          Container(
            height: 32,
            width: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.blue.shade900.withOpacity(0.9), Colors.purple.shade800.withOpacity(0.8), Colors.transparent]
              ),
              borderRadius: BorderRadius.circular(16), // 圆角适配
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
            ),
            padding: const EdgeInsets.only(left: 0),
            child: Row(
              children: [
                Container(
                    padding: const EdgeInsets.all(1),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const CircleAvatar(radius: 12, backgroundImage: NetworkImage('https://picsum.photos/seed/myAvatar/200'))
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        gift.senderName.length > 4 ? "${gift.senderName.substring(0,4)}..." : gift.senderName,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                    ),
                    Text("送出 ${gift.giftName}", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 8)),
                  ],
                ),
              ],
            ),
          ),

          // 2. 礼物图标 (放低，压在胶囊上)
          Positioned(
            left: 105,
            top: 4,
            child: Image.network(gift.giftIconUrl, width: 38, height: 38, fit: BoxFit.contain),
          ),

          // 3. 连击数字 (放胶囊外，底部对齐，下沉)
          Positioned(
            left: 145, // 紧贴胶囊
            bottom: 0,
            child: ScaleTransition(
              scale: _scaleAnimation,
              alignment: Alignment.bottomLeft,
              child: Transform.rotate(
                angle: -0.1,
                alignment: Alignment.bottomLeft,
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.white, Colors.white70],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ).createShader(bounds),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end, // 底部对齐
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // x 号 (不动)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: const Text("x", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, color: Colors.white)),
                      ),
                      const SizedBox(width: 2),
                      // 数字 (下沉 4px)
                      Transform.translate(
                        offset: const Offset(0, 0),
                        child: Text("${gift.count}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePill extends StatelessWidget {
  const _ProfilePill();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        const CircleAvatar(radius: 16, backgroundImage: NetworkImage('https://picsum.photos/seed/555/200')),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [Text("糖🍬宝...", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)), Text("0本场点赞", style: TextStyle(color: Colors.white70, fontSize: 9))]),
        const SizedBox(width: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.add, size: 14, color: Colors.white)),
      ]),
    );
  }
}

class _ViewerList extends StatelessWidget {
  const _ViewerList();
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(height: 32, child: ListView.builder(scrollDirection: Axis.horizontal, shrinkWrap: true, itemCount: 3, itemBuilder: (context, index) {
        return Padding(padding: const EdgeInsets.only(right: 4), child: CircleAvatar(radius: 14, backgroundImage: NetworkImage('https://picsum.photos/seed/${888 + index}/200')));
      })),
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(16)), child: const Text("4", style: TextStyle(color: Colors.white, fontSize: 12))),
    ]);
  }
}