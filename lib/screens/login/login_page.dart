import 'package:flutter/material.dart';
import '../../store/user_store.dart';
import '../../tools/HttpUtil.dart';
import '../home/live/real_live_page.dart';
import '../home/live_list_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    // 收起键盘
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = false);
    var response = await HttpUtil().post("/api/user/login", data: {"accountId": _emailController.text, "password": _passwordController.text});

    // 假设 HttpUtil 统一处理了 Result.succ 的 data 部分
    if (response != null) {
      // 2. 获取数据
      String token = response['token'];
      Map<String, dynamic> userInfo = response['userInfo'];
      String userId = userInfo['id'].toString(); // 注意转 String
      String userName = userInfo['nickname'];
      String avatar = userInfo['avatar'];
      await UserStore.to.setToken(token);
      await UserStore.to.saveProfile(userInfo);
      // 3. 存储 Token (使用 shared_preferences)
      // await SpUtil.save("token", token);

      // 4. 跳转到直播页 (传入真实用户信息)
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LiveListPage(),
          ),
        );
      }
    } else {
      // 登录失败提示...
    }
    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('登录成功')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("登录")),
      // 使用 SingleChildScrollView 防止键盘弹出时报错
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Form(
          key: _formKey,
          child: Column(
            // 默认就是从上往下排，不需要 MainAxisAlignment.center
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 核心修改：距离顶部 100px
              const SizedBox(height: 50),

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: '手机号', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '密码', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('登 录', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterPage()));
                },
                child: const Text('没有账号？去注册'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
