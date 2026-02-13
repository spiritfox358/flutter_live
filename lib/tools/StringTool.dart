import 'dart:convert';

class StringTool {
  // 1. 私有化构造函数，防止被 new DateTool()
  StringTool._();

  // 2. 定义静态方法
  static String formatTime(int seconds) {
    if (seconds < 0) return "00:00";
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  static bool parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
    }
    return false; // 默认值
  }

  static List<Map<String, dynamic>> parseMapList(String resList) {
    final List<dynamic> jsonData = jsonDecode(resList);
    final List<Map<String, dynamic>> scoreList = jsonData.map((item) => item as Map<String, dynamic>).toList();
    return scoreList;
  }

  static Map<String, dynamic> parseMap(String res) {
    final Map<String, dynamic> jsonData = jsonDecode(res);
    return jsonData;
  }
}
