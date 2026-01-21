import 'package:flutter/cupertino.dart';

import './index.dart';
import 'animate_gift_item_state.dart';

class AnimatedGiftItem extends StatefulWidget {
  final GiftEvent giftEvent;
  final VoidCallback onFinished;

  const AnimatedGiftItem({
    required Key key,
    required this.giftEvent,
    required this.onFinished,
  }) : super(key: key);

  @override
  State<AnimatedGiftItem> createState() => AnimatedGiftItemState();
}