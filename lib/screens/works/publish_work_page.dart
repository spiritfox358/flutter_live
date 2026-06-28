import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart'; // 🟢 新增插件
import 'package:path_provider/path_provider.dart'; // 🟢 新增插件
import '../../../tools/HttpUtil.dart';
import '../../widgets/in_app_notification.dart';

final ValueNotifier<int> globalMainTabNotifier = ValueNotifier<int>(0);

class PublishWorkPage extends StatefulWidget {
  const PublishWorkPage({super.key});

  @override
  State<PublishWorkPage> createState() => _PublishWorkPageState();
}

class _PublishWorkPageState extends State<PublishWorkPage> {
  final TextEditingController _titleController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _selectedVideo;
  File? _coverImage; // 🟢 新增：用于保存截取出来的封面图
  bool _isExtracting = false; // 🟢 新增：截取封面时的 loading 状态

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // 🟢 选择视频并自动截取封面
  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        setState(() {
          _selectedVideo = File(video.path);
          _isExtracting = true; // 开始提取封面，UI 显示 loading
        });

        // 获取手机的临时目录来存封面图
        final tempDir = await getTemporaryDirectory();

        // 核心：生成视频缩略图
        final thumbnailPath = await VideoThumbnail.thumbnailFile(
          video: video.path,
          thumbnailPath: tempDir.path,
          imageFormat: ImageFormat.JPEG,
          maxHeight: 800, // 封面图最大高度
          quality: 75, // 图片质量
        );

        setState(() {
          if (thumbnailPath != null) {
            _coverImage = File(thumbnailPath);
          }
          _isExtracting = false; // 提取完成
        });
      }
    } catch (e) {
      debugPrint("选择视频失败: $e");
      if (mounted) {
        setState(() => _isExtracting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("无法打开相册或提取封面失败")));
      }
    }
  }

  void _startPublish() {
    if (_selectedVideo == null || _coverImage == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("请先选择视频并等待封面生成")));
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("请填写作品标题")));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("已转入后台发布中..."),
        backgroundColor: Colors.blue,
      ),
    );

    // 🟢 传入截取好的封面图
    _performBackgroundUpload(title, 0, _selectedVideo!, _coverImage!);

    _titleController.clear();
    setState(() {
      _selectedVideo = null;
      _coverImage = null; // 清空封面
    });

    _closePage();
  }

  void _closePage() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark
        ? Colors.white.withValues(alpha: 0.9)
        : Colors.black54;
    final inputBgColor = isDark ? const Color(0xFF1A1A1A) : Colors.grey[100];
    final hintColor = isDark ? Colors.white24 : Colors.black26;
    final iconColor = isDark ? Colors.white : Colors.black;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: iconColor),
            onPressed: _closePage,
          ),
          title: Text(
            "发布视频",
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: _isExtracting ? null : _startPublish, // 提取封面时禁用发布按钮
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text(
                "发布",
                style: TextStyle(
                  color: Colors.purpleAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        body: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "选择视频",
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickVideo,
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: inputBgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.grey[300]!,
                      ),
                      // 🟢 如果封面生成了，直接用封面做背景图
                      image: _coverImage != null
                          ? DecorationImage(
                              image: FileImage(_coverImage!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _buildVideoPreviewArea(isDark),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  "标题",
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: inputBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _titleController,
                    style: TextStyle(color: textColor, fontSize: 16),
                    maxLength: 50,
                    maxLines: 2,
                    decoration: InputDecoration(
                      counterText: "",
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      hintText: "写点什么描述一下你的视频吧...",
                      hintStyle: TextStyle(color: hintColor),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 构建预览区内容
  Widget _buildVideoPreviewArea(bool isDark) {
    if (_isExtracting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_selectedVideo == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library,
            size: 50,
            color: isDark ? Colors.white38 : Colors.black26,
          ),
          const SizedBox(height: 8),
          Text(
            "点击选择要上传的视频",
            style: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
          ),
        ],
      );
    } else {
      // 🟢 有封面图的情况下，我们在中间画一个半透明的播放按钮
      return Center(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
        ),
      );
    }
  }
}

// ==========================================
// 🚀 独立上传函数：现在支持同时上传视频和封面了
// ==========================================
Future<void> _performBackgroundUpload(
  String title,
  int type,
  File videoFile,
  File coverFile,
) async {
  try {
    debugPrint("🚀 开始后台上传视频和封面...");

    var formData = FormData.fromMap({"title": title, "type": type});

    // 1. 添加视频文件
    formData.files.add(
      MapEntry(
        "file",
        await MultipartFile.fromFile(videoFile.path, filename: "video.mp4"),
      ),
    );

    // 2. 🟢 添加封面图片文件 (假设后端接收封面的参数名是 coverFile)
    formData.files.add(
      MapEntry(
        "coverFile",
        await MultipartFile.fromFile(coverFile.path, filename: "cover.jpg"),
      ),
    );

    await HttpUtil().post(
      "/api/work/create",
      data: formData,
      options: Options(
        sendTimeout: const Duration(minutes: 60),
        receiveTimeout: const Duration(minutes: 60),
      ),
    );

    debugPrint("✅ 后台发布成功");
    InAppNotification.show("视频发布成功！", isSuccess: true);
  } catch (e) {
    debugPrint("❌ 后台发布失败: $e");
    InAppNotification.show("视频发布失败，请检查网络", isSuccess: false);
  }
}
