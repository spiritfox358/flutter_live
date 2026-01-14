import 'package:flutter/material.dart';

void main() {
  runApp(MeScreen());
}

class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '个人中心',
      theme: ThemeData(
        primaryColor: Color(0xFFFF6B35), // 橙色主色调
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
        ),
      ),
      home: PersonalCenterPage(),
    );
  }
}

class PersonalCenterPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar( // 新增的橙色标题栏
        backgroundColor: Color(0xFFFF6B35), // 橙色背景
        title: Text(
          '个人中心',
          style: TextStyle(
            color: Colors.white, // 白色文字
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true, // 标题居中
        elevation: 4, // 添加阴影效果
        automaticallyImplyLeading: false, // 不显示返回箭头
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 用户信息区域
            _buildUserInfo(),
            // 访客统计
            _buildVisitorStats(),
            // 社交数据
            _buildSocialStats(),
            // 功能列表
            Expanded(
              child: _buildFunctionList(),
            ),
          ],
        ),
      ),
    );
  }

  // 其余代码保持不变...
  Widget _buildUserInfo() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 切换学生按钮
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFF6B35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text('切换到学生', style: TextStyle(color: Colors.white)),
              ),
              // 用户头像和昵称
              Column(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Color(0xFFFF6B35),
                    child: Icon(Icons.person, size: 30, color: Colors.white),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '独孤九剑',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // 切换学校按钮
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFF6B35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text('切换到学校', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisitorStats() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(
                '168',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF6B35),
                ),
              ),
              Text('访客总量', style: TextStyle(color: Colors.grey[600])),
            ],
          ),
          Container(
            width: 1,
            height: 30,
            color: Colors.grey[300],
          ),
          Column(
            children: [
              Text(
                '0',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF6B35),
                ),
              ),
              Text('今日访客', style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialStats() {
    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('6', '关注'),
          _buildStatItem('53', '收藏'),
          _buildStatItem('9', '粉丝'),
          _buildStatItem('', '认证'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF6B35),
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildFunctionList() {
    final List<Map<String, dynamic>> functions = [
      {'icon': Icons.school, 'title': '学堂设置'},
      {'icon': Icons.wallet, 'title': 'My Wallet'},
      {'icon': Icons.share, 'title': '我的推广'},
      {'icon': Icons.help_outline, 'title': '微乐优助手'},
      {'icon': Icons.security, 'title': '安全中心'},
      {'icon': Icons.settings, 'title': 'Settings'},
      {'icon': Icons.info_outline, 'title': '关于本软件'},
    ];

    return ListView.builder(
      padding: EdgeInsets.only(top: 8),
      itemCount: functions.length,
      itemBuilder: (context, index) {
        return ListTile(
          leading: Icon(
            functions[index]['icon'],
            color: Color(0xFFFF6B35),
          ),
          title: Text(functions[index]['title']),
          trailing: Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            // 处理点击事件
          },
        );
      },
    );
  }
}