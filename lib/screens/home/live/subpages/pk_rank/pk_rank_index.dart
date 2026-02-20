import 'dart:ui'; // 需要导入此包以使用 ImageFilter

import 'package:flutter/material.dart';

// 定义图片链接常量，方便复用
const String _rankImageUrl = 'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/pk_rank/%E9%92%BB%E7%9F%B3%E4%BA%94%E6%98%9F.png';

class PkRankIndex extends StatelessWidget {
  const PkRankIndex({Key? key}) : super(key: key);

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      // 禁用 BottomSheet 自带的拖拽关闭，因为我们要固定内容
      enableDrag: false,
      builder: (context) {
        return const PkRankIndex();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final paddingBottom = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      height: screenHeight * 0.75,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 背景层：图片放大 + 高斯模糊 + 遮罩
          _buildBlurredBackground(),

          // 2. 前景内容层：固定布局，不可滚动
          Column(
            children: [
              _buildHeader(),
              _buildSubHeader(),
              // 使用 Expanded 让中间部分占据剩余空间并居中，且不可滚动
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCenterBadge(),
                    const SizedBox(height: 20),
                    _buildRankInfo(),
                  ],
                ),
              ),
              _buildBottomTaskList(),
              SizedBox(height: paddingBottom + 20), // 底部安全距离
            ],
          ),
        ],
      ),
    );
  }

  /// 构建高斯模糊背景
  Widget _buildBlurredBackground() {
    // 使用 ClipRRect 确保背景图也遵循顶部的圆角
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 底层图片，放大铺满
          Image.network(
            _rankImageUrl,
            fit: BoxFit.cover,
            // 可以稍微加深一点底图颜色
            color: Colors.black.withOpacity(0.2),
            colorBlendMode: BlendMode.darken,
            errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFF142C3F)),
          ),
          // 高斯模糊滤镜层
          BackdropFilter(
            // sigma 值越大，模糊程度越高
            filter: ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0),
            child: Container(
              color: Colors.transparent, // 必须设置透明色
            ),
          ),
          // 半透明黑色遮罩层，确保文字可读性
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.4),
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 顶部标题栏
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '主播段位',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 24),
              Text(
                '巅峰榜',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 16,
                ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            child: Icon(
              Icons.help_outline,
              color: Colors.white.withOpacity(0.5),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  /// 副标题/功能标签行
  Widget _buildSubHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildTag(
            icon: const Icon(Icons.local_fire_department, color: Colors.orange, size: 14),
            text: '抢龙彩蛋上线',
          ),
          _buildTag(
            text: '观众英雄榜',
            trailing: SizedBox(
              width: 36,
              height: 16,
              child: Stack(
                children: [
                  Positioned(left: 0, child: _buildMiniAvatar(Colors.brown)),
                  Positioned(left: 10, child: _buildMiniAvatar(Colors.grey)),
                  Positioned(left: 20, child: _buildMiniAvatar(Colors.blueGrey)),
                ],
              ),
            ),
          ),
          _buildTag(text: '过往段位', textColor: Colors.white.withOpacity(0.4)),
        ],
      ),
    );
  }

  Widget _buildTag({Widget? icon, required String text, Widget? trailing, Color? textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          if (icon != null) ...[icon, const SizedBox(width: 4)],
          Text(
            text,
            style: TextStyle(color: textColor ?? Colors.white.withOpacity(0.9), fontSize: 12),
          ),
          if (trailing != null) ...[const SizedBox(width: 6), trailing],
        ],
      ),
    );
  }


  Widget _buildMiniAvatar(Color color) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        // 边框颜色调整为稍微透明的白色，以适应新背景
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
    );
  }

  /// 中间 3D 段位图标
  Widget _buildCenterBadge() {
    return Container(
      // 移除之前的背景RadialGradient，让模糊背景透出来，视觉更统一
      // 如果需要强调，可以加一个非常淡的白色光晕
      width: 220,
      height: 220,
      alignment: Alignment.center,
      child: Image.network(
        _rankImageUrl,
        fit: BoxFit.contain,
      ),
    );
  }

  /// 段位信息与进度条
  Widget _buildRankInfo() {
    int currentScore = 6316;
    int maxScore = 10000;
    double progress = currentScore / maxScore;
    int diff = maxScore - currentScore;

    return Column(
      children: [
        const Text(
          '钻石 5 星', // 修正文案
          style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              shadows: [
                Shadow(
                  offset: Offset(0, 2),
                  blurRadius: 4.0,
                  color: Color.fromARGB(120, 0, 0, 0),
                ),
              ]
          ),
        ),
        const SizedBox(height: 16),

        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '$currentScore',
                style: const TextStyle(
                  color: Color(0xFF6BD1DA),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto',
                ),
              ),
              TextSpan(
                text: '/$maxScore',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 16,
                  fontFamily: 'Roboto',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 进度条
        Container(
          width: 260,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2), // 背景槽加深
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            children: [
              Container(
                width: 260 * progress,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4EE8E8), Color(0xFFC8F6F6)],
                  ),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4EE8E8).withOpacity(0.6),
                      blurRadius: 8,
                      offset: const Offset(0, 0),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('差 ', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
            Text('$diff', style: const TextStyle(color: Color(0xFF6BD1DA), fontSize: 13, fontWeight: FontWeight.bold)),
            Text(' 积分升级', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
          ],
        ),
      ],
    );
  }

  /// 底部水平滑动的任务列表 (这个依然可以横向滑动)
  Widget _buildBottomTaskList() {
    final List<Map<String, String>> tasks = [
      {'title': '每日首场胜利(1/1)', 'subtitle': '已得积分', 'status': 'done'},
      {'title': '每日8场有效PK(1/8)', 'subtitle': '+10', 'status': 'pending'},
      {'title': '每日4场有效PK胜利(1/4)', 'subtitle': '+15', 'status': 'pending'},
      {'title': '抢夺连胜(33/...)', 'subtitle': '额外加分', 'status': 'pending'},
    ];

    return SizedBox(
      height: 70,
      // 使用 Physics 确保横向滑动顺畅
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: tasks.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final task = tasks[index];
          final isDone = task['status'] == 'done';
          return Container(
            width: 140,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              // 调整了卡片背景透明度，使其在复杂背景上更协调
                color: isDone ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isDone ? Colors.transparent : Colors.white.withOpacity(0.05)
                )
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  task['title']!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(isDone ? 0.4 : 0.7),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Text(
                  task['subtitle']!,
                  style: TextStyle(
                      color: isDone
                          ? Colors.white.withOpacity(0.3)
                          : const Color(0xFF6BD1DA), // 进行中的任务高亮
                      fontSize: 12,
                      fontWeight: isDone ? FontWeight.normal : FontWeight.bold
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}