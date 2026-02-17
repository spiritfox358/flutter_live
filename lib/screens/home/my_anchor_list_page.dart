import 'package:flutter/material.dart';
import '../../tools/HttpUtil.dart'; // 请确保路径正确
import 'live_list_page.dart'; // 引入 AnchorInfo 模型和 RippleAvatar 组件
import 'create_anchor_page.dart'; // 引入创建页面

class MyAnchorListPage extends StatefulWidget {
  const MyAnchorListPage({super.key});

  @override
  State<MyAnchorListPage> createState() => _MyAnchorListPageState();
}

class _MyAnchorListPageState extends State<MyAnchorListPage> with AutomaticKeepAliveClientMixin {
  List<AnchorInfo> _myAnchors = [];
  bool _isInitLoading = true;
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();

  @override
  bool get wantKeepAlive => true; // 保持页面状态，切换tab不重载

  @override
  void initState() {
    super.initState();
    _handleRefresh();
  }

  // 获取“我的主播”列表
  Future<void> _handleRefresh() async {
    try {
      // 假设后端有一个接口 /api/anchor/my_list 获取我创建的主播
      // 这里暂时用 /api/room/list 模拟，你可以替换成真实的接口
      var responseData = await HttpUtil().get("/api/room/list");

      if (mounted) {
        setState(() {
          // 这里简单模拟数据筛选，实际请使用真实数据
          List<dynamic> list = responseData as List;
          _myAnchors = list.map((json) => AnchorInfo.fromJson(json)).toList();
          _isInitLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isInitLoading = false);
      debugPrint("加载我的主播失败: $e");
    }
  }

  // 跳转到创建主播页面
  void _onCreateAnchor() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const CreateAnchorPage()),
    ).then((value) {
      // 如果创建成功返回后需要刷新列表
      if (value == true) {
        _handleRefresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用
    final theme = Theme.of(context);
    final dividerColor = theme.dividerColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // 悬浮按钮：创建主播
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onCreateAnchor,
        backgroundColor: const Color(0xFFFF0050),
        elevation: 4,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "创建主播",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        key: _refreshKey,
        color: const Color(0xFFFF0050),
        onRefresh: _handleRefresh,
        child: _isInitLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF0050)))
            : _myAnchors.isEmpty
            ? const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off, size: 60, color: Colors.grey),
              SizedBox(height: 10),
              Text("您还没有创建任何主播", style: TextStyle(color: Colors.grey)),
            ],
          ),
        )
            : ListView.separated(
          padding: const EdgeInsets.only(top: 10, bottom: 80),
          itemCount: _myAnchors.length,
          separatorBuilder: (ctx, i) => Divider(height: 1, indent: 16, endIndent: 16, color: dividerColor.withOpacity(0.1)),
          itemBuilder: (context, index) {
            return _buildMyAnchorItem(_myAnchors[index], theme);
          },
        ),
      ),
    );
  }

  // 构建单个列表项（样式参考 LiveListPage，但稍微简化，去掉“直播中”状态，偏向管理视角）
  Widget _buildMyAnchorItem(AnchorInfo anchor, ThemeData theme) {
    return InkWell(
      onTap: () {
        // 点击可以跳转到主播详情或编辑页面
        // Navigator.push(...)
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // 复用 LiveListPage 中的头像组件，如果是同文件可以直接用，不同文件需提取组件
            // 这里为了演示简单，写一个普通的圆角头像
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(image: NetworkImage(anchor.avatarUrl), fit: BoxFit.cover),
                border: Border.all(color: Colors.grey[200]!),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    anchor.name,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: theme.textTheme.titleMedium?.color),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "ID: ${anchor.roomId}",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    anchor.title.isNotEmpty ? anchor.title : "暂无设定",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            // 管理按钮
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.grey),
              onPressed: () {
                // 编辑逻辑
              },
            ),
          ],
        ),
      ),
    );
  }
}