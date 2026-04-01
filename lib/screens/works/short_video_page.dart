import 'package:flutter/material.dart';
// 🟢 换成 media_kit
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
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
  // 🟢 替换为 media_kit 控制器
  Player? _player;
  VideoController? _videoController;

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

        // 假设视频 URL 存在 content 字段中
        String videoUrl = _workData!['content'] ?? '';

        if (videoUrl.isNotEmpty) {
          // 🟢 初始化 media_kit 播放器
          _player = Player();
          _videoController = VideoController(_player!);

          _player!.setPlaylistMode(PlaylistMode.loop); // 循环播放

          // 监听播放位置以更新进度条
          _player!.stream.position.listen((position) {
            if (mounted) setState(() {});
          });

          // 监听播放状态以更新暂停/播放按钮 UI
          _player!.stream.playing.listen((playing) {
            if (mounted) {
              setState(() {
                _isPlaying = playing;
              });
            }
          });

          // 开始加载并自动播放
          await _player!.open(Media(videoUrl));
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
    _player?.dispose(); // media_kit 只需要 dispose Player 即可
    super.dispose();
  }

  // 播放/暂停切换逻辑
  void _togglePlay() {
    if (_player == null) return;

    // 🟢 media_kit 极简的一键切换播放状态
    _player!.playOrPause();
    // _isPlaying 状态会在上面的 stream.playing.listen 里自动同步，无需手动 setState
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
  Widget _buildVideoPlayer() {
    if (_videoController == null) {
      return Positioned.fill(child: Container(color: Colors.black));
    }

    // 🟢 核心修改：利用 media_kit 的 Video 组件原生自适应
    return Center(
      child: SizedBox.expand(
        child: Video(
          controller: _videoController!,
          fit: BoxFit.contain, // 等比例缩放，完整显示，留黑边
          controls: NoVideoControls, // 隐藏默认进度条
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    int currentStatus = _workData?['status'] ?? 1;
    bool isOnShelf = currentStatus == 1;

    String toggleText = isOnShelf ? "下架作品" : "上架作品";
    int targetStatus = isOnShelf ? 0 : 1;
    IconData toggleIcon = isOnShelf ? Icons.visibility_off_outlined : Icons.visibility_outlined;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 20),

                ListTile(
                  leading: Icon(toggleIcon, color: Colors.orange),
                  title: Text(toggleText, style: TextStyle(color: textColor, fontSize: 16)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await HttpUtil().post("/api/work/toggle_shelf_status", data: {
                      "workId": widget.workId,
                      "status": targetStatus.toString()
                    });
                    if (mounted) Navigator.pop(context, true);
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text("删除作品", style: TextStyle(color: Colors.red, fontSize: 16)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await HttpUtil().post("/api/work/delete", data: {"workId": widget.workId});
                    if (mounted) Navigator.pop(context, true);
                  },
                ),

                Divider(color: Colors.grey.withOpacity(0.2), height: 1),

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
    if (_player == null) return const SizedBox();

    // 🟢 直接从 media_kit 的 Player 状态中读取播放进度
    final duration = _player!.state.duration;
    final position = _player!.state.position;

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

  String _formatNumber(int number) {
    if (number >= 10000) return "${(number / 10000).toStringAsFixed(1)}w";
    return number.toString();
  }
}