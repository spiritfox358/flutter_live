import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: const Text('微乐优翻转学堂', style: TextStyle(color: Colors.white)),
        actions: [IconButton(icon: const Icon(Icons.search), onPressed: () {})],
      ),
      body: SingleChildScrollView( //
        child: Column(
          children: [
            // 1. 顶部横幅 (Banner)
            _buildBanner(),
            // 2. 分类导航 (Categories)
            _buildCategoryGrid(),
            // 3. 教师介绍/宣传板块 (Promotions)
            _buildPromotionSection(),
          ],
        ),
      ),
    );
  }

  // 模拟横幅组件
  Widget _buildBanner() {
    return Container(
      height: 180,
      width: double.infinity,
      child: Image.network(
        'https://via.placeholder.com/400x180', // 替换为你截图中的橙色背景图
        fit: BoxFit.cover,
      ),
    );
  }

  // 模拟分类网格
  Widget _buildCategoryGrid() {
    final List<Map<String, dynamic>> categories = [
      {'icon': Icons.book, 'title': '课外辅导'},
      {'icon': Icons.school, 'title': '学历培训'},
      {'icon': Icons.person, 'title': '语言培训'},
      {'icon': Icons.work, 'title': '职业培训'},
      {'icon': Icons.favorite, 'title': '兴趣类'},
    ];

    return Padding(
      padding: const EdgeInsets.all(15),
      child: GridView.builder(
        shrinkWrap: true, // 必须设置，否则在Column里会报错
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          mainAxisSpacing: 10,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          return Column(
            children: [
              CircleAvatar(
                backgroundColor: Colors.orange,
                child: Icon(categories[index]['icon'], color: Colors.white),
              ),
              const SizedBox(height: 5),
              Text(categories[index]['title'], style: const TextStyle(fontSize: 12)),
            ],
          );
        },
      ),
    );
  }

  // 模拟宣传板块 (基于你最后几张截图的 2x3 网格)
  Widget _buildPromotionSection() {
    return Container(
      padding: const EdgeInsets.all(10),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: [
          _buildPromoCard('免费宣传', '招生不愁', Colors.blue),
          _buildPromoCard('先学后教', '高效教学', Colors.green),
          _buildPromoCard('机构课程', '流量变现', Colors.orange),
          _buildPromoCard('资源输出', '做人做强', Colors.purple),
        ],
      ),
    );
  }

  Widget _buildPromoCard(String title, String sub, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          Text(sub, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}