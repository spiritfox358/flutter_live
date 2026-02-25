import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../tools/HttpUtil.dart';

/// 专门用于管理 PK 匹配逻辑、弹窗交互的组件
class PkMatchManager extends StatefulWidget {
  final String roomId;
  final String currentUserId;
  final String currentUserName;
  final String currentUserAvatar;

  // 当匹配成功（双方都同意）时，通知父组件开始推流/拉流
  final VoidCallback? onPkStarted;

  const PkMatchManager({
    super.key,
    required this.roomId,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserAvatar,
    this.onPkStarted,
  });

  @override
  State<PkMatchManager> createState() => PkMatchManagerState();
}

class PkMatchManagerState extends State<PkMatchManager> {
  bool _isMatching = false; // 是否正在发起匹配（等待中）
  Function? _cancelMatchingCallback; // 用于关闭“匹配中”弹窗的句柄

  // ================= Public Methods (供父组件调用) =================

  /// 1. 发起随机匹配
  /// 🟢 修复：虽然保留参数为了兼容调用，但内部直接忽略它，使用更稳定的 this.context
  void startRandomMatch(BuildContext ignoredContext) async {
    // A. 显示等待弹窗 (使用 this.context)
    if (!mounted) return;
    setState(() => _isMatching = true);
    _showMatchingDialog();

    try {
      // B. 请求后端接口
      final res = await HttpUtil().post(
        "/api/pk/random_match",
        data: {"roomId": int.parse(widget.roomId), "userName": widget.currentUserName, "avatar": widget.currentUserAvatar},
      );
      // don't do anything
    } catch (e) {
      if (mounted) {
        _closeMatchingDialog();

        // 同样等待动画
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("暂时没匹配到合适的对手，换个时间试试？"),
            backgroundColor: Colors.grey,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(20),
          ),
        );
      }
    }
  }

  /// 2. 处理被对方拒绝 (Socket收到 PK_REJECTED 时调用)
  void onMatchRejected() {
    // 也要先关弹窗
    if (_isMatching) {
      _closeMatchingDialog();
      // 加一点点延迟体验更好
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("对方拒绝了您的连线请求")));
        }
      });
    }
  }

  /// 3. 处理收到别人的邀请 (Socket收到 PK_INVITE 时调用)
  void showInviteDialog(BuildContext ignoredContext, {required String inviterName, required String inviterAvatar, required String inviterRoomId}) {
    // 同样使用 this.context 保证弹窗在最上层
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => _buildInviteDialog(ctx, inviterName, inviterAvatar, inviterRoomId));
  }

  // ================= Private Logic & UI =================

  void _closeMatchingDialog() {
    if (_isMatching) {
      // 这里的 _cancelMatchingCallback 存的是 Navigator.pop(ctx)
      _cancelMatchingCallback?.call();
      setState(() => _isMatching = false);
    }
  }

  /// 显示“正在匹配中”的弹窗
  void _showMatchingDialog() {
    showDialog(
      context: context, // 使用 stable context
      barrierDismissible: false,
      builder: (ctx) {
        _cancelMatchingCallback = () => Navigator.pop(ctx);
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(height: 20),
              CircularProgressIndicator(color: Colors.pinkAccent),
              SizedBox(height: 24),
              Text("正在随机寻找空闲主播...", style: TextStyle(color: Colors.white, fontSize: 16)),
              SizedBox(height: 10),
              Text("请耐心等待对方响应", style: TextStyle(color: Colors.white38, fontSize: 12)),
              SizedBox(height: 10),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _closeMatchingDialog();
              },
              child: const Text("取消", style: TextStyle(color: Colors.white54)),
            ),
          ],
        );
      },
    );
  }

  /// 构建“收到邀请”的弹窗
  Widget _buildInviteDialog(BuildContext ctx, String name, String avatar, String inviterRoomId) {
    Timer? autoRejectTimer;
    int timeLeft = 10;

    return StatefulBuilder(
      builder: (context, setStateTimer) {
        autoRejectTimer ??= Timer.periodic(const Duration(seconds: 1), (t) {
          if (timeLeft > 0) {
            setStateTimer(() => timeLeft--);
          } else {
            t.cancel();
            Navigator.pop(ctx);
            _replyInvite(inviterRoomId, true);
          }
        });

        return AlertDialog(
          backgroundColor: const Color(0xFF222222),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("PK 连线邀请", style: TextStyle(color: Colors.white, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.pinkAccent, width: 2),
                ),
                child: CircleAvatar(radius: 35, backgroundImage: NetworkImage(avatar)),
              ),
              const SizedBox(height: 16),
              Text("$name 邀请你进行PK连线", style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 8),
              Text("$timeLeft 秒后自动同意", style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                autoRejectTimer?.cancel();
                Navigator.pop(ctx);
                _replyInvite(inviterRoomId, false);
              },
              child: const Text("残忍拒绝", style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E63),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                autoRejectTimer?.cancel();
                Navigator.pop(ctx);
                _replyInvite(inviterRoomId, true);
              },
              child: const Text(
                "接受连线",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _replyInvite(String inviterRoomId, bool accept) async {
    try {
      await HttpUtil().post(
        "/api/pk/reply_invite",
        data: {"roomId": int.parse(widget.roomId), "inviterRoomId": int.parse(inviterRoomId), "accept": accept},
      );
    } catch (e) {
      debugPrint("回复邀请失败: $e");
    }
  }

  void stopMatching() {
    if (_isMatching) {
      _closeMatchingDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
