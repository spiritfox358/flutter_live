class UserModel {
  final String? nickname;
  final String? avatar;
  final int coin;
  final int level;
  final int coinsCurrentLevelThreshold;
  final int coinsToNextLevel;
  final String coinsToNextLevelText;
  final int coinsNextLevelThreshold;

  UserModel(this.coin, this.level, {required this.coinsToNextLevel,required this.coinsNextLevelThreshold, required this.coinsToNextLevelText, required this.coinsCurrentLevelThreshold, this.nickname, this.avatar});
}
