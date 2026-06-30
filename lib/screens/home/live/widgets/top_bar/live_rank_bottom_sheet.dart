import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_live/screens/home/live/widgets/profile/live_user_profile_popup.dart';

import '../../../../../tools/HttpUtil.dart';

class LiveRankBottomSheet extends StatefulWidget {
  final String roomId;
  final ValueChanged<Map<String, dynamic>>? onEnterRoom;

  const LiveRankBottomSheet({
    super.key,
    required this.roomId,
    this.onEnterRoom,
  });

  static Future<void> show(
    BuildContext context, {
    required String roomId,
    ValueChanged<Map<String, dynamic>>? onEnterRoom,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          LiveRankBottomSheet(roomId: roomId, onEnterRoom: onEnterRoom),
    );
  }

  @override
  State<LiveRankBottomSheet> createState() => _LiveRankBottomSheetState();
}

class LiveRankPill extends StatelessWidget {
  final String roomId;
  final ValueChanged<Map<String, dynamic>>? onEnterRoom;

  const LiveRankPill({super.key, required this.roomId, this.onEnterRoom});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => LiveRankBottomSheet.show(
        context,
        roomId: roomId,
        onEnterRoom: onEnterRoom,
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 18,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '小时榜',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveRankBottomSheetState extends State<LiveRankBottomSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final Timer _timer;

  Duration _remain = _calcRemain();
  bool _loadingHour = true;
  bool _loadingPopular = true;
  List<_LiveRankRoom> _hourRooms = [];
  List<_LiveRankRoom> _popularRooms = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _remain = _calcRemain());
    });
    unawaited(_loadAnchorRanks());
  }

  @override
  void dispose() {
    _timer.cancel();
    _tabController.dispose();
    super.dispose();
  }

  static Duration _calcRemain() {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, now.hour + 1);
    return end.difference(now);
  }

  String get _countdownText {
    final minutes = _remain.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = _remain.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _loadAnchorRanks() async {
    try {
      final results = await Future.wait([
        HttpUtil().get('/api/giftLog/anchor_ranking', params: {'type': 'hour'}),
        HttpUtil().get(
          '/api/giftLog/anchor_ranking',
          params: {'type': 'popular'},
        ),
      ]);
      final hourRooms = _parseRooms(results[0], metric: _RankMetric.gift);
      final popularRooms = _parseRooms(
        results[1],
        metric: _RankMetric.popularity,
      );

      if (!mounted) return;
      setState(() {
        _hourRooms = hourRooms;
        _popularRooms = popularRooms;
        _loadingHour = false;
        _loadingPopular = false;
      });
    } catch (e) {
      debugPrint('加载主播榜失败: $e');
      if (mounted) {
        setState(() {
          _loadingHour = false;
          _loadingPopular = false;
        });
      }
    }
  }

  List<_LiveRankRoom> _parseRooms(dynamic data, {required _RankMetric metric}) {
    return data is List
        ? data
              .whereType<Map>()
              .map((item) => _LiveRankRoom.fromJson(item, metric: metric))
              .where((room) => room.anchorId.isNotEmpty)
              .toList()
        : <_LiveRankRoom>[];
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.62;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: Material(
        color: Colors.white,
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        labelColor: Colors.black,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: const Color(0xFFFF2E55),
                        indicatorWeight: 3,
                        dividerColor: Colors.transparent,
                        labelStyle: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                        tabs: const [
                          Tab(text: '小时榜'),
                          Tab(text: '人气榜'),
                        ],
                      ),
                    ),
                    Text(
                      '结榜 $_countdownText',
                      style: const TextStyle(
                        color: Color(0xFFFF2E55),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList(_hourRooms, _loadingHour, '本小时暂无主播上榜'),
                    _buildList(_popularRooms, _loadingPopular, '暂无主播人气数据'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<_LiveRankRoom> rooms, bool loading, String emptyText) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF2E55)),
      );
    }

    if (rooms.isEmpty) {
      return Center(
        child: Text(emptyText, style: const TextStyle(color: Colors.grey)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      itemCount: rooms.length,
      separatorBuilder: (context, index) => const SizedBox(height: 0),
      itemBuilder: (context, index) {
        final room = rooms[index];
        return _RankRow(
          room: room,
          rank: index + 1,
          onEnterRoom: widget.onEnterRoom,
        );
      },
    );
  }
}

