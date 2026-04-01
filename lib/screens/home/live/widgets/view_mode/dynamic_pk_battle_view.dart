import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
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

  // 🚀 保留你的控制器字段，防止其他业务报错，但在本页面它已经被架空了！
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

// 🚀 降维打击：将 Stateless 升级为 Stateful，用于接管底层的 C++ 大屏幕！
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
// 🚀 唯一真理坐标库：C++ 和 Flutter UI 必须共用这份数据！
  List<List<double>> _currentLayouts = [];

  int? _textureId;

  // 🚀 核心修复 2：绝对稳定的身份证（只看房间和人，无视 URL 和名字变化）
  String _getStableId(LivePKPlayerModel p) {
    return "cell_${p.roomId}_${p.userId}";
  }

  // 获取基础链接（剥离 Token）
  String _getBaseUrl(String url) => url.split('?').first;

  // 🚀 缓存池：GlobalKey 必须与绝对唯一的 ID 绑定
  final Map<String, GlobalKey<_CellWrapperState>> _cellKeys = {};

  // 🚀🚀🚀 核心修复 1：制造一张绝对不可能重复的“超级身份证”！
  // 哪怕后端 userId 返回的全是空，加上 roomId、name 和 url 也绝对能区分开，彻底消灭“克隆人大头像” Bug！
  String _getUniqueId(LivePKPlayerModel p) {
    return "${p.roomId}_${p.userId}_${p.name}_${p.streamUrl}";
  }

  // 获取 VIP 身份证
  GlobalKey<_CellWrapperState> _getCellKey(String uniqueId) {
    if (!_cellKeys.containsKey(uniqueId)) {
      _cellKeys[uniqueId] = GlobalKey<_CellWrapperState>();
    }
    return _cellKeys[uniqueId]!;
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _initHardcoreEngine();
    });
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

    // 🚀 核心修复 2：精准清理旧 Key，防止内存泄漏
    final currentIds = widget.players.map((p) => _getUniqueId(p)).toSet();
    _cellKeys.removeWhere((id, key) => !currentIds.contains(id));

    // 🚀 核心修复 3：绝对精准的 C++ 引擎同步触发器！
    // 🚀 比较时只看 BaseUrl，只要没换人，哪怕 API 每秒刷新 Token，绝不触发引擎重启！
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

      // 🚀🚀🚀 核心修复 4：Dart 的 sort 是不稳定的！
      // 如果返回 0，每次接口轮询时主播位置都会乱跳！必须用超级身份证做最后决断，把位置死死焊住！
      return _getStableId(a).compareTo(_getStableId(b));
    });
    return sortedPlayers;
  }

  // 🚀 4. 将最新的人员和坐标发射给底层！
  void _syncStreamsToEngine() {
    if (_textureId == null || !widget.useVideoMode || widget.players.isEmpty) return;

    final sortedPlayers = _getSortedPlayers();
    List<String> urls = sortedPlayers.map((p) => p.streamUrl).toList();

    // 1. 计算出绝对坐标
    if (widget.focusedRoomId != null && sortedPlayers.any((p) => p.roomId == widget.focusedRoomId)) {
      int focusIndex = sortedPlayers.indexWhere((p) => p.roomId == widget.focusedRoomId);
      _currentLayouts = _generateFocusLayouts(sortedPlayers, focusIndex);
    } else {
      _currentLayouts = _generateGridLayouts(sortedPlayers.length);
    }

    // 2. 发给 C++ 渲染视频
    HardcoreMixer.playStreams(urls, _currentLayouts);

    // 3. 🚀 极其重要：强制 Flutter 刷新，让 UI 也按照这个坐标去排列！
    setState(() {});

    // ==========================================
    // 🚀🚀🚀 终极修复：紧跟拉流指令，强行把初始静音状态同步给底层！
    // 解决“进房UI显示静音，底层却有声音”的脱节 Bug！
    // ==========================================
    for (var p in sortedPlayers) {
      if (p.streamUrl.isNotEmpty) {
        // 利用剥离 Token 的 URL 去通知 C++ 静音
        HardcoreMixer.setMuted(p.streamUrl, p.isMuted);
      }
    }
  }


  // 🚀 混合悬浮 L 型算法：单指针自底向上堆叠，房主稳坐右下角基石！
  List<List<double>> _generateFocusLayouts(List<LivePKPlayerModel> players, int focusIndex) {
    List<List<double>> layouts = List.filled(players.length, []);
    if (players.length <= 1) return [[0.0, 0.0, 1.0, 1.0]];

    double subW = 1.0 / 3.0;
    double normalSubH = 1.0 / 6.0; // 普通副咖占 1 格
    double hostSubH = 1.0 / 3.0;   // 房主副咖占 2 格

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

    // 🎯 核心魔法：唯一的【底部指针】，从屏幕最下方 1.0 开始往上推！
    double currentBottomY = 1.0;
    int bottomIdx = 0;

    // 1. 房主优先：稳稳沉在最右下角，高度占 1/3
    if (hostSubIndex != -1) {
      currentBottomY -= hostSubH; // 指针往上抬 2 个格子
      layouts[hostSubIndex] = [2.0 / 3.0, currentBottomY, subW, hostSubH];
    }

    // 2. 底部溢出槽位 (当右侧一柱擎天被塞满后，往左下角流)
    List<List<double>> bottomSlots = [
      [1.0 / 3.0, 5.0 / 6.0], // 0: 底部偏右
      [0.0, 5.0 / 6.0],       // 1: 底部最左
      [1.0 / 3.0, 4.0 / 6.0], // 2: 底部偏右上层
      [0.0, 4.0 / 6.0],       // 3: 底部最左上层
    ];

    // 3. 普通副咖流水线：踩着房主的肩膀，继续往上堆叠！
    for (int i in normalSubIndices) {
      // 只要指针距离顶部还有空间塞得下 1 个格子 (加 0.001 容差防精度丢失)
      if (currentBottomY - normalSubH >= -0.001) {
        currentBottomY -= normalSubH; // 指针往上抬 1 个格子
        layouts[i] = [2.0 / 3.0, currentBottomY, subW, normalSubH];
      } else {
        // 右侧彻底顶到天花板了，往底部溢出槽位塞
        if (bottomIdx < bottomSlots.length) {
          layouts[i] = [bottomSlots[bottomIdx][0], bottomSlots[bottomIdx][1], subW, normalSubH];
          bottomIdx++;
        } else {
          layouts[i] = [-1.0, -1.0, 0.0, 0.0];
        }
      }
    }

    // 👑 4. 满载退让侦测
    // 右侧是否完整占满？（底部指针被推到了最顶部 0.0）
    bool isRightFull = currentBottomY <= 0.001;
    // 底部第一排是否完整占满？
    bool isBottomFull = bottomIdx >= 2;

    double mainW = isRightFull ? (2.0 / 3.0) : 1.0;
    double mainH = isBottomFull ? (5.0 / 6.0) : 1.0;

    layouts[focusIndex] = [0.0, 0.0, mainW, mainH];

    return layouts;
  }
  // 🚀 计算常规网格坐标
  List<List<double>> _generateGridLayouts(int count) {
    if (count == 3) {
      return [
        [0.0, 0.0, 0.5, 1.0], // 左半边
        [0.5, 0.0, 0.5, 0.5], // 右上
        [0.5, 0.5, 0.5, 0.5], // 右下
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
  void dispose() {
    // HardcoreMixer.dispose(); // 页面销毁，彻底干掉 C++ 引擎释放内存！
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.players.isEmpty || _textureId == null) return const SizedBox.shrink();

    // 🚀 核心修复 1：必须获取排序后的列表！这样才能和底层 C++ 的坐标系一一对应！
    final sortedPlayers = _getSortedPlayers();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. 底层 C++ 视频流 (一整块大玻璃板)
            Positioned.fill(child: Texture(textureId: _textureId!)),

            // 2. 顶层 Flutter UI (每一个带透明洞的 _CellWrapper)
            ...List.generate(sortedPlayers.length, (index) {
              if (index >= _currentLayouts.length) return const SizedBox.shrink();
              final layout = _currentLayouts[index];

              return Positioned(
                left: layout[0] * w,
                top: layout[1] * h,
                width: layout[2] * w,
                height: layout[3] * h,

                // 🚀 核心修复 2：调用你真正写好的 _CellWrapper 组件！
                child: Container(
                  // 加上黑色分割线
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 0.5),
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
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  // ---------- 下面是你原本的 UI 布局逻辑，完全保留 ----------

  Widget _buildFocusLayout(List<LivePKPlayerModel> sortedList, String focusId) {
    final focusedPlayer = sortedList.firstWhere((p) => p.roomId == focusId);
    final otherPlayers = sortedList.where((p) => p.roomId != focusId).toList();

    return Stack(
      fit: StackFit.expand,
      children: [
        _CellWrapper(
          key: ValueKey(_getStableId(focusedPlayer)),
          engineTextureId: _textureId,
          // 👈 给每一个格子都加上这行！
          player: focusedPlayer,
          pkStatus: widget.pkStatus,
          currentRoomId: widget.currentRoomId,
          allPlayers: widget.players,
          onTap: widget.onTapPlayer,
          useVideoMode: widget.useVideoMode,
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
                      // 🚀🚀🚀 终极修复：横向列表的身份证必须挂在最外层的 Container 上！
                      key: ValueKey(_getStableId(p)),
                      width: 80,
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white54, width: 1.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: _CellWrapper(
                        // key: _getCellKey(_getUniqueId(p)),
                        engineTextureId: _textureId,
                        player: p,
                        pkStatus: widget.pkStatus,
                        currentRoomId: widget.currentRoomId,
                        allPlayers: widget.players,
                        onTap: widget.onTapPlayer,
                        // 焦点模式下的横向小人，建议直接传 false 用头像，避免 C++ 坐标计算过于复杂
                        useVideoMode: false,
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

  Widget _vDivider() => Container(width: dividerThickness, color: dividerColor);

  Widget _hDivider() => Container(height: dividerThickness, color: dividerColor);

  // 没有任何的 Row/Column 嵌套，所以不论怎么加人、踢人，UI 树永远不会重建，绝对 0 闪烁！
  Widget _buildDynamicPKGrid(List<LivePKPlayerModel> sortedList) {
    List<List<double>> layouts = _generateGridLayouts(sortedList.length);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: List.generate(sortedList.length, (i) {
            var rect = layouts[i];
            return Positioned(
              // 🚀🚀🚀 终极修复：身份证必须挂在 Stack 的直接子元素 Positioned 上！
              // 这样 Flutter 就能在跨层重排时，精准抓取整个块进行平移，绝不会按序号乱杀人！
              key: ValueKey(_getStableId(sortedList[i])),
              left: rect[0] * constraints.maxWidth,
              top: rect[1] * constraints.maxHeight,
              width: rect[2] * constraints.maxWidth,
              height: rect[3] * constraints.maxHeight,
              child: _CellWrapper(
                // 🌟 因为架构扁平了，恢复成最轻量的 ValueKey 就能焊死状态！
                key: ValueKey(_getStableId(sortedList[i])),
                engineTextureId: _textureId,
                player: sortedList[i],
                pkStatus: widget.pkStatus,
                currentRoomId: widget.currentRoomId,
                allPlayers: widget.players,
                onTap: widget.onTapPlayer,
                useVideoMode: widget.useVideoMode,
              ),
            );
          }),
        );
      },
    );
  }
}

class _CellWrapper extends StatefulWidget {
  final int? engineTextureId; // 🚀 新增：用来绑定真实的底层引擎 ID
  final LivePKPlayerModel player;
  final PKStatus pkStatus;
  final String currentRoomId;
  final List<LivePKPlayerModel> allPlayers;
  final Function(LivePKPlayerModel)? onTap;
  final bool useVideoMode;

  const _CellWrapper({
    super.key,
    this.engineTextureId, // 🚀 加到构造函数里
    required this.player,
    required this.pkStatus,
    required this.currentRoomId,
    required this.allPlayers,
    this.onTap,
    this.useVideoMode = false,
  });

  @override
  State<_CellWrapper> createState() => _CellWrapperState();
}

class _CellWrapperState extends State<_CellWrapper> {
  int _tick = 0;
  Timer? _timer;

  // 🚀 1. 彻底删掉坑爹的 static！恢复干净的局部雷达！
  bool _isVideoReady = false;
  Timer? _radarTimer;

  @override
  void initState() {
    super.initState();
    _startCarousel();
    _syncPlayerState();
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

    if (oldWidget.useVideoMode != widget.useVideoMode ||
        oldWidget.player.videoController != widget.player.videoController ||
        oldWidget.player.isMuted != widget.player.isMuted) {
      _syncPlayerState();
    }

    // 🚀 雷达也免疫 Token！只有真正换了主播（BaseUrl 变了），才重新盖头像扫雷达！
    String oldBase = oldWidget.player.streamUrl.split('?').first;
    String newBase = widget.player.streamUrl.split('?').first;
    if (oldBase != newBase) {
      _startVideoRadar();
    }
  }

  // 🚀 3. 纯净的雷达：只管扫自己这个格子的 URL
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
          if (mounted) {
            setState(() => _isVideoReady = true); // 🎯 扫到了！立刻揭开幕布！
          }
          timer.cancel();
        }
      } catch (e) {}
    });
  }

  void _syncPlayerState() {}

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
    _radarTimer?.cancel(); // 🚀 销毁时关掉雷达
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

  // 🚀 核心替换：直接在 build 里读取记忆！绝对0延迟！
  // ==========================================
  Widget _buildMediaContent(LivePKPlayerModel player) {
    String safeUrl = player.streamUrl.trim();
    bool hasValidStream = safeUrl.isNotEmpty && (safeUrl.startsWith('http') || safeUrl.startsWith('rtmp'));

    // 备用贴纸 (头像毛玻璃)
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

    // 视频透明洞
    Widget videoWidget = Container(color: Colors.transparent);
    if (player.isPunished) videoWidget = ColorFiltered(colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation), child: videoWidget);

    // 🚀 终极判断：雷达没扫到、或者没开视频，就死死盖住头像！
    bool showAvatar = !_isVideoReady || !widget.useVideoMode || !hasValidStream;

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
