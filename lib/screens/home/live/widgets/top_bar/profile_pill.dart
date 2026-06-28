import 'package:flutter/material.dart';

import '../../../../../tools/HttpUtil.dart';
import '../profile/live_user_profile_popup.dart';

class ProfilePill extends StatefulWidget {
  final String name;
  final String avatar;
  final int anchorId;

  const ProfilePill({super.key, required this.name, required this.avatar, required this.anchorId});

  @override
  State<ProfilePill> createState() => _ProfilePillState();
}

class _ProfilePillState extends State<ProfilePill> {
  bool _isFollowed = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    try {
      final data = await HttpUtil().get('/api/relation/status', params: {'targetId': widget.anchorId});
      if (!mounted || data == null) return;
      // status: 0-未关注, 1-已关注, 2-互相关注, -1-自己
      final int status = data['status'] ?? 0;
      setState(() => _isFollowed = status == 1 || status == 2);
    } catch (e) {
      debugPrint("获取关注状态失败: $e");
    }
  }

  void _openProfile() {
    final Map<String, dynamic> userMap = {"userId": widget.anchorId};
    LiveUserProfilePopup.show(context, userMap);
  }

  Future<void> _toggleFollow() async {
    if (_loading) return;
    setState(() => _loading = true);
    final bool wasFollowed = _isFollowed;
    try {
      await HttpUtil().post(
        wasFollowed ? '/api/relation/unfollow' : '/api/relation/follow',
        data: {'targetId': widget.anchorId},
      );
      if (!mounted) return;
      setState(() {
        _isFollowed = !wasFollowed;
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(wasFollowed ? "已取消关注" : "关注成功")),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("操作失败: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          GestureDetector(
            onTap: _openProfile,
            child: CircleAvatar(radius: 18, backgroundImage: NetworkImage(widget.avatar)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _openProfile,
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4), // 👈 上边距
                  child: Text(
                    widget.name,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const Text("0本场点赞", style: TextStyle(color: Colors.white70, fontSize: 9)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _toggleFollow,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _isFollowed ? Colors.grey : Colors.amber,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(_isFollowed ? Icons.check : Icons.add, size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
