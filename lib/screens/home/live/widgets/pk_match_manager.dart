import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../tools/HttpUtil.dart';

class PkMatchManager extends StatefulWidget {
  final String roomId;
  final String currentUserId;
  final String currentUserName;
  final String currentUserAvatar;
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
  bool _isMatching = false;
  Function? _cancelMatchingCallback;

  // 🟢 核心新增：用 ValueNotifier 来局部刷新弹窗里的文字
  final ValueNotifier<String> _statusTextNotifier = ValueNotifier("正在随机寻找空闲主播...");

  // ================= Public Methods =================

  void startRandomMatch(BuildContext ignoredContext) async {
    if (!mounted) return;
    setState(() => _isMatching = true);
    _statusTextNotifier.value = "正在随机寻找空闲主播..."; // 重置文案
    _showMatchingDialog();

    try {
      final res = await HttpUtil().post(
        "/api/pk/random_match",
        data: {"roomId": int.parse(widget.roomId), "userName": widget.currentUserName, "avatar": widget.currentUserAvatar},
      );

      // 🟢 核心体验升级：收到后端的响应后，把名字展示出来！
      if (mounted && res != null && res['targetName'] != null) {
        String targetName = res['targetName'];
        _statusTextNotifier.value = "已连线 $targetName\n正在等待对方接受...";
      }
    } catch (e) {
      if (mounted) {
        _closeMatchingDialog();
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

  void onMatchRejected() {
    if (_isMatching) {
      _closeMatchingDialog();
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("对方拒绝了您的连线请求")));
        }
      });
    }
  }

  void showInviteDialog(BuildContext ignoredContext, {required String inviterName, required String inviterAvatar, required String inviterRoomId}) {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => _buildInviteDialog(ctx, inviterName, inviterAvatar, inviterRoomId));
  }

  void stopMatching() {
    if (_isMatching) {
      _closeMatchingDialog();
    }
  }

  // ================= Private Logic & UI =================

  void _closeMatchingDialog() {
    if (_isMatching) {
      _cancelMatchingCallback?.call();
      setState(() => _isMatching = false);
    }
  }

  void _showMatchingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        _cancelMatchingCallback = () => Navigator.pop(ctx);
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              const CircularProgressIndicator(color: Colors.pinkAccent),
              const SizedBox(height: 24),
              // 🟢 核心修改：使用 ValueListenableBuilder 监听状态变化，实时更新文字！
              ValueListenableBuilder<String>(
                valueListenable: _statusTextNotifier,
                builder: (context, text, child) {
                  return Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5));
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => _closeMatchingDialog(),
              child: const Text("取消", style: TextStyle(color: Colors.white54)),
            ),
          ],
        );
      },
    );
  }

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
            _replyInvite(inviterRoomId, false); // 🚨 超时应该是自动拒绝，保护主播体验
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
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.pinkAccent, width: 2)),
                child: CircleAvatar(radius: 35, backgroundImage: NetworkImage(avatar)),
              ),
              const SizedBox(height: 16),
              Text("$name 邀请你进行PK连线", style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 8),
              Text("$timeLeft 秒后自动拒绝", style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
              child: const Text("接受连线", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}