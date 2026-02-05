import 'package:flutter/material.dart';
import '../../tools/HttpUtil.dart'; // 引入 HttpUtil

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    // 收起键盘
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      // 🟢 调用注册接口
      var response = await HttpUtil().post(
          "/api/user/register",
          data: {
            "accountId": _accountController.text, // 参数 accountId
            "password": _passwordController.text, // 参数 password
          }
      );

      // HttpUtil 通常处理了错误并弹窗，response != null 表示成功
      if (response != null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('注册成功，请登录'), backgroundColor: Colors.green),
        );

        // 注册成功，返回登录页
        Navigator.pop(context);
      }
    } catch (e) {
      // 错误通常由 HttpUtil 内部拦截处理，这里兜底防止 loading 状态卡死
      debugPrint("注册异常: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("注册")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 50),

              // 账号输入框
              TextFormField(
                controller: _accountController,
                keyboardType: TextInputType.text, // 改为 text 以支持非邮箱账号
                decoration: const InputDecoration(
                    labelText: '账号',
                    border: OutlineInputBorder()
                ),
                validator: (v) => v!.isEmpty ? '请输入账号' : null,
              ),
              const SizedBox(height: 20),

              // 密码输入框
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: '密码',
                    border: OutlineInputBorder()
                ),
                validator: (v) => v!.length < 6 ? '密码最少6位' : null,
              ),
              const SizedBox(height: 20),

              // 确认密码输入框
              TextFormField(
                controller: _confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: '确认密码',
                    border: OutlineInputBorder()
                ),
                validator: (v) {
                  if (v != _passwordController.text) return '两次密码不一致';
                  return null;
                },
              ),
              const SizedBox(height: 40),

              // 注册按钮
              ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('注 册', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 20),

              // 底部跳转
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('已有账号？去登录'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}