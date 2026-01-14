import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class TeacherStatsScreen extends StatefulWidget {
  const TeacherStatsScreen({super.key});

  @override
  State<TeacherStatsScreen> createState() => _TeacherStatsScreenState();
}

class _TeacherStatsScreenState extends State<TeacherStatsScreen> {
  int _selectedTeacherIndex = 0;

  // Mock Data
  final List<Map<String, dynamic>> _teacherData = List.generate(10, (index) => {
    'name': 'Teacher ${index + 1}',
    'level': index < 3 ? 'Senior Lecturer' : 'Lecturer',
    'avatar': 'https://api.dicebear.com/7.x/avataaars/png?seed=${index + 50}',
    'weeklyReport': index % 2 == 0
        ? "High engagement this week. 5 new courses added, student attendance > 98%."
        : "Grading is slightly delayed. Recommended to focus on schedule management.",
    'stats': {
      'students': '${20 + index * 10}',
      'courses': '${15 + index * 2}',
      'micros': '${10 + index}',
      'rating': '4.${9 - (index % 3)}',
    },
    'chartSpots': [
      FlSpot(0, 3.0 + (index % 2)),
      FlSpot(1, 4.0 + (index % 3)),
      FlSpot(2, 5.0 + (index % 2)),
      FlSpot(3, 3.5 + (index % 4)),
      FlSpot(4, 6.0 - (index % 2)),
      FlSpot(5, 7.0 + (index % 2)),
      FlSpot(6, 6.5 - (index % 3)),
    ],
  });

  @override
  Widget build(BuildContext context) {
    // 1. Theme Awareness
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    var currentTeacher = _teacherData[_selectedTeacherIndex];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('教师教学质量评估', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: cardColor,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- Teacher Selector (Horizontal Scroll) ---
            _buildTeacherSelector(textColor, subTextColor),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Identity Card ---
                  _buildTeacherIdentityCard(currentTeacher, isDark),

                  const SizedBox(height: 24),

                  // --- Activity Chart with Legend ---
                  _buildSectionTitle("Engagement Trend", textColor),
                  const SizedBox(height: 8),
                  _buildChartLegend(textColor), // Added Legend
                  const SizedBox(height: 12),
                  _buildLineChart(currentTeacher['chartSpots'], cardColor, isDark),

                  const SizedBox(height: 24),

                  // --- Summary Box ---
                  _buildSummaryBox("Admin Feedback", currentTeacher['weeklyReport'], isDark),

                  const SizedBox(height: 24),

                  // --- Stats Grid ---
                  _buildSectionTitle("Core Metrics", textColor),
                  const SizedBox(height: 12),
                  _buildStatsGrid(currentTeacher['stats'], cardColor, textColor, subTextColor),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 1. Modern Identity Card ---
  Widget _buildTeacherIdentityCard(Map<String, dynamic> teacher, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        // Modern Gradient
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFFE65100), const Color(0xFFEF6C00)]
              : [const Color(0xFFFF9800), const Color(0xFFFFB74D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: CircleAvatar(
              radius: 32,
              backgroundImage: NetworkImage(teacher['avatar']),
              backgroundColor: Colors.grey[200],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(teacher['name'], style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)
                  ),
                  child: Text(teacher['level'], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("Score", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
              const Text("98", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  // --- 2. Chart Legend ---
  Widget _buildChartLegend(Color textColor) {
    return Row(
      children: [
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 8),
        Text("Daily Interaction Score", style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12)),
        const Spacer(),
        Text("Last 7 Days", style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 12, fontStyle: FontStyle.italic)),
      ],
    );
  }

  // --- 3. Modern Line Chart ---
  Widget _buildLineChart(List<FlSpot> spots, Color cardColor, bool isDark) {
    final gradientColors = [Colors.orange, Colors.orangeAccent];

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(16, 24, 24, 10),
      decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4))
          ]
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(color: isDark ? Colors.white10 : Colors.grey[200], strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: 1,
                  getTitlesWidget: (v, m) {
                    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                    if (v.toInt() >= 0 && v.toInt() < days.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(days[v.toInt()], style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey)),
                      );
                    }
                    return const SizedBox();
                  }
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minX: 0, maxX: 6,
          minY: 0, maxY: 8,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              gradient: const LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(radius: 4, color: Colors.white, strokeWidth: 2, strokeColor: Colors.orange);
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [Colors.orange.withOpacity(0.3), Colors.orange.withOpacity(0.0)],
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

  // --- 4. Stats Grid ---
  Widget _buildStatsGrid(Map<String, String> stats, Color cardColor, Color textColor, Color subTextColor) {
    // Icons & Colors mapping
    final items = [
      {'title': 'Total Students', 'val': stats['students'], 'icon': Icons.people_outline, 'col': Colors.blue},
      {'title': 'Courses', 'val': stats['courses'], 'icon': Icons.library_books_outlined, 'col': Colors.green},
      {'title': 'Micro-lectures', 'val': stats['micros'], 'icon': Icons.play_circle_outline, 'col': Colors.purple},
      {'title': 'Rating', 'val': stats['rating'], 'icon': Icons.star_border, 'col': Colors.amber},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.5, // Taller cards
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            // Subtle border for dark mode
            border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (item['col'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item['icon'] as IconData, color: item['col'] as Color, size: 20),
                  ),
                  Text(item['val'] as String, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                ],
              ),
              Text(item['title'] as String, style: TextStyle(fontSize: 13, color: subTextColor)),
            ],
          ),
        );
      },
    );
  }

  // --- 5. Teacher Selector ---
  Widget _buildTeacherSelector(Color textColor, Color subTextColor) {
    return Container(
      height: 120,
      constraints: BoxConstraints(maxHeight: 120),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _teacherData.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          bool isSelected = _selectedTeacherIndex == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedTeacherIndex = index),
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: isSelected ? Colors.orange : Colors.transparent,
                          width: 2.5
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundImage: NetworkImage(_teacherData[index]['avatar']),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                      _teacherData[index]['name'],
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.orange : subTextColor
                      )
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryBox(String title, String content, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.blue),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
              content,
              style: TextStyle(fontSize: 14, color: isDark ? Colors.blue[100] : Colors.blue[900], height: 1.5)
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) => Text(
      title,
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)
  );
}