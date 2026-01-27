class UserStatus {
  final int coin;
  final int level;
  final int coinsCurrentLevelThreshold;
  final int coinsToNextLevel;
  final String coinsToNextLevelText;
  final int coinsNextLevelThreshold;

  UserStatus(this.coin, this.level, {required this.coinsToNextLevel,required this.coinsNextLevelThreshold, required this.coinsToNextLevelText, required this.coinsCurrentLevelThreshold});
}
