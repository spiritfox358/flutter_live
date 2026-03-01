import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../main.dart';
import '../../../tools/HttpUtil.dart';
import '../../me/profile/user_profile_page.dart';
import '../../works/publish_work_page.dart'; // 🟢 替换为你的 HttpUtil 路径
// 🟢 TODO: 记得引入你的 main.dart，因为我们需要用到 globalMainTabNotifier
// import '../../../main.dart';

class RecommendFeedPage extends StatefulWidget {
  const RecommendFeedPage({super.key});

  @override
  State<RecommendFeedPage> createState() => _RecommendFeedPageState();
}

class _RecommendFeedPageState extends State<RecommendFeedPage> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  // 🟢 接口真实数据
  final List<Map<String, dynamic>> _feedList = [];
  String _cursor = "0"; // 游标，初始为 0
  bool _isLoading = false;
  bool _hasMore = true;

  // 记录当前整个页面是否可见
  bool _isPageVisible = true;

  @override
  void initState() {
    super.initState();
    _loadData(); // 初始加载第一页

    // 🟢 核心修复：强力监听底部 Tab 切换
    globalMainTabNotifier.addListener(_onBottomTabChanged);
    globalRefreshRecommendNotifier.addListener(_onRefreshSignal);
  }
// 🟢 新增：执行极其丝滑的刷新动作
  void _onRefreshSignal() {
    // 只有当推荐页在屏幕上显示的时候才允许刷新
    if (mounted && _isPageVisible) {

      // 1. 如果用户划到了下面，瞬间跳回第一个视频，防止数组越界报错
      if (_currentIndex != 0 && _pageController.hasClients) {
        _pageController.jumpToPage(0);
      }

      // 2. 清理老数据，重置状态
      setState(() {
        _cursor = "0";
        _hasMore = true;
        _feedList.clear(); // 清空后界面会瞬间显示 Loading 圆圈
      });

      // 3. 重新向后端请求最新数据
      _loadData();
    }
  }
  // 监听到系统底部 Tab 切换时的回调
  void _onBottomTabChanged() {
    if (mounted) {
      // 假设 0 代表你的“首页” Tab
      bool isNowVisible = (globalMainTabNotifier.value == 0);

      // 只有状态真正改变时才触发刷新
      if (_isPageVisible != isNowVisible) {
        setState(() {
          _isPageVisible = isNowVisible;
        });
        debugPrint("🔄 底部Tab发生切换，当前推荐页可见状态变更为: $_isPageVisible");
      }
    }
  }

  @override
  void dispose() {
    // 🟢 极其重要：页面销毁时必须移除监听，否则会导致内存泄漏！
    globalMainTabNotifier.removeListener(_onBottomTabChanged);
    globalRefreshRecommendNotifier.removeListener(_onRefreshSignal); // 🟢 移除监听
    _pageController.dispose(); // 🟢 释放控制器
    super.dispose();
  }

  // 🟢 拉取真实接口数据
  Future<void> _loadData() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    try {
      // 调用你的后端接口，传下游标
      var res = await HttpUtil().get("/api/feed/recommend", params: {"cursor": _cursor});

      if (res != null && mounted) {
        // 解析后端返回的 FeedResult
        List<dynamic> newList = res['list'] ?? [];
        String nextCursor = res['nextCursor']?.toString() ?? "0";

        setState(() {
          _feedList.addAll(newList.cast<Map<String, dynamic>>());
          _cursor = nextCursor;
          _isLoading = false;
          if (newList.isEmpty) {
            _hasMore = false; // 没有更多数据了
          }
        });
      }
    } catch (e) {
      debugPrint("获取推荐流失败: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _feedList.isEmpty && _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        dragStartBehavior: DragStartBehavior.down,
        physics: const TikTokPagePhysics(),
        itemCount: _feedList.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });

          // 🟢 预加载逻辑：如果滑到了倒数第 2 个，提前无缝加载下一页数据
          if (index >= _feedList.length - 2) {
            _loadData();
          }
        },
        itemBuilder: (context, index) {
          final item = _feedList[index];
          final int type = item['type'];

          // 🟢 灵魂指令：同时满足“滑到了当前视频” 且 “整个首页在底部导航里是可见的”！
          final bool isCurrentView = (_currentIndex == index) && _isPageVisible;

          switch (type) {
            case 1:
              return FeedVideoItem(feedData: item, isCurrentView: isCurrentView);
            case 2:
              return _buildPlaceholder("直播间: ${item['liveData']?['roomId']}", isCurrentView);
            case 3:
              return _buildPlaceholder("图文/文章", isCurrentView);
            default:
              return const SizedBox();
          }
        },
      ),
    );
  }

  Widget _buildPlaceholder(String text, bool isCurrent) {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.construction, color: Colors.white54, size: 50),
            const SizedBox(height: 16),
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 20)),
            const SizedBox(height: 8),
            Text(isCurrent ? "(当前处于可视区)" : "(已滑走)", style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// 独立的 Feed 视频播放组件 (加入 App 后台生命周期管理)
// =========================================================================
class FeedVideoItem extends StatefulWidget {
  final Map<String, dynamic> feedData;
  final bool isCurrentView; // 决定它该播放还是暂停的最高指令！

  const FeedVideoItem({
    super.key,
    required this.feedData,
    required this.isCurrentView,
  });

  @override
  // 🟢 核心修复 3：混入 WidgetsBindingObserver 监听 App 回桌面
  State<FeedVideoItem> createState() => _FeedVideoItemState();
}

class _FeedVideoItemState extends State<FeedVideoItem> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isLiked = false;
// 🟢 新增：记录是否已关注（如果是真实接口，可以从 widget.feedData['author']['isFollowed'] 里取初始值）
  bool _isFollowed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 注册生命周期监听
    _initVideo();
  }

  Future<void> _handleFollow() async {
    if (_isFollowed) return;

    try {
      final authorId = widget.feedData['author']?['userId'] ?? widget.feedData['author']?['id'];

      // TODO: 替换为真实的关注接口调用
      // await HttpUtil().post("/api/user/follow", data: {"targetUserId": authorId});

      // 模拟网络延迟
      await Future.delayed(const Duration(milliseconds: 200));

      if (mounted) {
        setState(() {
          _isFollowed = true; // 状态变为已关注，触发缩小消失动画
        });
        // 可选：弹出一个轻提示
        // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('关注成功'), duration: Duration(seconds: 1)));
      }
    } catch (e) {
      debugPrint("关注失败: $e");
    }
  }

  void _initVideo() {
    // 🟢 适配后端新的 JSON 结构 (videoUrl 放在了 videoData 里)
    final videoData = widget.feedData['videoData'] ?? {};
    final String videoUrl = videoData['videoUrl'] ?? "";

    if (videoUrl.isEmpty) return;

    _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
          _controller!.setLooping(true);

          if (widget.isCurrentView) {
            _play();
          }
        }
      });
  }

  // 🟢 监听 PageView 滑动 或 Tab 切换带来的状态改变
  @override
  void didUpdateWidget(covariant FeedVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrentView != oldWidget.isCurrentView) {
      if (widget.isCurrentView) {
        _play();
      } else {
        _pause();
        _controller?.seekTo(Duration.zero);
      }
    }
  }

  // 🟢 监听 App 退到桌面 / 息屏
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pause(); // 退到桌面或息屏，强行暂停
    } else if (state == AppLifecycleState.resumed) {
      if (widget.isCurrentView) {
        _play(); // 切回 App，且当前视频仍在可视区，继续播放
      }
    }
  }

  void _play() {
    if (_isInitialized) {
      _controller?.play();
      setState(() => _isPlaying = true);
    }
  }

  void _pause() {
    if (_isInitialized) {
      _controller?.pause();
      setState(() => _isPlaying = false);
    }
  }

  void _togglePlay() {
    if (_isPlaying) {
      _pause();
    } else {
      _play();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // 移除监听
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoData = widget.feedData['videoData'] ?? {};
    final String coverUrl = videoData['coverUrl'] ?? "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/bg_13.jpg";

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            color: Colors.black,
            // 🟢 核心修复：用 Stack 把封面图和视频叠在一起，杜绝黑屏闪烁！
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. 封面图永远在底层兜底 (视频没出来之前看它，视频出来之后它被挡住)
                Image.network(coverUrl, fit: BoxFit.cover),

                // 2. 视频初始化完成后，直接叠加在封面图上方
                if (_isInitialized)
                  SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.size.width,
                        height: _controller!.value.size.height,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        if (!_isPlaying && _isInitialized)
          IgnorePointer(
            child: Center(
              child: Icon(Icons.play_arrow_rounded, color: Colors.white.withOpacity(0.5), size: 80),
            ),
          ),

        SafeArea(
          child: Stack(
            children: [
              _buildRightActionBar(),
              _buildBottomLeftInfo(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightActionBar() {
    final author = widget.feedData['author'] ?? {};
    final videoData = widget.feedData['videoData'] ?? {};
    final int likeCount = videoData['likeCount'] ?? 0;
    final int commentCount = videoData['commentCount'] ?? 0;

    return Positioned(
      right: 12,
      bottom: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 🟢 1. 组合：头像 + 底部悬浮加号
          SizedBox(
            width: 50,
            height: 60, // 高度给够，留出底部加号的空间
            child: Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none, // 允许溢出叠加
              children: [
                // 底层：用户头像
                GestureDetector(
                  onTap: () {
                    // 点击头像，跳转到个人主页，把 author 数据传过去
                    Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => UserProfilePage(userInfo: author))
                    );
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                      image: DecorationImage(
                          image: CachedNetworkImageProvider(author['avatar'] ?? "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/bg_13.jpg"),
                          fit: BoxFit.cover
                      ),
                    ),
                  ),
                ),

                // 顶层：悬浮的关注加号 (带弹性缩放动画)
                Positioned(
                  bottom: 2, // 悬浮在头像底部的分界线上
                  child: AnimatedScale(
                    scale: _isFollowed ? 0.0 : 1.0, // 关注后缩放到 0 消失
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInBack, // 带有回弹效果的动画曲线
                    child: GestureDetector(
                      onTap: _handleFollow, // 点击触发关注
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF0050), // 抖音标志性的红色
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 🟢 2. 点赞
          GestureDetector(
            onTap: () => setState(() => _isLiked = !_isLiked),
            child: Column(
              children: [
                Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  color: _isLiked ? const Color(0xFFFF0050) : Colors.white, // 点赞也换成统一的主题红
                  size: 36,
                ),
                const SizedBox(height: 4),
                Text(
                  (_isLiked ? likeCount + 1 : likeCount).toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 🟢 3. 评论
          Column(
            children: [
              const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 34),
              const SizedBox(height: 4),
              Text(
                commentCount.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 🟢 4. 分享
          const Column(
            children: [
              Icon(Icons.share_rounded, color: Colors.white, size: 36),
              SizedBox(height: 4),
              Text("分享", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomLeftInfo() {
    final author = widget.feedData['author'] ?? {};
    final videoData = widget.feedData['videoData'] ?? {};

    return Positioned(
      left: 12,
      bottom: 20,
      right: 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            author['nickname'] ?? "未知用户",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black54)],
            ),
          ),
          const SizedBox(height: 8),

          Text(
            videoData['title'] ?? "",
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              shadows: [Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black54)],
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// 极速滚动的物理引擎 (保持你之前的配置不变)
// =========================================================================
class TikTokPagePhysics extends PageScrollPhysics {
  const TikTokPagePhysics({super.parent});

  @override
  TikTokPagePhysics applyTo(ScrollPhysics? ancestor) {
    return TikTokPagePhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
    mass: 0.5,
    stiffness: 400.0,
    damping: 25.0,
  );
}