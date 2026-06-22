import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_live/screens/message/models/dm_message.dart';
import 'package:flutter_live/store/user_store.dart';
import 'package:flutter_live/tools/HttpUtil.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class DmSocketEvent {
  final String type;
  final DmMessage? message;
  final int? conversationId;
  final int? unreadCount;
  final int? markedCount;
  final int? clientMessageId;

  const DmSocketEvent({
    required this.type,
    this.message,
    this.conversationId,
    this.unreadCount,
    this.markedCount,
    this.clientMessageId,
  });

  factory DmSocketEvent.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] ?? '').toString();
    final normalized = Map<String, dynamic>.from(json);
    if (type == 'DM_SENT' || type == 'DM_SYNCED') {
      normalized['senderId'] ??= UserStore.to.userId;
      normalized['receiverId'] ??= normalized['targetId'];
    }
    return DmSocketEvent(
      type: type,
      message: type == 'DM_RECEIVED' || type == 'DM_SENT' || type == 'DM_SYNCED'
          ? DmMessage.fromJson(normalized)
          : null,
      conversationId: _asIntOrNull(json['conversationId']),
      unreadCount: _asIntOrNull(json['unreadCount']),
      markedCount: _asIntOrNull(json['markedCount']),
      clientMessageId: _asIntOrNull(json['clientMessageId']),
    );
  }

  static int? _asIntOrNull(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class DmSocketService {
  DmSocketService._internal();

  static final DmSocketService instance = DmSocketService._internal();

  final StreamController<DmSocketEvent> _events =
      StreamController<DmSocketEvent>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _connecting = false;

  Stream<DmSocketEvent> get events => _events.stream;

  bool get isConnected => _channel != null;

  void connect() {
    if (_connecting || _channel != null || UserStore.to.token.isEmpty) return;
    _connecting = true;

    final scheme =
        HttpUtil.getBaseIpPort.contains('localhost') ||
            HttpUtil.getBaseIpPort.contains('192.168.')
        ? 'ws'
        : 'wss';
    final token = Uri.encodeComponent(UserStore.to.token);
    final uri = Uri.parse(
      '$scheme://${HttpUtil.getBaseIpPort}/ws/dm?token=$token',
    );

    try {
      _channel = WebSocketChannel.connect(uri);
      _subscription = _channel!.stream.listen(
        _handleRawMessage,
        onError: (error) {
          debugPrint('私信 WebSocket 出错: $error');
          disconnect();
        },
        onDone: disconnect,
      );
    } catch (e) {
      debugPrint('私信 WebSocket 连接失败: $e');
      disconnect();
    } finally {
      _connecting = false;
    }
  }

  bool sendText({
    required int targetId,
    required int conversationId,
    required int clientMessageId,
    required String content,
  }) {
    connect();
    final text = content.trim();
    if (_channel == null || targetId <= 0 || text.isEmpty) return false;

    _channel!.sink.add(
      jsonEncode({
        'type': 'DM_SEND',
        'targetId': targetId,
        'conversationId': conversationId,
        'clientMessageId': clientMessageId,
        'content': text,
        'messageType': 1,
      }),
    );
    return true;
  }

  void markRead(int conversationId) {
    if (_channel == null || conversationId <= 0) return;
    _channel!.sink.add(
      jsonEncode({'type': 'DM_READ', 'conversationId': conversationId}),
    );
  }

  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _connecting = false;
  }

  void dispose() {
    disconnect();
    _events.close();
  }

  void _handleRawMessage(dynamic raw) {
    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is Map) {
        _events.add(DmSocketEvent.fromJson(Map<String, dynamic>.from(decoded)));
      }
    } catch (e) {
      debugPrint('解析私信 WebSocket 消息失败: $e');
    }
  }
}
