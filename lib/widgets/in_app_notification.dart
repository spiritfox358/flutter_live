import 'dart:async';
import 'package:flutter/material.dart';

import '../main.dart';

// 引入我们在 main.dart 中定义的 navigatorKey
// 注意：请替换成你实际的 main.dart 路径

class InAppNotification {
  /// 🟢 触发通知的方法
  static void show(String message, {bool isSuccess = true}) {
    _showEntry(
      _NotificationWidget(
        message: message,
        isSuccess: isSuccess,
        onDismiss: () {},
      ),
    );
  }

  static void showMessage({
    required String title,
    required String content,
    String avatar = '',
    VoidCallback? onTap,
  }) {
    _showEntry(
      _MessageNotificationWidget(
        title: title,
        content: content,
        avatar: avatar,
        onTap: onTap,
        onDismiss: () {},
      ),
    );
  }

  static void _showEntry(Widget child) {
    // 拿到全局的 OverlayState
    final overlayState = navigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    // 创建一个 OverlayEntry (悬浮层条目)
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        void remove() {
          if (overlayEntry.mounted) {
            overlayEntry.remove();
          }
        }

        if (child is _NotificationWidget) {
          return _NotificationWidget(
            message: child.message,
            isSuccess: child.isSuccess,
            onDismiss: remove,
          );
        }
        if (child is _MessageNotificationWidget) {
          return _MessageNotificationWidget(
            title: child.title,
            content: child.content,
            avatar: child.avatar,
            onTap: child.onTap,
            onDismiss: remove,
          );
        }
        return child;
      },
    );

    // 插入到 Overlay 中显示
    overlayState.insert(overlayEntry);
  }
}

/// 🟢 带有下拉动画的通知 UI 组件
class _NotificationWidget extends StatefulWidget {
  final String message;
  final bool isSuccess;
  final VoidCallback onDismiss;

  const _NotificationWidget({
    required this.message,
    required this.isSuccess,
    required this.onDismiss,
  });

  @override
  State<_NotificationWidget> createState() => _NotificationWidgetState();
}

class _NotificationWidgetState extends State<_NotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 动画控制器：下拉动画时长 300 毫秒
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // 设置滑动范围：从顶部屏幕外 (y: -1) 滑动到原位 (y: 0)
    _offsetAnimation =
        Tween<Offset>(begin: const Offset(0.0, -1.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOutBack,
          ), // 使用弹性曲线，让弹出更有动感
        );

    // 开始进场动画
    _controller.forward();

    // 设置定时器，3秒后自动退场
    _timer = Timer(const Duration(seconds: 3), _dismiss);
  }

  // 触发退场动画，动画结束后销毁自身
  void _dismiss() {
    _timer?.cancel();
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 使用 SafeArea 防止被刘海屏/状态栏挡住
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: SlideTransition(
          position: _offsetAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              // 支持用户向上滑动主动隐藏通知
              onVerticalDragUpdate: (details) {
                if (details.delta.dy < -2) {
                  _dismiss();
                }
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2C2C2C)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // 图标
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: widget.isSuccess
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.isSuccess ? Icons.check_circle : Icons.error,
                        color: widget.isSuccess
                            ? Colors.green
                            : Colors.redAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 文字内容
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageNotificationWidget extends StatefulWidget {
  final String title;
  final String content;
  final String avatar;
  final VoidCallback? onTap;
  final VoidCallback onDismiss;

  const _MessageNotificationWidget({
    required this.title,
    required this.content,
    required this.avatar,
    this.onTap,
    required this.onDismiss,
  });

  @override
  State<_MessageNotificationWidget> createState() =>
      _MessageNotificationWidgetState();
}

class _MessageNotificationWidgetState extends State<_MessageNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
    _timer = Timer(const Duration(seconds: 4), _dismiss);
  }

  void _dismiss() {
    _timer?.cancel();
    _controller.reverse().then((_) => widget.onDismiss());
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: SlideTransition(
          position: _offsetAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () {
                widget.onTap?.call();
                _dismiss();
              },
              onVerticalDragUpdate: (details) {
                if (details.delta.dy < -2) {
                  _dismiss();
                }
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF151515)
                      : Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    ClipOval(
                      child: widget.avatar.isNotEmpty
                          ? Image.network(
                              widget.avatar,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _fallbackAvatar(),
                            )
                          : _fallbackAvatar(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.content,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Icons.chevron_right,
                      color: isDark ? Colors.white54 : Colors.black38,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      width: 44,
      height: 44,
      color: const Color(0xFFFF2E55),
      child: const Icon(Icons.chat_bubble, color: Colors.white, size: 22),
    );
  }
}
