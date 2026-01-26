import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 🟢 用户信息管理工具类 (单例模式)
class UserStore {
  // 私有构造函数
  UserStore._internal();

  static final UserStore _instance = UserStore._internal();

  static UserStore get to => _instance;

  late SharedPreferences _prefs;

  static const String _kTokenKey = "TOKEN";
  static const String _kProfileKey = "USER_PROFILE";

  // 初始化 (在 main.dart 启动时调用)
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // 1. 保存 Token
  Future<void> setToken(String token) async {
    await _prefs.setString(_kTokenKey, token);
  }

  // 2. 获取 Token
  String get token => _prefs.getString(_kTokenKey) ?? "";

  // 3. 判断是否登录
  bool get isLogin => token.isNotEmpty;

  // 4. 🟢 保存用户信息 (存整个 JSON 字符串)
  Future<void> saveProfile(Map<String, dynamic> json) async {
    // 这里把 Map 转成 String 存进去
    String profileStr = jsonEncode(json);
    await _prefs.setString(_kProfileKey, profileStr);
  }

  // 5. 获取用户信息 (返回 Map，方便取值)
  Map<String, dynamic>? get profile {
    String str = _prefs.getString(_kProfileKey) ?? "";
    if (str.isEmpty) return null;
    return jsonDecode(str);
  }

  // 便捷获取常用字段
  String get userId => profile?['id']?.toString() ?? "";

  String get userAccountId => profile?['accountId']?.toString() ?? "";

  String get userName => profile?['nickname'] ?? "未知用户";

  String get avatar => profile?['avatar'] ?? "";

  int get userLevel => profile?['level'] ?? 1;

  // 6. 退出登录 (清空数据)
  Future<void> logout() async {
    await _prefs.remove(_kTokenKey);
    await _prefs.remove(_kProfileKey);
  }
}
