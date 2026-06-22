class DmConversation {
  final int id;
  final int targetId;
  final String targetName;
  final String targetAvatar;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final int lastSenderId;
  final int unreadCount;
  final bool isTop;
  final bool isMuted;

  const DmConversation({
    required this.id,
    required this.targetId,
    required this.targetName,
    required this.targetAvatar,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastSenderId,
    required this.unreadCount,
    required this.isTop,
    required this.isMuted,
  });

  factory DmConversation.fromJson(Map<String, dynamic> json) {
    final targetId = _asInt(json['targetId']);
    return DmConversation(
      id: _asInt(json['id'] ?? json['conversationId']),
      targetId: targetId,
      targetName:
          (json['targetName'] ??
                  json['targetNickname'] ??
                  json['nickname'] ??
                  '用户$targetId')
              .toString(),
      targetAvatar: (json['targetAvatar'] ?? json['avatar'] ?? '').toString(),
      lastMessage: (json['lastMessage'] ?? '').toString(),
      lastMessageTime: _asDateTimeOrNull(json['lastMessageTime']),
      lastSenderId: _asInt(json['lastSenderId']),
      unreadCount: _asInt(json['unreadCount']),
      isTop: _asBool(json['isTop']),
      isMuted: _asBool(json['isMuted'] ?? json['isBlocked']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'targetId': targetId,
      'targetName': targetName,
      'targetAvatar': targetAvatar,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
      'lastSenderId': lastSenderId,
      'unreadCount': unreadCount,
      'isTop': isTop,
      'isMuted': isMuted,
    };
  }

  DmConversation copyWith({
    int? id,
    int? targetId,
    String? targetName,
    String? targetAvatar,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? lastSenderId,
    int? unreadCount,
    bool? isTop,
    bool? isMuted,
  }) {
    return DmConversation(
      id: id ?? this.id,
      targetId: targetId ?? this.targetId,
      targetName: targetName ?? this.targetName,
      targetAvatar: targetAvatar ?? this.targetAvatar,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      unreadCount: unreadCount ?? this.unreadCount,
      isTop: isTop ?? this.isTop,
      isMuted: isMuted ?? this.isMuted,
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

  static DateTime? _asDateTimeOrNull(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }
}
