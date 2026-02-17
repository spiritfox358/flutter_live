import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../tools/HttpUtil.dart';

class CreateAnchorPage extends StatefulWidget {
  const CreateAnchorPage({super.key});

  @override
  State<CreateAnchorPage> createState() => _CreateAnchorPageState();
}

class _CreateAnchorPageState extends State<CreateAnchorPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _signatureController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  bool _isSubmitting = false;
  int _gender = 1; // 🟢 新增：性别状态 (1=男, 2=女)，默认男

  @override
  void dispose() {
    _nameController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  // 选择图片逻辑
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 20,
        maxWidth: 500,
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

  // 提交创建逻辑
  Future<void> _submit() async {
    final nickname = _nameController.text.trim();
    final signature = _signatureController.text.trim();

    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("请上传主播头像")));
      return;
    }
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("请输入主播昵称")));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      Map<String, dynamic> map = {};
      map["nickname"] = nickname;
      map["signature"] = signature;
      map["gender"] = _gender; // 🟢 提交性别字段

      var formData = FormData.fromMap(map);

      if (_selectedImage != null) {
        formData.files.add(
          MapEntry(
            "avatarFile",
            await MultipartFile.fromFile(_selectedImage!.path, filename: "anchor_avatar.jpg"),
          ),
        );
      }

      await HttpUtil().post("/api/room/create_robot_anchor", data: formData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("创建成功"), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint("创建失败: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("创建失败: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white.withOpacity(0.9) : Colors.black54;
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "创建主播",
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16)),
            child: _isSubmitting
                ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: subTextColor),
            )
                : const Text(
              "创建",
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
              // 1. 头像区域
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
                          color: inputBgColor,
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.grey[300]!,
                            width: 2,
                          ),
                          image: _selectedImage != null
                              ? DecorationImage(
                            fit: BoxFit.cover,
                            image: FileImage(_selectedImage!),
                          )
                              : null,
                        ),
                        child: _selectedImage == null
                            ? Icon(Icons.person_add, size: 40, color: hintColor)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? Colors.black : Colors.grey[300]!,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            color: isDark ? Colors.white70 : Colors.black54,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "上传主播头像",
                style: TextStyle(color: isDark ? Colors.white38 : Colors.grey, fontSize: 12),
              ),

              const SizedBox(height: 40),

              // 2. 昵称标题
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    "主播昵称",
                    style: TextStyle(color: subTextColor, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(color: inputBgColor, borderRadius: BorderRadius.circular(12)),
                child: TextField(
                  controller: _nameController,
                  style: TextStyle(color: textColor, fontSize: 16),
                  maxLength: 12,
                  maxLines: 1,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    counterText: "",
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    hintText: "给你的AI主播起个名字",
                    hintStyle: TextStyle(color: hintColor),
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      icon: Icon(Icons.clear, color: hintColor, size: 18),
                      onPressed: () => _nameController.clear(),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 3. 签名标题
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    "个性签名",
                    style: TextStyle(color: subTextColor, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(color: inputBgColor, borderRadius: BorderRadius.circular(12)),
                child: TextField(
                  controller: _signatureController,
                  style: TextStyle(color: textColor, fontSize: 16),
                  maxLength: 50,
                  maxLines: 3,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    counterText: "",
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    hintText: "描述一下主播的性格或打个招呼...",
                    hintStyle: TextStyle(color: hintColor),
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      icon: Icon(Icons.clear, color: hintColor, size: 18),
                      onPressed: () => _signatureController.clear(),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 4. 🟢 性别标题
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    "性别",
                    style: TextStyle(color: subTextColor, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              // 🟢 性别选择区域
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(color: inputBgColor, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildGenderRadio(1, "男", Icons.male, Colors.blue, textColor),
                    _buildGenderRadio(2, "女", Icons.female, Colors.pink, textColor),
                  ],
                ),
              ),

              const SizedBox(height: 40), // 底部留白
            ],
          ),
        ),
      ),
    );
  }

  // 🟢 构建性别单选按钮 (复用样式)
  Widget _buildGenderRadio(int value, String label, IconData icon, Color activeColor, Color textColor) {
    final bool isSelected = _gender == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _gender = value;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? activeColor : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 18, color: isSelected ? activeColor : Colors.grey),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : textColor.withOpacity(0.7),
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}