import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class GradeReportScreen extends StatefulWidget {
  const GradeReportScreen({super.key});

  @override
  State<GradeReportScreen> createState() => _GradeReportScreenState();
}

class _GradeReportScreenState extends State<GradeReportScreen> {
  // 模拟数据：多个学期的成绩
  final List<SemesterRecord> _semesters = [
    SemesterRecord(
      term: "2025 春季学期 (Current)",
      gpa: 3.8,
      credits: 18,
      isExpanded: true,
      subjects: [
        Subject(name: "高等数学 II", score: 92, credit: 4, type: "理科"),
        Subject(name: "大学物理", score: 85, credit: 3, type: "理科"),
        Subject(name: "英语写作", score: 95, credit: 2, type: "文科"),
        Subject(name: "数据结构", score: 89, credit: 4, type: "工科"),
        Subject(name: "体育", score: 98, credit: 1, type: "素质"),
      ],
    ),
    SemesterRecord(
      term: "2024 秋季学期",
      gpa: 3.65,
      credits: 20,
      isExpanded: false,
      subjects: [
        Subject(name: "高等数学 I", score: 88, credit: 4, type: "理科"),
        Subject(name: "计算机导论", score: 90, credit: 3, type: "工科"),
        Subject(name: "近代史纲要", score: 82, credit: 2, type: "文科"),
        Subject(name: "C语言程序设计", score: 85, credit: 4, type: "工科"),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final cardColor = Theme.of(context).cardColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text("学业成绩单"),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: () {}),
          IconButton(icon: const Icon(Icons.download), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. 顶部 GPA 总览卡片
            _buildGPACard(isDark),
            const SizedBox(height: 20),

            // 2. 能力雷达图
            _buildRadarAnalysis(cardColor, textColor, isDark),
            const SizedBox(height: 20),

            // 3. 学期成绩列表
            Row(
              children: [
                Icon(Icons.history_edu, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Text("学期成绩明细", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
              ],
            ),
            const SizedBox(height: 10),
            ..._semesters.map((s) => _buildSemesterTile(s, cardColor, textColor, isDark)),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- 1. 炫酷 GPA 卡片 ---
  Widget _buildGPACard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF3949AB), const Color(0xFF1E88E5)]
              : [const Color(0xFF2196F3), const Color(0xFF64B5F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text("累积平均绩点 (CGPA)", style: TextStyle(color: Colors.white70, fontSize: 12)),
              SizedBox(height: 4),
              Text("3.78", style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Chip(
                label: Text("排名前 5%", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 10)),
                backgroundColor: Colors.white,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              )
            ],
          ),
          // 环形进度条
          SizedBox(
            height: 80,
            width: 80,
            child: Stack(
              children: [
                const SizedBox(
                  height: 80, width: 80,
                  child: CircularProgressIndicator(
                    value: 0.85, // 3.78 / 4.0 roughly
                    strokeWidth: 8,
                    color: Colors.white,
                    backgroundColor: Colors.white24,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text("Total", style: TextStyle(color: Colors.white54, fontSize: 10)),
                      Text("128", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      Text("学分", style: TextStyle(color: Colors.white54, fontSize: 8)),
                    ],
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- 2. 能力雷达图 ---
  Widget _buildRadarAnalysis(Color cardColor, Color textColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("能力维度分析", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              Icon(Icons.analytics_outlined, color: Colors.grey, size: 18),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: RadarChart(
              RadarChartData(
                radarTouchData: RadarTouchData(enabled: false),
                dataSets: [
                  RadarDataSet(
                    fillColor: Colors.blue.withOpacity(0.2),
                    borderColor: Colors.blue,
                    entryRadius: 3,
                    dataEntries: [
                      RadarEntry(value: 80), // 逻辑
                      RadarEntry(value: 90), // 语言
                      RadarEntry(value: 70), // 创意
                      RadarEntry(value: 85), // 记忆
                      RadarEntry(value: 95), // 专注
                    ],
                    borderWidth: 2,
                  ),
                ],
                radarBackgroundColor: Colors.transparent,
                borderData: FlBorderData(show: false),
                radarBorderData: const BorderSide(color: Colors.transparent),
                titlePositionPercentageOffset: 0.1,
                titleTextStyle: TextStyle(color: textColor, fontSize: 12),
                getTitle: (index, angle) {
                  const titles = ['逻辑', '语言', '创意', '记忆', '专注'];
                  return RadarChartTitle(text: titles[index], angle: angle);
                },
                tickCount: 1,
                ticksTextStyle: const TextStyle(color: Colors.transparent),
                gridBorderData: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 1),
                tickBorderData: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. 学期列表 (折叠面板) ---
  Widget _buildSemesterTile(SemesterRecord semester, Color cardColor, Color textColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: semester.isExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Text(semester.term, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          subtitle: Text("GPA: ${semester.gpa}  •  学分: ${semester.credits}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.calendar_month, color: Colors.blue, size: 20),
          ),
          children: [
            Container(
              height: 1, color: isDark ? Colors.white10 : Colors.grey.shade100,
            ),
            ...semester.subjects.map((sub) => _buildSubjectRow(sub, textColor)).toList(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // 单行课程成绩
  Widget _buildSubjectRow(Subject subject, Color textColor) {
    Color scoreColor;
    if (subject.score >= 90) scoreColor = const Color(0xFF2DCE89); // Green
    else if (subject.score >= 80) scoreColor = Colors.blue;
    else if (subject.score >= 60) scoreColor = Colors.orange;
    else scoreColor = Colors.red;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subject.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
                const SizedBox(height: 4),
                Text("${subject.type} • ${subject.credit} 学分", style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("${subject.score}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: scoreColor)),
              Text(_getGrade(subject.score), style: TextStyle(fontSize: 10, color: scoreColor.withOpacity(0.8))),
            ],
          ),
        ],
      ),
    );
  }

  String _getGrade(int score) {
    if (score >= 90) return "A+";
    if (score >= 85) return "A";
    if (score >= 80) return "B+";
    if (score >= 70) return "B";
    if (score >= 60) return "C";
    return "F";
  }
}

// --- 数据模型 ---
class SemesterRecord {
  final String term;
  final double gpa;
  final int credits;
  final bool isExpanded;
  final List<Subject> subjects;

  SemesterRecord({required this.term, required this.gpa, required this.credits, required this.subjects, this.isExpanded = false});
}

class Subject {
  final String name;
  final int score;
  final int credit;
  final String type; // 文科、理科等

  Subject({required this.name, required this.score, required this.credit, required this.type});
}