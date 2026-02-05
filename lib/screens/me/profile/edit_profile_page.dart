import 'dart:io';
import 'package:dio/dio.dart'; // 🟢 引入 Dio 用于构建 FormData
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// 🟢 确保引入你的 HttpUtil (请检查路径是否正确)
import '../../../tools/HttpUtil.dart';

class EditProfilePage extends StatefulWidget {
  final String currentAvatarUrl;
  final String currentNickname;

  const EditProfilePage({super.key, required this.currentAvatarUrl, required this.currentNickname});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _nameController;
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentNickname);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // 📸 1. 选择图片 (修改：去掉了二次确认弹窗)
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        // 🟢 修改点 1：压缩质量 (0-100)
        // 10~20 是非常低的质量，文件极小，头像场景够用了。
        // 如果设为 0 可能完全模糊，建议 10 或 15。
        imageQuality: 15,

        // 🟢 修改点 2：限制最大分辨率 (关键！)
        // 现在的手机拍照动不动就 4000x3000 像素，几 MB 大。
        // 头像只需要显示一个小圆圈，设置 400 或 300 像素足够清晰了。
        maxWidth: 400,
        maxHeight: 400,
      );
      if (image != null) {
        // 🟢 修改处：直接更新状态，不弹窗
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      debugPrint("选择图片失败: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("无法打开相册，请检查权限")));
      }
    }
  }

  // 💾 2. 真实的保存逻辑 (连接后端)
  Future<void> _saveProfile() async {
    final newName = _nameController.text.trim();

    // 如果没有改名字也没选图片，直接返回
    if (newName == widget.currentNickname && _selectedImage == null) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 构建 FormData
      Map<String, dynamic> map = {};

      // 只有昵称改变了才传，或者后端允许覆盖
      map["nickname"] = newName;

      // 创建 FormData
      var formData = FormData.fromMap(map);

      // 添加文件 (如果有)
      if (_selectedImage != null) {
        formData.files.add(
          MapEntry(
            "avatarFile", // 🟢 必须与后端 @RequestParam("avatarFile") 一致
            await MultipartFile.fromFile(
              _selectedImage!.path,
              filename: "avatar.jpg", // 文件名随意，后缀最好对上
            ),
          ),
        );
      }

      // 发送请求
      await HttpUtil().post("/api/user/update", data: formData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("保存成功"), backgroundColor: Colors.green));
      // 返回新的昵称给上一个页面更新显示
      Navigator.pop(context, newName);
    } catch (e) {
      debugPrint("保存失败: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("保存失败: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "编辑资料",
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16)),
            child: _isSaving
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70))
                : const Text(
                    "保存",
                    style: TextStyle(color: Colors.purpleAccent, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: Column(
            children: [
              // 头像区域
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white12, width: 2),
                          image: DecorationImage(
                            fit: BoxFit.cover,
                            image: _selectedImage != null ? FileImage(_selectedImage!) as ImageProvider : NetworkImage(widget.currentAvatarUrl),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C2C2C),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white70, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text("点击更换头像", style: TextStyle(color: Colors.white38, fontSize: 12)),

              const SizedBox(height: 40),

              // 昵称区域
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    "昵称",
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              Container(
                decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12)),
                child: TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  maxLength: 12,
                  maxLines: 1,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    counterText: "",
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    hintText: "请输入昵称",
                    hintStyle: const TextStyle(color: Colors.white24),
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white24, size: 18),
                      onPressed: () => _nameController.clear(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
