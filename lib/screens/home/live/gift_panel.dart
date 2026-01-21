// --- 礼物面板 ---
import 'package:flutter/cupertino.dart';
import './index.dart';
import 'gift_panel_state.dart';

class GiftPanel extends StatefulWidget {
  final Function(GiftItemData) onSend;

  const GiftPanel({super.key, required this.onSend});

  @override
  State<GiftPanel> createState() => GiftPanelState();
}
