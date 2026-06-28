import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../works/work_social_service.dart';

/// 图文详情页：标题 + 作者 + 正文 + 图片 + 点赞 + 评论
/// pop 时回传 {likeCount, commentCount, liked} 供列表页回写
class ArticleDetailPage extends StatefulWidget {
  final Map<String, dynamic> feedData;
  const ArticleDetailPage({super.key, required this.feedData});

  @override
  State<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
  late final Map _author;
  late final Map _article;
  late int _workId;
  late int _likeCount;
  late int _commentCount;
  late bool _isLiked;
  bool _isLikeBusy = false;

  bool _loadingComments = false;
  bool _sending = false;
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];

  @override
  void initState() {
    super.initState();
    _author = widget.feedData['author'] as Map? ?? {};
    _article = widget.feedData['articleData'] as Map? ?? {};
    _workId = _readInt(_article['workId']);
    _likeCount = _readInt(_article['likeCount']);
    _commentCount = _readInt(_article['commentCount']);
    _isLiked = _readBool(_article['liked']);
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _result =>
      {'likeCount': _likeCount, 'commentCount': _commentCount, 'liked': _isLiked};

  Future<void> _toggleLike() async {
    if (_isLikeBusy || _workId <= 0) return;
    final oldLiked = _isLiked, oldCount = _likeCount;
    final next = !oldLiked;
    setState(() {
      _isLikeBusy = true;
      _isLiked = next;
      _likeCount = (_likeCount + (next ? 1 : -1)).clamp(0, 1 << 31);
    });
    try {
      final r = next
          ? await WorkSocialService.likeWork(_workId)
          : await WorkSocialService.unlikeWork(_workId);
      if (!mounted) return;
      setState(() {
        _isLiked = r['liked'] == true;
        _likeCount = _readInt(r['likeCount']);
      });
    } catch (e) {
      debugPrint("图文点赞失败: $e");
      if (mounted) setState(() {
        _isLiked = oldLiked;
        _likeCount = oldCount;
      });
    } finally {
      if (mounted) setState(() => _isLikeBusy = false);
    }
  }

  Future<void> _loadComments() async {
    if (_loadingComments || _workId <= 0) return;
    setState(() => _loadingComments = true);
    try {
      final list = await WorkSocialService.getComments(_workId);
      if (mounted) setState(() => _comments = list);
    } catch (e) {
      debugPrint("图文加载评论失败: $e");
    } finally {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  Future<void> _sendComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _sending || _workId <= 0) return;
    setState(() => _sending = true);
    try {
      final c = await WorkSocialService.createComment(_workId, content);
      _commentController.clear();
      if (mounted) setState(() {
        _comments = [c, ..._comments];
        _commentCount += 1;
      });
    } catch (e) {
      debugPrint("图文发表评论失败: $e");
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = _article['title']?.toString() ?? "";
    final String text = _article['summaryFull']?.toString() ??
        _article['text']?.toString() ??
        _article['summary']?.toString() ??
        "";
    final List images = (_article['images'] as List?) ?? const [];

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _result);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _result),
          ),
          title: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: (_author['avatar']?.toString().isNotEmpty ?? false)
                    ? CachedNetworkImageProvider(_author['avatar'].toString())
                    : null,
                child: (_author['avatar']?.toString().isEmpty ?? true)
                    ? const Icon(Icons.person, size: 16, color: Colors.grey)
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _author['nickname']?.toString() ?? "未知用户",
                  style: const TextStyle(fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (title.isNotEmpty)
                    Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.3)),
                  if (title.isNotEmpty) const SizedBox(height: 12),
                  if (text.isNotEmpty)
                    Text(text, style: const TextStyle(fontSize: 15.5, height: 1.6)),
                  for (final img in images) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: img.toString(),
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          height: 160,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image_not_supported, color: Colors.grey),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Divider(color: Colors.grey.shade200),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text("$_commentCount 条评论",
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                  if (_loadingComments && _comments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text("还没有评论，来抢沙发", style: TextStyle(color: Colors.grey.shade500))),
                    )
                  else
                    ..._comments.map(_buildComment),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildComment(Map<String, dynamic> c) {
    final avatar = c['avatar']?.toString() ?? "";
    final nickname = c['nickname']?.toString() ?? "用户";
    final content = c['content']?.toString() ?? "";
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
            child: avatar.isEmpty ? const Icon(Icons.person, size: 16, color: Colors.grey) : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nickname, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const SizedBox(height: 3),
                Text(content, style: const TextStyle(fontSize: 14.5, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "说点什么...",
                  isDense: true,
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: _sending ? null : _sendComment,
              icon: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_rounded, color: Color(0xFFFF2D55)),
            ),
            GestureDetector(
              onTap: _toggleLike,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isLiked ? Icons.favorite : Icons.favorite_border,
                    color: _isLiked ? const Color(0xFFFF2D55) : Colors.grey.shade600,
                    size: 26,
                  ),
                  Text(_fmt(_likeCount), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static int _readInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? "") ?? 0;
  }

  static bool _readBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v.toInt() != 0;
    final t = v?.toString().toLowerCase();
    return t == 'true' || t == '1';
  }

  static String _fmt(int n) => n >= 10000 ? "${(n / 10000).toStringAsFixed(1)}w" : "$n";
}
