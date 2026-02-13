import 'package:flutter/material.dart';

class AdminBadgeWidget extends StatelessWidget {
  final String text;
  final Color backgroundColor;

  const AdminBadgeWidget({
    super.key,
    this.text = "管",
    this.backgroundColor = const Color(0xFFFF4081),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 17,
      height: 17,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          height: 0.9,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}