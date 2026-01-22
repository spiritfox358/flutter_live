
import '../screens/home/live/models/live_models.dart';
import '../tools/HttpUtil.dart';

class GiftApi {

  // 🟢 新增：获取礼物分类 Tab
  static Future<List<GiftTab>> getTabs() async {
    try {
      var data = await HttpUtil().get('/coin_gift_tab/list');
      if (data is List) {
        return data.map((e) => GiftTab.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print("获取Tab失败: $e");
      return [];
    }
  }
  // 获取礼物列表
  static Future<List<GiftItemData>> getGiftList() async {
    try {
      // 调用后端接口: /coin_gift/list
      var data = await HttpUtil().get('/coin_gift/list');

      // 解析数据: List<dynamic> -> List<GiftItemData>
      if (data is List) {
        return data.map((json) => GiftItemData.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print("获取礼物列表失败: $e");
      return []; // 出错返回空列表，防止崩坏
    }
  }
}