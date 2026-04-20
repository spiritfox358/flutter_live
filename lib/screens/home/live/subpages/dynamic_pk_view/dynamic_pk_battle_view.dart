import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_live/screens/home/live/widgets/pk_score_bar_widgets.dart';
import 'package:flutter_live/screens/home/live/widgets/avatar_animation.dart';

import '../../trtc_manager.dart';

class LivePKPlayerModel {
  final String userId;
  final String roomId;
  final String pkId;
  final String name;
  final String avatarUrl;
  final int rank;
  final int score;
  final bool isMuted;
  final String? propText;
  final bool isPunished;
  final bool isSpeaking;
  final bool isMyTeam;
  final bool isInitiator;
  final List<String> activeBuffs;

  final bool isCameraOn;

  LivePKPlayerModel({
    required this.userId,
    required this.roomId,
    required this.pkId,
    required this.name,
    required this.avatarUrl,
    required this.rank,
    required this.score,
    this.isMuted = false,
    this.propText,
    this.isPunished = false,
    this.isSpeaking = false,
    this.isMyTeam = false,
    this.isInitiator = false,
    this.activeBuffs = const [],
    this.isCameraOn = true,
  });
}

class DynamicPKBattleView extends StatefulWidget {
  final List<LivePKPlayerModel> players;
  final PKStatus pkStatus;
  final Function(LivePKPlayerModel)? onTapPlayer;
  final String currentRoomId;
  final String currentUserId;
  final String? focusedRoomId;
  final bool useVideoMode;

  // 🚀🚀🚀 修复：在这里补上外层的参数定义！
  final Set<String> activeVideoUsers;

  const DynamicPKBattleView({
    super.key,
    required this.players,
    this.onTapPlayer,
    this.pkStatus = PKStatus.idle,
    required this.currentRoomId,
    required this.currentUserId,
    this.focusedRoomId,
    this.useVideoMode = false,
    this.activeVideoUsers = const {}, // 🚀 默认空集合
  });

  @override
  State<DynamicPKBattleView> createState() => _DynamicPKBattleViewState();
}

class _DynamicPKBattleViewState extends State<DynamicPKBattleView> {
  List<List<double>> _currentLayouts = [];

  String _getStableId(LivePKPlayerModel p) {
    return "cell_${p.roomId}_${p.userId}";
  }

  @override
  void initState() {
    super.initState();
    _recalculateLayouts();
  }

