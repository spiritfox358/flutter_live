import 'package:flutter/material.dart';

// 🟢 1. 引入您的数据模型
import 'package:flutter_live/models/user_models.dart';

// 🟢 2. 引入您的等级组件
import 'package:flutter_live/screens/home/live/widgets/level_badge_widget.dart';

// 🟢 3. 引入礼物预览弹窗
import 'package:flutter_live/screens/home/live/widgets/gift_preview/gift_preview_popup.dart';
import 'package:flutter_live/store/user_store.dart';

/// 弹出个人中心 (底部弹窗入口)
void showLivePersonalCenterPopup(BuildContext context, UserModel userModel) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => LivePersonalCenterPopup(userModel: userModel),
  );
}

class LivePersonalCenterPopup extends StatelessWidget {
  final UserModel userModel;

  const LivePersonalCenterPopup({super.key, required this.userModel});

  @override
  Widget build(BuildContext context) {
    // 定义一些特定颜色
    const Color headerBlueStart = Color(0xFF559DF9);
    const Color headerBlueEnd = Color(0xFF2C60F3);
    const Color mainBgColor = Color(0xFFF5F6FA);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: mainBgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          children: [
            // 🟢 修改点 1：蓝色背景区域更加紧凑
            Container(
              width: double.infinity,
              // 减少了上下的 padding，使头部变矮
              padding: const EdgeInsets.only(top: 24, bottom: 16, left: 20, right: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [headerBlueStart, headerBlueEnd], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 头像 (稍微调小一点点以适配紧凑高度)
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      image: DecorationImage(image: NetworkImage(UserStore.to.avatar ?? "https://i.pravatar.cc/150?img=10"), fit: BoxFit.cover),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 昵称与等级
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          UserStore.to.nickname ?? "未知用户",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20, // 字体微调适配紧凑布局
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            LevelBadge(level: userModel.level, monthLevel: userModel.monthLevel),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Text("等级权益", style: TextStyle(color: Colors.white, fontSize: 10)),
                                  Icon(Icons.keyboard_arrow_right, size: 10, color: Colors.white),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 下方的内容区域
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // --- 神秘商店 Banner ---
                  _buildMysteryShopBanner(context),

                  const SizedBox(height: 12),

                  // --- 🟢 修改点 2：类别区域 50% 平分对齐 ---
                  SizedBox(
                    height: 160,
                    child: Row(
                      children: [
                        // 左侧：甄爱系列 (皮肤) - 占 50%
                        Expanded(
                          // 移除 flex，默认就是 1:1
                          child: _buildSkinCard(),
                        ),
                        const SizedBox(width: 10),
                        // 右侧：御见万象 & 玫瑰公爵 - 占 50%
                        Expanded(
                          // 移除 flex，默认就是 1:1
                          child: Column(
                            children: [
                              Expanded(
                                child: _buildFeatureItem(
                                  title: "御见万象",
                                  subtitle: "天工万象 匠心造物",
                                  iconColor: const Color(0xFF4A90E2),
                                  iconData: Icons.all_inclusive,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: _buildFeatureItem(
                                  title: "玫瑰公爵",
                                  subtitle: "永恒之约,星河重逢",
                                  iconColor: const Color(0xFF9B59B6),
                                  iconData: Icons.local_florist,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 第二行：加速升级 & 进场隐身 (Grid) - 已经是 50% 平分
                  Row(
                    children: [
                      Expanded(
                        child: _buildFeatureItem(
                          title: "加速升级",
                          subtitle: "开通后加速等级升级",
                          iconColor: const Color(0xFFFFB74D),
                          iconData: Icons.notifications_active,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildFeatureItem(
                          title: "进场隐身",
                          subtitle: "享进场隐身特权",
                          iconColor: const Color(0xFF64B5F6),
                          iconData: Icons.visibility_off,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // 第三行：神秘人 (单行)
                  _buildFeatureItem(title: "神秘人", subtitle: "享尊贵匿名套装", iconColor: const Color(0xFF9575CD), iconData: Icons.person_pin, height: 80),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMysteryShopBanner(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(colors: [Color(0xFF1E2235), Color(0xFF2C304B)], begin: Alignment.centerLeft, end: Alignment.centerRight),
        boxShadow: [BoxShadow(color: const Color(0xFF1E2235).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Stack(
        children: [
          Positioned(right: -20, top: -20, child: Icon(Icons.shopping_bag, size: 120, color: Colors.white.withOpacity(0.05))),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD4AF37), width: 1),
                  ),
                  child: const Center(
                    child: Text(
                      "M",
                      style: TextStyle(color: Color(0xFFD4AF37), fontSize: 28, fontWeight: FontWeight.bold, fontFamily: "serif"),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          const Text(
                            "神秘商店",
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                            child: const Text("新品发售", style: TextStyle(color: Colors.white70, fontSize: 9)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text("马年系列全新发售", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),

                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const GiftPreviewPopup(),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFDE09E), Color(0xFFE2B76D)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "立即探索",
                      style: TextStyle(color: Color(0xFF4E342E), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkinCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(colors: [Color(0xFFE57373), Color(0xFFF06292)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: Colors.pink.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Stack(
        children: [
          Positioned(right: 0, bottom: 0, child: Icon(Icons.favorite, size: 80, color: Colors.white.withOpacity(0.2))),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFFFCC80), borderRadius: BorderRadius.circular(4)),
                  child: const Text(
                    "皮肤",
                    style: TextStyle(color: Color(0xFF5D4037), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                const Text(
                  "甄爱系列浪漫上线",
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                const Text("皮肤商城", style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({required String title, required String subtitle, required Color iconColor, required IconData iconData, double? height}) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: iconColor.withOpacity(0.1)),
            child: Icon(iconData, color: iconColor, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Color(0xFF333333), fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF999999), fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
