import 'package:flutter/material.dart';

class ChatMessage {
  final String userId;
  final String name;
  final String content;
  final int level;
  final int monthLevel;
  final Color levelColor;
  final bool isGift; // 🟢 添加一个字段来标识是否是礼物消息
  final bool isAnchor;
  final String? levelHonourBuff; // 🚀 1. 改成 String?

  ChatMessage({
    required this.userId,
    required this.name,
    required this.content,
    this.level = 0,
    this.monthLevel = 0,
    this.levelColor = Colors.blue,
    this.isGift = false, // 默认不是礼物消息
    this.isAnchor = false,
    this.levelHonourBuff, // 🚀 2. 取消默认值 0
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
  final String giftEffectUrl;
  List<dynamic>? configJsonList;
  final int giftPrice;
  final String trayEffectUrl;
  final String comboKey;
  int count;

  GiftEvent({
    required this.senderName,
    required this.senderAvatar,
    required this.senderLevel,
    required this.giftName,
    required this.giftIconUrl,
    required this.trayEffectUrl,
    required this.configJsonList,
    this.count = 1,
    String? id,
    required this.giftPrice,
    required this.giftEffectUrl,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
       comboKey = "${senderName}_$giftName";

  GiftEvent copyWith({int? count}) {
    return GiftEvent(
      id: id,
      senderName: senderName,
      senderAvatar: senderAvatar,
      senderLevel: senderLevel,
      // ✅ 保持原值
      giftName: giftName,
      giftIconUrl: giftIconUrl,
      trayEffectUrl: trayEffectUrl,
      // ✅ 保持原值
      count: count ?? this.count,
      giftPrice: giftPrice,
      giftEffectUrl: giftEffectUrl,
      configJsonList: configJsonList,
    );
  }
}

class GiftItemData {
  final String id;
  final String name;
  final int price;
  final bool? isLocked;
  final String iconUrl;
  final String? effectAsset; // 🟢 修改：改为可空，防止后端没配特效报错
  final String? remark;
  final List<dynamic>? configJsonList;
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
    this.tabId,
    this.configJsonList,
    this.isLocked,
    this.remark, // 🟢 新增
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
      remark: json['remark'],
      // 后端叫 tagName
      expireTime: json['expireTime'],
      // 如果后续有过期时间逻辑可开启
      tabId: json['tabId']?.toString() ?? "",
      configJsonList: json['vibrationConfig'] is List ? (json['vibrationConfig'] as List).cast<dynamic>() : [],
      isLocked: json['isLocked'] as bool,
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
