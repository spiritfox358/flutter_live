import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_live/screens/home/live/widgets/pk_score_bar_widgets.dart';
import 'package:flutter_live/screens/home/live/widgets/avatar_animation.dart';
import 'package:media_kit_video/media_kit_video.dart';
class LivePKPlayerModel {
  final String userId;
  final String roomId;
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

  // 🚀 把 media_kit 的灵魂加回来！每个玩家自带自己的画面控制器！
  final VideoController? videoController;

  final List<String> activeBuffs;

  LivePKPlayerModel({
    required this.userId,
    required this.roomId,
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
    this.videoController, // 🚀 构造函数加回来
  });
}

class DynamicPKBattleView extends StatelessWidget {
  final List<LivePKPlayerModel> players;
  final PKStatus pkStatus;
  final Function(LivePKPlayerModel)? onTapPlayer;
  final String currentRoomId;
  final String? focusedRoomId;

  // 🚀 1. 接收外部的开关
  final bool useVideoMode;

  const DynamicPKBattleView({
    super.key,
    required this.players,
    this.onTapPlayer,
    this.pkStatus = PKStatus.idle,
    required this.currentRoomId,
    this.focusedRoomId,
    this.useVideoMode = false,
  });

  final double dividerThickness = 1.0;
  final Color dividerColor = Colors.black;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) return const SizedBox.shrink();

    final sortedPlayers = List<LivePKPlayerModel>.from(players);
    sortedPlayers.sort((a, b) {
      bool isMainAnchorA = a.roomId == currentRoomId;
      bool isMainAnchorB = b.roomId == currentRoomId;

      if (isMainAnchorA && !isMainAnchorB) return -1;
      if (!isMainAnchorA && isMainAnchorB) return 1;

      if (a.isMyTeam && !b.isMyTeam) return -1;
      if (!a.isMyTeam && b.isMyTeam) return 1;

      return 0;
    });

    if (focusedRoomId != null && sortedPlayers.any((p) => p.roomId == focusedRoomId)) {
      return Container(color: dividerColor, child: _buildFocusLayout(sortedPlayers, focusedRoomId!));
    } else {
      return Container(color: dividerColor, child: _buildDynamicPKGrid(sortedPlayers));
    }
  }

  Widget _buildFocusLayout(List<LivePKPlayerModel> sortedList, String focusId) {
    final focusedPlayer = sortedList.firstWhere((p) => p.roomId == focusId);
    final otherPlayers = sortedList.where((p) => p.roomId != focusId).toList();

    return Stack(
      fit: StackFit.expand,
      children: [
        _CellWrapper(
          player: focusedPlayer,
          pkStatus: pkStatus,
          currentRoomId: currentRoomId,
          allPlayers: players,
          onTap: onTapPlayer,
          useVideoMode: useVideoMode, // ✅ 这里你原本有传
        ),
        if (otherPlayers.isNotEmpty)
          Positioned(
            right: 8,
            bottom: 45,
            child: SizedBox(
              height: 110,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: otherPlayers.map((p) {
                    return Container(
                      width: 80,
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white54, width: 1.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: _CellWrapper(
                        player: p,
                        pkStatus: pkStatus,
                        currentRoomId: currentRoomId,
                        allPlayers: players,
                        onTap: onTapPlayer,
                        useVideoMode: useVideoMode, // 🚀 补齐：水平滚动里也要传！
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDynamicPKGrid(List<LivePKPlayerModel> sortedList) {
    int count = sortedList.length;
    switch (count) {
      case 2: return _buildFlexGrid([2], sortedList);
      case 3: return _build3PersonLayout(sortedList);
      case 4: return _buildFlexGrid([2, 2], sortedList);
      case 5: return _buildFlexGrid([2, 3], sortedList);
      case 6: return _buildFlexGrid([3, 3], sortedList);
      case 7: return _buildFlexGrid([3, 4], sortedList);
      case 8: return _buildFlexGrid([4, 4], sortedList);
      case 9: return _buildFlexGrid([3, 3, 3], sortedList);
      default: return const Center(child: Text('仅支持 2-9 人', style: TextStyle(color: Colors.white)));
    }
  }

  Widget _vDivider() => Container(width: dividerThickness, color: dividerColor);
  Widget _hDivider() => Container(height: dividerThickness, color: dividerColor);

  Widget _build3PersonLayout(List<LivePKPlayerModel> sortedList) {
    return Row(
      children: [
        Expanded(flex: 1, child: _CellWrapper(player: sortedList[0], pkStatus: pkStatus, currentRoomId: currentRoomId, allPlayers: players, onTap: onTapPlayer, useVideoMode: useVideoMode)), // 🚀 补齐
        _vDivider(),
        Expanded(
          flex: 1,
          child: Column(
            children: [
              Expanded(flex: 1, child: _CellWrapper(player: sortedList[1], pkStatus: pkStatus, currentRoomId: currentRoomId, allPlayers: players, onTap: onTapPlayer, useVideoMode: useVideoMode)), // 🚀 补齐
              _hDivider(),
              Expanded(flex: 1, child: _CellWrapper(player: sortedList[2], pkStatus: pkStatus, currentRoomId: currentRoomId, allPlayers: players, onTap: onTapPlayer, useVideoMode: useVideoMode)), // 🚀 补齐
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFlexGrid(List<int> rowConfigs, List<LivePKPlayerModel> sortedList) {
    List<Widget> rows = [];
    int playerIndex = 0;
    for (int i = 0; i < rowConfigs.length; i++) {
      int colsInThisRow = rowConfigs[i];
      List<Widget> rowChildren = [];
      for (int j = 0; j < colsInThisRow; j++) {
        if (playerIndex < sortedList.length) {
          rowChildren.add(
            Expanded(child: _CellWrapper(player: sortedList[playerIndex], pkStatus: pkStatus, currentRoomId: currentRoomId, allPlayers: players, onTap: onTapPlayer, useVideoMode: useVideoMode)), // 🚀 补齐
          );
          if (j < colsInThisRow - 1) rowChildren.add(_vDivider());
          playerIndex++;
        }
      }
      rows.add(Expanded(child: Row(children: rowChildren)));
      if (i < rowConfigs.length - 1) rows.add(_hDivider());
    }
    return Column(children: rows);
  }
}


class _CellWrapper extends StatefulWidget {
  final LivePKPlayerModel player;
  final PKStatus pkStatus;
  final String currentRoomId;
  final List<LivePKPlayerModel> allPlayers;
  final Function(LivePKPlayerModel)? onTap;

  // 🚀 1. 这里必须声明这个变量！
  final bool useVideoMode;

  const _CellWrapper({
    super.key,
    required this.player,
    required this.pkStatus,
    required this.currentRoomId,
    required this.allPlayers,
    this.onTap,

    // 🚀 2. 构造函数里必须接收它！默认给个 false
    this.useVideoMode = false,
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
    // 🚀 1. 首次渲染时，立刻对底层播放器下达管控指令！
    _syncPlayerState();
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

    // 🚀 2. 核心大管家：只要模式切换、控制器更换、或者你点击了“闭麦”，立刻同步给底层！
    if (oldWidget.useVideoMode != widget.useVideoMode ||
        oldWidget.player.videoController != widget.player.videoController ||
        oldWidget.player.isMuted != widget.player.isMuted) {
      _syncPlayerState();
    }
  }

  // 🚀🚀🚀 3. 物理级管控 media_kit 引擎
  void _syncPlayerState() {
    final player = widget.player.videoController?.player;
    if (player == null) return;

    if (widget.useVideoMode) {
      // 🟢 视频模式：确保机器运转，并根据业务的 isMuted 决定是否物理静音
      player.play();
      player.setVolume(widget.player.isMuted ? 0.0 : 100.0);
    } else {
      // 🔴 纯头像模式：强行物理静音，并直接拔掉 C++ 引擎的电源（pause）！
      // 彻底掐断声音，顺便把 CPU 占用降到 0！
      player.setVolume(0.0);
      player.pause();
    }
  }

  void _startCarousel() {
    _timer?.cancel();
    if (widget.player.activeBuffs.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
        if (mounted) {
          setState(() {
            _tick++;
          });
        }
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
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
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
          Text("房主", style: TextStyle(color: Colors.white, fontSize: 9.0, fontWeight: FontWeight.bold, height: 1.1)),
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
          border: isHighest ? Border.all(color: player.isMyTeam ? const Color(0xFFFF2E56).withAlpha(180) : const Color(0xFF2962FF).withAlpha(180), width: 0.8) : null,
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
                color: isBattleState ? (player.isMyTeam ? const Color(0xFFD32F2F).withAlpha(100) : const Color(0xFF1565C0).withAlpha(100)) : Colors.white24,
              ),
              child: Center(child: Text('${player.rank}', style: const TextStyle(color: Colors.white, fontSize: 9.0, fontWeight: FontWeight.bold, height: 1.1))),
            ),
            const SizedBox(width: 4),
            Text(
              displayScore,
              style: TextStyle(color: Colors.white, fontSize: 10.0, fontWeight: FontWeight.w600, height: 1.1, shadows: isHighest ? [const Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(0, 1))] : null),
            ),
          ],
        ),
      );
    }

    bool needsBottomGradient = !isMainAnchor || (isMainAnchor && (player.isInitiator || (hasActiveBuffs && showScoreBadge)));

    return GestureDetector(
      onTap: () {
        if (widget.onTap != null) widget.onTap!(player);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(color: Colors.black),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildMediaContent(player),

            if (needsBottomGradient)
              Positioned(left: 0, right: 0, bottom: 0, child: Container(height: 40.0, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.6), Colors.transparent])))),

            if (isMainAnchor && hasActiveBuffs)
              Positioned(top: 0.0, left: 0.0, child: AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: _buildBuffGradientLabel(currentBuffText, player.isMyTeam, key: ValueKey(currentIndex))))
            else if (showScoreBadge)
              Positioned(top: 4.0, left: 4.0, child: buildScoreBadgeWidget()),

            if (player.isMuted) const Positioned(top: 6, right: 6, child: Icon(Icons.mic_off_outlined, color: Colors.white70, size: 16.0)),

            if (isMainAnchor && (player.isInitiator || (hasActiveBuffs && showScoreBadge)))
              Positioned(
                bottom: 4.0, left: 4.0,
                child: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (player.isInitiator) Padding(padding: EdgeInsets.only(bottom: (hasActiveBuffs && showScoreBadge) ? 4.0 : 0.0), child: _buildInitiatorLabel(player.isMyTeam)),
                    if (hasActiveBuffs && showScoreBadge) buildScoreBadgeWidget(),
                  ],
                ),
              )
            else if (!isMainAnchor)
              Positioned(
                bottom: 4.0, left: 4.0, right: 4.0,
                child: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
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
                            Flexible(flex: 1, fit: FlexFit.loose, child: SizedBox(height: 14.0, child: Align(alignment: Alignment.centerLeft, widthFactor: 1.0, child: Text(player.name, style: const TextStyle(color: Colors.white, fontSize: 10.0, fontWeight: FontWeight.w500, height: 1.1, leadingDistribution: TextLeadingDistribution.even), maxLines: 1, softWrap: false, overflow: TextOverflow.clip)))),
                            if (hasActiveBuffs) ...[
                              Container(width: 1, height: 10, margin: const EdgeInsets.symmetric(horizontal: 4), color: Colors.white38),
                              Flexible(flex: 0, child: AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: Container(height: 14.0, alignment: Alignment.center, child: Text(currentBuffText, key: ValueKey(currentIndex), style: const TextStyle(color: Colors.yellowAccent, fontSize: 10.0, fontWeight: FontWeight.bold, height: 1.1, leadingDistribution: TextLeadingDistribution.even), maxLines: 1, softWrap: false, overflow: TextOverflow.visible)))),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaContent(LivePKPlayerModel player) {
    if (widget.useVideoMode && player.videoController != null) {
      Widget videoWidget = Video(controller: player.videoController!, fit: BoxFit.cover, controls: NoVideoControls);
      if (player.isPunished) return RepaintBoundary(child: ColorFiltered(colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation), child: videoWidget));
      return RepaintBoundary(child: videoWidget);
    }

    double avatarPadding = 12.0;
    if (widget.allPlayers.length == 9) avatarPadding = 18.0;
    else if (widget.allPlayers.length >= 7) avatarPadding = 5.0;

    Widget fallbackContent = Stack(
      fit: StackFit.expand,
      children: [
        Image.network(player.avatarUrl, fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => Container(color: Colors.grey[900])),
        BackdropFilter(filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0), child: Container(color: Colors.black.withOpacity(0.5))),
        Center(
          child: Padding(
            padding: EdgeInsets.all(avatarPadding),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 125.0, maxHeight: 125.0),
              child: FittedBox(fit: BoxFit.scaleDown, child: AvatarAnimation(avatarUrl: player.avatarUrl, isSpeaking: player.isSpeaking, isRotating: false)),
            ),
          ),
        ),
      ],
    );

    if (player.isPunished) return RepaintBoundary(child: ColorFiltered(colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation), child: fallbackContent));
    return RepaintBoundary(child: fallbackContent);
  }
}