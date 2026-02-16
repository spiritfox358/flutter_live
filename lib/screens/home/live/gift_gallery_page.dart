import 'package:flutter/material.dart';

import '../../../store/user_store.dart';
import '../../../tools/HttpUtil.dart';

// ⚠️ 请根据你的实际项目结构调整 HttpUtil 的引入路径
// ===========================================================================
// 1. 数据模型
// ===========================================================================
class GiftItemModel {
  final String name;
  final String icon; // 实际项目中可换成 imageUrl
  final Color iconColor;
  final bool isLit;
  final int remainingCount;
  final String? lighterAvatar;

  GiftItemModel({required this.name, required this.icon, required this.iconColor, this.isLit = false, this.remainingCount = 0, this.lighterAvatar});
}

// ===========================================================================
// 2. 核心弹窗组件
// ===========================================================================
class GiftGalleryPopup extends StatefulWidget {
  final Map<String, dynamic> user;

  const GiftGalleryPopup({super.key, required this.user});

  // 🟢 静态 Show 方法
  static void show(BuildContext context, Map<String, dynamic>? user) {
    if (user == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // 背景透明
      builder: (context) => GiftGalleryPopup(user: user),
    );
  }

  @override
  State<GiftGalleryPopup> createState() => _GiftGalleryPopupState();
}

class _GiftGalleryPopupState extends State<GiftGalleryPopup> {
  // 🟢 新增：用于存储当前页面使用的用户数据
  late Map<String, dynamic> _userData;

