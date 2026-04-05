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

  // 🟢 1. 新增：头像版本标识
  // 默认给一个当前时间戳，保证每次冷启动 App 都能拉取一次最新的
  String _avatarKey = DateTime.now().millisecondsSinceEpoch.toString();

  // 🟢 2. Getter：给外部获取这个 Key (拼接到 URL 后面)
  String get avatarKey => _avatarKey;

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

  String get nickname => profile?['nickname'] ?? "未知用户";
  String get signature => profile?['signature'] ?? "";

  String get avatar => profile?['avatar'] ?? "";
  String get profileBg => profile?['profileBg'] ?? "";
  String get profileBgColor => profile?['profileBgColor'] ?? "";
  String get levelHonourBuffUrl => profile?['levelHonourBuffUrl'] ?? "";

  Map<String, dynamic> get decorations => profile?['decorations'] ?? <String, dynamic>{};

  int get userLevel => profile?['level'] ?? 1;

  int get monthLevel => profile?['monthLevel'] ?? 0;

  int get coin => profile?['coin'] ?? 0;

  // 6. 退出登录 (清空数据)
  Future<void> logout() async {
    await _prefs.remove(_kTokenKey);
    await _prefs.remove(_kProfileKey);
  }

  // 🟢 7. 新增：单独更新等级 (刷礼物升级后调用)
  Future<void> updateLevel(int newLevel) async {
    Map<String, dynamic>? currentData = profile;
    if (currentData == null) return;

    // 只有当等级真的变了才执行保存操作
    if (currentData['level'] == newLevel) return;

    // 复制一份数据确保可变性
    final mutableMap = Map<String, dynamic>.from(currentData);
    mutableMap['level'] = newLevel;

    await saveProfile(mutableMap);
  }

  // 🟢 8. 新增：单独更新余额 (刷礼物扣费后调用)
  Future<void> updateCoin(int newCoin) async {
    Map<String, dynamic>? currentData = profile;
    if (currentData == null) return;

    if (currentData['coin'] == newCoin) return;

    final mutableMap = Map<String, dynamic>.from(currentData);
    mutableMap['coin'] = newCoin;

    await saveProfile(mutableMap);
  }

  // 🟢 9. 新增：强制更新头像版本号
  // 当在编辑页面修改头像成功后，调用此方法，更新 Key，从而让 UI 强制重载图片
  void forceUpdateAvatar() {
    _avatarKey = DateTime.now().millisecondsSinceEpoch.toString();
  }
}
