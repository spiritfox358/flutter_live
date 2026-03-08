import 'package:flutter/material.dart';
import 'package:flutter_live/screens/home/live/widgets/level_badge_widget.dart';
import 'package:flutter_live/store/user_store.dart';
import '../../../tools/HttpUtil.dart';
import '../../home/live/widgets/profile/live_user_profile_popup.dart';

// 🟢 1. 补全 MyRankInfo 类
class MyRankInfo {
  final int score;
  final int rank;
  final int gap;

  MyRankInfo({required this.score, required this.rank, required this.gap});
}

class UserRankingPage extends StatefulWidget {
  const UserRankingPage({super.key});

  @override
  State<UserRankingPage> createState() => _UserRankingPageState();
}

class _UserRankingPageState extends State<UserRankingPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 🟢 2. 新增状态：存储当前 Tab 计算出的“我的排名信息”
  MyRankInfo? _myRankInfo;

  final String _frameUrl =
      "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/adornment/duke_rose/%E7%8E%AB%E7%91%B0%E5%85%AC%E7%88%B5.png";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatScore(int score) {
    if (score > 10000) {
      return "${(score / 10000).toStringAsFixed(1)}w";
    }
    return score.toString();
  }

  @override
  Widget build(BuildContext context) {
    // 获取当前是否为深色模式
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      // Dark模式背景
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        elevation: 0,
        title: const SizedBox.shrink(), // 隐藏标题
        toolbarHeight: 0, // 只保留状态栏高度
      ),
      body: SafeArea(
        top: true, // 🟢 确保顶部留出状态栏空间
        child: Column(
          children: [
            _buildTabBar(isDark),
            const SizedBox(height: 10),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // 🟢 3. 传递 onLoaded 回调，更新页面状态
                  RankingTabLoader(
                    type: 4,
                    onLoaded: (info) => setState(() => _myRankInfo = info),
                    builder: (data, onRefresh) => _buildRankingListView(data, onRefresh, isDark),
                  ),
                  RankingTabLoader(
                    type: 1,
                    onLoaded: (info) => setState(() => _myRankInfo = info),
                    builder: (data, onRefresh) => _buildRankingListView(data, onRefresh, isDark),
                  ),
                  RankingTabLoader(
                    type: 2,
                    onLoaded: (info) => setState(() => _myRankInfo = info),
                    builder: (data, onRefresh) => _buildRankingListView(data, onRefresh, isDark),
                  ),
                  RankingTabLoader(
                    type: 3,
                    onLoaded: (info) => setState(() => _myRankInfo = info),
                    builder: (data, onRefresh) => _buildRankingListView(data, onRefresh, isDark),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // 🟢 4. 将状态传递给底部栏
      bottomNavigationBar: _buildMyRankBar(_myRankInfo, isDark),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      // ✅ 使用 decoration 实现圆角 + 背景
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.black12,
        borderRadius: BorderRadius.circular(30), // 圆角
      ),

      // ✅ 外边距，让卡片与屏幕边缘有距离
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),

      child: TabBar(
        controller: _tabController,
        dividerHeight: 0,
        labelColor: isDark ? Colors.white : Colors.black,
        unselectedLabelColor: Colors.grey,
        indicatorColor: isDark ? Colors.white : Colors.black,
        // ✅ 关键：覆盖所有状态的 overlayColor 为透明
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return Colors.transparent; // 按下时透明
          }
          if (states.contains(WidgetState.hovered)) {
            return Colors.transparent; // 悬停时透明
          }
          return Colors.transparent; // 其他状态也透明
        }),
        tabs: const [
          Tab(text: "小时榜"),
          Tab(text: "日榜"),
          Tab(text: "周榜"),
          Tab(text: "月榜"),
        ],
      ),
    );
  }

  Widget _buildRankingListView(List<RankModel> data, VoidCallback onRefresh, bool isDark) {
    if (data.isEmpty) {
      return Center(
        child: GestureDetector(
          onTap: onRefresh,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("暂无数据", style: TextStyle(color: Colors.grey)),
              SizedBox(height: 8),
              Text("点击刷新", style: TextStyle(color: Colors.blue, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    if (data.length < 3) {
      return Expanded(
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: data.length,
          itemBuilder: (context, index) {
            int diff = 0;
            if (index > 0) {
              diff = data[index - 1].score - data[index].score;
            }
            return _buildListItem(data[index], index + 1, diff, isDark);
          },
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [_buildPodiumItem(data[1], 2, isDark), _buildPodiumItem(data[0], 1, isDark), _buildPodiumItem(data[2], 3, isDark)],
          ),
        ),

        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white, // 列表背景适配
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 10, bottom: 20),
              itemCount: data.length - 3,
              itemBuilder: (context, index) {
                final item = data[index + 3];
                int diff = data[index + 2].score - item.score;
                return _buildListItem(item, index + 4, diff, isDark);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPodiumItem(RankModel item, int rank, bool isDark) {
    final bool isFirst = rank == 1;
    final double avatarSize = isFirst ? 80 : 60;
    final Color color = rank == 1 ? const Color(0xFFFFD700) : (rank == 2 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          // 🟢 修改处：添加 GestureDetector 包裹头像区域
          GestureDetector(
            onTap: () {
              print("点击了前三名用户: ${item.name}, ID: ${item.userId}");
              Map<String, dynamic> user = {"userId": item.userId};
              LiveUserProfilePopup.show(context, user);
            },
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // 1. 底层头像容器
                Container(
                  // 保持原有尺寸逻辑
                  width: avatarSize + 5,
                  height: avatarSize + 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // 🟢 关键修改1：如果有头像框，就不要显示底层的颜色边框和阴影，避免露白或超出
                    border: item.avatarFrame.isNotEmpty ? null : Border.all(color: color, width: 2),
                    boxShadow: item.avatarFrame.isNotEmpty ? [] : [BoxShadow(color: color.withOpacity(0.5), blurRadius: 10, spreadRadius: 1)],
                  ),
                  child: Padding(
                    // 🟢 关键修改2：如果有头像框，增加内边距(例如5.0)，让头像图片缩小一点，完全嵌入框的“洞”里
                    padding: EdgeInsets.all(item.avatarFrame.isNotEmpty ? 6.0 : 2.0),
                    child: CircleAvatar(backgroundImage: NetworkImage(item.avatar)),
                  ),
                ),

                // 2. 头像框 (层级在头像之上)
                if (item.avatarFrame.isNotEmpty)
                  Positioned(
                    // 🟢 关键修改3：根据框的素材情况，可能需要调整这个数值
                    // 如果框比较厚，可以设为 -8 或 -10，让框显得更大，完全包住头像
                    top: 0,
                    left: -4,
                    right: -1,
                    bottom: 0,
                    child: Image.network(
                      item.avatarFrame,
                      fit: BoxFit.contain, // 确保框按比例缩放
                    ),
                  ),

                // 3. 排名标签
                Positioned(
                  bottom: -10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                      // 可以给标签加个小描边，防止和头像框混在一起
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: Text(
                      rank.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 85, // 根据你的头像大小调整这个宽度，例如 avatarSize + 20
            child: Text(
              item.name,
              textAlign: TextAlign.center, // 名字居中显示
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis, // 必须配合 width 才会生效
            ),
          ),
          const SizedBox(height: 4),
          LevelBadge(level: item.level, monthLevel: item.monthLevel, showConsumption: true),
          const SizedBox(height: 4),
          Text("${_formatScore(item.score)} 贡献", style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildListItem(RankModel item, int rank, int diff, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              "$rank",
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600], // 排名数字适配
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),

          // 🟢 修改处：添加 GestureDetector 包裹列表头像
          GestureDetector(
            onTap: () {
              print("点击了列表用户: ${item.name}, ID: ${item.userId}");
              Map<String, dynamic> user = {"userId": item.userId};
              LiveUserProfilePopup.show(context, user);
            },
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                CircleAvatar(radius: 24, backgroundImage: NetworkImage(item.avatar)),
                if (item.avatarFrame.isNotEmpty)
                  Positioned(top: -4, left: -4, right: -4, bottom: -4, child: Image.network(item.avatarFrame, fit: BoxFit.contain)),
              ],
            ),
          ),

          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87, // 名字适配
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    LevelBadge(level: item.level, monthLevel: item.monthLevel, showConsumption: true),
                    const SizedBox(width: 6),
                    if (rank > 1) Text("距上一名 $diff", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          Text(
            _formatScore(item.score),
            style: const TextStyle(color: Color(0xFFFF5722), fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildMyRankBar(MyRankInfo? myInfo, bool isDark) {
    String rankStr = "50+";
    String scoreStr = "0";
    String descStr = "暂无数据";

    if (myInfo != null) {
      scoreStr = _formatScore(myInfo.score);
      if (myInfo.rank > 0) {
        rankStr = "${myInfo.rank}";
        if (myInfo.rank == 1) {
          descStr = "恭喜！您是榜首";
        } else {
          descStr = "距上一名差 ${_formatScore(myInfo.gap)}";
        }
      } else {
        rankStr = "50+";
        descStr = "差 ${_formatScore(myInfo.gap)} 上榜";
      }
    }
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white, // 底部栏背景适配
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1), // 阴影适配
            offset: const Offset(0, -2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            rankStr, // 🟢 动态排名
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey, // 排名文字适配
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(radius: 20, backgroundImage: NetworkImage(UserStore.to.avatar)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  UserStore.to.nickname,
                  style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black), // 昵称颜色适配
                ),
                Text(descStr, style: const TextStyle(color: Colors.grey, fontSize: 12)), // 🟢 动态描述
              ],
            ),
          ),
          if (1 == 2)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFF5722), Color(0xFFFF8A65)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "去冲榜",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}

class RankModel {
  final String userId; // 🟢 5. 新增 userId 用于匹配
  final String name;
  final String avatar;
  final String avatarFrame;
  final int level;
  final int monthLevel;
  final int score;
  final int rank;

  RankModel({
    required this.userId,
    required this.name,
    required this.avatar,
    required this.score,
    required this.rank,
    required this.avatarFrame,
    required this.level,
    required this.monthLevel,
  });

  factory RankModel.fromJson(Map<String, dynamic> json) {
    return RankModel(
      // 🟢 映射后端字段
      userId: (json['senderId'] ?? 0).toString(),
      name: json['senderName'] ?? "未知用户",
      avatar: json['senderAvatar'] ?? "https://api.multiavatar.com/default.png",
      score: json['totalScore'] ?? 0,
      rank: json['rank'] ?? 0,
      avatarFrame: json['avatarFrame'] ?? "",
      level: json['level'] ?? 0,
      monthLevel: json['monthLevel'] ?? 0,
    );
  }
}

class RankingTabLoader extends StatefulWidget {
  final int type;
  final Widget Function(List<RankModel>, Future<void> Function()) builder;

  // 🟢 6. 定义回调函数
  final Function(MyRankInfo) onLoaded;

  const RankingTabLoader({super.key, required this.type, required this.builder, required this.onLoaded});

  @override
  State<RankingTabLoader> createState() => _RankingTabLoaderState();
}

class _RankingTabLoaderState extends State<RankingTabLoader> with AutomaticKeepAliveClientMixin {
  List<RankModel> _dataList = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      if (!mounted) return;
      if (_dataList.isEmpty) {
        setState(() => _isLoading = true);
      }

      var results = await Future.wait([
        HttpUtil().get('/api/giftLog/ranking', params: {"type": widget.type}),
        HttpUtil().get('/api/giftLog/mine', params: {"type": widget.type}),
      ]);

      List<dynamic> rawList = results[0] ?? [];
      List<RankModel> list = rawList.map((e) => RankModel.fromJson(e)).toList();

      Map<String, dynamic> myData = results[1] ?? {};
      int myScore = myData['score'] ?? 0;

      // 🟢 7. 核心计算逻辑：使用 UserStore 进行 ID 匹配
      String myUserId = UserStore.to.userId;

      int myRank = 0;
      int gap = 0;

      // 使用 userId 匹配
      int index = list.indexWhere((e) => e.userId == myUserId);

      if (index != -1) {
        myRank = index + 1;
        if (index > 0) {
          gap = list[index - 1].score - myScore;
        } else {
          gap = 0;
        }
        myScore = list[index].score;
      } else {
        myRank = 0;
        if (list.isNotEmpty) {
          int thresholdScore = list.last.score;
          gap = thresholdScore - myScore;
          if (gap < 0) gap = 0;
        } else {
          gap = 0;
        }
      }

      if (mounted) {
        // 🟢 8. 触发回调
        widget.onLoaded(MyRankInfo(score: myScore, rank: myRank, gap: gap));

        setState(() {
          _dataList = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint("Fetch ranking error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(onRefresh: _fetchData, color: const Color(0xFFFFD700), child: widget.builder(_dataList, _fetchData));
  }
}
