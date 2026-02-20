import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../tools/HttpUtil.dart';

class EditProfileBgPage extends StatefulWidget {
  final Map<String, dynamic> userMap;

  const EditProfileBgPage({super.key, required this.userMap});

  @override
  State<EditProfileBgPage> createState() => _EditProfileBgPageState();
}

class _EditProfileBgPageState extends State<EditProfileBgPage> {
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  bool _isSaving = false;

  Future<void> _pickImage() async {
    try {
      // 🟢 背景图需要更高的清晰度，这里放宽了分辨率和质量限制
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
        maxWidth: 1080,
        maxHeight: 1920,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      debugPrint("选择图片失败: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("无法打开相册，请检查权限")),
        );
      }
    }
  }

  Future<void> _saveProfileBg() async {
    // 🟢 如果没有选择新图片，直接返回即可
    if (_selectedImage == null) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isSaving = true);

    try {
      var formData = FormData();

      // 🟢 修改此处：使用 profile_bg 字段提交文件
      formData.files.add(
        MapEntry(
          "profile_bg",
          await MultipartFile.fromFile(_selectedImage!.path, filename: "profile_bg.jpg"),
        ),
      );

      // 请求后端接口
      await HttpUtil().post("/api/user/update_profile_bg", data: formData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("背景更换成功"), backgroundColor: Colors.green),
      );
      // 返回选择的本地图片路径，方便上一页更新本地状态刷新UI
      Navigator.pop(context, _selectedImage!.path);
    } catch (e) {
      debugPrint("保存失败: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("保存失败: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white.withOpacity(0.9) : Colors.black54;
    final iconColor = isDark ? Colors.white : Colors.black;

    // 获取现有的背景图URL
    final currentBgUrl = widget.userMap["profile_bg"];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: iconColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "更换主页背景",
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfileBg,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16)),
            child: _isSaving
                ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: subTextColor),
            )
                : const Text(
              "保存",
              style: TextStyle(color: Colors.purpleAccent, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          children: [
            // 🟢 背景图选择区域 (大长方形)
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: double.infinity,
                    height: 220, // 背景图展示的高度
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.grey[300]!,
                        width: 2,
                      ),
                      // 🟢 优先展示新选的图，其次展示网络图
                      image: _selectedImage != null
                          ? DecorationImage(
                        image: FileImage(_selectedImage!),
                        fit: BoxFit.cover,
                      )
                          : (currentBgUrl != null && currentBgUrl.toString().isNotEmpty)
                          ? DecorationImage(
                        image: NetworkImage(currentBgUrl),
                        fit: BoxFit.cover,
                      )
                          : null,
                    ),
                    // 如果既没有选本地图，也没有网络图，显示加号提示
                    child: (_selectedImage == null && (currentBgUrl == null || currentBgUrl.toString().isEmpty))
                        ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate, size: 50, color: isDark ? Colors.white38 : Colors.black26),
                        const SizedBox(height: 8),
                        Text("点击上传背景图", style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)),
                      ],
                    )
                        : null,
                  ),

                  // 右下角的相机小图标提示
                  if (_selectedImage != null || (currentBgUrl != null && currentBgUrl.toString().isNotEmpty))
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "建议上传高清且比例合适的图片，以获得最佳主页展示效果",
              style: TextStyle(color: isDark ? Colors.white38 : Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}