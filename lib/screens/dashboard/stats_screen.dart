import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _selectedStudentIndex = 0;
  // 移除手动开关 _isDarkMode

  // 1. 模拟数据
  late final List<Map<String, dynamic>> _studentData = List.generate(10, (index) => {
    'name': '学生 ${index + 1}',
    'avatar': 'https://api.dicebear.com/7.x/avataaars/png?seed=${index + 999}',
    'weeklySummary': "本周表现${index % 2 == 0 ? '稳步上升' : '存在波动'}，建议关注重点学科。",
    'stats': {
      'course': '${80 + (index * 5)}',
      'unsubmitted': '${(index % 4) * 3}'
    },
    'trendSpots': List.generate(7, (i) => FlSpot(i.toDouble(), 2.0 + (index % 3) + (i % 2) * 2.5)),
    'completionTrajectory': List.generate(7, (i) => 5.0 + (index % 5) + i * 2.0),
    'suggestions': [
      {"type": "习惯", "title": "作息提醒", "content": "建议保证充足睡眠。", "stars": 5, "color": Colors.orange},
      {"type": "学习", "title": "复习建议", "content": "建议加强错题巩固。", "stars": 4, "color": Colors.blue}
    ]
  });

  @override
  Widget build(BuildContext context) {
    // 1. 获取系统主题配置
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 2. 自动适配颜色
    final bgColor = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black87;
    final subTextColor = theme.textTheme.bodyMedium?.color ?? Colors.black54;

    var currentData = _studentData[_selectedStudentIndex];

    final List<double> trajectory = (currentData['completionTrajectory'] as List)
        .map((e) => (e as num).toDouble())
        .toList();

    double totalTasks = trajectory.fold(0, (p, c) => p + c);
    bool isBadgeUnlocked = totalTasks >= 75;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('学情全景分析', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: cardColor,
        elevation: 0,
        centerTitle: true,
        // 移除 actions (手动切换按钮)
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildStudentSelector(subTextColor),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("本周学习挑战", textColor),
                  _buildMedalSystem(isBadgeUnlocked, totalTasks, cardColor, textColor, subTextColor),

                  const SizedBox(height: 24),

                  // --- 核心指标卡片 ---
                  _buildStatsGrid(currentData['stats'], cardColor, textColor, subTextColor),

                  const SizedBox(height: 24),

                  // --- 活跃趋势图 ---
                  _buildSectionTitle("${currentData['name']} 活跃趋势", textColor),
                  _buildYAxisLegend("Y轴说明：0-3 (低活跃), 4-6 (标准), 7+ (高活跃)"),
                  _buildLineChart(
                      Key('trend_$_selectedStudentIndex'),
                      currentData['trendSpots'],
                      Colors.cyan,
                      cardColor
                  ),

                  const SizedBox(height: 24),

                  // --- 任务轨迹图 ---
                  _buildSectionTitle("任务完成轨迹", textColor),
                  _buildYAxisLegend("Y轴说明：每日实际完成的任务/作业数量"),
                  _buildLineChart(
                    Key('traj_$_selectedStudentIndex'),
                    List.generate(7, (i) => FlSpot(i.toDouble(), trajectory[i])),
                    Colors.orangeAccent,
                    cardColor,
                  ),

                  const SizedBox(height: 20),
                  _buildSummaryCard(currentData['weeklySummary'], cardColor, textColor, subTextColor),

                  const SizedBox(height: 24),
                  _buildSectionTitle("AI 辅助教学建议", textColor),
                  ... (currentData['suggestions'] as List).map((s) => _buildSuggestionCard(s, cardColor, textColor, subTextColor)),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 指标网格 ---
  Widget _buildStatsGrid(Map<String, String> stats, Color cardColor, Color textColor, Color subTextColor) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 0.95, // 保持之前修复的高度比例
      children: [
        _buildEnhancedStatCard("课程总量", stats['course']!, Icons.auto_stories, const Color(0xFF42A5F5), cardColor, textColor, subTextColor, 150),
        _buildEnhancedStatCard("未交作业", stats['unsubmitted']!, Icons.assignment_late, const Color(0xFFEF5350), cardColor, textColor, subTextColor, 10),
      ],
    );
  }

  // --- 卡片组件 ---
  Widget _buildEnhancedStatCard(String title, String value, IconData icon, Color themeColor, Color cardColor, Color textColor, Color subTextColor, double target) {
    double currentVal = double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    double progress = (currentVal / target).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -15,
            bottom: -15,
            child: Opacity(
              opacity: 0.1,
              child: SizedBox(
                width: 90,
                height: 90,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 12,
                  color: themeColor,
                  backgroundColor: themeColor.withOpacity(0.2),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: themeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: themeColor, size: 24),
                ),
                const Spacer(),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor)),
                ),
                const SizedBox(height: 4),
                Text(title, style: TextStyle(fontSize: 13, color: subTextColor, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 图表组件 ---
  Widget _buildLineChart(Key key, List<FlSpot> spots, Color themeColor, Color bgColor) {
    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: LineChart(
        key: key,
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.white10, strokeWidth: 0.5)),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Text(['一','二','三','四','五','六','日'][v.toInt()%7], style: const TextStyle(color: Colors.grey, fontSize: 10)))),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, m) => Text('${v.toInt()}', style: const TextStyle(color: Colors.grey, fontSize: 10)))),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: themeColor,
              barWidth: 4,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [themeColor.withOpacity(0.3), themeColor.withOpacity(0.0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
            )
          ],
        ),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      ),
    );
  }

  // --- 其他组件 ---
  Widget _buildStudentSelector(Color subTextColor) {
    return Container(
      height: 110, padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal, itemCount: _studentData.length, padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (context, index) {
          bool isSelected = _selectedStudentIndex == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedStudentIndex = index),
            child: Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Column(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isSelected ? Colors.orange : Colors.transparent, width: 2)),
                  child: CircleAvatar(radius: 26, backgroundImage: NetworkImage(_studentData[index]['avatar'])),
                ),
                const SizedBox(height: 6),
                Text(_studentData[index]['name'], style: TextStyle(fontSize: 12, color: isSelected ? Colors.orange : subTextColor)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMedalSystem(bool isUnlocked, double total, Color cardColor, Color textColor, Color subTextColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Icon(Icons.workspace_premium, size: 60, color: isUnlocked ? Colors.amber : Colors.grey.withOpacity(0.2)),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isUnlocked ? "巅峰学霸勋章已解锁！" : "挑战任务：累计完成 75", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: (total / 75).clamp(0, 1), backgroundColor: Colors.black12, color: isUnlocked ? Colors.amber : Colors.orangeAccent, minHeight: 6, borderRadius: BorderRadius.circular(10)),
                const SizedBox(height: 8),
                Text("当前进度: ${total.toInt()} / 75", style: TextStyle(color: subTextColor, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(Map<String, dynamic> data, Color cardColor, Color textColor, Color subTextColor) => Container(
    margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(data['type'], style: TextStyle(color: data['color'], fontWeight: FontWeight.bold, fontSize: 12)), Row(children: List.generate(5, (i) => Icon(Icons.star, size: 14, color: i < data['stars'] ? Colors.amber : Colors.grey[400])))]),
      const SizedBox(height: 8),
      Text(data['title'], style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
      const SizedBox(height: 4),
      Text(data['content'], style: TextStyle(fontSize: 12, color: subTextColor, height: 1.4)),
    ]),
  );

  Widget _buildYAxisLegend(String text) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(8)), child: Text(text, style: const TextStyle(fontSize: 10, color: Colors.grey)));
  Widget _buildSectionTitle(String title, Color color) => Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)));
  Widget _buildSummaryCard(String summary, Color bgColor, Color textColor, Color subTextColor) => Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(15)), child: Text(summary, style: TextStyle(fontSize: 13, color: subTextColor)));
}