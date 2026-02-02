import 'package:flutter/material.dart';
import 'dart:async';

class BuildBottomInputBar extends StatelessWidget {
  final VoidCallback onTapInput;
  final VoidCallback onTapGift;

  // 接收主播身份和PK点击事件
  final bool isHost;
  final VoidCallback? onTapPK;

  const BuildBottomInputBar({
    super.key,
    required this.onTapInput,
    required this.onTapGift,
    this.isHost = false, // 默认为观众
    this.onTapPK,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: Colors.transparent,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onTapInput,
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                child: const Text(
                  "说点什么...",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 点赞按钮
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("点赞 +1 ❤️"),
                duration: Duration(milliseconds: 500),
              ));
            },
            child: const Icon(Icons.favorite_border, color: Colors.pinkAccent, size: 25),
          ),
          const SizedBox(width: 10),

          // 如果是主播显示PK按钮，如果是观众显示礼物按钮
          GestureDetector(
            onTap: isHost ? onTapPK : onTapGift,
            child: isHost
                ? _buildPKButton() // 🟢 调用新的无边框样式
                : const Icon(
              Icons.card_giftcard,
              color: Colors.pinkAccent,
              size: 25,
            ),
          ),

          const SizedBox(width: 10),
          // 分享/转发按钮
          const Icon(Icons.reply, color: Colors.white, size: 30),
        ],
      ),
    );
  }

  // 🟢 修改：PK 按钮样式 (纯文字、无边框、大字号)
  Widget _buildPKButton() {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      // 移除了 decoration (边框和背景)，完全透明
      child: const Text(
        "PK",
        style: TextStyle(
          color: Colors.pinkAccent,
          fontSize: 20,            // 🟢 字号放大 (原12 -> 18)
          fontWeight: FontWeight.w900, // 🟢 极粗体 (Black)
          fontStyle: FontStyle.italic, // 斜体，增加速度感
          height: 1.0, // 紧凑行高，防止文字偏上或偏下
          shadows: [
            // 🟢 可选：加一点点淡淡的文字阴影，防止背景太亮看不清
            Shadow(
              color: Colors.black26,
              offset: Offset(1, 1),
              blurRadius: 2,
            )
          ],
        ),
      ),
    );
  }
}

/// 状态枚举
enum OverlayStatus {
  idle,    // 闲置
  waiting, // 已点击，正在等键盘弹完 (隐身中)
  visible, // 键盘稳住了，UI显示 (显形)
}

/// 键盘输入遮罩层 (处理键盘弹出动画)
class ChatInputOverlay extends StatefulWidget {
  final Function(String) onSend;

  const ChatInputOverlay({
    super.key,
    required this.onSend,
  });

  @override
  State<ChatInputOverlay> createState() => ChatInputOverlayState();
}

class ChatInputOverlayState extends State<ChatInputOverlay> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late AnimationController _appearController;
  late Animation<double> _opacityAnimation;

  OverlayStatus _status = OverlayStatus.idle;

  // 记录上一帧的键盘高度，用于检测收起趋势
  double _lastKeyboardHeight = 0;

  // 标记是否已经弹起过
  bool _keyboardHasPopped = false;

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _appearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _appearController,
      curve: Curves.easeOut,
    ));
  }

  // 外部调用：开始输入
  void showInput() {
    _keyboardHasPopped = false;
    _debounceTimer?.cancel();
    _lastKeyboardHeight = 0;

    setState(() {
      _status = OverlayStatus.waiting;
    });

    if (_focusNode.hasFocus) _focusNode.unfocus();
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  // 立即隐藏
  void _hideInput() {
    _debounceTimer?.cancel();
    if (mounted) {
      setState(() {
        _status = OverlayStatus.idle;
      });
    }
    _focusNode.unfocus();
    _appearController.reset();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSend(text);
      _controller.clear();
    }
    _hideInput();
  }

  @override
  Widget build(BuildContext context) {
    final double currentKeyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final bool isKeyboardOpen = currentKeyboardHeight > 0;

    // ============ 1. 关 (Hide) 的逻辑 ============
    if (_status == OverlayStatus.visible && currentKeyboardHeight < _lastKeyboardHeight) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _hideInput();
      });
    }

    if (_status != OverlayStatus.idle && _keyboardHasPopped && !isKeyboardOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _hideInput();
      });
    }

    // ============ 2. 开 (Show) 的逻辑 ============
    if (isKeyboardOpen && !_keyboardHasPopped) {
      _keyboardHasPopped = true;
    }

    if (_status == OverlayStatus.waiting && isKeyboardOpen) {
      if (_debounceTimer == null || !_debounceTimer!.isActive) {
        _debounceTimer = Timer(const Duration(milliseconds: 300), () {
          if (mounted && _status == OverlayStatus.waiting) {
            setState(() {
              _status = OverlayStatus.visible;
            });
            _appearController.forward();
          }
        });
      }
    }

    _lastKeyboardHeight = currentKeyboardHeight;

    // ============ 3. UI 渲染 ============
    bool isActive = _status != OverlayStatus.idle;
    bool isUIVisible = _status == OverlayStatus.visible;

    return IgnorePointer(
      ignoring: !isActive,
      child: Stack(
        children: [
          // 遮罩层
          if (isActive)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _hideInput,
                child: Container(color: Colors.transparent),
              ),
            ),

          // 输入框主体
          Positioned(
            left: 0,
            right: 0,
            bottom: currentKeyboardHeight,
            child: Opacity(
              opacity: (isUIVisible && isKeyboardOpen) ? 1.0 : 0.0,
              child: FadeTransition(
                opacity: _opacityAnimation,
                child: _buildInputPanel(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputPanel() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF171717),
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 40, maxHeight: 100),
              decoration: BoxDecoration(
                color: const Color(0xFF333333),
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSend(),
                cursorColor: const Color(0xFFE91E63),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: "说点什么...",
                  hintStyle: TextStyle(color: Colors.white38),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _handleSend,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFE91E63),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: const Text(
                "发送",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _appearController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}