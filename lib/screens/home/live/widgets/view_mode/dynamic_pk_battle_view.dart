import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_live/screens/home/live/widgets/pk_score_bar_widgets.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_live/screens/home/live/widgets/avatar_animation.dart';

// ==========================================
// 📦 1. 真实业务数据模型
// ==========================================
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
  final VideoPlayerController? videoController;

  // 用于存放所有道具状态的数组
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
    this.videoController,
    this.activeBuffs = const [],
  });
}

// ==========================================
// 🎨 2. 真实业务网格组件 (包含焦点放大模式)
// ==========================================
class DynamicPKBattleView extends StatelessWidget {
  final List<LivePKPlayerModel> players;
  final PKStatus pkStatus;
  final Function(LivePKPlayerModel)? onTapPlayer;
  final String currentRoomId;
  final String? focusedRoomId; // ✨ 焦点嘉宾的 roomId (为 null 时显示普通网格)

  const DynamicPKBattleView({
    super.key,
    required this.players,
    this.onTapPlayer,
    this.pkStatus = PKStatus.idle,
    required this.currentRoomId,
    this.focusedRoomId,
  });

  final double dividerThickness = 1.0;
  final Color dividerColor = Colors.black;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) return const SizedBox.shrink();

    final sortedPlayers = List<LivePKPlayerModel>.from(players);
    sortedPlayers.sort((a, b) {
      // 规则 1：主视角房主（也就是第一个格子）永远排在最前面
      bool isMainAnchorA = a.roomId == currentRoomId;
      bool isMainAnchorB = b.roomId == currentRoomId;

      if (isMainAnchorA && !isMainAnchorB) return -1;
      if (!isMainAnchorA && isMainAnchorB) return 1;

      // 规则 2：我方阵营（红队）永远排在敌方阵营（蓝队）前面
      if (a.isMyTeam && !b.isMyTeam) return -1;
      if (!a.isMyTeam && b.isMyTeam) return 1;

      // 🚫 核心修复：彻底删除 b.score.compareTo(a.score)
      // 返回 0 代表保持后端传过来的初始进房顺序，绝不允许因为分数变化而导致格子乱跳！
      return 0;
    });

    // ✨ 焦点放大模式：如果有人被选中放大，走新布局
    if (focusedRoomId != null && sortedPlayers.any((p) => p.roomId == focusedRoomId)) {
      return Container(color: dividerColor, child: _buildFocusLayout(sortedPlayers, focusedRoomId!));
    }

    return Container(color: dividerColor, child: _buildDynamicPKGrid(sortedPlayers));
  }

  // ✨ 焦点布局：1 大 + N 小的演讲者视图
  Widget _buildFocusLayout(List<LivePKPlayerModel> sortedList, String focusId) {
    final focusedPlayer = sortedList.firstWhere((p) => p.roomId == focusId);
    final otherPlayers = sortedList.where((p) => p.roomId != focusId).toList();

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. 底层大图
        _CellWrapper(
            player: focusedPlayer,
            pkStatus: pkStatus,
            currentRoomId: currentRoomId,
            allPlayers: players,
            onTap: onTapPlayer
        ),

        // 2. 顶层悬浮小窗列表
        if (otherPlayers.isNotEmpty)
          Positioned(
            right: 8,
            bottom: 45, // 避开底部信息栏
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
                          onTap: onTapPlayer
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          )
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
        Expanded(flex: 1, child: _CellWrapper(player: sortedList[0], pkStatus: pkStatus, currentRoomId: currentRoomId, allPlayers: players, onTap: onTapPlayer)),
        _vDivider(),
        Expanded(
          flex: 1,
          child: Column(
            children: [
              Expanded(flex: 1, child: _CellWrapper(player: sortedList[1], pkStatus: pkStatus, currentRoomId: currentRoomId, allPlayers: players, onTap: onTapPlayer)),
              _hDivider(),
              Expanded(flex: 1, child: _CellWrapper(player: sortedList[2], pkStatus: pkStatus, currentRoomId: currentRoomId, allPlayers: players, onTap: onTapPlayer)),
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
          rowChildren.add(Expanded(child: _CellWrapper(player: sortedList[playerIndex], pkStatus: pkStatus, currentRoomId: currentRoomId, allPlayers: players, onTap: onTapPlayer)));
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

// ==========================================
// 🔄 3. 核心新增：带状态的单个网格组件
// ==========================================
class _CellWrapper extends StatefulWidget {
  final LivePKPlayerModel player;
  final PKStatus pkStatus;
  final String currentRoomId;
  final List<LivePKPlayerModel> allPlayers;
  final Function(LivePKPlayerModel)? onTap;

  const _CellWrapper({required this.player, required this.pkStatus, required this.currentRoomId, required this.allPlayers, this.onTap});

  @override
  State<_CellWrapper> createState() => _CellWrapperState();
}

class _CellWrapperState extends State<_CellWrapper> {
  int _tick = 0; // 全局轮播步数
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

  // 渲染红蓝渐变 Label
  Widget _buildBuffGradientLabel(String text, bool isMyTeam, {Key? key}) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: isMyTeam ? Alignment.centerLeft : Alignment.centerRight,
          end: isMyTeam ? Alignment.centerRight : Alignment.centerLeft,
          colors: isMyTeam
              ? [const Color(0xFFFF2E56), Colors.transparent]
              : [const Color(0xFF2962FF), Colors.transparent],
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

  // ✨✨✨ 统一胶囊：只要是房主，无论是谁，统统使用带有阵营色的胶囊！
  Widget _buildInitiatorLabel(bool isMyTeam) {
    return Container(
      height: 18.0,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      // 利用 Row 包裹来让容器根据文字自适应宽度
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isMyTeam
              ? [const Color(0xFFFF2E56).withAlpha(120), const Color(0xFFFF5252).withAlpha(120)] // 红队胶囊
              : [const Color(0xFF2962FF).withAlpha(120), const Color(0xFF448AFF).withAlpha(120)], // 蓝队胶囊
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

    // ✨✨✨ 分数牌 UI 组件 ✨✨✨
    Widget buildScoreBadgeWidget() {
      return Container(
        height: 18.0,
        padding: const EdgeInsets.only(left: 2, right: 6),
        decoration: BoxDecoration(
          color: getBadgeColor(0.3, isForScore: true),
          borderRadius: BorderRadius.circular(12.0),
          border: isHighest ? Border.all(color: Colors.amberAccent.withAlpha(100), width: 0.5) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 14.0, height: 14.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isBattleState ? (player.isMyTeam ? const Color(0xFFD32F2F).withAlpha(100) : const Color(0xFF1565C0).withAlpha(100)) : Colors.white24,
              ),
              child: Center(
                child: Text('${player.rank}', style: const TextStyle(color: Colors.white, fontSize: 9.0, fontWeight: FontWeight.bold, height: 1.1)),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${player.score}',
              style: TextStyle(
                color: Colors.white, fontSize: 10.0, fontWeight: FontWeight.w600, height: 1.1,
                shadows: isHighest ? [const Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(0, 1))] : null,
              ),
            ),
          ],
        ),
      );
    }

    // 智能计算是否需要显示底部黑色半透明渐变遮罩
    bool needsBottomGradient = !isMainAnchor || (isMainAnchor && (player.isInitiator || (hasActiveBuffs && showScoreBadge)));

    return GestureDetector(
      onTap: () {
        if (widget.onTap != null) widget.onTap!(player);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(color: Color(0xFF1B1B1B)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildMediaContent(player),

            // 底部的深色半透明遮罩
            if (needsBottomGradient)
              Positioned(
                left: 0, right: 0, bottom: 0,
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

            // 👉 1. 左上角逻辑
            if (isMainAnchor && hasActiveBuffs)
            // 【房主且有道具】：左上角霸占为道具轮播
              Positioned(
                top: 0.0, left: 0.0,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: _buildBuffGradientLabel(currentBuffText, player.isMyTeam, key: ValueKey(currentIndex)),
                ),
              )
            else if (showScoreBadge)
            // 【房主无道具 或 其他人】：正常显示左上角的分数牌
              Positioned(
                top: 4.0, left: 4.0,
                child: buildScoreBadgeWidget(),
              ),

            if (player.isMuted)
              const Positioned(top: 6, right: 6, child: Icon(Icons.mic_off_outlined, color: Colors.white70, size: 16.0)),

            // 👉 2. 左下角逻辑 (统一 Column 纵向排列，独立胶囊)
            if (isMainAnchor && (player.isInitiator || (hasActiveBuffs && showScoreBadge)))
            // ✨【房主自身】：左下角纵向排列
              Positioned(
                bottom: 4.0, left: 4.0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start, // 统一左对齐
                  children: [
                    if (player.isInitiator)
                      Padding(
                        padding: EdgeInsets.only(bottom: (hasActiveBuffs && showScoreBadge) ? 4.0 : 0.0),
                        child: _buildInitiatorLabel(player.isMyTeam),
                      ),
                    if (hasActiveBuffs && showScoreBadge)
                      buildScoreBadgeWidget(),
                  ],
                ),
              )
            else if (!isMainAnchor)
            // ✨【其他人】：左下角纵向排列 (上方悬浮房主胶囊，下方显示名字条)
              Positioned(
                bottom: 4.0, left: 4.0, right: 4.0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start, // 统一左对齐
                  children: [
                    if (player.isInitiator)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2.0),
                        child: _buildInitiatorLabel(player.isMyTeam),
                      ),

                    // 下方原来的名字和道具背景条
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: BoxDecoration(
                          color: getBadgeColor(0.4, isForScore: false),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              flex: 1, fit: FlexFit.loose,
                              child: Transform.translate(
                                offset: const Offset(0, 0),
                                child: Text(
                                  player.name,
                                  style: const TextStyle(color: Colors.white, fontSize: 11.0, fontWeight: FontWeight.w500, height: 1.2, leadingDistribution: TextLeadingDistribution.even),
                                  strutStyle: const StrutStyle(fontSize: 11.0, height: 1.2, leading: 0, forceStrutHeight: true),
                                  maxLines: 1, softWrap: false, overflow: TextOverflow.clip,
                                ),
                              ),
                            ),
                            if (hasActiveBuffs) ...[
                              Container(width: 1, height: 10, margin: const EdgeInsets.symmetric(horizontal: 4), color: Colors.white38),
                              Flexible(
                                flex: 0,
                                child: Transform.translate(
                                  offset: const Offset(0, 0.4),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: Text(
                                      currentBuffText,
                                      key: ValueKey(currentIndex),
                                      style: const TextStyle(color: Colors.yellowAccent, fontSize: 10.0, fontWeight: FontWeight.bold, height: 1.2, leadingDistribution: TextLeadingDistribution.even),
                                      strutStyle: const StrutStyle(fontSize: 11.0, height: 1.2, leading: 0, forceStrutHeight: true),
                                      maxLines: 1, softWrap: false, overflow: TextOverflow.visible,
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
          ],
        ),
      ),
    );
  }

  Widget _buildMediaContent(LivePKPlayerModel player) {
    Widget content;
    if (player.videoController != null && player.videoController!.value.isInitialized) {
      content = SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(width: player.videoController!.value.size.width, height: player.videoController!.value.size.height, child: VideoPlayer(player.videoController!)),
        ),
      );
    } else {
      double avatarPadding = 12.0;
      if (widget.allPlayers.length == 9) avatarPadding = 18.0;
      else if (widget.allPlayers.length >= 7) avatarPadding = 5.0;

      content = Stack(
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
    }

    if (player.isPunished) return RepaintBoundary(child: ColorFiltered(colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation), child: content));
    return RepaintBoundary(child: content);
  }
}