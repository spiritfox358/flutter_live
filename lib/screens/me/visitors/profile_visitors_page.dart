import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../tools/HttpUtil.dart';
import '../profile/user_profile_page.dart'; // 🟢 引入 HttpUtil (请根据你的实际路径调整)

class ProfileVisitorsPage extends StatefulWidget {
  const ProfileVisitorsPage({super.key});

  @override
  State<ProfileVisitorsPage> createState() => _ProfileVisitorsPageState();
}

class _ProfileVisitorsPageState extends State<ProfileVisitorsPage> {
  // 🟢 真实的数据列表
  List<dynamic> _visitors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchVisitors();
  }

  // 🟢 接入真实接口
  Future<void> _fetchVisitors() async {
    try {
      var res = await HttpUtil().get("/api/user/visitors");

      if (mounted) {
        setState(() {
          // 假设后端返回的数据在 data 字段中
          _visitors = (res as List<dynamic>?) ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("获取访客列表失败: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("加载失败，请检查网络")));
      }
    }
  }

  // 🟢 核心逻辑：通知后端清除红点，并返回上一页
  void _clearUnreadAndPop() {
    // 静默调用清除未读接口，不需要 await 阻塞页面返回
    HttpUtil().post("/api/user/visitor/clear_unread").catchError((e) {
      debugPrint("清除未读失败: $e");
    });

    // 退出当前页，并带上 true 给上一页，意思是 "我已看过，请刷新你的总数"
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final noticeBgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF6F6F6);
    final noticeTextColor = isDark ? Colors.white54 : Colors.black54;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _clearUnreadAndPop(); // 拦截后走我们的自定义返回逻辑
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: textColor),
            onPressed: _clearUnreadAndPop,
          ),
          title: Text(
            "主页访客",
            style: TextStyle(color: textColor, fontSize: 17, fontWeight: FontWeight.bold),
          ),
          actions: [
            TextButton(
              onPressed: () {},
              child: Text("设置", style: TextStyle(color: textColor, fontSize: 15)),
            ),
          ],
        ),
        body: Column(
          children: [
            // 1. 顶部提示语区域
            Container(
              width: double.infinity,
              color: noticeBgColor,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              alignment: Alignment.center,
              child: Text("仅展示 30 天内已授权的访客，访客记录仅你可见", style: TextStyle(color: noticeTextColor, fontSize: 13)),
            ),

            // 2. 下方的访客列表
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _visitors.isEmpty
                  ? const Center(
                      child: Text("暂无访客记录", style: TextStyle(color: Colors.grey)),
                    )
                  : ListView.builder(
                      itemCount: _visitors.length,
                      itemBuilder: (context, index) {
                        return _buildVisitorItem(_visitors[index], isDark);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建单个访客列表项
  Widget _buildVisitorItem(Map<String, dynamic> user, bool isDark) {
    // 兼容后端可能返回的字段命名差异
    final String visitorId = user['visitorId'].toString();
    final String name = user['name'] ?? user['nickname'] ?? "未知用户";
    final String avatar = user['avatar'] ?? "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/bg_13.jpg";
    final int status = user['status'] ?? 0;

    // 兼容后端返回 true/false 或 1/0
    final bool isNew = user['isNew'] ?? true;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Padding(
      // 减小左侧 padding，为红点腾出空间
      padding: const EdgeInsets.only(left: 10, right: 16, top: 12, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // 🟢 确保整个 Row 垂直居中
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                user['isNew'] = false; // 兼容布尔值
              });
              // 只有点击头像区域才跳转
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      UserProfilePage(userInfo: {'id': visitorId, 'nickname': name, 'avatar': avatar, 'signature': user['signature'] ?? '...'}),
                ),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min, // 紧凑包裹红点和头像
              children: [
                // 独立的红点区：固定宽度 14，保证头像统一对齐
                SizedBox(
                  width: 14,
                  child: isNew
                      ? Center(
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF2C55), // 抖音红
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : const SizedBox(), // 不是新访客也要占位，保持对齐
                ),
                // 头像区
                ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: avatar,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey[300]),
                    errorWidget: (context, url, error) => const Icon(Icons.error),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // 3. 昵称区
          Expanded(
            child: Text(
              name,
              style: TextStyle(color: textColor, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),

          // 4. 右侧操作按钮
          _buildActionButton(status, isDark),
          const SizedBox(width: 8),

          // 5. 最右侧箭头
          Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
        ],
      ),
    );
  }

  // 构建右侧不同状态的按钮
  Widget _buildActionButton(int status, bool isDark) {
    String text = "";
    Color bgColor = Colors.transparent;
    Color textColor = Colors.black;

    // 根据不同状态匹配文案和颜色
    switch (status) {
      case 0:
        text = "发私信";
        bgColor = isDark ? Colors.white24 : const Color(0xFFF0F0F0);
        textColor = isDark ? Colors.white : Colors.black87;
        break;
      case 1:
        text = "关注";
        bgColor = const Color(0xFFFF2C55); // 鲜艳的红色
        textColor = Colors.white;
        break;
      case 2:
        text = "已关注";
        bgColor = isDark ? Colors.white24 : const Color(0xFFF0F0F0);
        textColor = isDark ? Colors.white54 : Colors.black54;
        break;
      case 3:
        text = "已请求";
        bgColor = isDark ? Colors.white24 : const Color(0xFFF0F0F0);
        textColor = isDark ? Colors.white54 : Colors.black54;
        break;
      default:
        text = "关注";
        bgColor = const Color(0xFFFF2C55);
        textColor = Colors.white;
    }

    return GestureDetector(
      onTap: () {
        // TODO: 处理按钮点击事件 (调用关注/私信接口)
      },
      child: Container(
        width: 76,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4)),
        child: Text(
          text,
          style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
