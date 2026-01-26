import 'package:flutter/material.dart';
import 'package:flutter_live/screens/home/live/real_live_page.dart';
import 'package:flutter_live/store/user_store.dart';
import '../../tools/HttpUtil.dart';

class AnchorInfo {
  final String roomId;
  final String name;
  final String avatarUrl;
  final String title;
  final bool isLive;

  final int roomMode;
  final String? pkStartTime;
  final int pkDuration;
  final int punishmentDuration;
  final int myScore;
  final int opScore;
  final int bossIndex;
  final int bgIndex;

  AnchorInfo({
    required this.roomId,
    required this.name,
    required this.avatarUrl,
    required this.title,
    required this.isLive,
    this.roomMode = 0,
    this.pkStartTime,
    this.pkDuration = 90,
    this.punishmentDuration = 20,
    this.myScore = 0,
    this.opScore = 0,
    this.bossIndex = 0,
    this.bgIndex = 0,
  });

  static int _parseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  factory AnchorInfo.fromJson(Map<String, dynamic> json) {
    return AnchorInfo(
      roomId: json['id'].toString(),
      name: json['title'] ?? "未知主播",
      avatarUrl: json['coverImg'] ?? "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/live_bg_1.png",
      title: json['aiPersona'] ?? "暂无介绍",
      isLive: _parseInt(json['status']) == 1,
      roomMode: _parseInt(json['roomMode'] ?? json['room_mode']),
      pkStartTime: json['pkStartTime'] ?? json['pk_start_time'],
      pkDuration: _parseInt(json['pkDuration'] ?? json['pk_duration'], defaultValue: 90),
      punishmentDuration: _parseInt(json['punishmentDuration'] ?? json['punishment_duration'], defaultValue: 20),
      myScore: _parseInt(json['pkMyScore'] ?? json['pk_my_score']),
      opScore: _parseInt(json['pkOpponentScore'] ?? json['pk_opponent_score']),
      bossIndex: _parseInt(json['pkBossIndex'] ?? json['pk_boss_index']),
      bgIndex: _parseInt(json['pkBgIndex'] ?? json['pk_bg_index']),
    );
  }
}

class LiveListPage extends StatefulWidget {
  const LiveListPage({super.key});

  @override
  State<LiveListPage> createState() => _LiveListPageState();
}

class _LiveListPageState extends State<LiveListPage> {
  List<AnchorInfo> _anchors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRoomList();
  }

  Future<void> _fetchRoomList() async {
    try {
      var responseData = await HttpUtil().get("/api/room/list");
      if (mounted) {
        setState(() {
          _anchors = (responseData as List).map((json) => AnchorInfo.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("直播列表", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchRoomList();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _anchors.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1, indent: 70),
              itemBuilder: (context, index) => _buildListItem(_anchors[index]),
            ),
    );
  }

  Widget _buildListItem(AnchorInfo anchor) {
    final bool isMyRoom = (UserStore.to.userAccountId == "2039" && anchor.roomId == "1001");

    // 🟢 1. 状态文本与图标逻辑
    String modeText = "直播中";
    IconData modeIcon = Icons.videocam; // 默认直播图标

    if (anchor.isLive) {
      switch (anchor.roomMode) {
        case 1:
          modeText = "PK中";
          modeIcon = Icons.bolt; // PK使用闪电图标
          break;
        case 2:
          modeText = "惩罚中";
          modeIcon = Icons.timer_3_sharp;
          break;
        case 3:
          modeText = "连线中";
          modeIcon = Icons.link; // 连线中换成链接图标
          break;
        default:
          modeText = "直播中";
          modeIcon = Icons.videocam;
      }
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // 🟢 2. 头像加红框且发光逻辑
      leading: Stack(
        alignment: Alignment.center,
        children: [
          if (anchor.isLive)
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFF0050), width: 2),
                boxShadow: [BoxShadow(color: const Color(0xFFFF0050).withOpacity(0.6), blurRadius: 10, spreadRadius: 2)],
              ),
            ),
          CircleAvatar(radius: 20, backgroundImage: NetworkImage(anchor.avatarUrl)),
        ],
      ),
      title: Text(anchor.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(anchor.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: anchor.isLive
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(modeIcon, color: const Color(0xFFFF0050), size: 20),
                const SizedBox(height: 2),
                Text(modeText, style: const TextStyle(color: Color(0xFFFF0050), fontSize: 10)),
              ],
            )
          : const Text("离线", style: TextStyle(color: Colors.grey, fontSize: 12)),
      onTap: () => _enterRoom(anchor, isHost: isMyRoom),
    );
  }

  void _enterRoom(AnchorInfo anchor, {required bool isHost}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RealLivePage(
          userId: UserStore.to.userId,
          userName: UserStore.to.userName,
          avatarUrl: UserStore.to.avatar,
          level: UserStore.to.userLevel,
          isHost: isHost,
          roomId: anchor.roomId,
          initialRoomData: {
            "roomMode": anchor.roomMode,
            "pkStartTime": anchor.pkStartTime,
            "pkDuration": anchor.pkDuration,
            "punishmentDuration": anchor.punishmentDuration,
            "myScore": anchor.myScore,
            "opScore": anchor.opScore,
            "bossIndex": anchor.bossIndex,
            "bgIndex": anchor.bgIndex,
          },
        ),
      ),
    );
  }
}
