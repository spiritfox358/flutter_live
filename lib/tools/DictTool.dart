import 'dart:ffi';

import '../screens/home/live/widgets/pk_score_bar_widgets.dart';

class DictTool {
  // 1. 私有化构造函数，防止被 new DateTool()
  DictTool._();

  // 2. 定义静态方法
  static PKStatus getPkStatus(int status) {
    if (status == 1) return PKStatus.playing;
    if (status == 2) return PKStatus.punishment;
    return PKStatus.coHost;
  }
}
