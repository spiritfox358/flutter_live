import 'package:flutter/material.dart';
import 'package:flutter_live/screens/questions/question_bank_screen.dart'; // 引入之前的题库页面

class ExamListScreen extends StatefulWidget {
  const ExamListScreen({super.key});

  @override
  State<ExamListScreen> createState() => _ExamListScreenState();
}

class _ExamListScreenState extends State<ExamListScreen> {
  final List<String> _tabs = ["全部", "高考真题", "名校模拟", "专项训练"];
  int _selectedTabIndex = 0;

  // 模拟试卷数据
  final List<ExamPaper> _papers = [
    ExamPaper(
      title: "2024年新课标I卷数学真题",
      tags: ["高考真题", "高难度"],
      difficulty: 5,
      questionCount: 22,
      participants: 12580,
      progress: 0.0,
      subject: "数学",
      isHot: true,
    ),
    ExamPaper(
      title: "高一数学必修一：集合与函数专项",
      tags: ["专项训练", "基础巩固"],
      difficulty: 2,
      questionCount: 15,
      participants: 850,
      progress: 0.8, // 进度 80%
      subject: "数学",
    ),
    ExamPaper(
      title: "衡水中学2025届高三第一次摸底",
      tags: ["名校模拟", "必刷"],
      difficulty: 4,
      questionCount: 20,
      participants: 3200,
      progress: 0.0,
      subject: "数学",
      isNew: true,
    ),
    ExamPaper(
      title: "立体几何：空间向量解题技巧",
      tags: ["专项训练", "进阶"],
      difficulty: 3,
      questionCount: 12,
      participants: 560,
      progress: 0.3,
      subject: "数学",
    ),
    ExamPaper(
      title: "2023年全国乙卷理科数学",
      tags: ["高考真题", "经典"],
      difficulty: 4,
      questionCount: 22,
      participants: 45000,
      progress: 1.0, // 已完成
      subject: "数学",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // 主题适配
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("试卷中心", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        centerTitle: true,
        backgroundColor: cardColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.history), onPressed: () {}, tooltip: "练习记录"),
        ],
      ),
      body: Column(
        children: [
          // 1. 顶部搜索与筛选
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            color: cardColor,
            child: Column(
              children: [
                // 搜索框
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: "搜索试卷名称、知识点...",
                      hintStyle: TextStyle(color: subTextColor.withOpacity(0.5), fontSize: 14),
                      prefixIcon: Icon(Icons.search, color: subTextColor, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 分类 Tab
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(_tabs.length, (index) {
                      final isSelected = _selectedTabIndex == index;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedTabIndex = index),
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? primaryColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? Colors.transparent : (isDark ? Colors.white24 : Colors.grey[300]!),
                            ),
                          ),
                          child: Text(
                            _tabs[index],
                            style: TextStyle(
                              color: isSelected ? Colors.white : subTextColor,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),

          // 2. 试卷列表
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _papers.length,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _buildExamCard(context, _papers[index], cardColor, textColor, subTextColor, primaryColor, isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamCard(BuildContext context, ExamPaper paper, Color cardColor, Color textColor, Color subTextColor, Color primaryColor, bool isDark) {
    return InkWell(
      onTap: () {
        // 跳转到题库页面 (QuestionBankScreen)
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const QuestionBankScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左侧图标容器
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.description_outlined, color: primaryColor, size: 28),
                ),
                const SizedBox(width: 12),

                // 中间信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 标题 + 徽章
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              paper.title,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (paper.isHot) _buildBadge("热", Colors.red),
                          if (paper.isNew) _buildBadge("新", Colors.green),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // 标签行
                      Row(
                        children: [
                          ...paper.tags.map((t) => Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.grey[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(t, style: TextStyle(fontSize: 10, color: subTextColor)),
                          )),
                          const Spacer(),
                          Text("${paper.participants}人已练", style: TextStyle(fontSize: 11, color: subTextColor)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 难度星级
                      Row(
                        children: [
                          Text("难度: ", style: TextStyle(fontSize: 11, color: subTextColor)),
                          Row(
                            children: List.generate(5, (i) => Icon(
                                Icons.star,
                                size: 12,
                                color: i < paper.difficulty ? Colors.amber : (isDark ? Colors.white10 : Colors.grey[300])
                            )),
                          ),
                          const SizedBox(width: 12),
                          Text("题量: ${paper.questionCount}", style: TextStyle(fontSize: 11, color: subTextColor)),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 底部进度与按钮
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            paper.progress == 0 ? "未开始" : (paper.progress == 1.0 ? "已完成" : "进行中 ${(paper.progress * 100).toInt()}%"),
                            style: TextStyle(
                                fontSize: 11,
                                color: paper.progress == 1.0 ? Colors.green : (paper.progress == 0 ? subTextColor : Colors.blue)
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: paper.progress,
                          minHeight: 4,
                          backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                              paper.progress == 1.0 ? Colors.green : Colors.blue
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const QuestionBankScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: paper.progress == 1.0 ? Colors.transparent : primaryColor,
                      foregroundColor: paper.progress == 1.0 ? primaryColor : Colors.white,
                      elevation: paper.progress == 1.0 ? 0 : 2,
                      side: paper.progress == 1.0 ? BorderSide(color: primaryColor) : null,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: Text(
                      paper.progress == 1.0 ? "复习" : (paper.progress > 0 ? "继续" : "开始"),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color, width: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}

// 数据模型
class ExamPaper {
  final String title;
  final List<String> tags;
  final int difficulty; // 1-5
  final int questionCount;
  final int participants;
  final double progress; // 0.0 - 1.0
  final String subject;
  final bool isHot;
  final bool isNew;

  ExamPaper({
    required this.title,
    required this.tags,
    required this.difficulty,
    required this.questionCount,
    required this.participants,
    required this.progress,
    required this.subject,
    this.isHot = false,
    this.isNew = false,
  });
}