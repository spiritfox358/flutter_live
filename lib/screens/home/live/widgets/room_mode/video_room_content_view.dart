import 'dart:ui';
import 'dart:math'; // 🟢 引入随机数库
import 'package:flutter/material.dart';
// 🟢 换成 media_kit
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../../../tools/HttpUtil.dart';

class VideoRoomContentView extends StatefulWidget {
  final String videoUrl; // 兜底的默认视频地址 (如果列表为空用这个)
  final String bgUrl;    // 背景图
  final bool isMuted;
  final double videoHeight;

  // 🟢 新增：传入 roomId 用于查列表
  final String roomId;

  const VideoRoomContentView({
    super.key,
    required this.videoUrl,
    required this.bgUrl,
    this.isMuted = false,
    this.videoHeight = 240.0,
    required this.roomId, // 🟢 必传
  });

  @override
  State<VideoRoomContentView> createState() => _VideoRoomContentViewState();
}

class _VideoRoomContentViewState extends State<VideoRoomContentView> {
  // 🟢 替换为 media_kit 的双控制器架构
  Player? _player;
  VideoController? _videoController;

  bool _isInitialized = false;
  bool _hasError = false;

  // 🟢 资源列表相关
  List<dynamic> _resourceList = [];
  Map<String, dynamic>? _currentResource;
  bool _isLoadingList = true;

  // 🟢 控制显示相关
  bool _showControls = true; // 默认显示控制按钮

  @override
  void initState() {
    super.initState();
    _fetchResourceList(); // 🟢 初始化时拉取列表
  }

  // 🟢 1. 获取资源列表
  Future<void> _fetchResourceList() async {
    try {
      final res = await HttpUtil().get(
        "/api/room/resource/list",
        params: {"roomId": widget.roomId},
      );

      if (mounted) {
        if (res is List && res.isNotEmpty) {
          setState(() {
            _resourceList = res;
            _isLoadingList = false;
          });
          _playNextRandom(); // 拉取成功后直接开始播放随机视频
        } else {
          // 列表为空，播放默认传入的 widget.videoUrl
          _playVideo(widget.videoUrl);
        }
      }
    } catch (e) {
      debugPrint("获取资源列表失败: $e");
      // 失败也播放默认
      _playVideo(widget.videoUrl);
    }
  }

  // 🟢 2. 随机播放下一首
  void _playNextRandom() {
    if (_resourceList.isEmpty) return;

    final random = Random();
    int nextIndex = 0;

    // 如果列表只有1个，就循环播放那一个
    // 如果有多个，尽量随机一个和当前不一样的
    if (_resourceList.length > 1) {
      nextIndex = random.nextInt(_resourceList.length);
      // 简单的去重逻辑：如果随机到了当前正在播的，就取下一个
      if (_currentResource != null && _resourceList[nextIndex]['id'] == _currentResource!['id']) {
        nextIndex = (nextIndex + 1) % _resourceList.length;
      }
    }

    final resource = _resourceList[nextIndex];
    final String url = resource['url'] ?? "";

    setState(() {
      _currentResource = resource;
    });

    if (url.isNotEmpty) {
      _playVideo(url);
    }
  }

  // 🟢 3. 核心播放逻辑
  void _playVideo(String url) async {
    // 销毁旧的
    if (_player != null) {
      await _player!.dispose();
    }

    if (!mounted) return;

    setState(() {
      _isInitialized = false;
      _hasError = false;
    });

    if (url.isEmpty) return;

    try {
      debugPrint("🎬 开始播放视频: $url");

      // 🟢 初始化 media_kit
      final player = Player();
      final controller = VideoController(player);

      _player = player;
      _videoController = controller;

      // 🟢 监听播放结束，自动切歌
      player.stream.completed.listen((completed) {
        if (completed && mounted) {
          debugPrint("✅ 视频播放结束，自动切歌...");
          _playNextRandom();
        }
      });

      // 设置音量 (media_kit 范围 0.0 - 100.0)
      if (widget.isMuted) {
        player.setVolume(0.0);
      } else {
        player.setVolume(50.0);
      }

      await player.open(Media(url));

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint("视频初始化失败: $e");
      if (mounted) {
        setState(() => _hasError = true);
        // 🟢 如果播放出错，3秒后自动切下一个，防止卡死
        Future.delayed(const Duration(seconds: 3), () {
          if(mounted) _playNextRandom();
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant VideoRoomContentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果外部传入的 roomId 变了，重新拉取
    if (widget.roomId != oldWidget.roomId) {
      _fetchResourceList();
    }
  }

  @override
  void dispose() {
    // 🟢 清理 media_kit 播放器
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double topOffset = MediaQuery.of(context).padding.top + 50;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. 背景层
        Positioned.fill(
          child: Image.network(
            widget.bgUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: const Color(0xFF151515)),
          ),
        ),

        // 2. 背景模糊
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
            child: Container(color: Colors.black.withOpacity(0.2)),
          ),
        ),

        // 3. 视频层
        Positioned(
          top: topOffset,
          left: 0,
          right: 0,
          height: widget.videoHeight,
          child: Container(
            color: Colors.black,
            child: Stack(
              children: [
                Center(child: _buildVideoContent()),
                // 🟢 4. 控制层 (浮在视频上面)
                if (_resourceList.isNotEmpty) // 只有有列表时才显示控制
                  _buildControlLayer(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoContent() {
    if (_hasError) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.broken_image, color: Colors.white54, size: 30),
          SizedBox(height: 4),
          Text("播放出错，即将切换...", style: TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      );
    }

    if (!_isInitialized || _videoController == null) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
      );
    }

    // 🟢 极简 Video 组件渲染，自带 Fit 支持
    return SizedBox.expand(
      child: Video(
        controller: _videoController!,
        fit: BoxFit.contain, // 保证音乐 MV 不被过度裁切
        controls: NoVideoControls, // 隐藏默认进度条
      ),
    );
  }

  // 🟢 构建控制按钮层
  Widget _buildControlLayer() {
    return Positioned(
      bottom: 10,
      right: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 如果显示控件，则展示切歌按钮和信息
          if (_showControls) ...[
            // 显示当前播放标题 (如果有)
            if (_currentResource != null && _currentResource!['title'] != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "正在播放: ${_currentResource!['title']}",
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),

            // 切歌按钮
            FloatingActionButton.small(
              heroTag: null,
              onPressed: _playNextRandom,
              backgroundColor: Colors.white24,
              elevation: 0,
              child: const Icon(Icons.skip_next, color: Colors.white),
            ),
            const SizedBox(height: 10),
          ],

          // 显隐切换开关 (一直显示)
          FloatingActionButton.small(
            heroTag: "toggle_controls_btn",
            onPressed: () {
              setState(() {
                _showControls = !_showControls;
              });
            },
            backgroundColor: _showControls ? Colors.white24 : Colors.white10,
            elevation: 0,
            child: Icon(
              _showControls ? Icons.visibility : Icons.visibility_off,
              color: _showControls ? Colors.white : Colors.white54,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}