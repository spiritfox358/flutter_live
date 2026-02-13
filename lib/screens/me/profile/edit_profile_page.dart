import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../tools/HttpUtil.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> userMap;

  const EditProfilePage({super.key, required this.userMap});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _signatureController; // 🟢 新增：签名控制器
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  bool _isSaving = false;
  late int _gender; // 性别状态

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userMap["nickname"]);
    _signatureController = TextEditingController(text: widget.userMap["signature"] ?? ""); // 🟢 初始化签名
    _gender = widget.userMap["gender"];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _signatureController.dispose(); // 🟢 释放签名控制器
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 15,
        maxWidth: 400,
        maxHeight: 400,
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

  Future<void> _saveProfile() async {
    final newName = _nameController.text.trim();
    final newSignature = _signatureController.text.trim();

    // 🟢 判断：如果昵称、签名、头像、性别都未更改，则直接返回
    if (newName == widget.userMap["nickname"] &&
        newSignature == (widget.userMap["signature"] ?? "") &&
        _selectedImage == null &&
        _gender == widget.userMap["gender"]) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isSaving = true);

    try {
      Map<String, dynamic> map = {};
      map["nickname"] = newName;
      map["signature"] = newSignature; // 🟢 提交签名
      map["gender"] = _gender;

      var formData = FormData.fromMap(map);

      if (_selectedImage != null) {
        formData.files.add(
          MapEntry(
            "avatarFile",
            await MultipartFile.fromFile(_selectedImage!.path, filename: "avatar.jpg"),
          ),
        );
      }

      await HttpUtil().post("/api/user/update", data: formData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("保存成功"), backgroundColor: Colors.green),
      );
      Navigator.pop(context, newName);
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
          "编辑资料",
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
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
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.grey[300]!,
                            width: 2,
                          ),
                          image: DecorationImage(
                            fit: BoxFit.cover,
                            image: _selectedImage != null
                                ? FileImage(_selectedImage!) as ImageProvider
                                : NetworkImage(widget.userMap["avatar"]),
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
                "点击更换头像",
                style: TextStyle(color: isDark ? Colors.white38 : Colors.grey, fontSize: 12),
              ),

              const SizedBox(height: 40),

              // 昵称标题
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    "昵称",
                    style: TextStyle(color: subTextColor, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              // 昵称输入框
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
                    hintText: "请输入昵称",
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

              // 🟢 签名标题
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

              // 🟢 签名输入框
              Container(
                decoration: BoxDecoration(color: inputBgColor, borderRadius: BorderRadius.circular(12)),
                child: TextField(
                  controller: _signatureController,
                  style: TextStyle(color: textColor, fontSize: 16),
                  maxLength: 30,
                  maxLines: 2,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    counterText: "",
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    hintText: "写下你的个性签名",
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

              // 性别标题
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

              // 性别选择区域
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
            ],
          ),
        ),
      ),
    );
  }

  // 构建性别单选按钮
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