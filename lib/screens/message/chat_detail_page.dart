import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_live/screens/message/models/dm_conversation.dart';
import 'package:flutter_live/screens/message/models/dm_message.dart';
import 'package:flutter_live/screens/message/services/dm_service.dart';
import 'package:flutter_live/screens/message/services/dm_socket_service.dart';
import 'package:flutter_live/screens/message/services/dm_unread_notifier.dart';
import 'package:flutter_live/store/user_store.dart';
import 'package:flutter_live/tools/time_util.dart';

class ChatDetailPage extends StatefulWidget {
  final DmConversation conversation;

  const ChatDetailPage({super.key, required this.conversation});

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<DmMessage> _messages = [];

  StreamSubscription<DmSocketEvent>? _socketSub;
  bool _hasLoadedMessages = false;
  String? _error;

  void _onTextChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    DmSocketService.instance.connect();
    _socketSub = DmSocketService.instance.events.listen(_handleSocketEvent);
    _restoreCachedHistory();
    _loadHistory();
    _markRead();
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _restoreCachedHistory() async {
    final cached = await DmService.getCachedHistory(widget.conversation.id);
    if (!mounted || cached.isEmpty || _messages.isNotEmpty) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(cached);
      _hasLoadedMessages = true;
      _error = null;
    });
    _scrollToBottom(animated: false);
  }

  Future<void> _loadHistory() async {
    try {
      final list = await DmService.getHistory(
        conversationId: widget.conversation.id,
      );
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(_mergeWithLocalPending(list));
        _hasLoadedMessages = true;
        _error = null;
      });
      unawaited(_cacheCurrentHistory());
      _scrollToBottom(animated: false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasLoadedMessages = true;
        _error = _messages.isEmpty ? e.toString() : null;
      });
    }
  }

  Future<void> _markRead() async {
    unawaited(DmService.markConversationReadLocally(widget.conversation.id));
    await DmService.markRead(widget.conversation.id).catchError((_) => 0);
    DmSocketService.instance.markRead(widget.conversation.id);
    globalDmUnreadRefreshNotifier.value++;
  }

  void _handleSocketEvent(DmSocketEvent event) {
    final msg = event.message;
    if (event.type == 'DM_FAILED') {
      final clientMessageId = event.clientMessageId;
      if (clientMessageId != null) {
        _updateLocalMessageStatus(clientMessageId, DmMessageStatus.failed);
      }
      return;
    }
    if (msg == null || !_belongsToCurrentConversation(msg)) return;

    setState(() {
      if (event.type == 'DM_SENT' || event.type == 'DM_SYNCED') {
        final pendingIndex = _messages.lastIndexWhere(
          (item) =>
              (event.clientMessageId != null &&
                  item.id == event.clientMessageId) ||
              ((item.status == DmMessageStatus.sending || item.id < 0) &&
                  item.content == msg.content &&
                  item.isMe),
        );
        if (pendingIndex >= 0) {
          _messages[pendingIndex] = msg.copyWith(status: DmMessageStatus.sent);
        } else {
          _appendIfMissing(msg);
        }
      } else {
        _appendIfMissing(msg);
      }
    });
    unawaited(_cacheCurrentHistory());
    unawaited(_updateConversationPreview(msg));

    if (event.type == 'DM_RECEIVED') {
      _markRead();
    }
    _scrollToBottom();
  }

  bool _belongsToCurrentConversation(DmMessage msg) {
    if (msg.conversationId == widget.conversation.id) return true;
    final myUserId = int.tryParse(UserStore.to.userId) ?? 0;
    return (msg.senderId == widget.conversation.targetId &&
            msg.receiverId == myUserId) ||
        (msg.senderId == myUserId &&
            msg.receiverId == widget.conversation.targetId);
  }

  void _appendIfMissing(DmMessage msg) {
    if (_messages.any((item) => item.id > 0 && item.id == msg.id)) return;
    _messages.add(msg);
  }

  List<DmMessage> _mergeWithLocalPending(List<DmMessage> serverMessages) {
    final merged = [...serverMessages];
    final localPending = _messages.where(
      (message) => message.id < 0 || message.status == DmMessageStatus.sending,
    );

    for (final pending in localPending) {
      final alreadySaved = merged.any(
        (message) =>
            message.senderId == pending.senderId &&
            message.receiverId == pending.receiverId &&
            message.content == pending.content &&
            message.createdAt.difference(pending.createdAt).abs().inSeconds <
                10,
      );
      if (!alreadySaved) {
        merged.add(pending);
      }
    }

    merged.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return merged;
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final now = DateTime.now();
    final myUserId = int.tryParse(UserStore.to.userId) ?? 0;
    final pending = DmMessage(
      id: -now.millisecondsSinceEpoch,
      conversationId: widget.conversation.id,
      senderId: myUserId,
      receiverId: widget.conversation.targetId,
      content: text,
      messageType: 1,
      isRead: false,
      isRecalled: false,
      createdAt: now,
      status: DmMessageStatus.sending,
    );

    setState(() => _messages.add(pending));
    _textController.clear();
    final queued = DmSocketService.instance.sendText(
      targetId: widget.conversation.targetId,
      conversationId: widget.conversation.id,
      clientMessageId: pending.id,
      content: text,
    );
    if (!queued) {
      _updateLocalMessageStatus(pending.id, DmMessageStatus.failed);
      return;
    }
    _scrollToBottom();
    _settleOptimisticMessage(pending.id);
    unawaited(_updateConversationPreview(pending));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_cacheCurrentHistory());
    });
  }

  Future<void> _updateConversationPreview(DmMessage message) {
    return DmService.updateCachedConversationPreview(
      conversationId: widget.conversation.id,
      lastMessage: message.displayContent,
      lastMessageTime: message.createdAt,
      lastSenderId: message.senderId,
      unreadCount: 0,
    );
  }

  void _settleOptimisticMessage(int localId) {
    Future.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      final index = _messages.indexWhere(
        (message) =>
            message.id == localId && message.status == DmMessageStatus.sending,
      );
      if (index < 0) return;
      setState(() {
        _messages[index] = _messages[index].copyWith(
          status: DmMessageStatus.sent,
        );
      });
      unawaited(_cacheCurrentHistory());
    });

    Future.delayed(const Duration(seconds: 15), () {
      if (!mounted) return;
      final index = _messages.indexWhere((message) => message.id == localId);
      if (index < 0 ||
          _messages[index].id > 0 ||
          _messages[index].status != DmMessageStatus.sending) {
        return;
      }
      setState(() {
        _messages[index] = _messages[index].copyWith(
          status: DmMessageStatus.failed,
        );
      });
      unawaited(_cacheCurrentHistory());
    });
  }

  void _updateLocalMessageStatus(int localId, DmMessageStatus status) {
    final index = _messages.indexWhere((message) => message.id == localId);
    if (index < 0) return;
    setState(() {
      _messages[index] = _messages[index].copyWith(status: status);
    });
    unawaited(_cacheCurrentHistory());
  }

  void _goBack() {
    Navigator.pop(context, true);
  }

  Future<void> _cacheCurrentHistory() {
    return DmService.cacheHistory(
      conversationId: widget.conversation.id,
      messages: _messages,
    );
  }

  void _scrollToBottom({bool animated = true}) {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollController.hasClients) {
        if (animated) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(0);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1B2339) : const Color(0xFFF0F1F4);
    final appBarBgColor = isDark ? const Color(0xFF232D45) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarBgColor,
        elevation: 0.5,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: _goBack,
        ),
        title: Row(
          children: [
            _buildPeerAvatar(size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.conversation.targetName,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody(isDark)),
          _buildInputBar(isDark),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_error != null && _messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "消息加载失败",
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _loadHistory, child: const Text("重试")),
          ],
        ),
      );
    }
    if (_messages.isEmpty && _hasLoadedMessages) {
      return _buildEmptyState(isDark);
    }
    return _buildMessageList(isDark);
  }

  Widget _buildPeerAvatar({required double size}) {
    if (widget.conversation.targetAvatar.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: widget.conversation.targetAvatar,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorWidget: (context, url, error) => _buildTextAvatar(size),
        ),
      );
    }
    return _buildTextAvatar(size);
  }

  Widget _buildTextAvatar(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFFF5270), Color(0xFFFE2B54)],
        ),
      ),
      child: Center(
        child: Text(
          widget.conversation.targetName.isEmpty
              ? "?"
              : widget.conversation.targetName.substring(0, 1),
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.45,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: isDark ? Colors.white30 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            "发送第一条消息吧",
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white54 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(bool isDark) {
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[_messages.length - 1 - index];
        return _buildMessageBubble(msg, isDark);
      },
    );
  }

  Widget _buildMessageBubble(DmMessage msg, bool isDark) {
    final isMe = msg.isMe;
    final bubbleColor = isMe
        ? const Color(0xFFE91E63)
        : (isDark ? const Color(0xFF3A3F52) : Colors.white);
    final textColor = isMe
        ? Colors.white
        : (isDark ? Colors.white : Colors.black87);
    final timeColor = isMe
        ? Colors.white70
        : (isDark ? Colors.white38 : Colors.grey[500]);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Text(
                widget.conversation.targetName,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.grey,
                ),
              ),
            ),
          Row(
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isMe && msg.status == DmMessageStatus.failed)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.error, color: Color(0xFFFF2C55), size: 18),
                ),
              if (isMe && msg.status == DmMessageStatus.sending)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: isMe
                          ? const Radius.circular(18)
                          : const Radius.circular(4),
                      bottomRight: isMe
                          ? const Radius.circular(4)
                          : const Radius.circular(18),
                    ),
                    boxShadow: isMe
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                  ),
                  child: Text(
                    msg.displayContent,
                    style: TextStyle(
                      fontSize: 15,
                      color: textColor,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
              top: 4,
              left: isMe ? 0 : 12,
              right: isMe ? 12 : 0,
            ),
            child: Text(
              TimeUtil.formatRelativeTime(msg.createdAt),
              style: TextStyle(fontSize: 11, color: timeColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    final barBg = isDark ? const Color(0xFF232D45) : Colors.white;
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    return Container(
      color: barBg,
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: bottomSafe > 0 ? bottomSafe : 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 100),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                maxLines: null,
                textInputAction: TextInputAction.newline,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: "说点什么...",
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.grey[400],
                    fontSize: 15,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) {
              if (_textController.text.trim().isNotEmpty) {
                _sendMessage();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 38,
              height: 38,
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                color: _textController.text.trim().isEmpty
                    ? Colors.grey[400]
                    : const Color(0xFFE91E63),
                borderRadius: BorderRadius.circular(19),
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