  @override
  void didUpdateWidget(DynamicPKBattleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.players.length != widget.players.length || oldWidget.focusedRoomId != widget.focusedRoomId) {
      _recalculateLayouts();
    }
  }

  List<LivePKPlayerModel> _getSortedPlayers() {
    final sortedPlayers = List<LivePKPlayerModel>.from(widget.players);
    sortedPlayers.sort((a, b) {
      bool isMainAnchorA = a.roomId == widget.currentRoomId;
      bool isMainAnchorB = b.roomId == widget.currentRoomId;
      if (isMainAnchorA && !isMainAnchorB) return -1;
      if (!isMainAnchorA && isMainAnchorB) return 1;
      if (a.isMyTeam && !b.isMyTeam) return -1;
      if (!a.isMyTeam && b.isMyTeam) return 1;
      return _getStableId(a).compareTo(_getStableId(b));
    });
    return sortedPlayers;
  }

  void _recalculateLayouts() {
    if (widget.players.isEmpty) return;
    final sortedPlayers = _getSortedPlayers();

    if (widget.focusedRoomId != null && sortedPlayers.any((p) => p.roomId == widget.focusedRoomId)) {
      int focusIndex = sortedPlayers.indexWhere((p) => p.roomId == widget.focusedRoomId);
      _currentLayouts = _generateFocusLayouts(sortedPlayers, focusIndex);
    } else {
      _currentLayouts = _generateGridLayouts(sortedPlayers.length);
    }
    setState(() {});
  }

  List<List<double>> _generateFocusLayouts(List<LivePKPlayerModel> players, int focusIndex) {
    List<List<double>> layouts = List.filled(players.length, []);
    if (players.length <= 1)
      return [
        [0.0, 0.0, 1.0, 1.0],
      ];

    double subW = 1.0 / 3.0;
    double normalSubH = 1.0 / 6.0;
    double hostSubH = 1.0 / 3.0;

    int hostSubIndex = -1;
    List<int> normalSubIndices = [];

    for (int i = 0; i < players.length; i++) {
      if (i == focusIndex) continue;
      if (players[i].isInitiator) {
        hostSubIndex = i;
      } else {
        normalSubIndices.add(i);
      }
    }

    double currentBottomY = 1.0;
    int bottomIdx = 0;

    if (hostSubIndex != -1) {
      currentBottomY -= hostSubH;
      layouts[hostSubIndex] = [2.0 / 3.0, currentBottomY, subW, hostSubH];
    }

    List<List<double>> bottomSlots = [
      [1.0 / 3.0, 5.0 / 6.0],
      [0.0, 5.0 / 6.0],
      [1.0 / 3.0, 4.0 / 6.0],
      [0.0, 4.0 / 6.0],
    ];

    for (int i in normalSubIndices) {
      if (currentBottomY - normalSubH >= -0.001) {
        currentBottomY -= normalSubH;
        layouts[i] = [2.0 / 3.0, currentBottomY, subW, normalSubH];
      } else {
        if (bottomIdx < bottomSlots.length) {
          layouts[i] = [bottomSlots[bottomIdx][0], bottomSlots[bottomIdx][1], subW, normalSubH];
          bottomIdx++;
        } else {
          layouts[i] = [-1.0, -1.0, 0.0, 0.0];
        }
      }
    }

    bool isRightFull = currentBottomY <= 0.001;
    bool isBottomFull = bottomIdx >= 2;
    double mainW = isRightFull ? (2.0 / 3.0) : 1.0;
    double mainH = isBottomFull ? (5.0 / 6.0) : 1.0;

    layouts[focusIndex] = [0.0, 0.0, mainW, mainH];
    return layouts;
  }

  List<List<double>> _generateGridLayouts(int count) {
    if (count == 3) {
      return [
        [0.0, 0.0, 0.5, 1.0],
        [0.5, 0.0, 0.5, 0.5],
        [0.5, 0.5, 0.5, 0.5],
      ];
    }
    List<int> rowConfigs = [];
    switch (count) {
      case 2:
        rowConfigs = [2];
        break;
      case 4:
        rowConfigs = [2, 2];
        break;
      case 5:
        rowConfigs = [2, 3];
        break;
      case 6:
        rowConfigs = [3, 3];
        break;
      case 7:
        rowConfigs = [3, 4];
        break;
      case 8:
        rowConfigs = [4, 4];
        break;
      case 9:
        rowConfigs = [3, 3, 3];
        break;
      default:
        rowConfigs = [1];
    }
    List<List<double>> layouts = [];
    int numRows = rowConfigs.length;
    double h = 1.0 / numRows;
    for (int i = 0; i < numRows; i++) {
      int cols = rowConfigs[i];
      double w = 1.0 / cols;
      double y = i * h;
      for (int j = 0; j < cols; j++) {
        layouts.add([j * w, y, w, h]);
      }
    }
    return layouts;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.players.isEmpty) return const SizedBox.shrink();
    final sortedPlayers = _getSortedPlayers();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth.isInfinite ? MediaQuery.of(context).size.width : constraints.maxWidth;
        final double h = constraints.maxHeight.isInfinite ? MediaQuery.of(context).size.height : constraints.maxHeight;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            ...List.generate(sortedPlayers.length, (index) {
              if (index >= _currentLayouts.length) return const SizedBox.shrink();
              final layout = _currentLayouts[index];

              if (layout[0] < 0) return const SizedBox.shrink();

              return AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                left: layout[0] * w,
                top: layout[1] * h,
                width: layout[2] * w,
                height: layout[3] * h,
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Colors.black, width: 0.5),
                      right: BorderSide(color: Colors.black, width: 0.5),
                      bottom: BorderSide(color: Colors.black, width: 0.5),
                    ),
                  ),
                  child: _CellWrapper(
                    key: ValueKey(_getStableId(sortedPlayers[index])),
                    player: sortedPlayers[index],
                    pkStatus: widget.pkStatus,
                    currentRoomId: widget.currentRoomId,
                    currentUserId: widget.currentUserId,

                    // 🚀🚀🚀 修复：把外层接收到的集合，稳稳地传给内部的每个小格子！
                    activeVideoUsers: widget.activeVideoUsers,

                    allPlayers: widget.players,
                    onTap: widget.onTapPlayer,
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _CellWrapper extends StatefulWidget {
  final LivePKPlayerModel player;
  final PKStatus pkStatus;
  final String currentRoomId;
  final String currentUserId;
  final List<LivePKPlayerModel> allPlayers;
  final Function(LivePKPlayerModel)? onTap;
  final Set<String> activeVideoUsers; // 🚀 内层接收定义

  const _CellWrapper({
    super.key,
    required this.player,
    required this.pkStatus,
    required this.currentRoomId,
    required this.currentUserId,
    required this.allPlayers,
    this.onTap,
    this.activeVideoUsers = const {},
  });

  @override
  State<_CellWrapper> createState() => _CellWrapperState();
}

class _CellWrapperState extends State<_CellWrapper> {
  int _tick = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCarousel();
  }

  @override
  void didUpdateWidget(covariant _CellWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.player.activeBuffs.length <= 1) {
      _timer?.cancel();
      _timer = null;
    } else if (_timer == null || !_timer!.isActive) {
      _startCarousel();
    }
  }

  void _startCarousel() {
    _timer?.cancel();
    if (widget.player.activeBuffs.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
        if (mounted) setState(() => _tick++);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _buildBuffGradientLabel(String text, bool isMyTeam, {Key? key}) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: isMyTeam ? Alignment.centerLeft : Alignment.centerRight,
          end: isMyTeam ? Alignment.centerRight : Alignment.centerLeft,
          colors: isMyTeam ? [const Color(0xFFFF2E56), Colors.transparent] : [const Color(0xFF2962FF), Colors.transparent],
          stops: const [0.1, 1.0],
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isMyTeam) const Icon(Icons.arrow_back_ios, size: 7, color: Colors.white),
          if (!isMyTeam) const SizedBox(width: 2),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
          ),
          if (isMyTeam) const SizedBox(width: 2),
          if (isMyTeam) const Icon(Icons.arrow_forward_ios, size: 7, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildInitiatorLabel(bool isMyTeam) {
    return Container(
      height: 18.0,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isMyTeam
              ? [const Color(0xFFFF2E56).withAlpha(120), const Color(0xFFFF5252).withAlpha(120)]
              : [const Color(0xFF2962FF).withAlpha(120), const Color(0xFF448AFF).withAlpha(120)],
        ),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: const [
          Text(
            "房主",
            style: TextStyle(color: Colors.white, fontSize: 9.0, fontWeight: FontWeight.bold, height: 1.1),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    bool isMainAnchor = player.roomId == widget.currentRoomId;
    bool hasActiveBuffs = player.activeBuffs.isNotEmpty;
    int currentIndex = hasActiveBuffs ? (_tick % player.activeBuffs.length) : 0;
    String currentBuffText = hasActiveBuffs ? player.activeBuffs[currentIndex] : "";

    bool isBattleState = widget.pkStatus == PKStatus.playing || widget.pkStatus == PKStatus.punishment;
    bool isCoHostState = widget.pkStatus == PKStatus.coHost || widget.pkStatus == PKStatus.idle || widget.pkStatus == PKStatus.matching;
    bool showScoreBadge = isCoHostState || widget.allPlayers.length > 2;

    int highestScore = 0;
    for (var p in widget.allPlayers) {
      if (p.score > highestScore) highestScore = p.score;
    }
    bool isHighest = isBattleState && player.score == highestScore && highestScore > 0;

    Color getBadgeColor(double opacity, {bool isForScore = false}) {
      if (isCoHostState) return Colors.black.withOpacity(0.4);
      if (isForScore && isHighest) return Colors.orange.withOpacity(0.8);
      return player.isMyTeam ? const Color(0xFFFF2E56).withOpacity(opacity) : const Color(0xFF2962FF).withOpacity(opacity);
    }

    Widget buildScoreBadgeWidget() {
      String displayScore = player.score.toString();
      if (player.score >= 1000000) {
        displayScore = isMainAnchor ? "${(player.score / 10000.0).toStringAsFixed(1)}万" : "100万+";
      }

      return Container(
        height: 18.0,
        padding: const EdgeInsets.only(left: 2, right: 6),
        decoration: BoxDecoration(
          color: getBadgeColor(0.3, isForScore: true),
          borderRadius: BorderRadius.circular(12.0),
          border: isHighest
              ? Border.all(color: player.isMyTeam ? const Color(0xFFFF2E56).withAlpha(180) : const Color(0xFF2962FF).withAlpha(180), width: 0.8)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 14.0,
              height: 14.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isBattleState
                    ? (player.isMyTeam ? const Color(0xFFD32F2F).withAlpha(100) : const Color(0xFF1565C0).withAlpha(100))
                    : Colors.white24,
              ),
              child: Center(
                child: Text(
                  '${player.rank}',
                  style: const TextStyle(color: Colors.white, fontSize: 9.0, fontWeight: FontWeight.bold, height: 1.1),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              displayScore,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.0,
                fontWeight: FontWeight.w600,
                height: 1.1,
                shadows: isHighest ? [const Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(0, 1))] : null,
              ),
            ),
          ],
        ),
      );
    }

    bool needsBottomGradient = !isMainAnchor || (isMainAnchor && (player.isInitiator || (hasActiveBuffs && showScoreBadge)));

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(color: Color(0xFF1B1B1B)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 最底层：视频内容 / 头像占位图
          _buildMediaContent(player),

          // 2. 透明的“玻璃遮罩层”拦截手势
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (widget.onTap != null) widget.onTap!(player);
              },
              child: Container(color: Colors.transparent),
            ),
          ),

          // 3. UI 浮层
          if (needsBottomGradient)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  height: 40.0,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),

          if (isMainAnchor && hasActiveBuffs)
            Positioned(
              top: 0.0,
              left: 0.0,
              child: IgnorePointer(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildBuffGradientLabel(currentBuffText, player.isMyTeam, key: ValueKey(currentIndex)),
                ),
              ),
            )
          else if (showScoreBadge)
            Positioned(top: 4.0, left: 4.0, child: IgnorePointer(child: buildScoreBadgeWidget())),

          if (player.isMuted)
            const Positioned(
              top: 6,
              right: 6,
              child: IgnorePointer(child: Icon(Icons.mic_off_outlined, color: Colors.white70, size: 16.0)),
            ),

          if (isMainAnchor && (player.isInitiator || (hasActiveBuffs && showScoreBadge)))
            Positioned(
              bottom: 4.0,
              left: 4.0,
              child: IgnorePointer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (player.isInitiator)
                      Padding(
                        padding: EdgeInsets.only(bottom: (hasActiveBuffs && showScoreBadge) ? 4.0 : 0.0),
                        child: _buildInitiatorLabel(player.isMyTeam),
                      ),
                    if (hasActiveBuffs && showScoreBadge) buildScoreBadgeWidget(),
                  ],
                ),
              ),
            )
          else if (!isMainAnchor)
            Positioned(
              bottom: 4.0,
              left: 4.0,
              right: 4.0,
              child: IgnorePointer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (player.isInitiator) Padding(padding: const EdgeInsets.only(bottom: 2.0), child: _buildInitiatorLabel(player.isMyTeam)),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: BoxDecoration(color: getBadgeColor(0.4, isForScore: false), borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              flex: 1,
                              fit: FlexFit.loose,
                              child: SizedBox(
                                height: 14.0,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: 1.0,
                                  child: Text(
                                    player.name,
                                    style: const TextStyle(color: Colors.white, fontSize: 10.0, fontWeight: FontWeight.w500, height: 1.1),
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.clip,
                                  ),
                                ),
                              ),
                            ),
                            if (hasActiveBuffs) ...[
                              Container(width: 1, height: 10, margin: const EdgeInsets.symmetric(horizontal: 4), color: Colors.white38),
                              Flexible(
                                flex: 0,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: Container(
                                    height: 14.0,
                                    alignment: Alignment.center,
                                    child: Text(
                                      currentBuffText,
                                      key: ValueKey(currentIndex),
                                      style: const TextStyle(color: Colors.yellowAccent, fontSize: 10.0, fontWeight: FontWeight.bold, height: 1.1),
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.visible,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMediaContent(LivePKPlayerModel player) {
    bool isMe = player.userId == widget.currentUserId;

    bool hasVideoStream = isMe ? player.isCameraOn : widget.activeVideoUsers.contains(player.userId);

    // 🛑 保护机制：如果没有视频流，渲染绝美的毛玻璃头像！
    if (!hasVideoStream) {
      return LayoutBuilder(
        builder: (context, constraints) {
          // 1. 默认恢复你最原始的代码参数，绝对不自适应！
          double avatarPadding = widget.allPlayers.length >= 7 ? 12.0 : 20.0;
          double avatarSize = 120.0;

          // 🚀🚀🚀 核心拦截：只针对“半个格子”（1/6高度的扁格子，通常高度在 60~80px 左右）
          if (constraints.maxHeight < 100.0) {
            avatarPadding = 0.0; // 把内边距缩到极小，腾出空间
            avatarSize = constraints.maxHeight - (avatarPadding * 2); // 头像刚好塞满这个扁格子
          }

          Widget fallbackContent = Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                player.avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => Container(color: Colors.grey[900]),
              ),
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                child: Container(color: Colors.black.withOpacity(0.5)),
              ),
              Center(
                child: Padding(
                  padding: EdgeInsets.all(avatarPadding),
                  child: ConstrainedBox(
                    // 🚀 正常格子永远锁死 120，只有半个格子才会用算出来的专属大小
                    constraints: BoxConstraints(maxWidth: avatarSize, maxHeight: avatarSize),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: AvatarAnimation(avatarUrl: player.avatarUrl, isSpeaking: player.isSpeaking, isRotating: false),
                    ),
                  ),
                ),
              ),
            ],
          );

          if (player.isPunished) {
            fallbackContent = ColorFiltered(colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation), child: fallbackContent);
          }
          return fallbackContent;
        },
      );
    }

    // 🎥 正常渲染视频流
    Widget videoWidget;
    if (isMe) {
      videoWidget = TRTCManager().getLocalVideoWidget();
    } else {
      videoWidget = TRTCManager().getRemoteVideoWidget(player.userId);
    }

    if (player.isPunished) {
      videoWidget = ColorFiltered(colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation), child: videoWidget);
    }

    return videoWidget;
  }
}
