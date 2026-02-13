class UserDecorationsModel {
  final String? avatarFrame; // 头像框
  final String? entryEffect; // 进场特效
  final String? chatBubble; // 聊天气泡
  final String? homeBg; // 主页背景

  UserDecorationsModel({this.avatarFrame, this.entryEffect, this.chatBubble, this.homeBg});

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
      chatBubble: getString('chatBubble'),
      homeBg: getString('homeBg'),
    );
  }

  // 快速判断是否拥有某类装饰
  bool get hasAvatarFrame => avatarFrame != null;

  bool get hasEntryEffect => entryEffect != null;

  bool get hasChatBubble => chatBubble != null;

  bool get hasHomeBg => homeBg != null;

  @override
  String toString() {
    return 'UserDecorations(avatarFrame: $avatarFrame, entryEffect: $entryEffect, chatBubble: $chatBubble, homeBg: $homeBg)';
  }
}
