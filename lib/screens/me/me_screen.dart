import 'package:flutter/material.dart';
import 'package:flutter_live/screens/me/profile/edit_profile_page.dart';
import 'package:flutter_live/services/user_service.dart';
import '../../../store/user_store.dart';
import '../login/login_page.dart';
import 'support_page.dart';

class MeScreen extends StatefulWidget {
  const MeScreen({super.key});

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  Map<String, dynamic> get userProfile => UserStore.to.profile ?? {};

  @override
  void initState() {
    super.initState();
  }

  void _handleLogout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        title: Text("提示", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Text("确定要退出登录吗？", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("取消", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await UserStore.to.logout();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                      (route) => false,
                );
              }
            },
            child: const Text("退出", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color backgroundColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
    final Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black;
    final Color subTextColor = isDark ? Colors.white70 : Colors.grey;
    final Color iconColor = isDark ? Colors.white70 : Colors.black87;

    final String avatar = userProfile['avatar'] ?? "https://picsum.photos/200";
    final String nickname = userProfile['nickname'] ?? "未知用户";
    final String userId = userProfile['id']?.toString() ?? "0";
    final int level = userProfile['level'] ?? 1;
    final int vipLevel = userProfile['vipLevel'] ?? 0;
    final num coin = userProfile['coin'] ?? 0;
    final num diamond = userProfile['diamond'] ?? 0;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text("个人中心", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: cardColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: iconColor),
            onPressed: () {},
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 10),
            // 🟢 在这里调用头部构建方法
            _buildUserHeader(
                avatar, nickname, userId, level, vipLevel,
                cardColor, textColor, subTextColor
            ),
            const SizedBox(height: 16),
            _buildWalletCard(coin, diamond),
            const SizedBox(height: 16),
            _buildMenuSection(cardColor, textColor, iconColor),
            const SizedBox(height: 30),
            _buildLogoutButton(cardColor),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // 🟢 修改处：包裹 GestureDetector 并添加跳转逻辑
// 🟢 修改后的头部构建方法
  Widget _buildUserHeader(
      String avatar, String nickname, String id, int level, int vipLevel,
      Color cardColor, Color textColor, Color subTextColor
      ) {
    return GestureDetector(
      onTap: () async {
        // 1. 跳转到编辑页面
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditProfilePage(
              currentAvatarUrl: avatar,
              currentNickname: nickname,
            ),
          ),
        );

        // 🟢 2. 核心步骤：从编辑页回来后
        // 先等待最新的用户信息同步完成
        await UserService.syncUserInfo();

        // 🟢 3. 关键：手动更新头像版本号
        // 告诉 UserStore：“我刚才改了头像，请生成一个新的 Key，让图片强制刷新”
        UserStore.to.forceUpdateAvatar();

        // 4. 刷新当前 UI
        if (mounted) {
          setState(() {
            // 触发 build，UI 会读取到最新的 UserStore.to.profile 和 UserStore.to.avatarKey
          });
        }
      },
      child: Container(
        color: cardColor,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.purpleAccent.withOpacity(0.5), width: 2),
              ),
              child: CircleAvatar(
                radius: 36,
                // 🟢 4. 核心修改：使用 Store 里的 Key
                // 原理：平时 key 不变 -> 命中缓存 -> 界面不闪烁
                //      改完头像 key 变了 -> 视为新 URL -> 强制刷新图片
                backgroundImage: NetworkImage(avatar),

                onBackgroundImageError: (exception, stackTrace) {
                  debugPrint("头像加载失败");
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nickname,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "ID: $id",
                    style: TextStyle(color: subTextColor, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Colors.blue, Colors.cyan]),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "Lv.$level",
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (vipLevel > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.verified, size: 10, color: Colors.deepOrange),
                              const SizedBox(width: 2),
                              Text(
                                "VIP$vipLevel",
                                style: const TextStyle(color: Colors.deepOrange, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                    ],
                  )
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: subTextColor),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletCard(num coin, num diamond) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildAssetItem("我的金币", coin.toString(), Icons.monetization_on, Colors.amber),
          Container(width: 1, height: 40, color: Colors.white24),
          _buildAssetItem("我的钻石", diamond.toString(), Icons.diamond, Colors.pinkAccent),
        ],
      ),
    );
  }

  Widget _buildAssetItem(String label, String value, IconData icon, Color iconColor) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildMenuSection(Color cardColor, Color textColor, Color iconColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildMenuItem(
            Icons.favorite,
            "赞赏支持",
            null,
            textColor,
            iconColor,
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SupportPage())
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, String? trailingText, Color textColor, Color iconColor, {VoidCallback? onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: TextStyle(fontSize: 15, color: textColor)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(trailingText, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider(Color cardColor) {
    return const Divider(height: 1, indent: 60, color: Colors.grey);
  }

  Widget _buildLogoutButton(Color cardColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _handleLogout,
          style: ElevatedButton.styleFrom(
            backgroundColor: cardColor,
            foregroundColor: Colors.redAccent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.redAccent, width: 1),
            ),
          ),
          child: const Text(
            "退出登录",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}