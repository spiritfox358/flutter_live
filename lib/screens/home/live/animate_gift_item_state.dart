import 'dart:async';

import 'package:flutter/material.dart';
import './index.dart';
import 'animate_gift_item.dart';

class AnimatedGiftItemState extends State<AnimatedGiftItem> with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _comboController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _stayTimer;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _slideAnimation = Tween<Offset>(begin: const Offset(-1.2, 0.0), end: Offset.zero).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_entryController);
    _comboController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(CurvedAnimation(parent: _comboController, curve: Curves.easeInOut));
    _comboController.addStatusListener((status) {if (status == AnimationStatus.completed) {_comboController.reverse();}});
    _entryController.forward();
    _startTimer();
  }

  @override
  void didUpdateWidget(AnimatedGiftItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.giftEvent.count > oldWidget.giftEvent.count) {
      _startTimer();
      _comboController.forward(from: 0.0);
    }
  }

  void _startTimer() {
    _stayTimer?.cancel();
    _stayTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _entryController.reverse().then((_) => widget.onFinished());
      }
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _comboController.dispose();
    _stayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: _buildPremiumGiftBanner(widget.giftEvent),
      ),
    );
  }

  Widget _buildPremiumGiftBanner(GiftEvent gift) {
    return Container(
      margin: const EdgeInsets.only(left: 10, bottom: 10),
      height: 44,
      width: 230,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 180,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Colors.black.withOpacity(0.7), Colors.black.withOpacity(0.1)]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
              ),
              padding: const EdgeInsets.fromLTRB(4, 2, 40, 2),
              child: Row(
                children: [
                  Container(padding: const EdgeInsets.all(1), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const CircleAvatar(radius: 15, backgroundImage: NetworkImage('https://picsum.photos/seed/myAvatar/200'))),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(gift.senderName, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      Text("送出 ${gift.giftName}", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 9)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(right: 40, top: -12, child: Image.network(gift.giftIconUrl, width: 55, height: 55, fit: BoxFit.contain)),
          Positioned(
            right: 0,
            top: 0,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Transform.rotate(
                angle: -0.2,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("x", style: TextStyle(color: Colors.yellowAccent, fontSize: 16, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, shadows: [Shadow(color: Colors.orange.withOpacity(0.8), blurRadius: 8, offset: const Offset(1, 1))])),
                    Text("${gift.count}", style: TextStyle(color: Colors.yellowAccent, fontSize: 24, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 4, offset: const Offset(2, 2))])),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}