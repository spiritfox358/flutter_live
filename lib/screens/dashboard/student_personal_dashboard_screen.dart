import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(const StudentPersonalDashboardScreen());
}

class StudentPersonalDashboardScreen extends StatelessWidget {
  const StudentPersonalDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1B1B29), // 深色背景
        cardColor: const Color(0xFF27293D), // 卡片背景
      ),
      home: const StudentDashboardPage(),
    );
  }
}

class StudentDashboardPage extends StatelessWidget {
  const StudentDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 沉浸式顶部
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const CircleAvatar(
              backgroundImage: NetworkImage('https://api.dicebear.com/7.x/pixel-art/png?seed=12'),
              // 模拟头像
              radius: 20,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Hi, 张三",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Let's learn something new!",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        // 【修改点】加上 SafeArea
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 顶部数据卡片 (带迷你折线图)
              const Text(
                "学习概况",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: "专注时长",
                      value: "2,478 m",
                      icon: Icons.timer,
                      color: const Color(0xFF2DCE89),
                      // 绿色
                      spots: const [
                        FlSpot(0, 1),
                        FlSpot(1, 3),
                        FlSpot(2, 2),
                        FlSpot(3, 4),
                        FlSpot(4, 3),
                        FlSpot(5, 5),
                      ],
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _StatCard(
                      title: "完成作业",
                      value: "12 / 15",
                      icon: Icons.task_alt,
                      color: const Color(0xFFF5365C),
                      // 红色/粉色
                      spots: const [
                        FlSpot(0, 4),
                        FlSpot(1, 3),
                        FlSpot(2, 5),
                        FlSpot(3, 1),
                        FlSpot(4, 3),
                        FlSpot(5, 4),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              // 2. 中间部分：网格布局 (圆形进度 + 列表)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左侧：圆形进度卡片 (2x2 Grid)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "课程进度",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children:  [
                            Expanded(
                              child: _CircularMetricCard(
                                title: "数学",
                                percent: 0.76,
                                color: Color(0xFFD946EF),
                              ),
                            ), // 紫色
                            SizedBox(width: 12),
                            Expanded(
                              child: _CircularMetricCard(
                                title: "物理",
                                percent: 0.30,
                                color: Color(0xFF14B8A6),
                              ),
                            ), // 青色
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children:  [
                            Expanded(
                              child: _CircularMetricCard(
                                title: "英语",
                                percent: 0.85,
                                color: Color(0xFFF97316),
                              ),
                            ), // 橙色
                            SizedBox(width: 12),
                            Expanded(
                              child: _CircularMetricCard(
                                title: "历史",
                                percent: 0.45,
                                color: Color(0xFF3B82F6),
                              ),
                            ), // 蓝色
                          ],
                        ),
                      ],
                    )
                  ),
                ],
              ),
              const SizedBox(height: 25),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 右侧：条形进度列表
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              "考试准备",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Icon(Icons.more_vert, size: 20, color: Colors.grey),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF27293D),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: const [
                              _LinearMetric(
                                label: "代数 II",
                                value: 0.7,
                                color: Color(0xFFD946EF),
                                subText: "70/100 pts",
                              ),
                              SizedBox(height: 20),
                              _LinearMetric(
                                label: "力学",
                                value: 0.5,
                                color: Color(0xFF14B8A6),
                                subText: "50/100 pts",
                              ),
                              SizedBox(height: 20),
                              _LinearMetric(
                                label: "文学作品",
                                value: 0.2,
                                color: Color(0xFF3B82F6),
                                subText: "阅读中 Ch.4",
                              ),
                              SizedBox(height: 20),
                              _LinearMetric(
                                label: "世界战争 II",
                                value: 0.9,
                                color: Color(0xFFF97316),
                                subText: "温习中",
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // 3. 底部：快速访问/同学互动
              const Text(
                "Study Buddies",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 25,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF27293D),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Group Project A",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "Due in 2 days",
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 40,
                      width: 120,
                      child: Stack(
                        children: [
                          for (int i = 0; i < 4; i++)
                            Positioned(
                              left: i * 25.0,
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFF1B1B29),
                                child: CircleAvatar(
                                  radius: 16,
                                  // 随机颜色代替图片
                                  backgroundColor: Colors
                                      .primaries[i % Colors.primaries.length],
                                  child: Text(
                                    "${i + 1}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2DCE89).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send,
                        color: Color(0xFF2DCE89),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= 封装的组件 =================

// 1. 顶部带折线图的卡片
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final List<FlSpot> spots;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.spots,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: const Color(0xFF27293D),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          // 底部迷你图表
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            height: 40,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: color,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withOpacity(0.1), // 淡淡的阴影
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 2. 中间方形的圆形进度卡片
class _CircularMetricCard extends StatelessWidget {
  final String title;
  final double percent;
  final Color color;

  const _CircularMetricCard({
    required this.title,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 140),
      decoration: BoxDecoration(
        color: const Color(0xFF27293D),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 60,
            width: 60,
            child: Stack(
              children: [
                Center(
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      value: percent,
                      strokeWidth: 6,
                      backgroundColor: Colors.grey.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    "${(percent * 100).toInt()}%",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 13, color: Colors.white70),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// 3. 右侧线性进度条
class _LinearMetric extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final String subText;

  const _LinearMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.subText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(subText, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 6,
            backgroundColor: Colors.grey.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
