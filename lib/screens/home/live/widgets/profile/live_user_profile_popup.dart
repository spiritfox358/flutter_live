import 'package:flutter/material.dart';
import 'package:flutter_live/models/user_models.dart';
import 'package:flutter_live/screens/home/live/widgets/common/admin_badge_widget.dart';
import 'package:flutter_live/screens/home/live/widgets/level_badge_widget.dart';
import '../../../../../tools/HttpUtil.dart';
import '../../gift_gallery_page.dart';
import '../../models/user_decorations_model.dart';

class LiveUserProfilePopup extends StatefulWidget {
  final Map<String, dynamic> user;

  const LiveUserProfilePopup({super.key, required this.user});

  static void show(BuildContext context, Map<String, dynamic>? user) {
    showModalBottomSheet(
      context: context,
      // enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LiveUserProfilePopup(user: user!),
    );
  }

  @override
  State<LiveUserProfilePopup> createState() => _LiveUserProfilePopupState();
}

class _LiveUserProfilePopupState extends State<LiveUserProfilePopup> {
  Map<String, dynamic>? userInfo;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
  }

  Future<void> _fetchUserInfo() async {
    try {
      var data = await HttpUtil().get('/api/user/info', params: {'userId': widget.user["userId"]});
      if (mounted) {
        setState(() {
          userInfo = data;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("获取用户信息失败: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final safeAreaPadding = mediaQuery.padding;
    // 最大高度：不超过屏幕高度的 85%，并减去安全区域和一点余量
    final maxHeight = mediaQuery.size.height * 0.85 - safeAreaPadding.top;

    return ClipRRect(
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
      child: SingleChildScrollView(
        // 这里保留 BouncingScrollPhysics，这是最顺手的原生体验
        physics: const ClampingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Material(
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isLoading)
                  SizedBox(
                    height: 200, // 加载态占位
                    child: const Center(child: CircularProgressIndicator(color: Color(0xFFFF2E55))),
                  )
                else if (userInfo == null)
                  const SizedBox(height: 200, child: Center(child: Text("加载失败或用户不存在")))
                else ...[
                  _buildTopSection(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        _buildNameRow(),
                        const SizedBox(height: 8),
                        _buildTagsRow(),
                        const SizedBox(height: 12),
                        _buildStatsRow(),
                        const SizedBox(height: 8),
                        Text(
                          userInfo?['signature'] ?? "这个人很懒，什么都没留下",
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
                  _buildBottomGrid(),
                  // 底部留白
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ========== 以下子组件完全保持原样，无需变动 ==========

  Widget _buildTopSection() {
    String avatarUrl = userInfo?['avatar'] ?? "https://via.placeholder.com/150";
    final Map<String, dynamic>? rawDecorations = userInfo?['decorations'] as Map<String, dynamic>?;
    final UserDecorationsModel decorations = UserDecorationsModel.fromMap(rawDecorations ?? {});
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              LiveUserProfilePopup.show(context, userInfo);
            },
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    image: DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                ),
                if (decorations.hasAvatarFrame)
                  Positioned(
                    top: -6,
                    left: -6,
                    child: SizedBox(width: 84, height: 84, child: Image.network(decorations.avatarFrame as String, fit: BoxFit.contain)),
                  ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: MediaQuery.of(context).size.width - 135, // 例如留 16px 左右边距
            child: Row(
              children: [
                // 👇 用 Expanded 包裹关注按钮，让它占满剩余空间
                Expanded(
                  child: GestureDetector(
                    onTap: () => debugPrint("点击关注 ${userInfo?["userId"]}"),
                    child: Container(
                      height: 35,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF2E55),
                        borderRadius: BorderRadius.circular(4), // 建议至少 4
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center, // 内容居中
                        children: [
                          Icon(Icons.add, color: Colors.white, size: 16, fontWeight: FontWeight.bold),
                          const SizedBox(width: 0),
                          const Text(
                            "关注",
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildIconBtn(Icons.alternate_email),
                const SizedBox(width: 8),
                _buildIconBtn(Icons.warning_amber_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconBtn(IconData icon) {
    return Container(
      width: 35,
      height: 35,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: Colors.black54, size: 21),
    );
  }

  Widget _buildNameRow() {
    String nickname = userInfo?["nickname"];
    int level = int.tryParse(userInfo?['level'].toString() ?? "1") ?? 1;
    int monthLevel = int.tryParse(userInfo?['monthLevel'].toString() ?? "0") ?? 0;

    return Row(
      children: [
        Flexible(
          child: Text(
            nickname,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        LevelBadge(level: level, monthLevel: monthLevel),
      ],
    );
  }

  Widget _buildTagsRow() {
    String age = userInfo?['age']?.toString() ?? "18";
    String city = userInfo?['city'] ?? "未知星球";
    bool isFemale = userInfo?['gender'].toString() == "2";

    return Row(
      children: [
        if (1 == 2) Row(children: [AdminBadgeWidget(), const SizedBox(width: 8)]),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: isFemale ? const Color(0xFFFFEBEE) : Colors.blue[50], borderRadius: BorderRadius.circular(4)),
          child: Row(
            children: [
              Icon(isFemale ? Icons.female : Icons.male, color: isFemale ? const Color(0xFFFF4081) : Colors.blue, size: 12),
              const SizedBox(width: 2),
              Text("$age岁", style: TextStyle(color: isFemale ? const Color(0xFFFF4081) : Colors.blue, fontSize: 10)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildStaticTag(city, Colors.grey[100]!, Colors.grey),
      ],
    );
  }

  Widget _buildStaticTag(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(color: textCol, fontSize: 10)),
    );
  }

  Widget _buildStatsRow() {
    String follow = userInfo?['followCount']?.toString() ?? "0";
    String fans = userInfo?['fansCount']?.toString() ?? "0";

    return Row(children: [_buildStatItem(follow, "关注"), const SizedBox(width: 20), _buildStatItem(fans, "粉丝")]);
  }

  Widget _buildStatItem(String num, String label) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: "$num ",
            style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          TextSpan(
            text: label,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomGrid() {
    return Container(
      color: const Color(0xFFFAFAFA),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildCard(
                  iconUrl: "",
                  title: "粉丝团",
                  subWidget: const Icon(Icons.favorite, color: Colors.blueAccent, size: 14),
                  bgColor: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCard(
                  iconUrl: "",
                  title: "会员",
                  subWidget: const Text(
                    "未开通",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                  bgColor: Colors.white,
                  rightWidget: const Text(
                    "V",
                    style: TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {

                    // 礼物图鉴点击事件
                    print('点击了礼物图鉴');
                    // 或者跳转页面：Navigator.push(...)
                  },
                  child: _buildCard(
                    iconUrl: "",
                    title: "礼物图鉴",
                    subWidget: const Text(
                      "0/6",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    GiftGalleryPopup.show(context, userInfo);
                  },
                  child: _buildCard(
                    iconUrl: "",
                    title: "礼物展馆",
                    subWidget: _buildTag("已集齐", const Color(0xFFE1BEE7), Colors.purple),
                    rightWidget: const Text("28/28", style: TextStyle(color: Colors.grey, fontSize: 10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    // PK段位点击事件
                    print('点击了PK段位');
                  },
                  child: _buildCard(
                    iconUrl: "",
                    title: "PK段位",
                    subWidget: const Text(
                      "钻石1星",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Color(0xFF5E35B1), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(2)),
      child: Text(text, style: TextStyle(color: textCol, fontSize: 9), maxLines: 1),
    );
  }

  Widget _buildCard({required String iconUrl, required String title, Widget? subWidget, Color bgColor = Colors.white, Widget? rightWidget}) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          if (iconUrl.isNotEmpty)
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(color: Color(0xFFF5F5F5), shape: BoxShape.circle),
                  child: ClipOval(
                    child: Image.network(
                      iconUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.image_not_supported, color: Colors.grey, size: 18);
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.grey)));
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                if (subWidget != null)
                  SizedBox(
                    height: 16,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: subWidget),
                    ),
                  ),
              ],
            ),
          ),
          if (rightWidget != null) Padding(padding: const EdgeInsets.only(left: 2), child: rightWidget),
        ],
      ),
    );
  }
}
