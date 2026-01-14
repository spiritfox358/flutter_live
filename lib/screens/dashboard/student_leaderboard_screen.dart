import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;

// ==================== 1. 数据模型与模拟数据 ====================

class Student {
  final String name;
  final int rank;
  final double totalScore;
  final String avatarLabel;
  final List<double> performanceRadar; // 德智体美劳
  final List<FlSpot> trendData; // 排名趋势

  Student({
    required this.name,
    required this.rank,
    required this.totalScore,
    required this.performanceRadar,
    required this.trendData,
  }) : avatarLabel = name.substring(0, 1);
}

List<Student> getMockStudents() {
  final random = math.Random();
  return List.generate(20, (index) {
    int rank = index + 1;
    double baseScore = 95 - (index * 2.5);
    double score = baseScore + random.nextDouble() * 5;

    return Student(
      name: ['张伟', '李娜', '王俊凯', '刘亦菲', '陈易烊', '杨紫', '赵丽颖', '黄晓明', '周杰伦', '林俊杰', '王力宏', '邓紫棋', '陈奕迅', '李荣浩', '薛之谦', '华晨宇', '毛不易', '周深', '张杰', '李健'][index],
      rank: rank,
      totalScore: score > 100 ? 100 : score,
      performanceRadar: List.generate(5, (_) => (80 - rank * 1.5) + random.nextDouble() * 20).map((e) => e > 100 ? 100.0 : e).toList(),
      trendData: List.generate(6, (i) {
        double yValue = rank + (random.nextDouble() * 6 - 3);
        if (yValue < 1) yValue = 1;
        return FlSpot(i.toDouble(), yValue);
      }),
    );
  });
}

// ==================== 2. 主页面 Widget ====================

class StudentLeaderboardPage extends StatefulWidget {
  const StudentLeaderboardPage({super.key});

  @override
  State<StudentLeaderboardPage> createState() => _StudentLeaderboardPageState();
}

class _StudentLeaderboardPageState extends State<StudentLeaderboardPage> {
  late List<Student> students;

  @override
  void initState() {
    super.initState();
    students = getMockStudents();
  }

