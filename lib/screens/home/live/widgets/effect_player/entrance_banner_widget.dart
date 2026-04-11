import 'package:flutter/material.dart';

class EntranceBannerWidget extends StatefulWidget {
  // 基础数据
  final String avatarUrl; // 头像链接
  final String userName; // 用户名
  final VoidCallback onComplete; // 播放完毕回调

  // 🛠️ 核心 UI 尺寸可调节参数 (🚀 新增)
  final double avatarSize; // 头像大小
  final double bannerHeight; // 横条高度（窄一点更精致）

  // 🛠️ 核心可调节参数
  final double? floatEffectTop; // 出场特效top
  final double verticalOffset; // 出场高度
  final Color primaryColor; // 横条的主题色
  final Duration shimmerSpeed; // 扫光速度

  // ⏱️ 时间轴控制
  final Duration slideInTime; // 滑入耗时
  final Duration stayTime; // 停留时间
  final Duration slideOutTime; // 滑出耗时

  // 🎢 运动轨迹曲线控制
  final Curve slideInCurve;
  final Curve slideOutCurve;

  const EntranceBannerWidget({
    super.key,
    required this.avatarUrl,
    required this.userName,
    required this.onComplete,
    this.avatarSize = 37.0, // 🚀 默认头像变小 (原48)
    this.bannerHeight = 23.0, // 🚀 默认横条变窄 (原34)
    this.floatEffectTop = 16.0,
    this.verticalOffset = 150.0,
    this.primaryColor = const Color(0xFFFF4D81),
    this.shimmerSpeed = const Duration(milliseconds: 6000),
    this.slideInTime = const Duration(seconds: 1),
    this.stayTime = const Duration(milliseconds: 4000),
    this.slideOutTime = const Duration(seconds: 1),
    this.slideInCurve = Curves.easeOutExpo,
    this.slideOutCurve = Curves.easeInExpo,
  });

  @override
  State<EntranceBannerWidget> createState() => _EntranceBannerWidgetState();
}

class _EntranceBannerWidgetState extends State<EntranceBannerWidget> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _slideInAnimation;
  late Animation<double> _slideOutAnimation;

  late AnimationController _shimmerController;

  late double _inEndRatio;
  late double _outStartRatio;

  @override
  void initState() {
    super.initState();

    final int totalMs = widget.slideInTime.inMilliseconds + widget.stayTime.inMilliseconds + widget.slideOutTime.inMilliseconds;
    _inEndRatio = widget.slideInTime.inMilliseconds / totalMs;
    _outStartRatio = (widget.slideInTime.inMilliseconds + widget.stayTime.inMilliseconds) / totalMs;

    _mainController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    );

    _slideInAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: Interval(0.0, _inEndRatio, curve: widget.slideInCurve),
      ),
    );

    _slideOutAnimation = Tween<double>(begin: 0.0, end: -1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: Interval(_outStartRatio, 1.0, curve: widget.slideOutCurve),
      ),
    );

    _shimmerController = AnimationController(vsync: this, duration: widget.shimmerSpeed);
    _shimmerController.repeat();

    _mainController.forward().then((_) {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, child) {
        double offsetX = 0;

        if (_mainController.value <= _inEndRatio) {
          offsetX = _slideInAnimation.value * screenWidth;
        } else if (_mainController.value >= _outStartRatio) {
          offsetX = _slideOutAnimation.value * screenWidth;
        } else {
          offsetX = 0;
        }

        return Transform.translate(
          offset: Offset(offsetX, widget.verticalOffset),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(padding: const EdgeInsets.only(left: 12.0), child: _buildBannerUI()),
          ),
        );
      },
    );
  }

  Widget _buildBannerUI() {
    // 提取为局部变量方便使用
    final double aSize = widget.avatarSize;
    final double bHeight = widget.bannerHeight;

    return SizedBox(
      height: aSize,
      child: Stack(
        alignment: Alignment.centerLeft,
        clipBehavior: Clip.none,
        children: [
          // ====================================================
          // 1. 横条背景
          // ====================================================
          Container(
            margin: EdgeInsets.only(left: aSize / 2),
            height: bHeight,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.primaryColor,
                  widget.primaryColor.withOpacity(0.8),
                  widget.primaryColor.withOpacity(0.3),
                  widget.primaryColor.withOpacity(0.0),
                ],
                stops: const [0.0, 0.3, 0.6, 1.0],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // 💡 a. 动态扫光层 (大倾斜角刀光版)
                Positioned.fill(
                  child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (bounds) {
                      return const LinearGradient(
                        colors: [Colors.white, Colors.white, Colors.white30, Colors.transparent],
                        stops: [0.0, 0.3, 0.6, 1.0],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ).createShader(bounds);
                    },
                    child: AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (context, child) {
                        double p = _shimmerController.value;
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment(-3.0 + p * 8, -8.0),
                              end: Alignment(-1.0 + p * 8, 8.0),
                              colors: [
                                Colors.white.withOpacity(0.0),
                                Colors.white.withOpacity(0.15),
                                Colors.white.withOpacity(0.60),
                                Colors.white.withOpacity(0.15),
                                Colors.white.withOpacity(0.0),
                              ],
                              stops: const [0.0, 0.4, 0.5, 0.6, 1.0],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // 📝 b. 文字内容层
                Padding(
                  // padding 也根据新的尺寸动态适配
                  padding: EdgeInsets.only(left: (aSize / 2) + 6, right: 80.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        widget.userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13, // 🚀 配合变窄的横条，字号微微调小（原14）
                          fontWeight: FontWeight.w900,
                          shadows: [Shadow(color: Colors.black38, offset: Offset(1, 1), blurRadius: 2)],
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        "进入了直播间",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11, // 🚀 字号微微调小（原12）
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ====================================================
          // 2. 头像层
          // ====================================================
          Container(
            width: aSize,
            height: aSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.0),
              boxShadow: [BoxShadow(color: widget.primaryColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))],
              image: DecorationImage(image: NetworkImage(widget.avatarUrl), fit: BoxFit.cover),
            ),
          ),
        ],
      ),
    );
  }
}
