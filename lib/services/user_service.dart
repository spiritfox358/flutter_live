import 'package:flutter_live/store/user_store.dart';

import '../tools/HttpUtil.dart';

class UserService {
  static Future<bool> syncUserInfo() async {
    var data = await HttpUtil().get('/api/user/info');
    UserStore.to.saveProfile(data);
    return true;
  }
}
