import 'package:flutter/material.dart';
import '../../../../tools/HttpUtil.dart';
import '../home/live/widgets/profile/live_user_profile_popup.dart'; // 请确保路径与你项目一致

// 🟢 1. 纯粹的用户模型
class FollowingUserModel {
  final String userId;
  final String nickname;
  final String avatarUrl;
  final String signature;

  // 本地状态控制，实现秒切交互
  bool isFollowed;

  FollowingUserModel({
    required this.userId,
    required this.nickname,
    required this.avatarUrl,
    required this.signature,
    this.isFollowed = true,
  });

  factory FollowingUserModel.fromJson(Map<String, dynamic> json) {
    return FollowingUserModel(
      userId: json['id']?.toString() ?? "",
      nickname: json['nickname'] ?? "用户",
      avatarUrl: json['avatar'] ?? "https://via.placeholder.com/150",
      signature: json['signature'] ?? "暂无签名",
    );
  }
}

class FollowingListPage extends StatefulWidget {
  final String? targetUserId; // 可选：看别人的关注列表

  const FollowingListPage({super.key, this.targetUserId});

  @override
  State<FollowingListPage> createState() => _FollowingListPageState();
}

class _FollowingListPageState extends State<FollowingListPage> with AutomaticKeepAliveClientMixin {
  List<FollowingUserModel> _users = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // 🟢 2. 加载关注数据
  Future<void> _loadData() async {
    try {
      Map<String, dynamic> params = {};
      if (widget.targetUserId != null) params['userId'] = widget.targetUserId;

      // 调用你之前写的：查询我关注的所有人接口
      var response = await HttpUtil().get("/api/relation/followings", params: params);

      if (mounted) {
        setState(() {
          if (response is List) {
            _users = response.map((item) => FollowingUserModel.fromJson(item)).toList();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🟢 3. 核心交互：关注/取关切换
  Future<void> _toggleFollow(FollowingUserModel user) async {
    try {
      if (user.isFollowed) {
        // 取消关注
        await HttpUtil().post('/api/relation/unfollow', data: {'targetId': user.userId});
      } else {
        // 重新关注
        await HttpUtil().post('/api/relation/follow', data: {'targetId': user.userId});
      }

      // 🚀 乐观更新：不刷接口，直接改本地状态，让用户感觉不到网络延迟
      setState(() {
        user.isFollowed = !user.isFollowed;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("操作失败: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("关注", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xFFFF0050),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF0050)))
            : _users.isEmpty
            ? _buildEmptyState()
            : ListView.separated(
          padding: const EdgeInsets.only(bottom: 50),
          itemCount: _users.length,
          separatorBuilder: (context, index) => const Divider(height: 1, indent: 82, endIndent: 16, color: Color(0xFFF5F5F5)),
          itemBuilder: (context, index) => _buildUserItem(_users[index]),
        ),
      ),
    );
  }

  Widget _buildUserItem(FollowingUserModel user) {
    return InkWell(
      onTap: () {
        // 点击头像或昵称，弹出你写好的那个精美名片
        LiveUserProfilePopup.show(context, {"userId": user.userId});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 头像
            CircleAvatar(
              radius: 26,
              backgroundImage: NetworkImage(user.avatarUrl),
              backgroundColor: Colors.grey[200],
            ),
            const SizedBox(width: 14),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.nickname,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.signature,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // 🚀 交互按钮
            GestureDetector(
              onTap: () => _toggleFollow(user),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  // 已关注灰色，未关注粉色
                  color: user.isFollowed ? const Color(0xFFF5F5F5) : const Color(0xFFFF2E55),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  user.isFollowed ? "已关注" : "回关",
                  style: TextStyle(
                    color: user.isFollowed ? Colors.black54 : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView( // 必须是 ListView 才能触发下拉刷新
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        const Center(
          child: Text("还没有关注任何人哦", style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }
}