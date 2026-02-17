import 'package:flutter/material.dart';
import '../../tools/HttpUtil.dart'; // 确保引入 HttpUtil

class CreateAnchorPage extends StatefulWidget {
  const CreateAnchorPage({super.key});

  @override
  State<CreateAnchorPage> createState() => _CreateAnchorPageState();
}

class _CreateAnchorPageState extends State<CreateAnchorPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _personaController = TextEditingController();
  bool _isSubmitting = false;

  void _submit() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("请输入主播名称")));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 模拟提交 API
      // await HttpUtil().post("/api/anchor/create", data: {
      //   "name": _nameController.text,
      //   "persona": _personaController.text,
      // });

      // 模拟网络延迟
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("创建成功")));
        Navigator.pop(context, true); // 返回 true 表示需要刷新列表
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("创建失败: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("创建新的主播"),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "主播名称",
                hintText: "给你的AI主播起个名字",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _personaController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "人设描述 (Prompt)",
                hintText: "例如：傲娇的二次元少女，喜欢打游戏...",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF0050),
                  foregroundColor: Colors.white,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : const Text("立即创建", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}