  // 模拟数据
  final List<GiftItemModel> gifts = [
    GiftItemModel(
      name: "棒棒糖",
      icon: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/9_%E6%A3%92%E6%A3%92%E7%B3%96.png",
      iconColor: Colors.pinkAccent,
      isLit: true,
    ),
    GiftItemModel(
      name: "玫瑰",
      icon: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/1_%E7%8E%AB%E7%91%B0.png",
      iconColor: Colors.red,
      isLit: true,
    ),
    GiftItemModel(
      name: "小心心",
      icon: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/1_%E5%B0%8F%E5%BF%83%E5%BF%83.png",
      iconColor: Colors.pink,
      isLit: true,
    ),
    GiftItemModel(
      name: "暮光星辰",
      icon: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/99_%E6%9A%AE%E5%85%89%E6%98%9F%E8%BE%B0.png",
      iconColor: Colors.white,
      isLit: true,
      remainingCount: 6,
    ),
    GiftItemModel(
      name: "星光真爱",
      icon: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/520%E6%98%9F%E5%85%89%E7%9C%9F%E7%88%B1.png",
      iconColor: Colors.pink.shade200,
      isLit: true,
      remainingCount: 3,
    ),
    GiftItemModel(
      name: "暮光明珠",
      icon: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/888_%E6%9A%AE%E5%85%89%E6%98%8E%E7%8F%A0.png",
      iconColor: Colors.amber.shade100,
      isLit: true,
      remainingCount: 3,
    ),
    GiftItemModel(
      name: "星光营地",
      icon: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/1699_%E6%98%9F%E5%85%89%E8%90%A5%E5%9C%B0.png",
      iconColor: Colors.orange,
      isLit: true,
      remainingCount: 2,
    ),
    GiftItemModel(
      name: "暮光恋人",
      icon: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/1999_%E6%9A%AE%E5%85%89%E6%81%8B%E4%BA%BA.png",
      iconColor: Colors.purple.shade200,
      isLit: true,
      remainingCount: 1,
    ),
    GiftItemModel(
      name: "暮光花海",
      icon: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/2800_%E6%9A%AE%E5%85%89%E8%8A%B1%E6%B5%B7.png",
      iconColor: Colors.blue.shade100,
      isLit: true,
      remainingCount: 1,
    ),
    GiftItemModel(
      name: "大啤酒",
      icon:
          "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/%E8%B7%91%E8%BD%A6%20%C3%97%20%28%E7%BB%8F%E5%85%B8%29%20%C3%97%201200.png",
      iconColor: Colors.amber,
      isLit: true,
      remainingCount: 3,
    ),
    GiftItemModel(
      name: "加油鸭",
      icon: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/15_%E5%8A%A0%E6%B2%B9%E9%B8%AD.png",
      iconColor: Colors.yellow,
      isLit: true,
      remainingCount: 6,
    ),
    GiftItemModel(
      name: "爱你哟",
      icon: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/52_%E7%88%B1%E4%BD%A0%E5%93%9F.png",
      iconColor: Colors.redAccent,
      isLit: true,
      remainingCount: 4,
    ),
    GiftItemModel(
      name: "礼花筒",
      icon:
          "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/%E7%A4%BC%E8%8A%B1%E7%AD%92%20%C3%97%20%28%E6%99%AE%E9%80%9A%29%20%C3%97%20199.png",
      iconColor: Colors.redAccent,
      isLit: true,
      remainingCount: 4,
    ),
    GiftItemModel(
      name: "比心兔兔",
      icon: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/299_%E6%AF%94%E5%BF%83%E5%85%94%E5%85%94.png",
      iconColor: Colors.redAccent,
      isLit: true,
      remainingCount: 4,
    ),
    GiftItemModel(
      name: "一束花开",
      icon: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/366_%E4%B8%80%E6%9D%9F%E8%8A%B1%E5%BC%80.png",
      iconColor: Colors.redAccent,
      isLit: true,
      remainingCount: 4,
    ),
    GiftItemModel(
      name: "真爱玫瑰",
      icon:
          "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/%E7%9C%9F%E7%88%B1%E7%8E%AB%E7%91%B0%20%C3%97%20%28%E6%99%AE%E9%80%9A%29%20%C3%97%20366.png",
      iconColor: Colors.redAccent,
      isLit: true,
      remainingCount: 4,
    ),
    GiftItemModel(
      name: "热气球",
      icon: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/520_%E7%83%AD%E6%B0%94%E7%90%83_3896.png",
      iconColor: Colors.brown,
      isLit: true,
      remainingCount: 2,
    ),
    GiftItemModel(
      name: "万象烟花",
      icon:
          "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/%E4%B8%87%E8%B1%A1%E7%83%9F%E8%8A%B1%20%C3%97%20%28%E7%83%9F%E8%8A%B1%29%20%C3%97%20688.png",
      iconColor: Colors.redAccent,
      isLit: true,
      remainingCount: 4,
    ),
    GiftItemModel(
      name: "跑车",
      icon:
          "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/%E8%B7%91%E8%BD%A6%20%C3%97%20%28%E7%BB%8F%E5%85%B8%29%20%C3%97%201200.png",
      iconColor: Colors.red,
      isLit: true,
      remainingCount: 1,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // 1. 先使用传入的参数作为默认数据 (保证 UI 立刻有内容)
    _userData = widget.user;
    // 2. 异步请求最新数据
    _fetchUserInfo();
  }

  // 🟢 接口调用逻辑
  void _fetchUserInfo() async {
    final userId = widget.user['userId'];
    if (userId == null) return;

    try {
      // 调用 HttpUtil (参考你提供的 HttpUtil.dart)
      var result = await HttpUtil().get('/api/user/info', params: {'userId': userId});

      // 请求成功，更新 UI
      if (mounted && result != null) {
        setState(() {
          // 将返回的数据覆盖当前数据
          // 如果返回的数据不包含完整字段，你可能需要做合并操作：{..._userData, ...result}
          _userData = result;
        });
      }
    } catch (e) {
      debugPrint("获取用户详情失败: $e");
      // 失败时不更新 UI，保持原有显示
    }
  }

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.of(context).size.height * 0.75;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0D1E40), Color(0xFF050A18)]),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // 子组件居左
        children: [
          // 顶部把手
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 5),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // 标题栏 (🔴 修改：传入 _userData 而不是 widget.user)
          _buildHeader(_userData),

          // 进度条
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                children: [
                  TextSpan(
                    text: "已点亮 ${gifts.where((g) => g.isLit).length}",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  TextSpan(
                    text: "/${gifts.length}",
                    style: const TextStyle(color: Colors.white30), // 灰色
                  ),
                ],
              ),
            ),
          ),

          // 礼物 Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.7, // 调整宽高比适配斜切形状
                mainAxisSpacing: 12,
                crossAxisSpacing: 8,
              ),
              itemCount: gifts.length,
              itemBuilder: (context, index) => _buildGiftCard(gifts[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> user) {
    // 优先取 name, 如果没有取 nickName (根据实际后端返回调整)
    String userName = user['nickname'] ?? "未知用户";
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    userName,
                    style: const TextStyle(color: Colors.yellowAccent, fontSize: 18, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  // "的礼物展馆",
                  "的满贯展馆",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
            child: const Row(
              children: [
                Text("展馆新人专属", style: TextStyle(color: Colors.white70, fontSize: 10)),
                SizedBox(width: 2),
                Icon(Icons.help_outline, color: Colors.white70, size: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🟢 核心修改：构建单个礼物卡片 (使用 CustomPaint 实现斜切)
  Widget _buildGiftCard(GiftItemModel item) {
    // 1. 背景下沉高度
    const double bgTopMargin = 18.0;
    // 2. 底部状态条高度
    const double bottomBarHeight = 24.0;

    return Stack(
      clipBehavior: Clip.none, // 允许溢出
      children: [
        // ============================================================
        // 🟢 第一层：背景容器 (背景图 + 底部状态条 + 礼物名称)
        // ============================================================
        Positioned(
          top: bgTopMargin,
          bottom: 0,
          left: 0,
          right: 0,
          child: Stack(
            children: [
              // A. 背景画笔
              Positioned.fill(
                child: CustomPaint(painter: GiftCardPainter(isLit: item.isLit)),
              ),

              // B. 底部状态条
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: bottomBarHeight,
                  margin: const EdgeInsets.only(bottom: 0),
                  decoration: BoxDecoration(
                    color: item.isLit ? Colors.blue.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                  ),
                  alignment: Alignment.center,
                  child: item.isLit
                      ? const Text("已点亮", style: TextStyle(color: Colors.blueAccent, fontSize: 10))
                      : RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 10, color: Colors.white54),
                            children: [
                              const TextSpan(text: "差"),
                              TextSpan(
                                text: "${item.remainingCount}",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              const TextSpan(text: "个"),
                            ],
                          ),
                        ),
                ),
              ),

              // C. 礼物名称 (位于状态条上方，头像下方)
              Positioned(
                bottom: bottomBarHeight + 8,
                left: 4,
                right: 4,
                child: Text(
                  item.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: item.isLit ? Colors.blue.shade100 : Colors.white38, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),

        // ============================================================
        // 🟢 第二层：前景物体 (礼物 + 头像)
        // ============================================================
        Positioned(
          top: 0,
          // 顶住最上沿
          left: 0,
          right: 0,
          // 限制底部，确保不会遮挡下面的文字
          bottom: bottomBarHeight + 20,
          child: Center(
            // 使用 Stack 自由堆叠
            child: SizedBox(
              width: 60,
              height: 60,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // 1. 礼物图标 (先画，在底层)
                  Positioned(
                    top: 0, // 礼物靠上
                    child: item.isLit
                        ? Image.network(item.icon, width: 50, height: 50, fit: BoxFit.contain)
                        : Opacity(opacity: 0.5, child: Image.network(item.icon, width: 50, height: 50, fit: BoxFit.contain)),
                  ),

                  // 2. 头像 (后画，在顶层！确保盖住礼物)
                  if (item.isLit)
                    Positioned(
                      bottom: 5, // 钉在容器底部
                      child: Container(
                        width: 19,
                        height: 19,
                        decoration: BoxDecoration(
                          color: const Color(0xFF162445), // 这一层颜色让头像看起来像“切”进了礼物
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF162445), width: 1.5),
                        ),
                        child: CircleAvatar(radius: 18, backgroundImage: NetworkImage(UserStore.to.avatar)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// 3. 🎨 核心画笔：绘制斜切圆融形状
// ===========================================================================
class GiftCardPainter extends CustomPainter {
  final bool isLit;

  GiftCardPainter({required this.isLit});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF1A2E55), const Color(0xFF111C35).withOpacity(0.9)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.blue.withOpacity(0.4)
      ..strokeWidth = 1.0;

    final Path path = Path();

    // 参数配置
    double radius = 12.0; // 底部圆角
    double topRadius = 18.0; // 顶部圆角 (稍微加大一点更顺滑)
    double slantHeight = 25.0; // 左侧起始高度 (y值越大越低)

    // 计算斜率带来的高度差 (用于精准计算圆角结束点)
    // 这是一个简单的比例：每移动 1px，y轴上升多少
    double slopeDropPerPixel = slantHeight / size.width;
    double leftCornerYOffset = slopeDropPerPixel * topRadius; // 左边圆角结束时的y提升量
    double rightCornerYOffset = slopeDropPerPixel * topRadius; // 右边圆角开始时的y下降量

    // 1. 左下角起点
    path.moveTo(0, size.height - radius);

    // 2. 左侧边线 -> 往上画，停在圆角开始处
    path.lineTo(0, slantHeight + topRadius);

    // 🟢【修改点1】左上角圆角：不画水平圆，而是画“切线圆”
    // 控制点 (0, slantHeight)：即“原本尖角”的位置
    // 终点 (topRadius, slantHeight - leftCornerYOffset)：落在斜线上
    path.quadraticBezierTo(0, slantHeight, topRadius, slantHeight - leftCornerYOffset);

    // 🟢【修改点2】顶部直线：直接连到右上角圆角“开始”的地方
    // 终点 x = width - topRadius
    // 终点 y = 0 + rightCornerYOffset (因为右边是0，稍微下来一点点以适应斜率)
    path.lineTo(size.width - topRadius, rightCornerYOffset);

    // 🟢【修改点3】右上角圆角
    // 控制点 (size.width, 0)：即“原本尖角”的位置
    // 终点 (size.width, topRadius)：回到垂直线上
    path.quadraticBezierTo(size.width, 0, size.width, topRadius);

    // 6. 右侧边线 -> 到底部
    path.lineTo(size.width, size.height - radius);

    // 7. 右下角圆角
    path.quadraticBezierTo(size.width, size.height, size.width - radius, size.height);

    // 8. 底部边线
    path.lineTo(radius, size.height);

    // 9. 左下角圆角 -> 闭合
    path.quadraticBezierTo(0, size.height, 0, size.height - radius);

    path.close();

    canvas.drawPath(path, fillPaint);

    if (isLit) {
      canvas.drawPath(path, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant GiftCardPainter oldDelegate) {
    return oldDelegate.isLit != isLit;
  }
}
