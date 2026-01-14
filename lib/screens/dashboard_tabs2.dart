import 'package:flutter/material.dart';

class DashboardTabPage2 extends StatelessWidget {
  const DashboardTabPage2({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("数据中心", style: TextStyle(fontSize: 16)),
          centerTitle: true,
          toolbarHeight: 44, // 缩小 AppBar 高度
        ),
        body: Column(
          children: [
            // 自定义一个紧凑的容器
            Container(
              height: 36, // 这里控制 Tab 的具体高度，设得很小
              color: Colors.grey[100],
              child: const TabBar(
                physics: NeverScrollableScrollPhysics(),
                indicatorColor: Colors.blue,
                indicatorWeight: 3, // 指示器线条加粗一点
                labelColor: Colors.black,
                labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                unselectedLabelColor: Colors.grey,
                // 调整 padding 让它在小高度下也不拥挤
                labelPadding: EdgeInsets.zero,
                tabs: [
                  // 使用 Align 确保文字在高度压缩时依然垂直居中
                  Tab(child: Align(alignment: Alignment.center, child: Text('学生看板'))),
                  Tab(child: Align(alignment: Alignment.center, child: Text('老师看板'))),
                  Tab(child: Align(alignment: Alignment.center, child: Text('校区看板'))),
                ],
              ),
            ),
            // 内容区域
            const Expanded(
              child: TabBarView(
                physics: NeverScrollableScrollPhysics(), // 禁止滑动
                children: [
                  Center(child: Text("学生看板内容")),
                  Center(child: Text("老师看板内容")),
                  Center(child: Text("校区看板内容")),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}