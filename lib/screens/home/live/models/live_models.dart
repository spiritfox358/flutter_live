import 'package:flutter/material.dart';

class ChatMessage {
  final String name;
  final String content;
  final int level;
  final Color levelColor;

  ChatMessage({
    required this.name,
    required this.content,
    this.level = 0,
    this.levelColor = Colors.blue,
  });
}

class GiftEvent {
  final String id;
  final String senderName;
  final String giftName;
  final String giftIconUrl;
  final String comboKey;
  int count;

  GiftEvent({
    required this.senderName,
    required this.giftName,
    required this.giftIconUrl,
    this.count = 1,
    String? id,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        comboKey = "${senderName}_${giftName}";

  GiftEvent copyWith({int? count}) {
    return GiftEvent(
      id: id,
      senderName: senderName,
      giftName: giftName,
      giftIconUrl: giftIconUrl,
      count: count ?? this.count,
    );
  }
}

class GiftItemData {
  final String name;
  final int price;
  final String iconUrl;
  final String effectAsset;
  final String? tag;
  final String? expireTime;

  const GiftItemData({
    required this.name,
    required this.price,
    required this.iconUrl,
    required this.effectAsset,
    this.tag,
    this.expireTime,
  });
}

class AIBoss {
  final String name;
  final String avatarUrl;
  final String videoUrl;
  final int difficulty;
  final List<String> tauntMessages;

  const AIBoss({
    required this.name,
    required this.avatarUrl,
    required this.videoUrl,
    this.difficulty = 1,
    this.tauntMessages = const [],
  });
}