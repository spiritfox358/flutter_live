import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_live/tools/VoicePlayerTool.dart';
import '../../../../../tools/HttpUtil.dart';
import '../avatar_animation.dart';

// 🟢 1. 定义麦位数据模型 (用于渲染 8 个座位)
class VoiceSeatModel {
  final int index;
  final bool isEmpty;
  final String avatar;
  final String name;
  final int coinCount;
  final bool isMuted;

  VoiceSeatModel({
    required this.index,
    this.isEmpty = true,
    this.avatar = "",
    this.name = "申请上麦",
    this.coinCount = 0,
    this.isMuted = false,
  });
}

class VoiceRoomContentView extends StatefulWidget {
  final String currentBgImage;
  final String roomTitle;
  final String anchorName;
  final String anchorAvatar;
  final String roomId;

  const VoiceRoomContentView({
    super.key,
    required this.currentBgImage,
    required this.roomTitle,
    required this.anchorName,
    this.anchorAvatar = "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/avatar/xiaoqi.jpg",
    required this.roomId,
  });

  @override
  State<VoiceRoomContentView> createState() => VoiceRoomContentViewState();
}

class VoiceRoomContentViewState extends State<VoiceRoomContentView> {
  final VoicePlayerTool _ttsService = VoicePlayerTool();
  Timer? _autoChatTimer;
  bool _isFetchingAutoChat = false;
// 🟢 1. 新增：专门保存累加字幕的列表和滚动控制器
  final List<String> _subtitleHistory = [];
  final ScrollController _subtitleScrollController = ScrollController();
  // 🟢 2. 模拟 8 个麦位的数据 (根据你的截图设计的假数据，方便预览效果)
  late List<VoiceSeatModel> _seats;

  @override
  void initState() {
    super.initState();
    _initMockSeats();
    // 延迟启动自动闲聊
    Future.delayed(const Duration(seconds: 3), () {
      // _checkAutoChat();
    });
  }

  // 初始化假数据
  void _initMockSeats() {
    _seats = [
      VoiceSeatModel(index: 0, isEmpty: false, name: "星星", avatar: "https://picsum.photos/seed/101/200", coinCount: 42),
      VoiceSeatModel(index: 1, isEmpty: false, name: "换厅", avatar: "https://picsum.photos/seed/102/200", coinCount: 0),
      VoiceSeatModel(index: 2, isEmpty: true, name: "申请上麦"),
      VoiceSeatModel(index: 3, isEmpty: true, name: "男女都要"),
      VoiceSeatModel(index: 4, isEmpty: true, name: "纯点"),
      VoiceSeatModel(index: 5, isEmpty: true, name: "半点"),
      VoiceSeatModel(index: 6, isEmpty: true, name: "互动"),
      VoiceSeatModel(index: 7, isEmpty: true, name: "都有"),
    ];
  }

  // 🟢 3. 替换：将纯文本加进列表，并滚动到底部
  void updateRealTimeSubtitle(String text) {
    setState(() {
      _subtitleHistory.add(text);
      // 限制最多保留 50 条历史，防止挂机太久内存爆炸
      if (_subtitleHistory.length > 50) {
        _subtitleHistory.removeAt(0);
      }
    });

    // 点亮房主头像的粉色光环，假装他在说话
    _ttsService.isSpeaking.value = true;
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) _ttsService.isSpeaking.value = false;
    });

    _scrollToBottom();
  }

  // 🟢 3. 替换：将语音文本加进列表，并滚动到底部
  void speakFromSocket(Map<String, dynamic> data) {
    _ttsService.playBase64Audio(data['audioData'], text: data['text']);

    setState(() {
      _subtitleHistory.add(data['text']);
      if (_subtitleHistory.length > 50) {
        _subtitleHistory.removeAt(0);
      }
    });

    _scrollToBottom();
  }

  // 🟢 新增：自动丝滑滚动到最新字幕的底部
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_subtitleScrollController.hasClients) {
        _subtitleScrollController.animateTo(
          _subtitleScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoChatTimer?.cancel();
    _ttsService.stopAndClear();
    _subtitleScrollController.dispose(); // 🟢 2. 新增：销毁滚动控制器
    super.dispose();
  }

  // =========================================================
  // 自动闲聊逻辑 (保持你的原逻辑不变)
  // =========================================================
  void _checkAutoChat() {
    _autoChatTimer?.cancel();
    _autoChatTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_ttsService.isSpeaking.value && !_isFetchingAutoChat) {
        // _fetchAutoChat();
      }
    });
  }

  Future<void> _fetchAutoChat() async {
    _isFetchingAutoChat = true;
    try {
      final topics = ["好无聊啊，大家怎么不说话？", "有人想听歌吗？", "榜一大哥在吗？出来聊聊呗。"];
      final text = topics[DateTime.now().millisecondsSinceEpoch % topics.length];

      var responseData = await HttpUtil().get('/api/robot/auto_chat', params: {'text': text, "roomId": widget.roomId});
      if (responseData != null && responseData is Map) {
        final text = responseData['text'];
        final audioData = responseData['audioData'];
        if (audioData != null && audioData.isNotEmpty) {
          speakFromSocket({'audioData': audioData, 'text': text});
        }
      }
    } catch (e) {
      debugPrint("自动闲聊获取失败: $e");
    } finally {
      _isFetchingAutoChat = false;
    }
  }

  // =========================================================
  // UI 构建部分
  // =========================================================
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. 房间背景
        Positioned.fill(
          child: Image.network(
            widget.currentBgImage,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: const Color(0xFF141629)),
          ),
        ),
        // 深色遮罩，突出前面的人物
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0F1123).withOpacity(0.7),
                  const Color(0xFF1F2445).withOpacity(0.9),
                ],
              ),
            ),
          ),
        ),

        // 2. 核心语音房布局 (往下偏移避开 TopBar)
        Positioned(
          top: 110, // 距离顶部留出空间，刚好在头部栏下方
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- A. 主播位与字幕区 ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHostArea(),
                  const SizedBox(width: 16),
                  Expanded(child: _buildSubtitleArea()),
                ],
              ),

              const SizedBox(height: 30),

              // --- B. 8个麦位网格区 ---
              _buildSeatsGrid(),
            ],
          ),
        ),
      ],
    );
  }

