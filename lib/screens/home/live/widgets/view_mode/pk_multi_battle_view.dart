import 'package:flutter/material.dart';

import '../common/jumping_flame_effect.dart';

/// 极致还原：多人连麦 PK 网格与道具状态布局测试页 (纯原生呼吸发光特效版)
class PKRealLayoutDemoPage extends StatefulWidget {
  const PKRealLayoutDemoPage({super.key});

  @override
  State<PKRealLayoutDemoPage> createState() => _PKRealLayoutDemoPageState();
}

class _PKRealLayoutDemoPageState extends State<PKRealLayoutDemoPage> {
  // ==========================================
  // 🛠️ 核心控制台：在这里修改所有样式！
  // ==========================================

  int playerCount = 9; // 测试人数控制 (支持 2-9人)
  final double gridAspectRatio = 3 / 4;

  // 📏 分割线样式
  final double dividerThickness = 1.0;
  final Color dividerColor = Colors.black;

  // 🏆 左上角：排名与分数模块样式
  final Color rankBadgeBgColor = Colors.black.withOpacity(0.4);
  final Color rankCircleColor = const Color(0xFF8AA4FC);
  final double rankCircleSize = 14.0;
  final EdgeInsets rankBadgePadding = const EdgeInsets.only(left: 2, right: 6, top: 2, bottom: 2);
  final double rankBadgeRadius = 12.0;

  // 🏷️ 底部：名字与道具模块样式
  final double bottomGradientHeight = 40.0;
  final Color propBgColor = const Color(0xFF6C8CFF).withOpacity(0.85);
  final double propRadius = 4.0;

  // 🔤 字体大小配置
  final double textRankSize = 9.0;
  final double textScoreSize = 10.0;
  final double textNameSize = 11.0;
  final double textPropSize = 10.0;

  // 🔇 图标配置
  final double muteIconSize = 16.0;
  final Color muteIconColor = Colors.white70;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E28),
      appBar: AppBar(title: Text('$playerCount人 PK - 呼吸红光版'), backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Center(
        child: SizedBox(
          height: 315,
          width: double.infinity,
          child: Container(
            color: dividerColor,
            child: _buildDynamicPKGrid(),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 🧠 逻辑层：基于行数的万能网格分配器
  // ==========================================
  Widget _buildDynamicPKGrid() {
    final players = List.generate(playerCount, (index) {
      return _MockPlayer(
        name: index == 0 ? '我(主播)' : '连麦嘉宾${index + 1}',
        avatarUrl: 'https://picsum.photos/seed/pk_glow_$index/300/300',
        rank: index == 0 ? 1 : index + 1,
        score: 100000 + (10 - index) * 12345,
        isMuted: index % 3 == 0,
        // 让第2个和第4个格子处于暴击中，展示红光效果
        propText: index % 2 != 0 ? (index == 1 ? '暴击中 22s' : (index == 3 ? '暴击中' : '迷雾中')) : null,
      );
    });

    if (players.isEmpty) return const SizedBox.shrink();

    switch (playerCount) {
      case 2: return _buildFlexGrid([2], players);
      case 3: return _build3PersonLayout(players);
      case 4: return _buildFlexGrid([2, 2], players);
      case 5: return _buildFlexGrid([2, 3], players);
      case 6: return _buildFlexGrid([3, 3], players);
      case 7: return _buildFlexGrid([3, 4], players);
      case 8: return _buildFlexGrid([4, 4], players);
      case 9: return _buildFlexGrid([3, 3, 3], players);
      default: return const Center(child: Text('仅支持 2-9 人', style: TextStyle(color: Colors.white)));
    }
  }

  Widget _vDivider() => Container(width: dividerThickness, color: dividerColor);
  Widget _hDivider() => Container(height: dividerThickness, color: dividerColor);

  Widget _build3PersonLayout(List<_MockPlayer> p) {
    return Row(
      children: [
        Expanded(flex: 1, child: _buildCell(p[0])),
        _vDivider(),
        Expanded(
          flex: 1,
          child: Column(
            children: [
              Expanded(flex: 1, child: _buildCell(p[1])),
              _hDivider(),
              Expanded(flex: 1, child: _buildCell(p[2])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFlexGrid(List<int> rowConfigs, List<_MockPlayer> p) {
    List<Widget> rows = [];
    int playerIndex = 0;

    for (int i = 0; i < rowConfigs.length; i++) {
      int colsInThisRow = rowConfigs[i];
      List<Widget> rowChildren = [];

      for (int j = 0; j < colsInThisRow; j++) {
        if (playerIndex < p.length) {
          rowChildren.add(Expanded(child: _buildCell(p[playerIndex])));
          if (j < colsInThisRow - 1) rowChildren.add(_vDivider());
          playerIndex++;
        }
      }

      rows.add(Expanded(child: Row(children: rowChildren)));
      if (i < rowConfigs.length - 1) rows.add(_hDivider());
    }

    return Column(children: rows);
  }

  // ==========================================
  // 🎨 视图层：单个方块 UI 渲染
  // ==========================================
  Widget _buildCell(_MockPlayer player) {
    bool hasProp = player.propText != null && player.propText!.isNotEmpty;
    String displayName = player.name;
    bool showScoreBadge = playerCount > 2;

    // ✨ 判断是否在“暴击中”
    bool isCritical = hasProp && player.propText!.contains('暴击');

    return Container(
      color: const Color(0xFF1B1B1B),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 🖼️ 底层：视频/头像
          Image.network(
            player.avatarUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.grey[800]),
          ),

          // 3. 🌫️ 阴影层：底部弱渐变 (保护名字文字)
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              height: bottomGradientHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                ),
              ),
            ),
          ),

          // 4. 🥇 覆盖层左上角：排名 + 分数
          if (showScoreBadge)
            Positioned(
              top: 6, left: 6,
              child: Container(
                padding: rankBadgePadding,
                decoration: BoxDecoration(color: rankBadgeBgColor, borderRadius: BorderRadius.circular(rankBadgeRadius)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: rankCircleSize, height: rankCircleSize,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: rankCircleColor),
                      child: Center(child: Text('${player.rank}', style: TextStyle(color: Colors.white, fontSize: textRankSize, fontWeight: FontWeight.bold))),
                    ),
                    const SizedBox(width: 4),
                    Text('${player.score}', style: TextStyle(color: Colors.white, fontSize: textScoreSize, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),

          // 5. 🔇 覆盖层右上角：静音图标
          if (player.isMuted)
            Positioned(top: 6, right: 6, child: Icon(Icons.mic_off_outlined, color: muteIconColor, size: muteIconSize)),

          // 6. 🏷️ 覆盖层底部：名字与道具状态栏
          Positioned(
            bottom: 4, left: 4, right: 4,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: TextStyle(color: Colors.white, fontSize: textNameSize, fontWeight: FontWeight.w500, height: 1.2),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasProp) ...[
                      Container(width: 1, height: 9, margin: const EdgeInsets.symmetric(horizontal: 4), color: Colors.white38),
                      Text(player.propText!, style: TextStyle(color: Colors.white, fontSize: textPropSize, fontWeight: FontWeight.w600, height: 1.2), maxLines: 1),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockPlayer {
  final String name; final String avatarUrl; final int rank; final int score; final bool isMuted; final String? propText;
  _MockPlayer({required this.name, required this.avatarUrl, required this.rank, required this.score, this.isMuted = false, this.propText});
}