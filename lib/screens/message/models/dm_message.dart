import 'package:flutter_live/store/user_store.dart';

enum DmMessageStatus { sending, sent, failed }

class DmMessage {
  final int id;
  final int conversationId;
  final int senderId;
  final int receiverId;
  final String content;
  final int messageType;
  final String? extraData;
  final bool isRead;
  final bool isRecalled;
  final DateTime createdAt;
  DmMessageStatus status;

  DmMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.messageType,
    this.extraData,
    required this.isRead,
    required this.isRecalled,
    required this.createdAt,
    this.status = DmMessageStatus.sent,
  });

  bool get isMe => senderId.toString() == UserStore.to.userId;

  String get displayContent => isRecalled ? "[消息已撤回]" : content;

  factory DmMessage.fromJson(Map<String, dynamic> json) {
    return DmMessage(
      id: _asInt(json['id'] ?? json['messageId']),
      conversationId: _asInt(json['conversationId']),
      senderId: _asInt(json['senderId']),
      receiverId: _asInt(json['receiverId'] ?? json['targetId']),
      content: (json['content'] ?? '').toString(),
      messageType: _asInt(json['messageType'], fallback: 1),
      extraData: json['extraData']?.toString(),
      isRead: _asBool(json['isRead']),
      isRecalled: _asBool(json['isRecalled']),
      createdAt: _asDateTime(json['createdAt']),
      status: _asStatus(json['status']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'messageType': messageType,
      'extraData': extraData,
      'isRead': isRead,
      'isRecalled': isRecalled,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
    };
  }

  DmMessage copyWith({
    int? id,
    int? conversationId,
    int? senderId,
    int? receiverId,
    String? content,
    int? messageType,
    String? extraData,
    bool? isRead,
    bool? isRecalled,
    DateTime? createdAt,
    DmMessageStatus? status,
  }) {
    return DmMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      extraData: extraData ?? this.extraData,
      isRead: isRead ?? this.isRead,
      isRecalled: isRecalled ?? this.isRecalled,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return false;
  }

  static DateTime _asDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  static DmMessageStatus _asStatus(dynamic value) {
    final name = value?.toString();
    return DmMessageStatus.values.firstWhere(
      (status) => status.name == name,
      orElse: () => DmMessageStatus.sent,
    );
  }
}
