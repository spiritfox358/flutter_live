import 'package:flutter/material.dart';
import 'package:flutter_live/screens/home/live/subpages/pk_rank/pk_rank_index.dart';
import 'package:flutter_live/screens/home/live/widgets/level_badge_widget.dart';
import 'package:flutter_live/screens/me/profile/user_profile_page.dart';
import '../../../../../tools/HttpUtil.dart';
import '../../models/user_decorations_model.dart';
import '../../subpages/gift_gallery/gift_gallery_index.dart';

class LiveUserProfilePopup extends StatefulWidget {
  final Map<String, dynamic> user;

  const LiveUserProfilePopup({super.key, required this.user});

  static void show(BuildContext context, Map<String, dynamic>? user) {
    showModalBottomSheet(
      context: context,
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

  // 🚀 新增：关注状态相关变量
  int _relationStatus = 0; // 0-未关注, 1-已关注, 2-互相关注, -1-自己
  String _relationText = "关注";
  bool _isRelationLoading = true; // 防止连点死锁

  @override
  void initState() {
    super.initState();
    _fetchData(); // 🚀 统一加载用户信息和关系状态
  }

  // 🚀 统一获取数据的入口
  Future<void> _fetchData() async {
    await Future.wait([
      _fetchUserInfo(),
      _fetchRelationStatus(),
    ]);
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
      if (mounted) setState(() => isLoading = false);
    }
  }

  // 🚀 新增：拉取我和他的关注关系
  Future<void> _fetchRelationStatus() async {
    try {
      var data = await HttpUtil().get('/api/relation/status', params: {'targetId': widget.user["userId"]});
      if (mounted && data != null) {
        setState(() {
          _relationStatus = data['status'] ?? 0;
          _relationText = data['text'] ?? "关注";
          _isRelationLoading = false;
        });
      }
    } catch (e) {
      debugPrint("获取关系状态失败: $e");
      if (mounted) setState(() => _isRelationLoading = false);
    }
  }

  // 🚀 新增：点击关注/取消关注的逻辑
  Future<void> _toggleFollow() async {
    if (_isRelationLoading || _relationStatus == -1) return;

    setState(() => _isRelationLoading = true);
    try {
      if (_relationStatus == 0) {
        // 当前未关注 -> 发起关注
        await HttpUtil().post('/api/relation/follow', data: {'targetId': widget.user["userId"]});
      } else {
        // 当前已关注/互关 -> 取消关注
        await HttpUtil().post('/api/relation/unfollow', data: {'targetId': widget.user["userId"]});
      }
      // 操作成功后，重新拉取状态和用户信息（为了刷新粉丝数）
      await _fetchData();
    } catch (e) {
      if (mounted) {
        setState(() => _isRelationLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("操作失败: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final safeAreaPadding = mediaQuery.padding;
    final maxHeight = mediaQuery.size.height * 0.85 - safeAreaPadding.top;

    return ClipRRect(
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
      child: SingleChildScrollView(
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
                  const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator(color: Color(0xFFFF2E55))),
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
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopSection() {
    String avatarUrl = userInfo?['avatar'] ?? "https://via.placeholder.com/150";
    final Map<String, dynamic>? rawDecorations = userInfo?['decorations'] as Map<String, dynamic>?;
    final UserDecorationsModel decorations = UserDecorationsModel.fromMap(rawDecorations ?? {});

    // 🚀 核心逻辑优化：针对“自己”进行完全不同的 UI 渲染
    bool isMe = _relationStatus == -1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 头像部分
          GestureDetector(
            onTap: () {
              // 这个跳转跟点击头像一样，直接进个人中心
              Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfilePage(userInfo: userInfo)));
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

          const SizedBox(width: 16), // 🚀 调整一下间距

          // 右侧按钮区域
          Expanded( // 🚀 让这一块可以撑满
            child: Column( // 使用 Column 容纳按钮
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isMe) ...[
                  // 🚀🚀🚀 终极改造：如果是自己，显示整个横跨的大按钮，不显示其他两个小按钮
                  GestureDetector(
                    onTap: () {
                      // 🚀 跳转跟头像点击逻辑完全一样
                      Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfilePage(userInfo: userInfo)));
                    },
                    child: Container(
                      height: 38, // 🚀 调高一点点，看着更厚实
                      width: double.infinity, // 🟢 撑满这一行的所有剩余空间！
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5), // 自己是灰色
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300, width: 0.5), // 🟢 加上边框，更有质感
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person, color: Colors.black54, size: 16), // 🟢 加上个人图标
                            const SizedBox(width: 6),
                            Text(
                              _relationText, // 🚀 动态显示后端传来的“个人中心”
                              style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // 🚀 场景：是别人，保持原有的“关注 + 2个小图标”逻辑
                  Row(
                    children: [
                      // 原来的 Expanded(child: 关注按钮) 逻辑
                      Expanded(
                        child: GestureDetector(
                          onTap: _toggleFollow,
                          child: Container(
                            height: 35,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: _relationStatus == 0 ? const Color(0xFFFF2E55) : const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isRelationLoading)
                                  const SizedBox(
                                      width: 14, height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey)
                                  )
                                else ...[
                                  if (_relationStatus == 0)
                                    const Icon(Icons.add, color: Colors.white, size: 16, fontWeight: FontWeight.bold)
                                  else if (_relationStatus == 2)
                                    const Icon(Icons.swap_horiz, color: Colors.black54, size: 16),

                                  SizedBox(width: _relationStatus == 0 ? 0 : 4),
                                  Text(
                                    _relationText,
                                    style: TextStyle(
                                        color: _relationStatus == 0 ? Colors.white : Colors.black54,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),
                      // 原来的 _buildIconBtn(Icons.alternate_email) 和举报按钮
                      _buildIconBtn(Icons.alternate_email),
                      const SizedBox(width: 8),
                      _buildIconBtn(Icons.warning_amber_rounded),
                    ],
                  ),
                ],
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
        border: Border.all(color: Colors.grey.shade300),
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
        LevelBadge(level: level, monthLevel: monthLevel, showConsumption: true),
      ],
    );
  }

  Widget _buildTagsRow() {
    String age = userInfo?['age']?.toString() ?? "18";
    String city = userInfo?['city'] ?? "未知星球";
    bool isFemale = userInfo?['gender'].toString() == "2";

    return Row(
      children: [
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
                    print('点击了礼物图鉴');
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
                    PkRankIndex.show(context);
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