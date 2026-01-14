import 'package:flutter/material.dart';

class QuestionBankScreen extends StatefulWidget {
  const QuestionBankScreen({super.key});

  @override
  State<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends State<QuestionBankScreen> {
  int _selectedCategoryIndex = 0;
  final List<String> _categories = ["全部", "集合与逻辑", "函数", "立体几何", "解析几何", "数列", "概率统计"];
  late List<MathQuestion> _questions;

  @override
  void initState() {
    super.initState();
    _questions = _getMockQuestions();
  }

  // 生成模拟题目 (扩充至 10 道)
  List<MathQuestion> _getMockQuestions() {
    return [
      // 1. 单选题 - 集合
      MathQuestion(
        id: 1,
        type: QuestionType.singleChoice,
        difficulty: "简单",
        tags: ["集合", "2024真题"],
        stem: "已知集合 A = {x | -1 < x < 2}，B = {x | x > 0}，则 A ∩ B =",
        options: ["{x | 0 < x < 2}", "{x | x > 0}", "{x | -1 < x < 2}", "{x | x > -1}"],
        correctIndex: 0,
        explanation: "由题意得，公共部分为 (0, 2)。故选 A。",
      ),
      // 2. 判断题 - 函数 (新)
      MathQuestion(
        id: 2,
        type: QuestionType.trueOrFalse,
        difficulty: "简单",
        tags: ["函数奇偶性"],
        stem: "函数 f(x) = x³ + x 是奇函数。",
        correctIndex: 0, // 0 代表正确，1 代表错误
        explanation: "定义域为 R。f(-x) = (-x)³ + (-x) = -x³ - x = -(x³ + x) = -f(x)。\n满足奇函数定义，故该命题正确。",
      ),
      // 3. 解答题 - 数列
      MathQuestion(
        id: 3,
        type: QuestionType.subjective,
        difficulty: "困难",
        tags: ["数列", "证明题"],
        stem: "已知数列 {an} 满足 a₁=1，a(n+1) = 2an + 1。\n(1) 证明 {an + 1} 是等比数列；\n(2) 求 {an} 的通项公式。",
        explanation: "(1) 证明：\na(n+1) + 1 = 2an + 2 = 2(an + 1)\n所以 (a(n+1)+1)/(an+1) = 2 (常数)。\n又 a₁+1 = 2 ≠ 0，故 {an+1} 是首项为2，公比为2的等比数列。\n\n(2) 解：\n由(1)得 an + 1 = 2 * 2^(n-1) = 2^n。\n所以 an = 2^n - 1。",
      ),
      // 4. 单选题 - 向量
      MathQuestion(
        id: 4,
        type: QuestionType.singleChoice,
        difficulty: "中等",
        tags: ["平面向量"],
        stem: "已知向量 a=(1,2), b=(x,4)，若 a//b，则 x 的值为",
        options: ["2", "-2", "8", "-8"],
        correctIndex: 0,
        explanation: "因为 a//b，所以 1×4 - 2x = 0，解得 2x = 4，x = 2。\n故选 A。",
      ),
      // 5. 判断题 - 立体几何 (新)
      MathQuestion(
        id: 5,
        type: QuestionType.trueOrFalse,
        difficulty: "中等",
        tags: ["立体几何", "线面关系"],
        stem: "若一条直线平行于一个平面，则该直线平行于该平面内的所有直线。",
        correctIndex: 1, // 错误
        explanation: "错误。线面平行只能推出该直线与平面内对应的交线平行（或异面），并不能平行于平面内的“所有”直线。例如平面内的相交直线就可能与该直线异面。",
      ),
      // 6. 解答题 - 概率 (新)
      MathQuestion(
        id: 6,
        type: QuestionType.subjective,
        difficulty: "中等",
        tags: ["概率", "分布列"],
        stem: "某射击运动员进行射击测试，每次击中目标的概率为 0.6，连续射击 3 次。\n求击中目标的次数 X 的分布列及数学期望 E(X)。",
        explanation: "解：X 服从二项分布 B(3, 0.6)。\nP(X=0) = C(3,0) * 0.4^3 = 0.064\nP(X=1) = C(3,1) * 0.6 * 0.4^2 = 0.288\nP(X=2) = C(3,2) * 0.6^2 * 0.4 = 0.432\nP(X=3) = C(3,3) * 0.6^3 = 0.216\n\n数学期望 E(X) = np = 3 * 0.6 = 1.8。",
      ),
      // 7. 单选题 - 导数
      MathQuestion(
        id: 7,
        type: QuestionType.singleChoice,
        difficulty: "困难",
        tags: ["导数", "极值"],
        stem: "函数 f(x) = xlnx 在区间 (0, +∞) 上的最小值为",
        options: ["-1/e", "1/e", "-e", "0"],
        correctIndex: 0,
        explanation: "f'(x) = lnx + 1。令 f'(x)=0，得 lnx=-1，x=1/e。\n当 x ∈ (0, 1/e) 时，f'(x)<0，函数递减；\n当 x ∈ (1/e, +∞) 时，f'(x)>0，函数递增。\n所以 x=1/e 时取极小值也是最小值。\nf(1/e) = (1/e) * ln(1/e) = (1/e) * (-1) = -1/e。\n故选 A。",
      ),
      // 8. 判断题 - 不等式 (新)
      MathQuestion(
        id: 8,
        type: QuestionType.trueOrFalse,
        difficulty: "简单",
        tags: ["基本不等式"],
        stem: "对于任意正实数 a, b，都有 a + b ≥ 2√(ab)。",
        correctIndex: 0, // 正确
        explanation: "正确。这是基本不等式（AM-GM不等式），当且仅当 a=b 时等号成立。",
      ),
      // 9. 单选题 - 三角函数
      MathQuestion(
        id: 9,
        type: QuestionType.singleChoice,
        difficulty: "中等",
        tags: ["三角函数"],
        stem: "sin 15° cos 15° 的值是",
        options: ["1/2", "1/4", "√3/4", "√3/2"],
        correctIndex: 1,
        explanation: "sin 15° cos 15° = (1/2) * 2 sin 15° cos 15° = (1/2) * sin 30° = (1/2) * (1/2) = 1/4。\n故选 B。",
      ),
      // 10. 解答题 - 解析几何 (新)
      MathQuestion(
        id: 10,
        type: QuestionType.subjective,
        difficulty: "困难",
        tags: ["圆锥曲线", "椭圆"],
        stem: "求中心在原点，焦点在 x 轴上，长轴长为 4，短轴长为 2 的椭圆标准方程。",
        explanation: "解：由题意得 2a = 4 => a = 2；2b = 2 => b = 1。\n焦点在 x 轴，故方程形式为 x²/a² + y²/b² = 1。\n代入 a=2, b=1 得：\nx²/4 + y² = 1。",
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("高中数学智能题库", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        centerTitle: true,
        backgroundColor: cardColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // 顶部筛选
          Container(
            color: cardColor,
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedCategoryIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_categories[index]),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : textColor,
                      fontSize: 12,
                    ),
                    selected: isSelected,
                    onSelected: (bool selected) => setState(() => _selectedCategoryIndex = index),
                    backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
                    selectedColor: primaryColor,
                    showCheckmark: false,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                  ),
                );
              },
            ),
          ),

          // 题目列表
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _questions.length,
              separatorBuilder: (c, i) => const SizedBox(height: 20),
              itemBuilder: (context, index) {
                return _QuestionCard(
                  question: _questions[index],
                  index: index,
                  cardColor: cardColor,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  isDark: isDark,
                  primaryColor: primaryColor,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ================= 核心组件：支持多题型的卡片 =================

class _QuestionCard extends StatefulWidget {
  final MathQuestion question;
  final int index;
  final Color cardColor;
  final Color textColor;
  final Color subTextColor;
  final bool isDark;
  final Color primaryColor;

  const _QuestionCard({
    required this.question,
    required this.index,
    required this.cardColor,
    required this.textColor,
    required this.subTextColor,
    required this.isDark,
    required this.primaryColor,
  });

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  int? _selectedOption; // 用于选择题和判断题 (0=A/正确, 1=B/错误, etc)
  bool _showExplanation = false;
  final TextEditingController _textController = TextEditingController();
  bool _isSubmitted = false; // 简答题提交状态

  void _toggleExplanation() {
    setState(() {
      _showExplanation = !_showExplanation;
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(widget.isDark ? 0.2 : 0.05),
            blurRadius: 10, offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 题头 (题型标签)
          Row(
            children: [
              Text("${widget.index + 1}.", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: widget.primaryColor, fontStyle: FontStyle.italic)),
              const SizedBox(width: 8),
              _buildTypeTag(q.type),
              const SizedBox(width: 6),
              _buildTag(q.difficulty, _getDifficultyColor(q.difficulty)),
              const Spacer(),
              if (q.tags.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: widget.isDark ? Colors.white10 : Colors.grey[200],
                      borderRadius: BorderRadius.circular(4)
                  ),
                  child: Text("#${q.tags.first}", style: TextStyle(fontSize: 10, color: widget.subTextColor)),
                )
            ],
          ),
          const SizedBox(height: 16),

          // 2. 题干
          Text(q.stem, style: TextStyle(fontSize: 16, height: 1.6, color: widget.textColor, fontWeight: FontWeight.w500)),
          const SizedBox(height: 20),

          // 3. 动态内容区 (根据题型变化)
          _buildContentArea(q),

          // 4. 底部工具栏
          const SizedBox(height: 12),
          Divider(color: widget.isDark ? Colors.white10 : Colors.grey[200]),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatusText(q),
              TextButton.icon(
                onPressed: _toggleExplanation,
                icon: Icon(_showExplanation ? Icons.keyboard_arrow_up : Icons.lightbulb_outline, size: 16),
                label: Text(_showExplanation ? "收起解析" : "查看解析"),
                style: TextButton.styleFrom(foregroundColor: widget.primaryColor),
              )
            ],
          ),

          // 5. 解析区域
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExplanationBox(q),
            crossFadeState: _showExplanation ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  // --- 根据题型分发渲染逻辑 ---
  Widget _buildContentArea(MathQuestion q) {
    switch (q.type) {
      case QuestionType.singleChoice:
        return Column(children: List.generate(4, (i) => _buildOptionItem(i, q.options![i])));
      case QuestionType.trueOrFalse:
        return _buildTrueOrFalseArea(q);
      case QuestionType.subjective:
        return _buildSubjectiveArea();
    }
  }

  // A. 判断题区域 (新设计)
  Widget _buildTrueOrFalseArea(MathQuestion q) {
    return Row(
      children: [
        Expanded(child: _buildTFButton(0, "正确", Icons.check_circle_outline, Colors.green)),
        const SizedBox(width: 16),
        Expanded(child: _buildTFButton(1, "错误", Icons.highlight_off, Colors.red)),
      ],
    );
  }

  Widget _buildTFButton(int index, String label, IconData icon, Color color) {
    bool isSelected = _selectedOption == index;
    bool isCorrect = widget.question.correctIndex == index;
    bool showResult = _selectedOption != null;

    Color bgColor = widget.isDark ? Colors.white10 : Colors.grey[100]!;
    Color borderColor = Colors.transparent;
    Color textColor = widget.textColor;

    if (showResult) {
      if (isSelected) {
        if (isCorrect) {
          bgColor = color.withOpacity(0.1);
          borderColor = color;
          textColor = color;
        } else {
          bgColor = Colors.red.withOpacity(0.1);
          borderColor = Colors.red;
          textColor = Colors.red;
        }
      } else if (isCorrect) {
        // 未选中但正确
        borderColor = color.withOpacity(0.5);
        textColor = color;
      }
    }

    return GestureDetector(
      onTap: () {
        if (_selectedOption != null) return;
        setState(() {
          _selectedOption = index;
          if (index != widget.question.correctIndex) _showExplanation = true;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, color: showResult && isSelected ? textColor : (widget.isDark ? Colors.white54 : Colors.grey), size: 32),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          ],
        ),
      ),
    );
  }

  // B. 解答题区域 (保留)
  Widget _buildSubjectiveArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 120,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.isDark ? Colors.white10 : Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: widget.isDark ? Colors.white24 : Colors.grey[300]!),
          ),
          child: !_isSubmitted
              ? TextField(
            controller: _textController,
            maxLines: null,
            style: TextStyle(color: widget.textColor),
            decoration: const InputDecoration(border: InputBorder.none, hintText: "在此输入解题过程..."),
          )
              : SingleChildScrollView(child: Text(_textController.text.isEmpty ? "(未填写文本)" : _textController.text, style: TextStyle(color: widget.textColor))),
        ),
        const SizedBox(height: 12),
        if (!_isSubmitted)
          Row(
            children: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.camera_alt), color: widget.primaryColor, tooltip: "拍照上传"),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  setState(() { _isSubmitted = true; _showExplanation = true; });
                },
                style: ElevatedButton.styleFrom(backgroundColor: widget.primaryColor, foregroundColor: Colors.white),
                child: const Text("提交并对照"),
              ),
            ],
          )
      ],
    );
  }

  // C. 选择题选项
  Widget _buildOptionItem(int index, String text) {
    bool isSelected = _selectedOption == index;
    bool isCorrect = widget.question.correctIndex == index;
    bool showResult = _selectedOption != null;

    Color borderColor = widget.isDark ? Colors.white10 : Colors.grey.shade300;
    Color bgColor = Colors.transparent;
    IconData? icon;
    Color iconColor = Colors.transparent;

    if (showResult) {
      if (isSelected) {
        if (isCorrect) {
          borderColor = Colors.green; bgColor = Colors.green.withOpacity(0.1); icon = Icons.check_circle; iconColor = Colors.green;
        } else {
          borderColor = Colors.red; bgColor = Colors.red.withOpacity(0.1); icon = Icons.cancel; iconColor = Colors.red;
        }
      } else if (isCorrect) {
        borderColor = Colors.green; icon = Icons.check_circle_outline; iconColor = Colors.green;
      }
    }

    const labels = ["A", "B", "C", "D"];
    return GestureDetector(
      onTap: () {
        if (_selectedOption != null) return;
        setState(() {
          _selectedOption = index;
          if (index != widget.question.correctIndex) _showExplanation = true;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: isSelected || (showResult && isCorrect) ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 24, height: 24, alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected || (showResult && isCorrect) ? iconColor : (widget.isDark ? Colors.white10 : Colors.grey[200]),
                shape: BoxShape.circle,
              ),
              child: Text(labels[index], style: TextStyle(color: isSelected || (showResult && isCorrect) ? Colors.white : widget.textColor, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: TextStyle(fontSize: 15, color: widget.textColor))),
            if (showResult && (isSelected || isCorrect)) Icon(icon, color: iconColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusText(MathQuestion q) {
    if (q.type == QuestionType.singleChoice || q.type == QuestionType.trueOrFalse) {
      return Text(
        _selectedOption == null ? "请选择答案" : (_selectedOption == q.correctIndex ? "🎉 回答正确" : "❌ 回答错误"),
        style: TextStyle(
            color: _selectedOption == null ? Colors.grey : (_selectedOption == q.correctIndex ? Colors.green : Colors.red),
            fontSize: 12, fontWeight: FontWeight.bold
        ),
      );
    } else {
      if (!_isSubmitted) return const Text("请作答", style: TextStyle(color: Colors.grey, fontSize: 12));
      return const Text("已提交，请对照解析", style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold));
    }
  }

  Widget _buildExplanationBox(MathQuestion q) {
    return Container(
      width: double.infinity, margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.analytics, size: 16, color: Colors.blue),
            SizedBox(width: 6),
            Text("名师解析", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          Text(q.explanation, style: TextStyle(fontSize: 13, color: widget.textColor.withOpacity(0.8), height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTypeTag(QuestionType type) {
    String text;
    Color color;
    switch(type) {
      case QuestionType.singleChoice: text="单选"; color=Colors.blue; break;
      case QuestionType.trueOrFalse: text="判断"; color=Colors.teal; break; // 新增类型
      case QuestionType.subjective: text="解答"; color=Colors.orange; break;
    }
    return _buildTag(text, color);
  }

  Color _getDifficultyColor(String diff) {
    switch (diff) {
      case "简单": return Colors.green;
      case "中等": return Colors.orange;
      case "困难": return Colors.red;
      default: return Colors.grey;
    }
  }
}

// ================= 更新后的数据模型 =================

enum QuestionType {
  singleChoice, // 单选
  trueOrFalse,  // 判断 (新)
  subjective,   // 解答
}

class MathQuestion {
  final int id;
  final QuestionType type;
  final String difficulty;
  final List<String> tags;
  final String stem;
  final List<String>? options; // 选择题专用
  final int? correctIndex;     // 选择题/判断题专用 (0=True/A, 1=False/B)
  final String explanation;

  MathQuestion({
    required this.id,
    required this.type,
    required this.difficulty,
    required this.tags,
    required this.stem,
    this.options,
    this.correctIndex,
    required this.explanation,
  });
}