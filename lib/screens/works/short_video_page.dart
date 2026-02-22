import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../tools/HttpUtil.dart'; // 请替换为你实际的 HttpUtil 路径

class ShortVideoPage extends StatefulWidget {
  // 🟢 1. 外部传入的参数
  final int workId;

  const ShortVideoPage({super.key, required this.workId});

  @override
  State<ShortVideoPage> createState() => _ShortVideoPageState();
}

class _ShortVideoPageState extends State<ShortVideoPage> {
  // 视频控制器
  VideoPlayerController? _videoController;

  // 接口返回的数据
  Map<String, dynamic>? _workData;
  bool _isLoading = true;
  bool _isPlaying = true;

  // 模拟一些交互状态 (如果有真实接口请替换)
  bool _isLiked = false;
  bool _isFavorited = false;

  @override
  void initState() {
    super.initState();
    _fetchVideoDetail();
  }

  // 🟢 2. 请求接口并初始化播放器
  Future<void> _fetchVideoDetail() async {
    try {
      // 调用详情接口
      var res = await HttpUtil().get("/api/work/detail", params: {"workId": widget.workId});

      if (mounted && res != null) {
        setState(() {
          _workData = res;
        });

        // 假设视频 URL 存在 content 字段中 (你之前说如果是视频，content 存 URL)
        String videoUrl = _workData!['content'] ?? '';

        if (videoUrl.isNotEmpty) {
          // 初始化播放器
          _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
            ..initialize().then((_) {
              if (mounted) {
                setState(() {}); // 刷新 UI 渲染视频
                _videoController!.setLooping(true); // 循环播放
                _videoController!.play(); // 自动播放
              }
            });

          // 监听进度，用于更新底部进度条
          _videoController!.addListener(() {
            if (mounted) setState(() {});
          });
        }
      }
    } catch (e) {
      debugPrint("获取视频详情失败: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 🟢 3. 页面销毁时必须释放播放器内存
  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  // 播放/暂停切换逻辑
  void _togglePlay() {
    if (_videoController == null || !_videoController!.value.isInitialized) return;

    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
        _isPlaying = false;
      } else {
        _videoController!.play();
        _isPlaying = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Stack(
              children: [
                // 1. 底层：视频播放器 (带有点击暂停手势)
                GestureDetector(
                  onTap: _togglePlay,
                  child: Stack(
                    children: [
                      _buildVideoPlayer(),
                      // 暂停时的中间巨大播放按钮图标
                      if (!_isPlaying) const Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white54, size: 80)),
                    ],
                  ),
                ),

                // 2. 顶层：UI 覆盖层
                SafeArea(
                  child: Stack(
                    children: [
                      // 顶部：返回按钮
                      _buildTopBar(),

                      // 右侧：交互按钮栏 (点赞、评论等)
                      _buildRightActionBar(),

                      // 左下角：作者信息与文案
                      _buildBottomLeftInfo(),
                    ],
                  ),
                ),

                // 3. 最底部：播放进度条
                Positioned(left: 0, right: 0, bottom: 0, child: _buildProgressBar()),
              ],
            ),
      // 4. 底部创作者工具栏 (如果是自己的作品才显示，这里暂且保留)
      bottomNavigationBar: _workData != null ? _buildBottomCreatorBar() : const SizedBox(),
    );
  }

