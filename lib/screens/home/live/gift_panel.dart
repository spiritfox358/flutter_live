// --- 礼物面板 ---
import 'package:flutter/cupertino.dart';
import '../../../models/user_models.dart';
import 'gift_panel_state.dart';
import 'models/live_models.dart';

class GiftPanel extends StatefulWidget {
  final Function(GiftItemData) onSend;

  // 🟢 新增：接收从外面传进来的礼物列表 (可选，如果传了就不用 API 再查一遍)
  final List<GiftItemData>? initialGiftList;
  final int myBalance;
  final ValueNotifier<UserStatus> userStatusNotifier;
  const GiftPanel({
    super.key,
    required this.onSend,
    required this.myBalance,
    this.initialGiftList, // 可选参数
    required this.userStatusNotifier,
  });

  @override
  State<GiftPanel> createState() => GiftPanelState();
}
