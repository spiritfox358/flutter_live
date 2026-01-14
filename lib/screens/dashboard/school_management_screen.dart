import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class SchoolManagementScreen extends StatefulWidget {
  const SchoolManagementScreen({super.key});

  @override
  State<SchoolManagementScreen> createState() => _SchoolManagementScreenState();
}

class _SchoolManagementScreenState extends State<SchoolManagementScreen> {
  // 模拟数据：营收趋势
  final List<FlSpot> _revenueSpots = [
    const FlSpot(0, 30), const FlSpot(1, 45), const FlSpot(2, 40),
    const FlSpot(3, 60), const FlSpot(4, 55), const FlSpot(5, 75), const FlSpot(6, 90)
  ];

  // 模拟数据：风险预警
  final List<Map<String, dynamic>> _alerts = [
    {'title': '退费申请待审批', 'count': 2, 'level': 'High', 'desc': '家长：张子轩 (钢琴课)'},
    {'title': '低出勤率班级', 'count': 3, 'level': 'Medium', 'desc': '周六上午-少儿编程入门'},
    {'title': '课时即将耗尽学员', 'count': 15, 'level': 'Low', 'desc': '剩余课时 < 3节'},
  ];

  // 模拟数据：金牌教师榜 (按续费率)
  final List<Map<String, dynamic>> _topTeachers = [
    {'name': '李娜', 'subject': '钢琴', 'retention': 95, 'income': '¥12w'},
    {'name': '张伟', 'subject': '编程', 'retention': 92, 'income': '¥15w'},
    {'name': '王俊凯', 'subject': '声乐', 'retention': 88, 'income': '¥9w'},
  ];

  @override
  Widget build(BuildContext context) {
    // 适配主题
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Column(
          children: [
            Text("校区经营驾驶舱", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
            Text("2025年春季学期 · 第8周", style: TextStyle(fontSize: 12, color: subTextColor)),
          ],
        ),
        centerTitle: true,
        backgroundColor: cardColor,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.filter_list), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 核心 KPI 卡片 (营收、消课、招生)
            Row(
              children: [
                Expanded(child: _buildKpiCard("本月营收", "¥45.2w", "+12%", Colors.blue, isDark)),
                const SizedBox(width: 12),
                Expanded(child: _buildKpiCard("本月消课", "¥38.5w", "+5%", Colors.purple, isDark)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildKpiCard("新增学员", "42人", "-8%", Colors.orange, isDark)),
                const SizedBox(width: 12),
                Expanded(child: _buildKpiCard("在读总数", "856人", "+2%", Colors.green, isDark)),
              ],
            ),

            const SizedBox(height: 24),

            // 2. 营收趋势图
            _buildSectionTitle("营收趋势分析 (近6个月)", textColor),
            const SizedBox(height: 12),
            _buildRevenueChart(cardColor, textColor, isDark),

            const SizedBox(height: 24),

            // 3. 风险预警 (老板最关注的坏消息)
            _buildSectionTitle("经营风险预警", textColor),
            const SizedBox(height: 12),
            ..._alerts.map((alert) => _buildAlertTile(alert, cardColor, textColor, subTextColor)).toList(),

            const SizedBox(height: 24),

            // 4. 招生漏斗 (简单版)
            _buildSectionTitle("招生转化漏斗", textColor),
            const SizedBox(height: 12),
            _buildFunnelChart(cardColor, textColor),

            const SizedBox(height: 24),

            // 5. 教师贡献榜
            _buildSectionTitle("教师贡献排行榜 (续费率)", textColor),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: _topTeachers.asMap().entries.map((entry) {
                  return _buildTeacherRow(entry.value, entry.key, textColor, subTextColor, isDark);
                }).toList(),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- 组件：KPI 卡片 ---
  Widget _buildKpiCard(String title, String value, String trend, Color color, bool isDark) {
    final isPositive = trend.startsWith('+');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.15) : color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: isDark ? color.withOpacity(0.9) : color, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(isPositive ? Icons.trending_up : Icons.trending_down, size: 14, color: isPositive ? Colors.green : Colors.red),
              const SizedBox(width: 4),
              Text(trend, style: TextStyle(color: isPositive ? Colors.green : Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              Text("同比", style: TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          )
        ],
      ),
    );
  }

  // --- 组件：折线图 ---
  Widget _buildRevenueChart(Color cardColor, Color textColor, bool isDark) {
    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(12, 24, 24, 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LineChart(
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
                  return Text("${val.toInt() + 1}月", style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 10));
                },
                interval: 1,
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: _revenueSpots,
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [Colors.blue.withOpacity(0.3), Colors.blue.withOpacity(0.0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 组件：预警条目 ---
  Widget _buildAlertTile(Map<String, dynamic> alert, Color cardColor, Color textColor, Color subTextColor) {
    Color levelColor;
    if (alert['level'] == 'High') levelColor = Colors.red;
    else if (alert['level'] == 'Medium') levelColor = Colors.orange;
    else levelColor = Colors.blue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: levelColor, width: 4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: levelColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.warning_amber_rounded, color: levelColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(alert['title'], style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: levelColor, borderRadius: BorderRadius.circular(4)),
                      child: Text("${alert['count']}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(alert['desc'], style: TextStyle(color: subTextColor, fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: subTextColor),
        ],
      ),
    );
  }

  // --- 组件：漏斗图 (模拟) ---
  Widget _buildFunnelChart(Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _buildFunnelRow("咨询线索 (Leads)", "128", 1.0, Colors.blue, textColor),
          _buildFunnelRow("试听学员 (Trial)", "64", 0.7, Colors.blue.shade400, textColor),
          _buildFunnelRow("报名缴费 (Deal)", "42", 0.45, Colors.blue.shade700, textColor),
        ],
      ),
    );
  }

  Widget _buildFunnelRow(String label, String value, double widthFactor, Color color, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(label, style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.7)))),
          Expanded(
            flex: 7,
            child: Stack(
              children: [
                Container(height: 24, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(4))),
                FractionallySizedBox(
                  widthFactor: widthFactor,
                  child: Container(
                    height: 24,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                    child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 组件：教师行 ---
  Widget _buildTeacherRow(Map<String, dynamic> teacher, int index, Color textColor, Color subTextColor, bool isDark) {
    final colors = [const Color(0xFFFFD700), const Color(0xFFC0C0C0), const Color(0xFFCD7F32)];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          // 排名
          SizedBox(
            width: 24,
            child: index < 3
                ? Icon(Icons.workspace_premium, color: colors[index])
                : Text("${index + 1}", style: TextStyle(color: subTextColor, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          CircleAvatar(child: Text(teacher['name'][0]), backgroundColor: Colors.blue.withOpacity(0.1), radius: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(teacher['name'], style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                Text(teacher['subject'], style: TextStyle(fontSize: 12, color: subTextColor)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("${teacher['retention']}%", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
              Text("续费率", style: TextStyle(fontSize: 10, color: subTextColor)),
            ],
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(teacher['income'], style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 16)),
              Text("产出", style: TextStyle(fontSize: 10, color: subTextColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Row(
      children: [
        Container(width: 4, height: 16, decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}