import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
// 🟢 换成 media_kit
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../main.dart';
import '../../../tools/HttpUtil.dart';
import '../../me/profile/user_profile_page.dart';
import '../../works/publish_work_page.dart';
import '../../works/work_social_service.dart';

class RecommendFeedPage extends StatefulWidget {
  const RecommendFeedPage({super.key});

  @override
  State<RecommendFeedPage> createState() => _RecommendFeedPageState();
}

class _RecommendFeedPageState extends State<RecommendFeedPage> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  final List<Map<String, dynamic>> _feedList = [];
  String _cursor = "0";
  bool _isLoading = false;
  bool _hasMore = true;
  bool _isPageVisible = true;
  Size? _lockedViewportSize;

  @override
  void initState() {
    super.initState();
    _loadData();

    globalMainTabNotifier.addListener(_onBottomTabChanged);
    globalRefreshRecommendNotifier.addListener(_onRefreshSignal);
  }

  void _onRefreshSignal() {
    if (mounted && _isPageVisible) {
      if (_currentIndex != 0 && _pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      setState(() {
        _cursor = "0";
        _hasMore = true;
        _feedList.clear();
      });
      _loadData();
    }
  }

  void _onBottomTabChanged() {
    if (mounted) {
      bool isNowVisible = (globalMainTabNotifier.value == 0);
      if (_isPageVisible != isNowVisible) {
        setState(() {
          _isPageVisible = isNowVisible;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lockedViewportSize ??= MediaQuery.of(context).size;
  }

  @override
  void dispose() {
    globalMainTabNotifier.removeListener(_onBottomTabChanged);
    globalRefreshRecommendNotifier.removeListener(_onRefreshSignal);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    try {
      var res = await HttpUtil().get("/api/feed/recommend", params: {"cursor": _cursor});
      if (res != null && mounted) {
        List<dynamic> newList = res['list'] ?? [];
        String nextCursor = res['nextCursor']?.toString() ?? "0";
        setState(() {
          _feedList.addAll(newList.cast<Map<String, dynamic>>());
          _cursor = nextCursor;
          _isLoading = false;
          if (newList.isEmpty) _hasMore = false;
        });
      }
    } catch (e) {
      debugPrint("获取推荐流失败: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewportSize = _lockedViewportSize ?? MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minWidth: viewportSize.width,
          maxWidth: viewportSize.width,
          minHeight: viewportSize.height,
          maxHeight: viewportSize.height,
          child: SizedBox(
            width: viewportSize.width,
            height: viewportSize.height,
            child: _feedList.isEmpty && _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : PageView.builder(
                    controller: _pageController,
                    scrollDirection: Axis.vertical,
                    dragStartBehavior: DragStartBehavior.down,
                    physics: const TikTokPagePhysics(),
                    // 🚀🚀🚀 核心提速魔法 1：允许隐式滚动！
                    // 只要开启这个，Flutter 会在后台提前把“下一个”视频的组件初始化并缓冲，等你滑过去的时候直接秒播！
                    allowImplicitScrolling: true,
                    itemCount: _feedList.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                      if (index >= _feedList.length - 2) {
                        _loadData();
                      }
                    },
                    itemBuilder: (context, index) {
                      final item = _feedList[index];
                      final int type = item['type'];
                      final bool isCurrentView = (_currentIndex == index) && _isPageVisible;

                      switch (type) {
                        case 1:
                          return FeedVideoItem(
                            key: ValueKey(item['feedId']?.toString() ?? 'feed_$index'),
                            feedData: item,
                            isCurrentView: isCurrentView,
                            onLikeChanged: (liked, likeCount) {
                              final videoData = Map<String, dynamic>.from(item['videoData'] as Map? ?? {});
                              videoData['liked'] = liked;
                              videoData['likeCount'] = likeCount;
                              _feedList[index] = {
                                ...item,
                                'videoData': videoData,
                              };
                            },
                            onCommentCountChanged: (commentCount) {
                              final videoData = Map<String, dynamic>.from(item['videoData'] as Map? ?? {});
                              videoData['commentCount'] = commentCount;
                              _feedList[index] = {
                                ...item,
                                'videoData': videoData,
                              };
                            },
                          );
                        case 2:
                          return _buildPlaceholder("直播间: ${item['liveData']?['roomId']}", isCurrentView);
                        case 3:
                          return _buildPlaceholder("图文/文章", isCurrentView);
                        default:
                          return const SizedBox();
                      }
                    },
                  ),
          ),
        ),
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
  final bool isCurrentView;
  final void Function(bool liked, int likeCount)? onLikeChanged;
  final void Function(int commentCount)? onCommentCountChanged;

  const FeedVideoItem({
    super.key,
    required this.feedData,
    required this.isCurrentView,
    this.onLikeChanged,
    this.onCommentCountChanged,
  });

  @override
  State<FeedVideoItem> createState() => _FeedVideoItemState();
}

class _FeedVideoItemState extends State<FeedVideoItem> with WidgetsBindingObserver {
  Player? _player;
  VideoController? _videoController;

  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isLiked = false;
  bool _isLikeBusy = false;
  bool _isFollowed = false;
  bool _isLoadingComments = false;
  bool _isSendingComment = false;
  int _likeCount = 0;
  int _commentCount = 0;
  int _workId = 0;
  final ValueNotifier<double> _keyboardNotifier = ValueNotifier<double>(0);
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];

  // 🚀🚀🚀 核心提速魔法 2：记录是否已经渲染出真实画面的“第一帧”
  bool _hasRenderedFirstFrame = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncSocialStateFromWidget();
    _initVideo();
  }

  void _syncSocialStateFromWidget() {
    final videoData = widget.feedData['videoData'] ?? {};
    _workId = _readInt(videoData['workId']);
    _likeCount = _readInt(videoData['likeCount']);
    _commentCount = _readInt(videoData['commentCount']);
    _isLiked = _readBool(videoData['liked']);
  }

  Future<void> _toggleLike() async {
    if (_isLikeBusy || _workId <= 0) return;
    final oldLiked = _isLiked;
    final oldCount = _likeCount;
    final nextLiked = !oldLiked;

    setState(() {
      _isLikeBusy = true;
      _isLiked = nextLiked;
      _likeCount = (_likeCount + (nextLiked ? 1 : -1)).clamp(0, 1 << 31);
    });
    widget.onLikeChanged?.call(_isLiked, _likeCount);

    try {
      final result = nextLiked
          ? await WorkSocialService.likeWork(_workId)
          : await WorkSocialService.unlikeWork(_workId);
      if (!mounted) return;
      setState(() {
        _isLiked = result['liked'] == true;
        _likeCount = _readInt(result['likeCount']);
      });
      widget.onLikeChanged?.call(_isLiked, _likeCount);
    } catch (e) {
      debugPrint("推荐流点赞失败: $e");
      if (!mounted) return;
      setState(() {
        _isLiked = oldLiked;
        _likeCount = oldCount;
      });
      widget.onLikeChanged?.call(_isLiked, _likeCount);
    } finally {
      if (mounted) setState(() => _isLikeBusy = false);
    }
  }

  Future<void> _handleFollow() async {
    if (_isFollowed) return;
    try {
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        setState(() {
          _isFollowed = true;
        });
      }
    } catch (e) {
      debugPrint("关注失败: $e");
    }
  }

  Future<void> _loadComments({VoidCallback? rebuildSheet}) async {
    if (_isLoadingComments || _workId <= 0) return;
    setState(() => _isLoadingComments = true);
    rebuildSheet?.call();
    try {
      final list = await WorkSocialService.getComments(_workId);
      if (mounted) setState(() => _comments = list);
    } catch (e) {
      debugPrint("推荐流加载评论失败: $e");
    } finally {
      if (mounted) setState(() => _isLoadingComments = false);
      rebuildSheet?.call();
    }
  }

  void _showCommentsSheet() {
    if (_workId <= 0) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        var didRequestComments = false;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            if (!didRequestComments) {
              didRequestComments = true;
              Future.microtask(() => _loadComments(rebuildSheet: () => setSheetState(() {})));
            }

            Future<void> sendComment() async {
              final content = _commentController.text.trim();
              if (content.isEmpty || _isSendingComment) return;

              setSheetState(() => _isSendingComment = true);
              try {
                final comment = await WorkSocialService.createComment(_workId, content);
                _commentController.clear();
                if (mounted) {
                  setState(() {
                    _comments = [comment, ..._comments];
                    _commentCount += 1;
                  });
                  widget.onCommentCountChanged?.call(_commentCount);
                }
                setSheetState(() {});
              } catch (e) {
                debugPrint("推荐流发表评论失败: $e");
              } finally {
                setSheetState(() => _isSendingComment = false);
              }
            }

            final sheetHeight = MediaQuery.of(context).size.height * 0.68;

            return MediaQuery.removeViewInsets(
              context: context,
              removeBottom: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => FocusScope.of(context).unfocus(),
                child: Container(
                  height: sheetHeight,
                  decoration: const BoxDecoration(
                    color: Color(0xFF111111),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        "$_commentCount 条评论",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: _isLoadingComments && _comments.isEmpty
                            ? const Center(child: CircularProgressIndicator(color: Colors.white))
                            : _comments.isEmpty
                                ? const Center(
                                    child: Text("还没有评论", style: TextStyle(color: Colors.white54)),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    itemCount: _comments.length,
                                    itemBuilder: (context, index) {
                                      final comment = _comments[index];
                                      final avatar = comment['avatar']?.toString() ?? "";
                                      final nickname = comment['nickname']?.toString() ?? "用户";
                                      final content = comment['content']?.toString() ?? "";
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            CircleAvatar(
                                              radius: 18,
                                              backgroundColor: Colors.white12,
                                              backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
                                              child: avatar.isEmpty
                                                  ? const Icon(Icons.person, color: Colors.white54, size: 18)
                                                  : null,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(nickname, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                                  const SizedBox(height: 4),
                                                  Text(content, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                      ),
                      ValueListenableBuilder<double>(
                        valueListenable: _keyboardNotifier,
                        builder: (context, keyboardInset, child) {
                          return Container(
                            padding: EdgeInsets.fromLTRB(12, 8, 12, keyboardInset + 10),
                            decoration: const BoxDecoration(
                              border: Border(top: BorderSide(color: Colors.white12)),
                            ),
                            child: child,
                          );
                        },
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                onTap: () {},
                                controller: _commentController,
                                minLines: 1,
                                maxLines: 3,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: "说点什么...",
                                  hintStyle: const TextStyle(color: Colors.white38),
                                  filled: true,
                                  fillColor: Colors.white10,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _isSendingComment ? null : sendComment,
                              icon: _isSendingComment
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                                    )
                                  : const Icon(Icons.send_rounded, color: Color(0xFFFF2D55)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    ),
                ),
              ),
              ),
            );
          },
        );
      },
    );
  }

  void _initVideo() async {
    final videoData = widget.feedData['videoData'] ?? {};
    final String videoUrl = videoData['videoUrl'] ?? "";
    if (videoUrl.isEmpty) return;

    _player = Player();
    _videoController = VideoController(_player!);

    _player!.setPlaylistMode(PlaylistMode.loop);

    // 监听播放状态
    _player!.stream.playing.listen((playing) {
      if (mounted) {
        setState(() {
          _isPlaying = playing;
        });
      }
    });

    // 🚀 核心监听：只要进度条大于 0 (代表真实画面已出来)，立刻隐藏封面图！
    _player!.stream.position.listen((position) {
      if (mounted && !_hasRenderedFirstFrame && position.inMilliseconds > 50) {
        setState(() {
          _hasRenderedFirstFrame = true;
        });
      }
    });

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }

    // 因为外层加了 allowImplicitScrolling，所以下一个视频在这里会被“提前缓冲加载”，但不会出声
    await _player!.open(Media(videoUrl), play: widget.isCurrentView);
  }

  @override
  void didUpdateWidget(covariant FeedVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldFeedId = oldWidget.feedData['feedId']?.toString();
    final newFeedId = widget.feedData['feedId']?.toString();
    if (oldFeedId != newFeedId) {
      _syncSocialStateFromWidget();
    }
    if (widget.isCurrentView != oldWidget.isCurrentView) {
      if (widget.isCurrentView) {
        _play();
      } else {
        _pause();
        _player?.seek(Duration.zero);
        // 🚀 划走时，重置状态，让封面图重新出现兜底
        setState(() {
          _hasRenderedFirstFrame = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pause();
    } else if (state == AppLifecycleState.resumed) {
      if (widget.isCurrentView) {
        _play();
      }
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final bottomInset = view.viewInsets.bottom / view.devicePixelRatio;
    if (_keyboardNotifier.value != bottomInset) {
      _keyboardNotifier.value = bottomInset;
    }
  }

  void _play() {
    _player?.play();
  }

  void _pause() {
    _player?.pause();
  }

  void _togglePlay() {
    _player?.playOrPause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _player?.dispose();
    _commentController.dispose();
    _keyboardNotifier.dispose();
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
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. 最底层：视频真实的播放组件 (初始化时可能是黑屏)
                if (_isInitialized && _videoController != null)
                  SizedBox.expand(
                    child: Video(
                      controller: _videoController!,
                      fit: BoxFit.cover,
                      controls: NoVideoControls,
                    ),
                  ),

                // 2. 🚀 盖在视频上的顶层：封面图 (AnimatedOpacity 实现无缝平滑过渡)
                // 只有当底层视频吐出了第一帧画面 (_hasRenderedFirstFrame == true)，封面图才会渐隐消失！
                AnimatedOpacity(
                  opacity: _hasRenderedFirstFrame ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Image.network(
                    coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => Container(color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 暂停时的巨大播放按钮
        if (!_isPlaying && _isInitialized)
          IgnorePointer(
            child: Center(
              child: Icon(Icons.play_arrow_rounded, color: Colors.white.withValues(alpha: 0.5), size: 80),
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

  // --- 右侧菜单和底部信息保持不变 ---
  Widget _buildRightActionBar() {
    final author = widget.feedData['author'] ?? {};

    return Positioned(
      right: 12,
      bottom: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 50,
            height: 60,
            child: Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: () {
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
                Positioned(
                  bottom: 2,
                  child: AnimatedScale(
                    scale: _isFollowed ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInBack,
                    child: GestureDetector(
                      onTap: _handleFollow,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF0050),
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

          GestureDetector(
            onTap: _toggleLike,
            child: Column(
              children: [
                Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  color: _isLiked ? const Color(0xFFFF0050) : Colors.white,
                  size: 36,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatNumber(_likeCount),
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          GestureDetector(
            onTap: _showCommentsSheet,
            child: Column(
              children: [
                const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 34),
                const SizedBox(height: 4),
                Text(
                  _formatNumber(_commentCount),
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // TODO: 分享功能暂未实现，先隐藏
          // const SizedBox(height: 20),
          // const Column(
          //   children: [
          //     Icon(Icons.share_rounded, color: Colors.white, size: 36),
          //     SizedBox(height: 4),
          //     Text("分享", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          //   ],
          // ),
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

  int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? "") ?? 0;
  }

  bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value.toInt() != 0;
    final text = value?.toString().toLowerCase();
    return text == 'true' || text == '1';
  }

  String _formatNumber(int number) {
    if (number >= 10000) return "${(number / 10000).toStringAsFixed(1)}w";
    return number.toString();
  }
}

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