  // --- 1. 真实视频播放层 ---
  // --- 1. 真实视频播放层 (方案二：完整模式 - 有黑边) ---
  Widget _buildVideoPlayer() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      // ... (省略封面图和loading代码，同上) ...
      return Positioned.fill(child: Container(color: Colors.black));
    }

    // 🟢 核心修复：完整显示，不拉伸
    return Center(
      // 1. 使用 AspectRatio 组件强制保持宽高比
      child: AspectRatio(
        // 2.直接使用视频控制器报告的原始宽高比
        aspectRatio: _videoController!.value.aspectRatio,
        // 3. 放入播放器
        child: VideoPlayer(_videoController!),
      ),
    );
  }

  // --- 2. 顶部状态栏 ---
  Widget _buildTopBar() {
    return Positioned(
      top: 10,
      left: 10,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white, size: 28),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  // --- 3. 右侧交互栏 (动态绑定数据) ---
  Widget _buildRightActionBar() {
    int likeCount = _workData?['likeCount'] ?? _workData?['like_count'] ?? 0;
    int collectCount = _workData?['collectCount'] ?? _workData?['collect_count'] ?? 0;

    return Positioned(
      right: 10,
      bottom: 60,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 头像
          _buildAvatarWithFollow(),
          const SizedBox(height: 20),

          // 🟢 1. 点赞 (增加完整 onTap 逻辑)
          _buildActionItem(
            icon: _isLiked ? Icons.favorite : Icons.favorite_outlined,
            color: _isLiked ? Colors.red : Colors.white,
            text: _formatNumber(likeCount + (_isLiked ? 1 : 0)),
            onTap: () {
              setState(() => _isLiked = !_isLiked);
              // TODO: 🟢 调用点赞/取消点赞接口
              // HttpUtil().post("/api/work/like", params: {"workId": widget.workId, "status": _isLiked ? 1 : 0});
              debugPrint("点击了点赞，当前状态: $_isLiked");
            },
          ),
          const SizedBox(height: 16),

          // 🟢 2. 评论 (增加完整 onTap 逻辑)
          _buildActionItem(
            icon: Icons.chat_rounded,
            color: Colors.white,
            text: "评论", // 替换为真实评论数
            onTap: () {
              // TODO: 🟢 调用获取评论列表接口，并弹出底部评论面板
              debugPrint("点击了评论，准备拉取评论列表并弹窗，作品ID: ${widget.workId}");
            },
          ),
          const SizedBox(height: 16),

          // 🟢 3. 收藏 (增加完整 onTap 逻辑)
          _buildActionItem(
            icon: _isFavorited ? Icons.star : Icons.star_outlined,
            color: _isFavorited ? Colors.yellow : Colors.white,
            text: _formatNumber(collectCount + (_isFavorited ? 1 : 0)),
            onTap: () {
              setState(() => _isFavorited = !_isFavorited);
              // TODO: 🟢 调用收藏/取消收藏接口
              // HttpUtil().post("/api/work/collect", params: {"workId": widget.workId, "status": _isFavorited ? 1 : 0});
              debugPrint("点击了收藏，当前状态: $_isFavorited");
            },
          ),
          const SizedBox(height: 16),

          // 🟢 4. 更多 (触发底部菜单)
          _buildActionItem(
            icon: Icons.more_horiz,
            color: Colors.white,
            text: "更多",
            onTap: () {
              _showMoreMenu(context);
            },
          ),
          const SizedBox(height: 24),

          // 右下角旋转唱片 (取作者头像)
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[800],
              border: Border.all(color: Colors.white38, width: 8),
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: _workData?['avatar'] ?? "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/bg_13.jpg",
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🟢 新增：弹出底部的“更多”操作菜单
  void _showMoreMenu(BuildContext context) {
    // 自动适配手机暗黑/明亮模式
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    // 获取当前作品的状态（⚠️请根据你后端实际返回的字段名修改 'status'）
    // 假设 1 表示已上架，0 表示已下架
    int currentStatus = _workData?['status'] ?? 1;
    bool isOnShelf = currentStatus == 1;

    // 动态计算目标状态和 UI 显示
    String toggleText = isOnShelf ? "下架作品" : "上架作品";
    int targetStatus = isOnShelf ? 0 : 1;
    IconData toggleIcon = isOnShelf ? Icons.visibility_off_outlined : Icons.visibility_outlined;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // 外部透明，内部容器实现圆角
      builder: (BuildContext ctx) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min, // 核心：高度自适应内容
              children: [
                const SizedBox(height: 12),
                // 顶部小横条指示器 (类似 iOS 抽屉把手)
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 20),

                // 选项1：动态 上架/下架 作品
                ListTile(
                  leading: Icon(toggleIcon, color: Colors.orange),
                  title: Text(toggleText, style: TextStyle(color: textColor, fontSize: 16)),
                  onTap: () async {
                    Navigator.pop(ctx); // 先关闭底部弹窗，让 UI 反馈更顺滑

                    // 🟢 调用上下架接口 (加上 await 确保请求发出)
                    await HttpUtil().post("/api/work/toggle_shelf_status", data: {
                      "workId": widget.workId,
                      "status": targetStatus.toString()
                    });
                    debugPrint("触发了$toggleText操作: workId=${widget.workId}, status=$targetStatus");

                    // 🟢 操作完成后，关闭当前页面，并返回 true 通知上一页刷新
                    if (mounted) {
                      Navigator.pop(context, true);
                    }
                  },
                ),

                // 选项2：删除作品
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text("删除作品", style: TextStyle(color: Colors.red, fontSize: 16)),
                  onTap: () async {
                    Navigator.pop(ctx); // 先关闭底部弹窗

                    // 🟢 调用删除接口
                    await HttpUtil().post("/api/work/delete", data: {"workId": widget.workId});
                    debugPrint("触发了删除操作: workId=${widget.workId}");

                    // 🟢 操作完成后，关闭当前页面，并返回 true 通知上一页刷新
                    if (mounted) {
                      Navigator.pop(context, true);
                    }
                  },
                ),

                // 浅色分割线
                Divider(color: Colors.grey.withOpacity(0.2), height: 1),

                // 底部取消按钮
                InkWell(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    alignment: Alignment.center,
                    child: Text("取消", style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionItem({required IconData icon, required Color color, required String text, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              shadows: [Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black54)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarWithFollow() {
    String avatarUrl = _workData?['avatar'] ?? "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/bg_13.jpg";

    return SizedBox(
      width: 50,
      height: 60,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: ClipOval(
              child: CachedNetworkImage(imageUrl: avatarUrl, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            bottom: 4,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              child: const Icon(Icons.add, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. 左下角信息区 (绑定动态标题和昵称) ---
  Widget _buildBottomLeftInfo() {
    String nickname = _workData?['nickname'] ?? "未知用户";
    String title = _workData?['title'] ?? "未命名作品";
    String avatar = _workData?['avatar'] ?? "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/bg_13.jpg";

    return Positioned(
      left: 12,
      bottom: 20,
      right: 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(radius: 10, backgroundImage: CachedNetworkImageProvider(avatar)),
                const SizedBox(width: 6),
                Text(
                  nickname,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 4),
                Text("· 刚刚", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
            child: Text(
              title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // --- 5. 底部播放进度条 ---
  Widget _buildProgressBar() {
    if (_videoController == null || !_videoController!.value.isInitialized) return const SizedBox();

    // 计算播放比例
    final duration = _videoController!.value.duration;
    final position = _videoController!.value.position;
    double progress = 0.0;
    if (duration.inMilliseconds > 0) {
      progress = position.inMilliseconds / duration.inMilliseconds;
    }

    return Container(
      height: 2,
      alignment: Alignment.centerLeft,
      color: Colors.white.withOpacity(0.3),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Container(width: constraints.maxWidth * progress.clamp(0.0, 1.0), color: Colors.white);
        },
      ),
    );
  }

  // --- 6. 底部创作者工具栏 ---
  Widget _buildBottomCreatorBar() {
    return SafeArea(
      top: false,
      child: Container(
        height: 50,
        color: const Color(0xFF141414),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.remove_red_eye, color: Colors.white70, size: 18),
                SizedBox(width: 8),
                Text("查看数据", style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
            Row(
              children: [
                Icon(Icons.insert_chart_outlined, color: Colors.white70, size: 18),
                SizedBox(width: 4),
                Text("图文分析", style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
            Text("公开", style: TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  // 格式化数字 (10000 -> 1.0w)
  String _formatNumber(int number) {
    if (number >= 10000) return "${(number / 10000).toStringAsFixed(1)}w";
    return number.toString();
  }
}
