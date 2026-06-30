import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../tools/HttpUtil.dart';
import '../../widgets/in_app_notification.dart';

/// 图文发布页：标题 + 正文 + 多张图片 -> /api/work/create_article (type=1)
class PublishArticlePage extends StatefulWidget {
  const PublishArticlePage({super.key});

  @override
  State<PublishArticlePage> createState() => _PublishArticlePageState();
}

class _PublishArticlePageState extends State<PublishArticlePage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  final List<File> _images = [];
  static const int _maxImages = 9;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_images.length >= _maxImages) {
      _toast("最多选择 $_maxImages 张图片");
      return;
    }
    try {
      final List<XFile> picked = await _picker.pickMultiImage();
      if (picked.isEmpty) return;
      setState(() {
        for (final x in picked) {
          if (_images.length >= _maxImages) break;
          _images.add(File(x.path));
        }
      });
    } catch (e) {
      debugPrint("选择图片失败: $e");
      _toast("无法打开相册");
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  void _startPublish() {
    final title = _titleController.text.trim();
    final text = _textController.text.trim();

    if (title.isEmpty && text.isEmpty && _images.isEmpty) {
      _toast("标题、正文、图片至少要填一项");
      return;
    }
    if (title.isEmpty) {
      _toast("给你的图文起个标题吧");
      return;
    }

    _toast("已转入后台发布中...", color: Colors.blue);
    _performBackgroundUpload(title, text, List<File>.from(_images));

    _titleController.clear();
    _textController.clear();
    setState(() => _images.clear());
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  void _toast(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    final inputBgColor = isDark ? const Color(0xFF1A1A1A) : Colors.grey[100];
    final hintColor = isDark ? Colors.white24 : Colors.black26;
    final iconColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: iconColor),
          onPressed: () {
            if (Navigator.canPop(context)) Navigator.pop(context);
          },
        ),
        title: Text(
          "发布图文",
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _submitting ? null : _startPublish,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16)),
            child: const Text(
              "发布",
              style: TextStyle(color: Colors.purpleAccent, fontSize: 18, fontWeight: FontWeight.bold),
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
              // 标题
              Text("标题", style: TextStyle(color: subTextColor, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(color: inputBgColor, borderRadius: BorderRadius.circular(12)),
                child: TextField(
                  controller: _titleController,
                  style: TextStyle(color: textColor, fontSize: 16),
                  maxLength: 50,
                  decoration: InputDecoration(
                    counterText: "",
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    hintText: "起个吸引人的标题...",
                    hintStyle: TextStyle(color: hintColor),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 正文
              Text("正文", style: TextStyle(color: subTextColor, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(color: inputBgColor, borderRadius: BorderRadius.circular(12)),
                child: TextField(
                  controller: _textController,
                  style: TextStyle(color: textColor, fontSize: 15, height: 1.5),
                  maxLength: 1000,
                  minLines: 5,
                  maxLines: 12,
                  decoration: InputDecoration(
                    counterStyle: TextStyle(color: hintColor),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    hintText: "分享你的想法、故事或攻略...",
                    hintStyle: TextStyle(color: hintColor),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 图片
              Text("图片 (${_images.length}/$_maxImages)",
                  style: TextStyle(color: subTextColor, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildImageGrid(isDark, inputBgColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageGrid(bool isDark, Color? tileBg) {
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (int i = 0; i < _images.length; i++)
          Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(_images[i], fit: BoxFit.cover),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _removeImage(i),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
        if (_images.length < _maxImages)
          GestureDetector(
            onTap: _pickImages,
            child: Container(
              decoration: BoxDecoration(
                color: tileBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? Colors.white12 : Colors.grey[300]!),
              ),
              child: Icon(Icons.add_a_photo_outlined,
                  color: isDark ? Colors.white38 : Colors.black38, size: 28),
            ),
          ),
      ],
    );
  }
}

// ==========================================
// 🚀 后台上传图文：多图 + 标题 + 正文
// ==========================================
Future<void> _performBackgroundUpload(String title, String text, List<File> images) async {
  try {
    final formData = FormData.fromMap({"title": title, "text": text});
    for (int i = 0; i < images.length; i++) {
      formData.files.add(
        MapEntry(
          "images",
          await MultipartFile.fromFile(images[i].path, filename: "img_$i.jpg"),
        ),
      );
    }

    await HttpUtil().post(
      "/api/work/create_article",
      data: formData,
      options: Options(
        sendTimeout: const Duration(minutes: 10),
        receiveTimeout: const Duration(minutes: 10),
      ),
    );

    InAppNotification.show("图文发布成功！", isSuccess: true);
  } catch (e) {
    debugPrint("❌ 图文发布失败: $e");
    InAppNotification.show("图文发布失败，请检查网络", isSuccess: false);
  }
}
