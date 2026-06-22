import 'dart:convert';

import 'package:flutter_live/screens/message/models/dm_conversation.dart';
import 'package:flutter_live/screens/message/models/dm_message.dart';
import 'package:flutter_live/store/user_store.dart';
import 'package:flutter_live/tools/HttpUtil.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DmService {
  static String get _conversationCacheKey =>
      'DM_CONVERSATIONS_${UserStore.to.userId}';

  static String get _readOverrideCacheKey =>
      'DM_READ_OVERRIDES_${UserStore.to.userId}';

  static String _messageCacheKey(int conversationId) =>
      'DM_MESSAGES_${UserStore.to.userId}_$conversationId';

  static Future<List<DmConversation>> getCachedConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_conversationCacheKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => DmConversation.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> cacheConversations(
    List<DmConversation> conversations,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(
      conversations.map((conversation) => conversation.toJson()).toList(),
    );
    await prefs.setString(_conversationCacheKey, raw);
  }

  static Future<void> updateCachedConversationPreview({
    required int conversationId,
    required String lastMessage,
    required DateTime lastMessageTime,
    required int lastSenderId,
    int? unreadCount,
  }) async {
    final conversations = await getCachedConversations();
    final index = conversations.indexWhere(
      (conversation) => conversation.id == conversationId,
    );
    if (index < 0) return;

    final updated = conversations[index].copyWith(
      lastMessage: lastMessage,
      lastMessageTime: lastMessageTime,
      lastSenderId: lastSenderId,
      unreadCount: unreadCount,
    );
    conversations
      ..removeAt(index)
      ..insert(0, updated);
    conversations.sort((a, b) {
      if (a.isTop != b.isTop) return a.isTop ? -1 : 1;
      final aTime = a.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    await cacheConversations(conversations);
  }

  static Future<void> markConversationReadLocally(int conversationId) async {
    final readAt = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final overrides = await _getReadOverrides(prefs);
    overrides[conversationId.toString()] = readAt.toIso8601String();
    await prefs.setString(_readOverrideCacheKey, jsonEncode(overrides));

    final conversations = await getCachedConversations();
    final index = conversations.indexWhere(
      (conversation) => conversation.id == conversationId,
    );
    if (index < 0) return;
    conversations[index] = conversations[index].copyWith(unreadCount: 0);
    await cacheConversations(conversations);
  }

  static Future<Map<String, String>> _getReadOverrides(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(_readOverrideCacheKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      return {};
    }
  }

  static Future<List<DmConversation>> _applyReadOverrides(
    List<DmConversation> conversations,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final overrides = await _getReadOverrides(prefs);
    if (overrides.isEmpty) return conversations;

    return conversations.map((conversation) {
      final rawReadAt = overrides[conversation.id.toString()];
      final readAt = rawReadAt == null ? null : DateTime.tryParse(rawReadAt);
      final lastMessageTime = conversation.lastMessageTime;
      if (readAt == null || lastMessageTime == null) return conversation;
      if (lastMessageTime.isAfter(readAt)) return conversation;
      return conversation.copyWith(unreadCount: 0);
    }).toList();
  }

  static Future<List<DmMessage>> getCachedHistory(int conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_messageCacheKey(conversationId));
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => DmMessage.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> cacheHistory({
    required int conversationId,
    required List<DmMessage> messages,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final deduped = _dedupeAndSortMessages(messages);
    final raw = jsonEncode(deduped.map((message) => message.toJson()).toList());
    await prefs.setString(_messageCacheKey(conversationId), raw);
  }

  static List<DmMessage> _dedupeAndSortMessages(List<DmMessage> messages) {
    final byId = <int, DmMessage>{};
    final pending = <DmMessage>[];
    for (final message in messages) {
      if (message.id > 0) {
        byId[message.id] = message;
      } else {
        pending.add(message);
      }
    }
    final result = [...byId.values, ...pending]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result;
  }

  static Future<List<DmConversation>> getConversations() async {
    final data = await HttpUtil().get('/api/dm/conversations');
    if (data is! List) return [];

    final conversations = data
        .whereType<Map>()
        .map((item) => DmConversation.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    final hydrated = await Future.wait(
      conversations.map(_hydrateTargetProfile),
    );
    final merged = await _applyReadOverrides(hydrated);
    await cacheConversations(merged);
    return merged;
  }

  static Future<DmConversation> getOrCreateConversation({
    required int targetId,
    String? targetName,
    String? targetAvatar,
  }) async {
    final cached = await getCachedConversations();
    final cachedIndex = cached.indexWhere(
      (conversation) => conversation.targetId == targetId,
    );
    if (cachedIndex >= 0) return cached[cachedIndex];

    final data = await HttpUtil().get('/api/dm/conversation/$targetId');
    final conversation = DmConversation.fromJson(
      Map<String, dynamic>.from(data as Map),
    ).copyWith(targetName: targetName, targetAvatar: targetAvatar);
    final hydrated = await _hydrateTargetProfile(conversation);
    await cacheConversations([hydrated, ...cached]);
    return hydrated;
  }

  static Future<List<DmMessage>> getHistory({
    required int conversationId,
    int page = 1,
    int size = 30,
  }) async {
    final data = await HttpUtil().get(
      '/api/dm/history',
      params: {'conversationId': conversationId, 'page': page, 'size': size},
    );
    if (data is! List) return [];

    final messages = data
        .whereType<Map>()
        .map((item) => DmMessage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    await cacheHistory(conversationId: conversationId, messages: messages);
    return messages;
  }

  static Future<int> markRead(int conversationId) async {
    final data = await HttpUtil().post(
      '/api/dm/read',
      data: {'conversationId': conversationId},
    );
    if (data is Map) {
      final count = data['markedCount'];
      if (count is int) return count;
      if (count is num) return count.toInt();
    }
    return 0;
  }

  static Future<int> getUnreadCount() async {
    final data = await HttpUtil().get('/api/dm/unread');
    if (data is Map) {
      final count = data['unreadCount'];
      if (count is int) return count;
      if (count is num) return count.toInt();
    }
    return 0;
  }

  static Future<void> recall(int messageId) async {
    await HttpUtil().post('/api/dm/recall', data: {'messageId': messageId});
  }

  static Future<void> toggleTop(int conversationId) async {
    await HttpUtil().post(
      '/api/dm/top',
      data: {'conversationId': conversationId},
    );
  }

  static Future<void> deleteConversation(int conversationId) async {
    await HttpUtil().delete('/api/dm/conversation/$conversationId');
  }

  static Future<DmConversation> _hydrateTargetProfile(
    DmConversation conversation,
  ) async {
    if (conversation.targetId <= 0 ||
        (conversation.targetName != '用户${conversation.targetId}' &&
            conversation.targetAvatar.isNotEmpty)) {
      return conversation;
    }

    try {
      final user = await HttpUtil().get(
        '/api/user/info',
        params: {'userId': conversation.targetId},
      );
      if (user is Map) {
        return conversation.copyWith(
          targetName: (user['nickname'] ?? conversation.targetName).toString(),
          targetAvatar: (user['avatar'] ?? conversation.targetAvatar)
              .toString(),
        );
      }
    } catch (_) {
      // Keep the conversation usable even if user profile hydration fails.
    }
    return conversation;
  }
}
