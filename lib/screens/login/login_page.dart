import 'dart:math';
import 'package:flutter/material.dart';

import '../home/live_list_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 🟢 默认填好 2039，方便你测试房主
    _idController.text = "2039";
    _nameController.text = "机械姬本人";
  }

  // 生成随机观众数据
  void _randomViewer() {
    setState(() {
      _idController.text = "${Random().nextInt(8999) + 1000}";
      _nameController.text = "吃瓜群众${Random().nextInt(999)}";
    });
  }

  void _login() {
    if (_idController.text.isEmpty || _nameController.text.isEmpty) return;

    // 跳转到直播列表
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LiveListPage(
          userId: _idController.text,
          userName: _nameController.text,
          level: "73",
          avatarUrl:
              "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/avatar/6e738b58d65d8b3685efffc4cdb9c2cd.png",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("直播 Demo 登录")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.live_tv, size: 80, color: Colors.purple),
            const SizedBox(height: 40),

            // ID 输入框
            TextField(
              controller: _idController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "用户 ID (2039是房主)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.perm_identity),
                helperText: "提示：只有 ID 为 2039 才能开启房间 1001",
              ),
            ),
            const SizedBox(height: 20),

            // 昵称输入框
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "用户昵称",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),

            // 快速切换按钮
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _randomViewer,
                icon: const Icon(Icons.refresh),
                label: const Text("随机切换成观众账号"),
              ),
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
                child: const Text("登录大厅", style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