class _RankRow extends StatelessWidget {
  final _LiveRankRoom room;
  final int rank;
  final ValueChanged<Map<String, dynamic>>? onEnterRoom;

  const _RankRow({
    required this.room,
    required this.rank,
    required this.onEnterRoom,
  });

  @override
  Widget build(BuildContext context) {
    final rankColor = switch (rank) {
      1 => const Color(0xFFFFC107),
      2 => const Color(0xFFB0BEC5),
      3 => const Color(0xFFCD7F32),
      _ => Colors.grey,
    };

    return InkWell(
      onTap: () =>
          LiveUserProfilePopup.show(context, {'userId': room.anchorId}),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: rankColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.of(context).pop();
                onEnterRoom?.call(room.toRoomData());
              },
              child: Container(
                width: 50,
                height: 50,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFF2E55), width: 2),
                ),
                child: CircleAvatar(
                  backgroundColor: const Color(0xFFF2F2F2),
                  backgroundImage: NetworkImage(room.avatar),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    room.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              room.scoreText,
              style: const TextStyle(
                color: Color(0xFFFF2E55),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveRankRoom {
  final String roomId;
  final String anchorId;
  final String title;
  final String avatar;
  final String description;
  final int onlineCount;
  final int totalLikes;
  final int giftScore;
  final int contributorCount;
  final int popularityScore;
  final int status;
  final int roomType;
  final _RankMetric metric;
  static const String _fallbackAvatar =
      'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/default_avatar.png';

  const _LiveRankRoom({
    required this.roomId,
    required this.anchorId,
    required this.title,
    required this.avatar,
    required this.description,
    required this.onlineCount,
    required this.totalLikes,
    required this.giftScore,
    required this.contributorCount,
    required this.popularityScore,
    required this.status,
    required this.roomType,
    required this.metric,
  });

  String get scoreText {
    if (metric == _RankMetric.gift) {
      return '${_formatScore(giftScore)} 收礼';
    }
    return '${_formatScore(popularityScore)} 热度';
  }

  String get subtitle {
    if (metric == _RankMetric.gift) {
      return '$contributorCount 人占榜 · $onlineCount 人在线';
    }
    return '$onlineCount 人在线 · $contributorCount 人占榜';
  }

  static _LiveRankRoom fromJson(
    Map<dynamic, dynamic> json, {
    required _RankMetric metric,
  }) {
    return _LiveRankRoom(
      roomId: (json['id'] ?? json['roomId'] ?? '').toString(),
      anchorId: (json['anchorId'] ?? json['ownerId'] ?? '').toString(),
      title: (json['title'] ?? json['userName'] ?? '主播').toString(),
      avatar: _readString(json['coverImg'] ?? json['avatar'], _fallbackAvatar),
      description: (json['aiPersona'] ?? json['signature'] ?? '').toString(),
      onlineCount: _asInt(json['onlineCount'] ?? json['online_count']),
      totalLikes: _asInt(json['totalLikes'] ?? json['total_likes']),
      giftScore: _asInt(json['giftScore'] ?? json['gift_score']),
      contributorCount: _asInt(
        json['contributorCount'] ?? json['contributor_count'],
      ),
      popularityScore: _asInt(
        json['popularityScore'] ?? json['popularity_score'],
      ),
      status: _asInt(json['status']),
      roomType: _asInt(json['roomType'] ?? json['room_type']),
      metric: metric,
    );
  }

  Map<String, dynamic> toRoomData() {
    return {
      'id': roomId,
      'roomId': roomId,
      'anchorId': anchorId,
      'userName': title,
      'title': title,
      'avatar': avatar,
      'coverImg': avatar,
      'roomType': roomType,
      'status': status,
    };
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _readString(dynamic value, String fallback) {
    final text = value?.toString() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String _formatScore(int score) {
    if (score >= 10000) return '${(score / 10000).toStringAsFixed(1)}w';
    return score.toString();
  }
}

enum _RankMetric { gift, popularity }
