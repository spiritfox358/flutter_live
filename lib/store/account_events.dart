import 'package:flutter/foundation.dart';

/// 账号发生变化（登录 / 切换账号）时自增。
/// 用于通知那些被 keep-alive 保活、不会自动重建的页面（如底部"关注"页）
/// 及时用新账号重新拉取数据。
final ValueNotifier<int> globalAccountChangedNotifier = ValueNotifier<int>(0);