// 构建左上角主播区域
  Widget _buildHostArea() {
    return SizedBox(
      width: 90, // 控制整体占用的列宽
      child: Column(
        children: [
          // 🟢 彻底抛弃 AvatarAnimation，手写纯净版头像，尺寸精准控制！
          SizedBox(
            width: 72, // 这个 72 就是头像肉眼可见的绝对真实大小！
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none, // 允许胶囊往下溢出
              children: [

                // --- A. 纯净版头像本体 ---
                ValueListenableBuilder<bool>(
                    valueListenable: _ttsService.isSpeaking,
                    builder: (context, isSpeaking, child) {
                      return Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          // 说话时边框变成粉色，不说话时是半透明白色
                          border: Border.all(
                            color: isSpeaking ? Colors.pinkAccent : Colors.white.withOpacity(0.5),
                            width: isSpeaking ? 2.0 : 1.0,
                          ),
                          image: DecorationImage(
                            image: NetworkImage(widget.anchorAvatar),
                            fit: BoxFit.cover, // 绝对填满，没有任何透明留白！
                          ),
                        ),
                      );
                    }
                ),

                // --- B. 叠加在底部的“关注一麦”胶囊 ---
                Positioned(
                  bottom: -8, // 🟢 往下溢出 8 像素，完美呈现半截骑在头像上的效果
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6), // 半透明黑色底
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.5),
                    ),
                    child: const Text(
                      "关注一麦",
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),

                // --- C. 右下角的麦克风标识 ---
                Positioned(
                  right: -4,  // 靠右边一点
                  bottom: 12, // 避开底部的胶囊
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic, color: Colors.white, size: 12),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14), // 🟢 留出空隙给溢出的胶囊，防止和昵称打架

          // 主播名字
          Text(
            widget.anchorName,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

// 🟢 4. 替换：构建主播右侧的字幕/公告区域 (支持无限累加和滑动)
  Widget _buildSubtitleArea() {
    return Container(
      height: 100,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      // 不再监听 TTS 的单句覆盖，而是直接判断我们的历史列表
      child: _subtitleHistory.isEmpty
          ? const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("实时字幕即将开始", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text("欢迎体验实时字幕功能～", style: TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      )
          : ListView.builder(
        controller: _subtitleScrollController,
        physics: const BouncingScrollPhysics(),
        itemCount: _subtitleHistory.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6.0), // 每句话之间留点空隙
            child: Text(
              _subtitleHistory[index],
              style: const TextStyle(
                color: Colors.amberAccent,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        },
      ),
    );
  }

// 构建 8 个麦位网格
  Widget _buildSeatsGrid() {
    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 6, // 数字越小，上下两排挨得越近
        crossAxisSpacing: 12,
        // 🟢 核心修复：把比例调小到 0.60，给底部的“胶囊 + 名字 + 魅力值”留出极其充足的垂直空间，彻底消灭斑马线！
        childAspectRatio: 0.60,
      ),
      itemBuilder: (context, index) {
        return _buildSingleSeat(_seats[index]);
      },
    );
  }

// 构建单个麦位
  Widget _buildSingleSeat(VoiceSeatModel seat) {
    return GestureDetector(
      onTap: () {
        debugPrint("点击了麦位: ${seat.index}");
      },
      child: Column(
        children: [
          // 1. 头像区 (包含头像、胶囊、闭麦图标)
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none, // 允许胶囊溢出边界
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: seat.isEmpty ? Colors.white.withOpacity(0.1) : null,
                  border: Border.all(
                    color: seat.isEmpty ? Colors.transparent : Colors.white.withOpacity(0.8),
                    width: 1.5,
                  ),
                  image: seat.isEmpty
                      ? null
                      : DecorationImage(image: NetworkImage(seat.avatar), fit: BoxFit.cover),
                ),
                child: seat.isEmpty
                    ? const Icon(Icons.add, color: Colors.white54, size: 24)
                    : null,
              ),

              if (!seat.isEmpty && seat.isMuted)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.black87,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic_off, color: Colors.redAccent, size: 10),
                  ),
                ),

              // 上麦后，显示黑色半透明胶囊昵称
              if (!seat.isEmpty)
                Positioned(
                  bottom: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    constraints: const BoxConstraints(maxWidth: 64),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      seat.name, // 这里的胶囊通常显示角色状态(如"找厅")，你可以后续换成 seat.role 等字段
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14), // 给胶囊留出间隙

          // 🟢 2. 永远显示麦位名称/昵称 (我把这行代码加回来了！)
          Text(
            seat.name,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          // 3. 如果有人，在名字下方“追加”显示魅力值
          if (!seat.isEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite, color: Colors.pinkAccent, size: 10),
                  const SizedBox(width: 2),
                  Text(
                    seat.coinCount.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }
}