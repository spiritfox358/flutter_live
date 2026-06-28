import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../main.dart';
import '../../../tools/HttpUtil.dart';
import '../../me/profile/user_profile_page.dart';
import 'article_detail_page.dart';

/// 首页「推荐」图文列表页。
/// 取代原来的全屏视频滑动 RecommendFeedPage（视频代码保留，只是不再挂在首页）。
class ArticleFeedPage extends StatefulWidget {
  const ArticleFeedPage({super.key});

  @override
  State<ArticleFeedPage> createState() => _ArticleFeedPageState();
}

class _ArticleFeedPageState extends State<ArticleFeedPage> {
  final List<Map<String, dynamic>> _feedList = [];
  final ScrollController _scrollController = ScrollController();
  String _cursor = "0";
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
    globalRefreshRecommendNotifier.addListener(_onRefreshSignal);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    globalRefreshRecommendNotifier.removeListener(_onRefreshSignal);
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      _loadData();
    }
  }

  void _onRefreshSignal() {
    if (mounted) _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _cursor = "0";
      _hasMore = true;
      _feedList.clear();
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    await _loadData();
  }

  Future<void> _loadData() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    try {
      final res = await HttpUtil()
          .get("/api/feed/recommend", params: {"cursor": _cursor});
      if (res != null && mounted) {
        final List<dynamic> newList = res['list'] ?? [];
        final String nextCursor = res['nextCursor']?.toString() ?? "0";
        setState(() {
          _feedList.addAll(newList.cast<Map<String, dynamic>>());
          _cursor = nextCursor;
          _isLoading = false;
          if (newList.isEmpty) _hasMore = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("获取图文推荐流失败: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 列表内某条作品的点赞数 / 评论数变化时，回写到内存，保证滚动回来状态不丢
  void _patchArticleData(int index, Map<String, dynamic> patch) {
    final item = _feedList[index];
    final articleData =
        Map<String, dynamic>.from(item['articleData'] as Map? ?? {});
    articleData.addAll(patch);
    _feedList[index] = {...item, 'articleData': articleData};
  }

  @override
  Widget build(BuildContext context) {
    if (_feedList.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_feedList.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          children: const [
            SizedBox(height: 200),
            Center(child: Text("还没有内容，下拉刷新试试", style: TextStyle(color: Colors.grey))),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: _feedList.length + 1,
        itemBuilder: (context, index) {
          if (index == _feedList.length) {
            return _buildFooter();
          }
          final item = _feedList[index];
          final int type = item['type'] ?? 0;
          switch (type) {
            case 3:
              return ArticleCard(
                key: ValueKey(item['feedId']?.toString() ?? 'feed_$index'),
                feedData: item,
                onChanged: (patch) => _patchArticleData(index, patch),
              );
            case 2:
              return LiveFeedCard(feedData: item);
            default:
              return const SizedBox.shrink();
          }
        },
      ),
    );
  }

  Widget _buildFooter() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (!_hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: Text("没有更多了", style: TextStyle(color: Colors.grey, fontSize: 12))),
      );
    }
    return const SizedBox(height: 12);
  }
}

/// 单条图文卡片
class ArticleCard extends StatelessWidget {
  final Map<String, dynamic> feedData;
  final ValueChanged<Map<String, dynamic>>? onChanged;

  const ArticleCard({super.key, required this.feedData, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final author = feedData['author'] as Map? ?? {};
    final article = feedData['articleData'] as Map? ?? {};
    final String title = article['title']?.toString() ?? "";
    final String summary = article['summary']?.toString() ?? "";
    final String coverUrl = _pickCover(article);
    final int likeCount = _readInt(article['likeCount']);
    final int commentCount = _readInt(article['commentCount']);

    return InkWell(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ArticleDetailPage(feedData: feedData),
          ),
        );
        if (result is Map<String, dynamic>) onChanged?.call(result);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (coverUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: coverUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    height: 180,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image_not_supported, color: Colors.grey),
                  ),
                ),
              ),
            if (coverUrl.isNotEmpty) const SizedBox(height: 10),
            if (title.isNotEmpty)
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            if (summary.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700, height: 1.4),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _Avatar(url: author['avatar']?.toString() ?? "", onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserProfilePage(userInfo: Map<String, dynamic>.from(author)),
                    ),
                  );
                }),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    author['nickname']?.toString() ?? "未知用户",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                  ),
                ),
                Icon(Icons.favorite_border, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 3),
                Text(_fmt(likeCount), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(width: 12),
                Icon(Icons.chat_bubble_outline, size: 15, color: Colors.grey.shade500),
                const SizedBox(width: 3),
                Text(_fmt(commentCount), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _pickCover(Map article) {
    final cover = article['coverUrl']?.toString() ?? "";
    if (cover.isNotEmpty) return cover;
    final images = article['images'];
    if (images is List && images.isNotEmpty) return images.first.toString();
    return "";
  }

  static int _readInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? "") ?? 0;
  }

  static String _fmt(int n) => n >= 10000 ? "${(n / 10000).toStringAsFixed(1)}w" : "$n";
}

/// 信息流里穿插的「正在直播」卡片
class LiveFeedCard extends StatelessWidget {
  final Map<String, dynamic> feedData;
  const LiveFeedCard({super.key, required this.feedData});

  @override
  Widget build(BuildContext context) {
    final author = feedData['author'] as Map? ?? {};
    final live = feedData['liveData'] as Map? ?? {};
    final String cover = live['liveCover']?.toString() ?? "";
    final int online = ArticleCard._readInt(live['onlineCount']);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF2D55), Color(0xFFFF6B8B)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: cover.isNotEmpty
                  ? CachedNetworkImage(imageUrl: cover, width: 64, height: 64, fit: BoxFit.cover)
                  : Container(width: 64, height: 64, color: Colors.white24, child: const Icon(Icons.live_tv, color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text("LIVE", style: TextStyle(color: Color(0xFFFF2D55), fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Text("$online 人在线", style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${author['nickname'] ?? '主播'} 正在直播",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String url;
  final VoidCallback? onTap;
  const _Avatar({required this.url, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: 14,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: url.isNotEmpty ? CachedNetworkImageProvider(url) : null,
        child: url.isEmpty ? const Icon(Icons.person, size: 16, color: Colors.grey) : null,
      ),
    );
  }
}
