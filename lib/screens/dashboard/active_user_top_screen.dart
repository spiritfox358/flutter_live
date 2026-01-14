import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_live/tools/DateTool.dart';

class ActiveUserTopScreen extends StatefulWidget {
  const ActiveUserTopScreen({super.key});

  @override
  State<ActiveUserTopScreen> createState() => _ActiveUserTopScreenState();
}

class _ActiveUserTopScreenState extends State<ActiveUserTopScreen> {
  // ================= 配置区域 =================
  final String _apiUrl = "http://101.200.77.1:8888/active/top30";
  // ===========================================

  List<TopUser> _users = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final response = await Dio().get(_apiUrl);

      if (response.statusCode == 200) {
        final List<dynamic> dataList = response.data as List;

        // 【关键逻辑】前端按 lastLoginTime 倒序排列 (最近的时间排前面)
        dataList.sort((a, b) {
          String t1 = a['lastLoginTime'] ?? '';
          String t2 = b['lastLoginTime'] ?? '';
          return t2.compareTo(t1); // 字符串时间比较：大(晚)的排前面
        });

        // 生成排名并转换模型
        List<TopUser> parsedList = dataList.asMap().entries.map((entry) {
          int index = entry.key;
          Map<String, dynamic> json = entry.value;

          // 排名只跟时间顺序有关
          json['rank'] = index + 1;

          return TopUser.fromJson(json);
        }).toList();

        setState(() {
          _users = parsedList;
          _isLoading = false;
        });
      } else {
        throw Exception("服务器状态码异常: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "请求失败，已显示演示数据。\n详细: $e";
        _users = _generateFallbackMockData();
      });
      debugPrint("Dio Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black87;
    final subTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("实时登录榜 Top 30", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        centerTitle: true,
        backgroundColor: cardColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() { _isLoading = true; _errorMessage = null; });
              _fetchData();
            },
          )
        ],
      ),
      body: _buildBody(cardColor, textColor, subTextColor, isDark),
    );
  }

  Widget _buildBody(Color cardColor, Color textColor, Color subTextColor, bool isDark) {
    if (_isLoading) return Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor));

    return CustomScrollView(
      slivers: [
        if (_errorMessage != null)
          SliverToBoxAdapter(
            child: Container(color: Colors.orange.withOpacity(0.1), padding: const EdgeInsets.all(8), child: Text("接口异常，显示演示数据", style: TextStyle(color: Colors.orange, fontSize: 12), textAlign: TextAlign.center)),
          ),

        // 1. 领奖台 (前三名)
        SliverToBoxAdapter(
          child: _buildPodiumSection(_users.take(3).toList(), isDark, textColor, subTextColor),
        ),

        // 2. 列表标题
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text("完整榜单", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                const Spacer(),
                Text("按登录时间排序", style: TextStyle(fontSize: 12, color: subTextColor)),
              ],
            ),
          ),
        ),

        // 3. 剩余列表 (4-30名)
        SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              if (index + 3 >= _users.length) return null;
              final user = _users[index + 3];
              return _buildListItem(user, cardColor, textColor, subTextColor, isDark);
            },
            childCount: (_users.length > 3) ? _users.length - 3 : 0,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  // --- 领奖台 ---
  Widget _buildPodiumSection(List<TopUser> top3, bool isDark, Color textColor, Color subTextColor) {
    if (top3.length < 3) return const SizedBox();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark ? [const Color(0xFF1E2A45), const Color(0xFF151B2D)] : [Colors.blue.shade50, Colors.white],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 第2名
          Expanded(child: _buildPodiumItem(top3[1], 2, 80, const Color(0xFFC0C0C0), textColor, subTextColor)),
          const SizedBox(width: 8),
          // 第1名
          Expanded(child: _buildPodiumItem(top3[0], 1, 100, const Color(0xFFFFD700), textColor, subTextColor)),
          const SizedBox(width: 8),
          // 第3名
          Expanded(child: _buildPodiumItem(top3[2], 3, 80, const Color(0xFFCD7F32), textColor, subTextColor)),
        ],
      ),
    );
  }

  Widget _buildPodiumItem(TopUser user, int rank, double avatarSize, Color medalColor, Color textColor, Color subTextColor) {
    bool isChampion = rank == 1;
    // 使用格式化后的时间
    String timeStr = DateTool.formatISO(user.loginTime);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: medalColor, width: 3)),
              child: CircleAvatar(radius: avatarSize / 2, backgroundImage: NetworkImage(user.avatar)),
            ),
            Positioned(
              top: isChampion ? -28 : -20,
              child: Icon(Icons.emoji_events, color: medalColor, size: isChampion ? 32 : 24),
            ),
            Positioned(
              bottom: -10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(color: medalColor, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))]),
                child: Text("$rank", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(user.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: isChampion ? 15 : 13, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        // 这里原本是分数，现在改成时间，字体稍微调小
        Text(timeStr, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: medalColor)),
      ],
    );
  }

  // --- 列表项 ---
  Widget _buildListItem(TopUser user, Color cardColor, Color textColor, Color subTextColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[100]!),
      ),
      child: Row(
        children: [
          SizedBox(width: 30, child: Text("${user.rank}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: subTextColor, fontStyle: FontStyle.italic), textAlign: TextAlign.center)),
          const SizedBox(width: 12),
          CircleAvatar(radius: 20, backgroundImage: NetworkImage(user.avatar)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: subTextColor),
                    const SizedBox(width: 4),
                    Text(DateTool.formatISO(user.loginTime), style: TextStyle(fontSize: 12, color: subTextColor)),
                  ],
                ),
              ],
            ),
          ),
          // 右侧显示 IP
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(user.lastLoginIp, style: TextStyle(fontSize: 11, color: subTextColor)),
              Text("ID: ${user.userNo}", style: TextStyle(fontSize: 10, color: subTextColor.withOpacity(0.5))),
            ],
          )
        ],
      ),
    );
  }

  // --- 兜底数据 ---
  List<TopUser> _generateFallbackMockData() {
    return List.generate(30, (index) {
      // 模拟时间递减
      DateTime now = DateTime.now().subtract(Duration(minutes: index * 5));
      return TopUser(
        rank: index + 1,
        name: "演示用户 ${index + 1}",
        userNo: "mock_00$index",
        avatar: "https://api.dicebear.com/7.x/avataaars/png?seed=mock_$index",
        loginTime: now.toIso8601String(),
        lastLoginIp: "192.168.1.${index + 10}",
      );
    });
  }
}

// ================= 模型 (已移除 Score 和 Trend) =================

class TopUser {
  final int rank;
  final String name;
  final String userNo;
  final String avatar;
  final String loginTime;
  final String lastLoginIp;

  TopUser({
    required this.rank,
    required this.name,
    required this.userNo,
    required this.avatar,
    required this.loginTime,
    required this.lastLoginIp,
  });

  factory TopUser.fromJson(Map<String, dynamic> json) {
    return TopUser(
      rank: json['rank'] ?? 0,
      name: json['fullName'] ?? '未知用户',
      userNo: json['userNo'] ?? '',
      avatar: json['headImg'] ?? 'https://api.dicebear.com/7.x/avataaars/png?seed=default',
      loginTime: json['lastLoginTime'] ?? '',
      lastLoginIp: json['lastLoginIp'] ?? '未知IP',
    );
  }
}