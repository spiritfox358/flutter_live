import 'package:intl/intl.dart';

class DateTool {
  // 1. 私有化构造函数，防止被 new DateTool()
  DateTool._();

  // 2. 定义静态方法
  static String formatISO(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '未知时间';
    try {
      DateTime dt = DateTime.parse(isoString).toLocal();
      // 自定义格式，例如：2023-10-01 12:30
      return "${dt.year}-${_twoDigits(dt.month)}-${_twoDigits(dt.day)} ${_twoDigits(dt.hour)}:${_twoDigits(dt.minute)}:${_twoDigits(dt.second)}";
    } catch (e) {
      return isoString;
    }
  }

  // 私有辅助方法
  static String _twoDigits(int n) {
    return n.toString().padLeft(2, '0');
  }
}