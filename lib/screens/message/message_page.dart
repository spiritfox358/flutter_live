import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_live/screens/home/live/live_swipe_page.dart';
import 'package:flutter_live/screens/me/profile/user_profile_page.dart';
import 'package:flutter_live/screens/message/chat_detail_page.dart';
import 'package:flutter_live/screens/message/models/dm_conversation.dart';
import 'package:flutter_live/screens/message/services/dm_service.dart';
import 'package:flutter_live/screens/message/services/dm_socket_service.dart';
import 'package:flutter_live/screens/message/services/dm_unread_notifier.dart';
import 'package:flutter_live/tools/HttpUtil.dart';
import 'package:flutter_live/tools/time_util.dart';

class MessagePage extends StatefulWidget {
  const MessagePage({super.key});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessageStoryUser {
  final String userId;
  final String name;
  final String avatar;
  final String signature;
  final String roomId;
  final bool isLive;
  final Map<String, dynamic> rawJson;

  const _MessageStoryUser({
    required this.userId,
    required this.name,
    required this.avatar,
    required this.signature,
    required this.roomId,
    required this.isLive,
    required this.rawJson,
  });

  factory _MessageStoryUser.fromJson(Map<String, dynamic> json) {
    return _MessageStoryUser(
      userId: json['userId']?.toString() ?? '',
      name: (json['userName'] ?? '用户').toString(),
      avatar: (json['userAvatar'] ?? '').toString(),
      signature: (json['signature'] ?? '').toString(),
      roomId: json['roomId']?.toString() ?? '',
      isLive: json['isLive']?.toString() == '1',
      rawJson: json,
    );
  }
}

class _MessagePageState extends State<MessagePage> {
  static final List<DmConversation> _conversationCache = [];
  static bool _hasLoadedConversationCache = false;

  final List<_MessageStoryUser> _stories = [];
  final List<dynamic> _liveStoryRawList = [];
  final List<DmConversation> _conversations = [];
  StreamSubscription<DmSocketEvent>? _socketSub;
  bool _hasLoadedConversations = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _conversations.addAll(_conversationCache);
    _hasLoadedConversations = _hasLoadedConversationCache;
    unawaited(
      _restoreCachedConversations(fetchIfEmpty: true).then((_) {
        if (_conversations.isNotEmpty) {
          return _syncConversationsSilently();
        }
      }),
    );
    DmSocketService.instance.connect();
    _socketSub = DmSocketService.instance.events.listen(_handleSocketEvent);
    unawaited(_loadStories());
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    super.dispose();
  }

  Future<void> _restoreCachedConversations({
    bool force = false,
    bool fetchIfEmpty = false,
  }) async {
    final cached = await DmService.getCachedConversations();
    if (!mounted) return;
    if (cached.isEmpty) {
      setState(() => _hasLoadedConversations = true);
      if (fetchIfEmpty) _loadConversations();
      return;
    }
    if (!force && _conversations.isNotEmpty) {
      return;
    }
    setState(() {
      _conversations
        ..clear()
        ..addAll(cached);
      _conversationCache
        ..clear()
        ..addAll(cached);
      _hasLoadedConversations = true;
      _hasLoadedConversationCache = true;
    });
  }

  Future<void> _loadConversations() async {
    try {
      final list = await DmService.getConversations();
      if (!mounted) return;
      setState(() {
        _conversations
          ..clear()
          ..addAll(list);
        _conversationCache
          ..clear()
          ..addAll(list);
        _hasLoadedConversations = true;
        _hasLoadedConversationCache = true;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasLoadedConversations = true;
        _hasLoadedConversationCache = true;
        _error = _conversations.isEmpty ? e.toString() : null;
      });
    }
  }

  Future<void> _loadStories() async {
    try {
      final data = await HttpUtil().get('/api/relation/following_rooms');
      if (!mounted || data is! List) return;

      final stories = data
          .whereType<Map>()
          .map(
            (item) =>
                _MessageStoryUser.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.userId.isNotEmpty)
          .toList();
      final liveRawList = data
          .whereType<Map>()
          .where((item) => item['isLive']?.toString() == '1')
          .toList();

      setState(() {
        _stories
          ..clear()
          ..addAll(stories);
        _liveStoryRawList
          ..clear()
          ..addAll(liveRawList);
      });
    } catch (e) {
      debugPrint('加载消息页关注头像失败: $e');
    }
  }

