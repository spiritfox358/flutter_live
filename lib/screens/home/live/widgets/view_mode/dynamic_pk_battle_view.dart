import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_live/screens/home/live/widgets/pk_score_bar_widgets.dart';
import 'package:flutter_live/screens/home/live/widgets/avatar_animation.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../../bridge/hardcore_mixer.dart';

class LivePKPlayerModel {
  final String userId;
  final String roomId;
  final String name;
  final String avatarUrl;
  final String streamUrl;
  final int rank;
  final int score;
  final bool isMuted;
  final String? propText;
  final bool isPunished;
  final bool isSpeaking;
  final bool isMyTeam;
  final bool isInitiator;
  final VideoController? videoController;
  final List<String> activeBuffs;

  LivePKPlayerModel({
    required this.userId,
    required this.roomId,
    required this.name,
    required this.avatarUrl,
    required this.streamUrl,
    required this.rank,
    required this.score,
    this.isMuted = false,
    this.propText,
    this.isPunished = false,
    this.isSpeaking = false,
    this.isMyTeam = false,
    this.isInitiator = false,
    this.activeBuffs = const [],
    this.videoController,
  });
}

class DynamicPKBattleView extends StatefulWidget {
  final List<LivePKPlayerModel> players;
  final PKStatus pkStatus;
  final Function(LivePKPlayerModel)? onTapPlayer;
  final String currentRoomId;
  final String? focusedRoomId;
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

  @override
  State<DynamicPKBattleView> createState() => _DynamicPKBattleViewState();
}

class _DynamicPKBattleViewState extends State<DynamicPKBattleView> {
  final double dividerThickness = 1.0;
  final Color dividerColor = Colors.black;
  static const _screenChannel = MethodChannel('app.channel.screen');
  List<List<double>> _currentLayouts = [];
  int? _textureId;

  // 🚀 性能修复 6：全局唯一的 Radar 定时器和结果缓存
  Timer? _globalRadarTimer;
  List<String> _readyUrls = [];
  final Map<String, GlobalKey<_CellWrapperState>> _cellKeys = {};

  // 🚀🚀🚀 终极真理武器：记录容器真实的 UI 宽和高！绝对不再瞎猜！
  double? _actualContainerWidth;
  double? _actualContainerHeight;

  String _getStableId(LivePKPlayerModel p) {
    return "cell_${p.roomId}_${p.userId}";
  }

  String _getBaseUrl(String url) => url.split('?').first;