  @override
  Widget build(BuildContext context) {
    // 1. 获取系统主题
    final currentTheme = Theme.of(context);
    final textColor = currentTheme.textTheme.bodyLarge?.color ?? Colors.black87;

    return Scaffold(
      backgroundColor: currentTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('学生表现风云榜', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: currentTheme.appBarTheme.backgroundColor ?? currentTheme.cardColor,
        foregroundColor: currentTheme.appBarTheme.foregroundColor ?? textColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('卓越之星 (Top 3)', textColor),
            const SizedBox(height: 16),
            _buildTopThreeCards(context, currentTheme),
            const SizedBox(height: 30),

            _buildSectionHeader('多维数据分析', textColor),
            const SizedBox(height: 16),

            _ChartCard(
              title: '学业综合得分 (Top 7)',
              theme: currentTheme,
              chart: _buildBarChart(textColor),
            ),
            const SizedBox(height: 16),

            _ChartCard(
              title: '五维能力模型 (平均 vs 第一名)',
              theme: currentTheme,
              chart: _buildRadarChart(textColor, students[0], students),
              height: 300,
            ),
            const SizedBox(height: 16),

            _ChartCard(
              title: '近期排名进步趋势 (Top 3)',
              theme: currentTheme,
              chart: _buildLineChart(textColor, students.sublist(0, 3)),
            ),

            const SizedBox(height: 30),
            _buildSectionHeader('完整排行榜', textColor),
            const SizedBox(height: 10),
            _buildFullList(currentTheme),
          ],
        ),
      ),
    );
  }

  // ==================== 3. 组件构建 Helper 方法 ====================

  Widget _buildSectionHeader(String title, Color color) {
    return Text(
      title,
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
    );
  }

  Widget _buildTopThreeCards(BuildContext context, ThemeData theme) {
    final top3 = students.sublist(0, 3);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildRankCard(context, top3[1], 2, Colors.blueGrey[300]!, theme), // 银牌
        _buildRankCard(context, top3[0], 1, Colors.amber, theme),          // 金牌
        _buildRankCard(context, top3[2], 3, Colors.brown[300]!, theme),    // 铜牌
      ],
    );
  }

  Widget _buildRankCard(BuildContext context, Student student, int rank, Color medalColor, ThemeData theme) {
    final isFirst = rank == 1;
    final avatarSize = isFirst ? 36.0 : 30.0;

    final isDark = theme.brightness == Brightness.dark;
    final nameColor = theme.textTheme.bodyLarge?.color;
    final scoreColor = theme.textTheme.bodySmall?.color;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4)
                )
              ],
              border: Border.all(color: medalColor.withOpacity(0.5), width: isFirst ? 2 : 1)
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events, color: medalColor, size: isFirst ? 32 : 24),
              const SizedBox(height: 8),
              CircleAvatar(
                radius: avatarSize,
                backgroundColor: medalColor.withOpacity(0.2),
                child: Text(student.avatarLabel, style: TextStyle(color: medalColor, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
              Text(
                student.name,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: nameColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                  '${student.totalScore.toStringAsFixed(1)}分',
                  style: TextStyle(fontSize: 12, color: scoreColor)
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullList(ThemeData theme) {
    // 获取当前主题的文字颜色（亮色模式为黑，深色模式为白）
    final textColor = theme.textTheme.bodyLarge?.color;

    return Card(
      color: theme.cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: students.length,
        separatorBuilder: (ctx, i) => Divider(height: 1, color: theme.dividerColor),
        itemBuilder: (ctx, index) {
          final student = students[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: index < 3 ? theme.primaryColor : Colors.grey[400],
              foregroundColor: Colors.white,
              radius: 14,
              child: Text('#${student.rank}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            title: Text(student.name, style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                student.totalScore.toStringAsFixed(1),
                // 【修改点】颜色改为 textColor (亮色模式为黑，深色模式为白)
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==================== 4. 图表构建 (fl_chart) ====================

  Widget _buildBarChart(Color textColor) {
    final top7 = students.sublist(0, 7);
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 115,
        barTouchData: BarTouchData(
          enabled: false,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.transparent,
            tooltipPadding: EdgeInsets.zero,
            tooltipMargin: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                rod.toY.toStringAsFixed(1),
                TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12),
              );
            },
            rotateAngle: -90,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(top7[value.toInt()].avatarLabel, style: TextStyle(color: textColor, fontSize: 12)),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: top7.asMap().entries.map((entry) {
          final index = entry.key;
          final student = entry.value;
          final List<Color> gradientColors = index == 0
              ? [Colors.amber, Colors.orange]
              : (index < 3 ? [Colors.blue, Colors.lightBlueAccent] : [Colors.indigo.shade300, Colors.blue.shade200]);

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                  toY: student.totalScore,
                  gradient: LinearGradient(colors: gradientColors, begin: Alignment.bottomCenter, end: Alignment.topCenter),
                  width: 16,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  backDrawRodData: BackgroundBarChartRodData(show: true, toY: 100, color: textColor.withOpacity(0.05))
              )
            ],
            showingTooltipIndicators: [0],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRadarChart(Color textColor, Student topStudent, List<Student> allStudents) {
    List<double> avgPerformance = List.filled(5, 0.0);
    for (var s in allStudents) {
      for (int i = 0; i < 5; i++) {
        avgPerformance[i] += s.performanceRadar[i];
      }
    }
    avgPerformance = avgPerformance.map((e) => e / allStudents.length).toList();

    const dimensions = ['德', '智', '体', '美', '劳'];
    final gridColor = textColor.withOpacity(0.2);
    final axisTextStyle = TextStyle(color: textColor, fontSize: 10);

    return RadarChart(
      RadarChartData(
        dataSets: [
          RadarDataSet(
            fillColor: Colors.grey.withOpacity(0.2),
            borderColor: Colors.grey,
            entryRadius: 2,
            dataEntries: avgPerformance.map((e) => RadarEntry(value: e)).toList(),
            borderWidth: 1.5,
          ),
          RadarDataSet(
            fillColor: Colors.indigo.withOpacity(0.4),
            borderColor: Colors.indigo,
            entryRadius: 3,
            dataEntries: topStudent.performanceRadar.map((e) => RadarEntry(value: e)).toList(),
            borderWidth: 2,
          ),
        ],
        radarBackgroundColor: Colors.transparent,
        borderData: FlBorderData(show: false),
        radarBorderData: const BorderSide(color: Colors.transparent),
        titlePositionPercentageOffset: 0.2,
        titleTextStyle: axisTextStyle,
        getTitle: (index, angle) {
          return RadarChartTitle(text: dimensions[index], angle: angle);
        },
        tickCount: 4,
        ticksTextStyle: const TextStyle(color: Colors.transparent),
        gridBorderData: BorderSide(color: gridColor, width: 1),
        tickBorderData: BorderSide(color: gridColor, width: 1),
      ),
    );
  }

  Widget _buildLineChart(Color textColor, List<Student> top3Students) {
    final lineColors = [Colors.amber, Colors.blueGrey, Colors.brown];

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 5,
          getDrawingHorizontalLine: (value) => FlLine(color: textColor.withOpacity(0.1), strokeWidth: 1),
          getDrawingVerticalLine: (value) => FlLine(color: textColor.withOpacity(0.1), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('T-${5 - value.toInt()}', style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 10)),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 5,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(value.toInt().toString(), style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 10));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0, maxX: 5,
        minY: 0, maxY: 25,
        lineBarsData: top3Students.asMap().entries.map((entry) {
          final index = entry.key;
          final student = entry.value;
          return LineChartBarData(
            spots: student.trendData,
            isCurved: true,
            color: lineColors[index],
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(radius: 4, color: barData.color!, strokeWidth: 2, strokeColor: Colors.white);
            }),
            belowBarData: BarAreaData(show: false),
          );
        }).toList(),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget chart;
  final ThemeData theme;
  final double height;

  const _ChartCard({
    required this.title,
    required this.chart,
    required this.theme,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      color: theme.cardColor,
      elevation: 4,
      shadowColor: Colors.black.withOpacity(isDark ? 0.5 : 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge!.color!.withOpacity(0.8))),
            const SizedBox(height: 20),
            SizedBox(
              height: height,
              child: chart,
            ),
          ],
        ),
      ),
    );
  }
}