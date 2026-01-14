import 'package:flutter/material.dart';

class CourseScreen extends StatelessWidget {
  const CourseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Two tabs: My Course and My Micro-class
      child: Scaffold(
        appBar: AppBar(
          title: const Text('我的课程'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '我的课程'),
              Tab(text: '我的微课'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildCourseList(), // Tab 1 content
            _buildMicroClassList(), // Tab 2 content
          ],
        ),
      ),
    );
  }

  // Widget for "我的课程" (My Courses)
  Widget _buildCourseList() {
    final List<Map<String, String>> courses = [
      {'title': '16272', 'date': '2026-01-01', 'img': 'https://wlypublic.oss-cn-beijing.aliyuncs.com/coursecover/model01.jpg'},
      {'title': '5有67', 'date': '2026-01-01', 'img': 'https://wlypublic.oss-cn-beijing.aliyuncs.com/coursecover/model01.jpg'},
      {'title': '械', 'date': '2020-09-15', 'img': 'https://wlypublic.oss-cn-beijing.aliyuncs.com/coursecover/model01.jpg'},
      {'title': '16272', 'date': '2026-01-01', 'img': 'https://wlypublic.oss-cn-beijing.aliyuncs.com/coursecover/model01.jpg'},
      {'title': '5有67', 'date': '2026-01-01', 'img': 'https://wlypublic.oss-cn-beijing.aliyuncs.com/coursecover/model01.jpg'},
      {'title': '械', 'date': '2020-09-15', 'img': 'https://wlypublic.oss-cn-beijing.aliyuncs.com/coursecover/model01.jpg'},
      {'title': '16272', 'date': '2026-01-01', 'img': 'https://wlypublic.oss-cn-beijing.aliyuncs.com/coursecover/model01.jpg'},
      {'title': '5有67', 'date': '2026-01-01', 'img': 'https://wlypublic.oss-cn-beijing.aliyuncs.com/coursecover/model01.jpg'},
      {'title': '械', 'date': '2020-09-15', 'img': 'https://wlypublic.oss-cn-beijing.aliyuncs.com/coursecover/model01.jpg'},
      {'title': '16272', 'date': '2026-01-01', 'img': 'https://wlypublic.oss-cn-beijing.aliyuncs.com/coursecover/model01.jpg'},
      {'title': '5有67', 'date': '2026-01-01', 'img': 'https://wlypublic.oss-cn-beijing.aliyuncs.com/coursecover/model01.jpg'},
      {'title': '械', 'date': '2020-09-15', 'img': 'https://wlypublic.oss-cn-beijing.aliyuncs.com/coursecover/model01.jpg'},
      {'title': '16272', 'date': '2026-01-01', 'img': 'https://wlypublic.oss-cn-beijing.aliyuncs.com/coursecover/model01.jpg'},
      {'title': '5有67', 'date': '2026-01-01', 'img': 'https://wlypublic.oss-cn-beijing.aliyuncs.com/coursecover/model01.jpg'},
      {'title': '械', 'date': '2020-09-15', 'img': 'https://wlypublic.oss-cn-beijing.aliyuncs.com/coursecover/model01.jpg'},
      {'title': '16272', 'date': '2026-01-01', 'img': 'https://wlypublic.oss-cn-beijing.aliyuncs.com/coursecover/model01.jpg'},
      {'title': '5有67', 'date': '2026-01-01', 'img': 'https://wlypublic.oss-cn-beijing.aliyuncs.com/coursecover/model01.jpg'},
      {'title': '械', 'date': '2020-09-15', 'img': 'https://wlypublic.oss-cn-beijing.aliyuncs.com/coursecover/model01.jpg'},
      {'title': '16272', 'date': '2026-01-01', 'img': 'https://wlypublic.oss-cn-beijing.aliyuncs.com/coursecover/model01.jpg'},
      {'title': '5有67', 'date': '2026-01-01', 'img': 'https://wlypublic.oss-cn-beijing.aliyuncs.com/coursecover/model01.jpg'},
      {'title': '械', 'date': '2020-09-15', 'img': 'https://wlypublic.oss-cn-beijing.aliyuncs.com/coursecover/model01.jpg'},
    ];

    return ListView.builder(
      itemCount: courses.length,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            leading: Image.network(courses[index]['img']!, width: 80, fit: BoxFit.cover),
            title: Text(courses[index]['title']!),
            subtitle: Text(courses[index]['date']!),
            trailing: const Icon(Icons.keyboard_arrow_down),
          ),
        );
      },
    );
  }

  // Widget for "我的微课" (My Micro-classes)
  Widget _buildMicroClassList() {
    final List<Map<String, String>> microClasses = [
      {'title': '辟邪剑法3', 'date': '2020-08-25 08:44'},
      {'title': 'President Yang Speech', 'date': '2020-03-06 09:51'},
      {'title': '天龙八部', 'date': '2020-06-01 08:21'},
      {'title': '辟邪剑法3', 'date': '2020-08-25 08:44'},
      {'title': 'President Yang Speech', 'date': '2020-03-06 09:51'},
      {'title': '天龙八部', 'date': '2020-06-01 08:21'},
      {'title': '辟邪剑法3', 'date': '2020-08-25 08:44'},
      {'title': 'President Yang Speech', 'date': '2020-03-06 09:51'},
      {'title': '天龙八部', 'date': '2020-06-01 08:21'},
      {'title': '辟邪剑法3', 'date': '2020-08-25 08:44'},
      {'title': 'President Yang Speech', 'date': '2020-03-06 09:51'},
      {'title': '天龙八部', 'date': '2020-06-01 08:21'},
      {'title': '辟邪剑法3', 'date': '2020-08-25 08:44'},
      {'title': 'President Yang Speech', 'date': '2020-03-06 09:51'},
      {'title': '天龙八部', 'date': '2020-06-01 08:21'},
      {'title': '辟邪剑法3', 'date': '2020-08-25 08:44'},
      {'title': 'President Yang Speech', 'date': '2020-03-06 09:51'},
      {'title': '天龙八部', 'date': '2020-06-01 08:21'},
      {'title': '辟邪剑法3', 'date': '2020-08-25 08:44'},
      {'title': 'President Yang Speech', 'date': '2020-03-06 09:51'},
      {'title': '天龙八部', 'date': '2020-06-01 08:21'},
    ];

    return ListView.builder(
      itemCount: microClasses.length,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            leading: const Icon(Icons.play_circle_outline, color: Colors.orange, size: 40),
            title: Text(microClasses[index]['title']!),
            subtitle: Text(microClasses[index]['date']!),
            trailing: const Icon(Icons.keyboard_arrow_down),
          ),
        );
      },
    );
  }
}