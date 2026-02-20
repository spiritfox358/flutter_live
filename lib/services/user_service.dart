import 'package:flutter_live/store/user_store.dart';

import '../tools/HttpUtil.dart';

class UserService {
  static Future<bool> syncUserInfo() async {
    var data = await HttpUtil().get('/api/user/info');
    UserStore.to.saveProfile(data);
    return true;
  }

  static Future<Map<String, dynamic>> getUserInfo(String? userId) async {
    var data = await HttpUtil().get('/api/user/info', params: {?userId: userId});
    return data;
  }
}
