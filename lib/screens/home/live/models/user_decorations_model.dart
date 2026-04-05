class UserDecorationsModel {
  final String? avatarFrame; // 头像框
  final String? entryEffect; // 进场特效
  final String? levelHonourBuff; // 🚀 改回 String? (接收后端的 resourceUrl 字符串)
  final String? homeBg; // 主页背景

  UserDecorationsModel({this.avatarFrame, this.entryEffect, this.levelHonourBuff, this.homeBg});

  // 从 user['decorations'] 动态构建
  factory UserDecorationsModel.fromMap(dynamic raw) {
    if (raw == null || raw is! Map) {
      return UserDecorationsModel();
    }

    final map = raw as Map<Object?, Object?>;

    String? getString(String key) {
      final value = map[key];
      return value is String ? value : null;
    }

    return UserDecorationsModel(
      avatarFrame: getString('avatarFrame'),
      entryEffect: getString('entryEffect'),
      levelHonourBuff: getString('levelHonourBuff'), // 🚀 用普通字符串解析
      homeBg: getString('homeBg'),
    );
  }

  // 快速判断是否拥有某类装饰
  bool get hasAvatarFrame => avatarFrame != null;

  bool get hasEntryEffect => entryEffect != null;

  // 🚀 快速判断是否有值
  bool get hasLevelHonourBuff => levelHonourBuff != null && levelHonourBuff!.isNotEmpty;

  bool get hasHomeBg => homeBg != null;

  @override
  String toString() {
    return 'UserDecorations(avatarFrame: $avatarFrame, entryEffect: $entryEffect, levelHonourBuff: $levelHonourBuff, homeBg: $homeBg)';
  }
}