  String _getUniqueId(LivePKPlayerModel p) {
    return "${p.roomId}_${p.userId}_${p.name}_${p.streamUrl}";
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _initHardcoreEngine();
      _screenChannel.invokeMethod('keepScreenOn', {'on': true}); // 🚀 开灯
    });

    // 🚀 每半秒查一次底层就足够了，不要用 200ms
    _globalRadarTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (!mounted || _textureId == null) return;
      try {
        final urls = await HardcoreMixer.getReadyUrls();
        // 简单对比，如果有变化才通知 UI 刷新，减少重绘
        if (urls.join(',') != _readyUrls.join(',')) {
          setState(() {
            _readyUrls = urls;
          });
        }
      } catch (e) {}
    });
  }

  @override
  void dispose() {
    _globalRadarTimer?.cancel();
    _screenChannel.invokeMethod('keepScreenOn', {'on': false}); // 🚀 关灯
    super.dispose();
  }

  Future<void> _initHardcoreEngine() async {
    int? id = await HardcoreMixer.initEngine();
    if (mounted) {
      setState(() => _textureId = id);
      _syncStreamsToEngine();
    }
  }

  @override
  void didUpdateWidget(DynamicPKBattleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentIds = widget.players.map((p) => _getUniqueId(p)).toSet();
    _cellKeys.removeWhere((id, key) => !currentIds.contains(id));

    String oldUrls = oldWidget.players.map((p) => _getBaseUrl(p.streamUrl)).join(',');
    String newUrls = widget.players.map((p) => _getBaseUrl(p.streamUrl)).join(',');

    if (oldUrls != newUrls || oldWidget.useVideoMode != widget.useVideoMode || oldWidget.focusedRoomId != widget.focusedRoomId) {
      _syncStreamsToEngine();
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

  void _syncStreamsToEngine() {
    // 🚀 如果真实高度还没抓到，绝不往下发错误的指令！
    if (_textureId == null || !widget.useVideoMode || widget.players.isEmpty || _actualContainerWidth == null || _actualContainerHeight == null)
      return;

    final sortedPlayers = _getSortedPlayers();
    List<String> urls = sortedPlayers.map((p) => p.streamUrl).toList();

    if (widget.focusedRoomId != null && sortedPlayers.any((p) => p.roomId == widget.focusedRoomId)) {
      int focusIndex = sortedPlayers.indexWhere((p) => p.roomId == widget.focusedRoomId);
      _currentLayouts = _generateFocusLayouts(sortedPlayers, focusIndex);
    } else {
      _currentLayouts = _generateGridLayouts(sortedPlayers.length);
    }

    // 🚀🚀🚀 终极真理：用 LayoutBuilder 抓出来的真实宽高 * 像素密度！
    // Android 画板和 Flutter UI 绝对 1:1，再也不可能发生拉伸了！
    double ratio = MediaQuery.of(context).devicePixelRatio;
    HardcoreMixer.playStreams(urls, _currentLayouts, _actualContainerWidth! * ratio, _actualContainerHeight! * ratio);

    setState(() {});

    for (var p in sortedPlayers) {
      if (p.streamUrl.isNotEmpty) {
        HardcoreMixer.setMuted(p.streamUrl, p.isMuted);
      }
    }
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
    if (widget.players.isEmpty || _textureId == null) return const SizedBox.shrink();
    final sortedPlayers = _getSortedPlayers();

    return LayoutBuilder(
      builder: (context, constraints) {
        // 🚀 新增保护：如果父组件没有限制大小（如 ScrollView），降级使用屏幕物理尺寸
        final double w = constraints.maxWidth.isInfinite ? MediaQuery.of(context).size.width : constraints.maxWidth;
        final double h = constraints.maxHeight.isInfinite ? MediaQuery.of(context).size.height : constraints.maxHeight;

        if (_actualContainerWidth != w || _actualContainerHeight != h) {
          _actualContainerWidth = w;
          _actualContainerHeight = h;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _syncStreamsToEngine();
          });
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: Texture(textureId: _textureId!)),

            ...List.generate(sortedPlayers.length, (index) {
              if (index >= _currentLayouts.length) return const SizedBox.shrink();
              final layout = _currentLayouts[index];

              return Positioned(
                left: layout[0] * w,
                top: layout[1] * h,
                width: layout[2] * w,
                height: layout[3] * h,
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Colors.black, width: 0.2),
                      right: BorderSide(color: Colors.black, width: 0.2),
                    ),
                  ),
                  child: _CellWrapper(
                    key: ValueKey(_getStableId(sortedPlayers[index])),
                    engineTextureId: _textureId,
                    player: sortedPlayers[index],
                    pkStatus: widget.pkStatus,
                    currentRoomId: widget.currentRoomId,
                    allPlayers: widget.players,
                    onTap: widget.onTapPlayer,
                    useVideoMode: widget.useVideoMode,
                    readyUrls: _readyUrls, // 🚀 传给子组件
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
  final int? engineTextureId;
  final LivePKPlayerModel player;
  final PKStatus pkStatus;
  final String currentRoomId;
  final List<LivePKPlayerModel> allPlayers;
  final Function(LivePKPlayerModel)? onTap;
  final bool useVideoMode;
  final List<String> readyUrls; // 🚀 新增接收参数

  const _CellWrapper({
    super.key,
    this.engineTextureId,
    required this.player,
    required this.pkStatus,
    required this.currentRoomId,
    required this.allPlayers,
    this.onTap,
    this.useVideoMode = false,
    this.readyUrls = const [], // 🚀 默认空数组
  });

  @override
  State<_CellWrapper> createState() => _CellWrapperState();
}

class _CellWrapperState extends State<_CellWrapper> {
  int _tick = 0;
  Timer? _timer;
  bool _isVideoReady = false;
  Timer? _radarTimer;

  @override
  void initState() {
    super.initState();
    _startCarousel();
    _startVideoRadar();
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

    String oldBase = oldWidget.player.streamUrl.split('?').first;
    String newBase = widget.player.streamUrl.split('?').first;
    if (oldBase != newBase) {
      _startVideoRadar();
    }
  }

  void _startVideoRadar() {
    _isVideoReady = false;
    _radarTimer?.cancel();
    String safeUrl = widget.player.streamUrl.trim();
    if (safeUrl.isEmpty) {
      if (mounted) setState(() {});
      return;
    }
    _radarTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      if (!mounted || widget.engineTextureId == null) return;
      try {
        final urls = await HardcoreMixer.getReadyUrls();
        if (urls.contains(safeUrl)) {
          if (mounted) setState(() => _isVideoReady = true);
          timer.cancel();
        }
      } catch (e) {}
    });
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
    _radarTimer?.cancel();
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

    return GestureDetector(
      onTap: () {
        if (widget.onTap != null) widget.onTap!(player);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(color: Colors.transparent),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildMediaContent(player),

            if (needsBottomGradient)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
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

            if (isMainAnchor && hasActiveBuffs)
              Positioned(
                top: 0.0,
                left: 0.0,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildBuffGradientLabel(currentBuffText, player.isMyTeam, key: ValueKey(currentIndex)),
                ),
              )
            else if (showScoreBadge)
              Positioned(top: 4.0, left: 4.0, child: buildScoreBadgeWidget()),

            if (player.isMuted) const Positioned(top: 6, right: 6, child: Icon(Icons.mic_off_outlined, color: Colors.white70, size: 16.0)),

            if (isMainAnchor && (player.isInitiator || (hasActiveBuffs && showScoreBadge)))
              Positioned(
                bottom: 4.0,
                left: 4.0,
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
              )
            else if (!isMainAnchor)
              Positioned(
                bottom: 4.0,
                left: 4.0,
                right: 4.0,
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
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.0,
                                      fontWeight: FontWeight.w500,
                                      height: 1.1,
                                      leadingDistribution: TextLeadingDistribution.even,
                                    ),
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
                                      style: const TextStyle(
                                        color: Colors.yellowAccent,
                                        fontSize: 10.0,
                                        fontWeight: FontWeight.bold,
                                        height: 1.1,
                                        leadingDistribution: TextLeadingDistribution.even,
                                      ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildMediaContent(LivePKPlayerModel player) {
    String safeUrl = player.streamUrl.trim();
    bool hasValidStream = safeUrl.isNotEmpty && (safeUrl.startsWith('http') || safeUrl.startsWith('rtmp'));

    double avatarPadding = widget.allPlayers.length == 9 ? 18.0 : (widget.allPlayers.length >= 7 ? 5.0 : 12.0);
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
              constraints: const BoxConstraints(maxWidth: 125.0, maxHeight: 125.0),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AvatarAnimation(avatarUrl: player.avatarUrl, isSpeaking: player.isSpeaking, isRotating: false),
              ),
            ),
          ),
        ),
      ],
    );
    if (player.isPunished)
      fallbackContent = ColorFiltered(colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation), child: fallbackContent);

    Widget videoWidget = Container(color: Colors.transparent);
    if (player.isPunished) videoWidget = ColorFiltered(colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation), child: videoWidget);

    // 🚀 性能修复 7：直接根据父组件传来的全局状态判断视频是否准备好
    bool isVideoReady = widget.readyUrls.contains(safeUrl);
    bool showAvatar = !isVideoReady || !widget.useVideoMode || !hasValidStream;

    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        child: showAvatar
            ? KeyedSubtree(key: const ValueKey("avatar"), child: fallbackContent)
            : KeyedSubtree(key: const ValueKey("video_hole"), child: videoWidget),
      ),
    );
  }
}