  Future<void> _syncConversationsSilently() async {
    try {
      final remote = await DmService.getConversations(updateCache: false);
      if (!mounted || remote.isEmpty) return;

      final merged = _mergeConversations(_conversations, remote);
      if (!_hasConversationChanged(_conversations, merged)) return;

      setState(() {
        _conversations
          ..clear()
          ..addAll(merged);
        _conversationCache
          ..clear()
          ..addAll(merged);
        _hasLoadedConversations = true;
        _hasLoadedConversationCache = true;
        _error = null;
      });
      unawaited(DmService.cacheConversations(merged));
    } catch (e) {
      debugPrint('静默同步私信列表失败: $e');
    }
  }

  List<DmConversation> _mergeConversations(
    List<DmConversation> local,
    List<DmConversation> remote,
  ) {
    final byId = <int, DmConversation>{
      for (final conversation in local) conversation.id: conversation,
    };

    for (final incoming in remote) {
      final current = byId[incoming.id];
      if (current == null) {
        byId[incoming.id] = incoming;
        continue;
      }

      final currentTime =
          current.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final incomingTime =
          incoming.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);

      if (incomingTime.isAfter(currentTime) ||
          incoming.unreadCount != current.unreadCount ||
          incoming.isTop != current.isTop ||
          incoming.isMuted != current.isMuted) {
        byId[incoming.id] = incoming;
      }
    }

    return byId.values.toList()..sort((a, b) {
      if (a.isTop != b.isTop) return a.isTop ? -1 : 1;
      final aTime = a.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
  }

  bool _hasConversationChanged(
    List<DmConversation> before,
    List<DmConversation> after,
  ) {
    if (before.length != after.length) return true;
    for (var i = 0; i < before.length; i++) {
      final a = before[i];
      final b = after[i];
      if (a.id != b.id ||
          a.lastMessage != b.lastMessage ||
          a.lastSenderId != b.lastSenderId ||
          a.unreadCount != b.unreadCount ||
          a.isTop != b.isTop ||
          a.isMuted != b.isMuted ||
          a.lastMessageTime?.millisecondsSinceEpoch !=
              b.lastMessageTime?.millisecondsSinceEpoch) {
        return true;
      }
    }
    return false;
  }

  void _handleSocketEvent(DmSocketEvent event) {
    final message = event.message;
    if (message == null) return;

    final index = _conversations.indexWhere(
      (item) =>
          (event.conversationId != null && item.id == event.conversationId) ||
          (event.conversationId == null &&
              (item.targetId == message.senderId ||
                  item.targetId == message.receiverId)),
    );
    if (index < 0) {
      unawaited(_syncConversationsSilently());
      return;
    }

    final old = _conversations[index];
    final updated = old.copyWith(
      lastMessage: message.displayContent,
      lastMessageTime: message.createdAt,
      lastSenderId: message.senderId,
      unreadCount: event.type == 'DM_RECEIVED'
          ? (event.unreadCount ?? old.unreadCount + 1)
          : old.unreadCount,
    );

    setState(() {
      _conversations.removeAt(index);
      _insertConversation(updated);
      _conversationCache
        ..clear()
        ..addAll(_conversations);
    });
    unawaited(DmService.cacheConversations(_conversations));
  }

  void _insertConversation(DmConversation conversation) {
    final insertAt = _conversations.indexWhere((item) {
      if (conversation.isTop != item.isTop) {
        return conversation.isTop && !item.isTop;
      }
      final a =
          conversation.lastMessageTime ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final b = item.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return a.isAfter(b);
    });

    if (insertAt < 0) {
      _conversations.add(conversation);
    } else {
      _conversations.insert(insertAt, conversation);
    }
  }

  Future<void> _openConversation(DmConversation conversation) async {
    if (conversation.unreadCount > 0) {
      globalDmUnreadDeltaNotifier.value -= conversation.unreadCount;
    }
    unawaited(DmService.markConversationReadLocally(conversation.id));
    if (conversation.unreadCount > 0) {
      _replaceConversation(conversation.copyWith(unreadCount: 0));
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatDetailPage(conversation: conversation),
      ),
    );
    await _restoreCachedConversations(force: true);
  }

