import 'package:flutter/material.dart';

class ChatMessage {
  final String name;
  final String content;
  final int level;
  final Color levelColor;
  final bool isGift; // 🟢 添加一个字段来标识是否是礼物消息
  ChatMessage({
    required this.name,
    required this.content,
    this.level = 0,
    this.levelColor = Colors.blue,
    this.isGift = false, // 默认不是礼物消息
  });
}

// 🟢 新增：礼物分类 Tab 模型
class GiftTab {
  final String id;
  final String name;
  final String code;

  GiftTab({required this.id, required this.name, required this.code});

  factory GiftTab.fromJson(Map<String, dynamic> json) {
    return GiftTab(id: json['id'].toString() ?? "0", name: json['name'] ?? '', code: json['code'] ?? '');
  }
}

class GiftEvent {
  final String id;
  final String senderName;
  final String senderAvatar;
  final int senderLevel;
  final String giftName;
  final String giftIconUrl;
  final String comboKey;
  int count;

  GiftEvent({
    required this.senderName,
    required this.senderAvatar,
    required this.senderLevel,
    required this.giftName,
    required this.giftIconUrl,
    this.count = 1,
    String? id,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
       comboKey = "${senderName}_$giftName";

  GiftEvent copyWith({int? count}) {
    return GiftEvent(
      id: id,
      senderName: senderName,
      senderAvatar: senderAvatar,
      giftName: giftName,
      giftIconUrl: giftIconUrl,
      count: count ?? this.count,
      senderLevel: 0,
    );
  }
}

class GiftItemData {
  final String id;
  final String name;
  final int price;
  final String iconUrl;
  final String? effectAsset; // 🟢 修改：改为可空，防止后端没配特效报错
  final String? tag;
  final String? expireTime;
  final String? tabId; // 🟢 新增：关联的 Tab ID

  const GiftItemData({
    required this.id,
    required this.name,
    required this.price,
    required this.iconUrl,
    this.effectAsset, // 去掉 required
    this.tag,
    this.expireTime,
    this.tabId, // 🟢 新增
  });

  factory GiftItemData.fromJson(Map<String, dynamic> json) {
    return GiftItemData(
      id: json['id']?.toString() ?? "",
      name: json['name'] ?? '',
      price: json['price'] ?? 0,
      iconUrl: json['iconUrl'] ?? '',
      effectAsset: json['effectUrl'],
      // 后端叫 effectUrl
      tag: json['tagName'],
      // 后端叫 tagName
      // expireTime: json['expireTime'] // 如果后续有过期时间逻辑可开启
      tabId: json['tabId']?.toString() ?? "",
    );
  }
}

class AIBoss {
  final String name;
  final String avatarUrl;
  final String videoUrl;
  final int difficulty;
  final List<String> tauntMessages;

  const AIBoss({required this.name, required this.avatarUrl, required this.videoUrl, this.difficulty = 1, this.tauntMessages = const []});
}
