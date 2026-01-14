import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ActiveUserScreen extends StatefulWidget {
  const ActiveUserScreen({super.key});

  @override
  State<ActiveUserScreen> createState() => _ActiveUserScreenState();
}

class _ActiveUserScreenState extends State<ActiveUserScreen> {
  int _selectedFilterIndex = 0;
  final List<String> _filters = ["全部", "在线", "学生", "老师"];

  // 模拟用户活跃数据
  late List<UserActivity> _activities;

  @override
  void initState() {
    super.initState();
    _activities = _getMockData();
  }

  List<UserActivity> _getMockData() {
    return [
      UserActivity(
        name: "张伟",
        role: "学生",
        avatar: "https://api.dicebear.com/7.x/avataaars/png?seed=zhang",
        status: UserStatus.online,
        lastActiveTime: "刚刚",
        device: "iPhone 14 Pro",
        action: "正在观看《高一数学必修一》",
        location: "图书馆",
      ),
      UserActivity(
        name: "李娜老师",
        role: "老师",
        avatar: "https://api.dicebear.com/7.x/avataaars/png?seed=li",
        status: UserStatus.online,
        lastActiveTime: "2分钟前",
        device: "MacBook Pro",
        action: "正在批改作业",
        location: "教研室",
      ),
      UserActivity(
        name: "王俊凯",
        role: "学生",
        avatar: "https://api.dicebear.com/7.x/avataaars/png?seed=wang",
        status: UserStatus.away,
        lastActiveTime: "15分钟前",
        device: "Android Pad",
        action: "挂机中",
        location: "宿舍",
      ),
      UserActivity(
        name: "陈子涵",
        role: "学生",
        avatar: "https://api.dicebear.com/7.x/avataaars/png?seed=chen",
        status: UserStatus.offline,
        lastActiveTime: "3小时前",
        device: "Windows PC",
        action: "提交了试卷",
        location: "校外",
      ),
      UserActivity(
        name: "教务处-王主任",
        role: "管理员",
        avatar: "https://api.dicebear.com/7.x/initials/png?seed=Admin",
        status: UserStatus.online,
        lastActiveTime: "刚刚",
        device: "Web Admin",
        action: "查看后台报表",
        location: "行政楼",
      ),
      UserActivity(
        name: "刘亦菲",
        role: "学生",
        avatar: "https://api.dicebear.com/7.x/avataaars/png?seed=liu",
        status: UserStatus.offline,
        lastActiveTime: "昨天 23:10",
        device: "iPad Air",
        action: "下载了课件",
        location: "宿舍",
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // 主题适配
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black87;
    final subTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("实时活跃监控", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        centerTitle: true,
        backgroundColor: cardColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () {}, tooltip: "刷新数据"),
        ],
      ),
      body: Column(
        children: [
          // 1. 顶部 KPI 数据概览
          Container(
            padding: const EdgeInsets.all(16),
            color: cardColor,
            child: Row(
              children: [
                _buildKpiItem("当前在线", "1,248", Colors.green, subTextColor, textColor),
                _buildVerticalDivider(isDark),
                _buildKpiItem("今日活跃 (DAU)", "8,502", Colors.blue, subTextColor, textColor),
                _buildVerticalDivider(isDark),
                _buildKpiItem("平均停留时长", "42m", Colors.orange, subTextColor, textColor),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 2. 活跃趋势图 (Mini Chart)
          Container(
            height: 180,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("近24小时流量趋势", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 12),
                Expanded(child: _buildTrendChart(primaryColor, isDark)),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 3. 筛选栏
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (c, i) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final isSelected = _selectedFilterIndex == index;
                return ChoiceChip(
                  label: Text(_filters[index]),
                  selected: isSelected,
                  onSelected: (v) => setState(() => _selectedFilterIndex = index),
                  selectedColor: primaryColor.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: isSelected ? primaryColor : subTextColor,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  showCheckmark: false,
                );
              },
            ),
          ),

          // 4. 用户列表
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _activities.length,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _buildUserCard(_activities[index], cardColor, textColor, subTextColor, isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(UserActivity user, Color cardColor, Color textColor, Color subTextColor, bool isDark) {
    Color statusColor;
    String statusText;
    switch (user.status) {
      case UserStatus.online: statusColor = Colors.green; statusText = "在线"; break;
      case UserStatus.away: statusColor = Colors.orange; statusText = "离开"; break;
      case UserStatus.offline: statusColor = Colors.grey; statusText = "离线"; break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[100]!),
      ),
      child: Row(
        children: [
          // 头像 + 在线状态点
          Stack(
            children: [
              CircleAvatar(radius: 24, backgroundImage: NetworkImage(user.avatar)),
              Positioned(
                right: 0, bottom: 0,
                child: Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: cardColor, width: 2),
                  ),
                ),
              )
            ],
          ),
          const SizedBox(width: 12),

          // 中间信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(user.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(user.role, style: const TextStyle(fontSize: 10, color: Colors.blue)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user.action,
                  style: TextStyle(fontSize: 12, color: subTextColor),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(user.device.contains("Phone") ? Icons.phone_iphone : Icons.laptop_mac, size: 12, color: subTextColor),
                    const SizedBox(width: 4),
                    Text(user.device, style: TextStyle(fontSize: 10, color: subTextColor)),
                    const SizedBox(width: 8),
                    const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
                    Text(user.location, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                )
              ],
            ),
          ),

          // 右侧时间
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(user.lastActiveTime, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
              const SizedBox(height: 4),
              Text(statusText, style: TextStyle(fontSize: 11, color: statusColor)),
            ],
          )
        ],
      ),
    );
  }

  // --- 辅助组件 ---

  Widget _buildKpiItem(String label, String value, Color color, Color subColor, Color mainColor) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: mainColor)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 11, color: subColor)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildVerticalDivider(bool isDark) {
    return Container(
      width: 1, height: 30,
      color: isDark ? Colors.white10 : Colors.grey[200],
    );
  }

  Widget _buildTrendChart(Color color, bool isDark) {
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                if (val % 2 != 0) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text("${val.toInt()}:00", style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38)),
                );
              },
              interval: 1,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              const FlSpot(0, 10), const FlSpot(2, 30), const FlSpot(4, 15),
              const FlSpot(6, 60), const FlSpot(8, 80), const FlSpot(10, 40),
              const FlSpot(12, 55),
            ],
            isCurved: true,
            color: color,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [color.withOpacity(0.3), color.withOpacity(0.0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= 数据模型 =================

enum UserStatus { online, away, offline }

class UserActivity {
  final String name;
  final String role;
  final String avatar;
  final UserStatus status;
  final String lastActiveTime;
  final String device;
  final String action;
  final String location;

  UserActivity({
    required this.name,
    required this.role,
    required this.avatar,
    required this.status,
    required this.lastActiveTime,
    required this.device,
    required this.action,
    required this.location,
  });
}