  void _replaceConversation(DmConversation conversation) {
    final index = _conversations.indexWhere(
      (item) => item.id == conversation.id,
    );
    if (index < 0) return;

    setState(() {
      _conversations[index] = conversation;
      _conversationCache
        ..clear()
        ..addAll(_conversations);
    });
    unawaited(DmService.cacheConversations(_conversations));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          "消息",
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildStoriesArea(isDark)),
          SliverToBoxAdapter(child: _buildSystemMessageItem(isDark)),
          if (_error != null && _conversations.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildErrorState(isDark),
            )
          else if (_conversations.isEmpty && _hasLoadedConversations)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(isDark),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    _buildConversationItem(_conversations[index], isDark),
                childCount: _conversations.length,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStoriesArea(bool isDark) {
    if (_stories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 110,
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: _stories.length,
        itemBuilder: (context, index) =>
            _buildStoryItem(_stories[index], isDark),
      ),
    );
  }

  Widget _buildStoryItem(_MessageStoryUser story, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        onTap: () => _openStoryUser(story),
        borderRadius: BorderRadius.circular(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFFF2C55),
                          Color(0xFFFE2B54),
                          Color(0xFFFF7B93),
                        ],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                    ),
                  ),
                  ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: story.avatar,
                      width: 58,
                      height: 58,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.person),
                      ),
                    ),
                  ),
                  if (story.isLive)
                    Positioned(
                      bottom: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF2C55), Color(0xFFFF5270)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? Colors.black : Colors.white,
                            width: 1.5,
                          ),
                        ),
                        child: const Text(
                          '直播中',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 70,
              child: Text(
                story.name,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 12,
                ),
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openStoryUser(_MessageStoryUser story) {
    if (story.isLive && story.roomId.isNotEmpty) {
      var activeIndex = _liveStoryRawList.indexWhere(
        (item) => item['roomId']?.toString() == story.roomId,
      );
      if (activeIndex < 0) activeIndex = 0;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LiveSwipePage(
            initialRoomList: _liveStoryRawList,
            initialIndex: activeIndex,
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfilePage(
          userInfo: {
            'userId': story.userId,
            'id': story.userId,
            'nickname': story.name,
            'avatar': story.avatar,
            'signature': story.signature,
          },
        ),
      ),
    );
  }

  Widget _buildSystemMessageItem(bool isDark) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFFF5270), Color(0xFFFE2B54)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: Icon(Icons.messenger, color: Colors.white, size: 28),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "互动消息",
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "点赞、评论和关注会出现在这里",
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.grey[500],
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationItem(DmConversation conversation, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.grey[500];
    final timeText = conversation.lastMessageTime == null
        ? ""
        : TimeUtil.formatRelativeTime(conversation.lastMessageTime!);

    return InkWell(
      onTap: () => _openConversation(conversation),
      onLongPress: () => _showConversationActions(conversation),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _buildConversationAvatar(conversation),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                conversation.targetName,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (conversation.isMuted)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.notifications_off_outlined,
                                  color: Colors.grey[400],
                                  size: 14,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        timeText,
                        style: TextStyle(color: subTextColor, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessage.isEmpty
                              ? "还没有消息"
                              : conversation.lastMessage,
                          style: TextStyle(color: subTextColor, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conversation.unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        _buildUnreadBadge(conversation.unreadCount),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationAvatar(DmConversation conversation) {
    if (conversation.targetAvatar.isEmpty) {
      return Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(
          color: Color(0xFFE91E63),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            conversation.targetName.isEmpty
                ? "?"
                : conversation.targetName.substring(0, 1),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: conversation.targetAvatar,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: Colors.grey[200]),
        errorWidget: (context, url, error) =>
            Container(color: Colors.grey[200], child: const Icon(Icons.person)),
      ),
    );
  }

  Widget _buildUnreadBadge(int count) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFF2C55),
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? "99+" : count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Text(
        "还没有私信",
        style: TextStyle(
          color: isDark ? Colors.white54 : Colors.grey[500],
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "消息加载失败",
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: _loadConversations, child: const Text("重试")),
        ],
      ),
    );
  }

  void _showConversationActions(DmConversation conversation) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  conversation.isTop
                      ? Icons.vertical_align_bottom
                      : Icons.vertical_align_top,
                ),
                title: Text(conversation.isTop ? "取消置顶" : "置顶会话"),
                onTap: () async {
                  Navigator.pop(context);
                  await DmService.toggleTop(conversation.id);
                  _loadConversations();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFFF2C55),
                ),
                title: const Text(
                  "删除会话",
                  style: TextStyle(color: Color(0xFFFF2C55)),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await DmService.deleteConversation(conversation.id);
                  _loadConversations();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
