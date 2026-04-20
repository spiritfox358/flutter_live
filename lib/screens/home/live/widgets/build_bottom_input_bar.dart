import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter_live/screens/home/live/widgets/pk_score_bar_widgets.dart';

class BuildBottomInputBar extends StatelessWidget {
  final VoidCallback onTapInput;
  final VoidCallback onTapGift;
  final PKStatus pkStatus;

  // 🟢 新增：连麦按钮点击回调
  final VoidCallback? onTapCoHost;

  // 接收主播身份和PK点击事件
  final bool isHost;
  final VoidCallback? onTapPK;

  const BuildBottomInputBar({
    super.key,
    required this.onTapInput,
    required this.onTapGift,
    required this.pkStatus,
    this.isHost = false, // 默认为观众
    this.onTapPK,
    this.onTapCoHost,
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
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(18)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                child: const Text("说点什么...", style: TextStyle(color: Colors.white70, fontSize: 14)),
              ),
            ),
          ),

          if (pkStatus == PKStatus.idle) ...[
            const SizedBox(width: 10),
            // 🟢 修改：原本的点赞变成了“连麦”按钮
            GestureDetector(
              onTap: onTapCoHost, // 🟢 绑定回调
              child: const Icon(Icons.join_inner_sharp, color: Colors.pinkAccent, size: 25), // 🟢 换成麦克风图标
            ),
          ],

          const SizedBox(width: 10),

          // 如果是主播显示PK按钮，如果是观众显示礼物按钮
          GestureDetector(
            onTap: isHost ? onTapPK : onTapGift,
            child: isHost ? _buildPKButton() : const Icon(Icons.card_giftcard, color: Colors.pinkAccent, size: 25),
          ),

          const SizedBox(width: 10),
          // 分享/转发按钮
          const Icon(Icons.share_outlined, color: Colors.pinkAccent, size: 25),
        ],
      ),
    );
  }

  Widget _buildPKButton() {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      child: const Text(
        "PK",
        style: TextStyle(
          color: Colors.pinkAccent,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          height: 1.0,
          shadows: [Shadow(color: Colors.black26, offset: Offset(1, 1), blurRadius: 2)],
        ),
      ),
    );
  }
}

/// 状态枚举
enum OverlayStatus {
  idle, // 闲置
  waiting, // 已点击，正在等键盘弹完 (隐身中)
  visible, // 键盘稳住了，UI显示 (显形)
}

/// 键盘输入遮罩层 (处理键盘弹出动画)
class ChatInputOverlay extends StatefulWidget {
  final Function(String) onSend;

  const ChatInputOverlay({super.key, required this.onSend});

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
    _appearController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _appearController, curve: Curves.easeOut));
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
        _debounceTimer = Timer(const Duration(milliseconds: 100), () {
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
              child: FadeTransition(opacity: _opacityAnimation, child: _buildInputPanel()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputPanel() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFEAE8E8),
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 40, maxHeight: 100),
              decoration: BoxDecoration(color: const Color(0xFFC7C6C6), borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: const TextStyle(color: Colors.black, fontSize: 15),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSend(),
                cursorColor: const Color(0xFFE91E63),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: "说点什么...",
                  hintStyle: TextStyle(color: Colors.black26),
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
              decoration: BoxDecoration(color: const Color(0xFFE91E63), borderRadius: BorderRadius.circular(20)),
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
