import 'package:flutter/material.dart';
import 'dart:math' as math;

class SchoolBoardPage extends StatefulWidget {
  const SchoolBoardPage({super.key});

  @override
  State<SchoolBoardPage> createState() => _SchoolBoardPageState();
}

class _SchoolBoardPageState extends State<SchoolBoardPage> {
  // 模拟数据
  late List<Post> _posts;
  final List<String> _hotTopics = ["#期末冲刺", "#校园运动会", "#每日一题", "#最美笔记", "#社团招新"];

  @override
  void initState() {
    super.initState();
    _posts = _generateMockPosts();
  }

  // 生成模拟帖子数据
  List<Post> _generateMockPosts() {
    return [
      Post(
        user: User(name: "教务处", avatar: "https://api.dicebear.com/7.x/initials/png?seed=SA", role: UserRole.admin),
        content: "【重要通知】本学期期末考试将于下月15日正式开始，请各位同学合理安排复习时间。图书馆开放时间延长至晚上23:00。",
        timeAgo: "置顶 · 1小时前",
        likes: 128,
        comments: [
          Comment(user: User(name: "李明", role: UserRole.student), content: "收到！这就去图书馆占座。"),
          Comment(user: User(name: "王老师", role: UserRole.teacher), content: "同学们注意劳逸结合。"),
        ],
        images: [],
        tag: "校务通知",
        tagColor: Colors.red,
      ),
      Post(
        user: User(name: "张伟", avatar: "https://api.dicebear.com/7.x/avataaars/png?seed=zhang", role: UserRole.student),
        content: "终于搞定了这道压轴题！微积分的快乐谁懂啊？分享一下我的解题思路，欢迎指正👇",
        timeAgo: "15分钟前",
        likes: 45,
        comments: [
          Comment(user: User(name: "数学陈老师", role: UserRole.teacher), content: "思路非常清晰，辅助线做得很有灵性！👍"),
          Comment(user: User(name: "赵丽颖", role: UserRole.student), content: "学霸求带！"),
        ],
        images: ["https://picsum.photos/seed/math/400/300"],
        tag: "学习打卡",
        tagColor: Colors.blue,
      ),
      Post(
        user: User(name: "刘亦菲", avatar: "https://api.dicebear.com/7.x/avataaars/png?seed=liu", role: UserRole.student),
        content: "今天的晚霞好美，在操场跑步也是一种享受~ 🏃‍♀️",
        timeAgo: "30分钟前",
        likes: 232,
        comments: [],
        images: ["https://picsum.photos/seed/sunset/400/250", "https://picsum.photos/seed/run/400/250"],
        tag: "校园生活",
        tagColor: Colors.orange,
      ),
      Post(
        user: User(name: "李娜老师", avatar: "https://api.dicebear.com/7.x/avataaars/png?seed=li", role: UserRole.teacher),
        content: "表扬一下二班的同学，今天的随堂测验全员及格，平均分创新高！奖励大家这周作业减半！🎉",
        timeAgo: "2小时前",
        likes: 890,
        comments: [
          Comment(user: User(name: "全体二班同学", role: UserRole.student), content: "老师万岁！！！"),
          Comment(user: User(name: "隔壁班小王", role: UserRole.student), content: "羡慕哭了..."),
        ],
        images: [],
        tag: "班级表彰",
        tagColor: Colors.green,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // 适配系统主题
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          // 1. 热门话题横向滚动栏
          SliverToBoxAdapter(
            child: Container(
              height: 33,
              margin: const EdgeInsets.symmetric(vertical: 10),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _hotTopics.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [Colors.blue.withOpacity(0.3), Colors.purple.withOpacity(0.3)]
                            : [Colors.blue.shade100, Colors.purple.shade100],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue.withOpacity(0.1)),
                    ),
                    child: Text(
                      _hotTopics[index],
                      style: TextStyle(
                          color: isDark ? Colors.blue.shade100 : Colors.blue.shade800,
                          fontWeight: FontWeight.bold
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 2. 动态列表
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                final post = _posts[index];
                return _buildPostCard(post, cardColor, textColor, subTextColor, isDark);
              },
              childCount: _posts.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildPostCard(Post post, Color cardColor, Color textColor, Color subTextColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：头像、名字、时间、标签
          Row(
            children: [
              CircleAvatar(
                backgroundImage: NetworkImage(post.user.avatar ?? ""),
                backgroundColor: Colors.grey[200],
                child: post.user.avatar == null ? Text(post.user.name[0]) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(post.user.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                        const SizedBox(width: 8),
                        _buildRoleBadge(post.user.role),
                      ],
                    ),
                    Text(post.timeAgo, style: TextStyle(color: subTextColor, fontSize: 12)),
                  ],
                ),
              ),
              if (post.tag != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: post.tagColor?.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: post.tagColor?.withOpacity(0.5) ?? Colors.transparent),
                  ),
                  child: Text(post.tag!, style: TextStyle(fontSize: 10, color: post.tagColor, fontWeight: FontWeight.bold)),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // 内容
          Text(post.content, style: TextStyle(fontSize: 15, height: 1.5, color: textColor)),

          // 图片九宫格 (简化版)
          if (post.images.isNotEmpty) ...[
            const SizedBox(height: 12),
            post.images.length == 1
                ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(post.images[0], fit: BoxFit.cover, height: 200, width: double.infinity),
            )
                : Row(
              children: post.images.map((img) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(img, fit: BoxFit.cover, height: 120),
                  ),
                ),
              )).toList(),
            ),
          ],

          const SizedBox(height: 16),
          Divider(color: isDark ? Colors.white10 : Colors.grey[200]),

          // 底部交互栏
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActionButton(Icons.favorite_border, "${post.likes}", subTextColor),
              _buildActionButton(Icons.chat_bubble_outline, "${post.comments.length}", subTextColor),
              _buildActionButton(Icons.share, "分享", subTextColor),
            ],
          ),

          // 评论区 (如果有)
          if (post.comments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: post.comments.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: "${c.user.name}: ",
                          style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 13),
                        ),
                        TextSpan(
                          text: c.content,
                          style: TextStyle(color: subTextColor, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )).toList(),
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildRoleBadge(UserRole role) {
    Color color;
    String text;
    switch (role) {
      case UserRole.teacher:
        color = Colors.orange;
        text = "老师";
        break;
      case UserRole.admin:
        color = Colors.red;
        text = "官方";
        break;
      case UserRole.student:
      default:
        return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color) {
    return InkWell(
      onTap: () {},
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 13)),
        ],
      ),
    );
  }
}

// ================= 数据模型 =================

enum UserRole { student, teacher, admin }

class User {
  final String name;
  final String? avatar;
  final UserRole role;

  User({required this.name, this.avatar, this.role = UserRole.student});
}

class Comment {
  final User user;
  final String content;

  Comment({required this.user, required this.content});
}

class Post {
  final User user;
  final String content;
  final String timeAgo;
  final int likes;
  final List<Comment> comments;
  final List<String> images;
  final String? tag;
  final Color? tagColor;

  Post({
    required this.user,
    required this.content,
    required this.timeAgo,
    this.likes = 0,
    this.comments = const [],
    this.images = const [],
    this.tag,
    this.tagColor,
  });
}