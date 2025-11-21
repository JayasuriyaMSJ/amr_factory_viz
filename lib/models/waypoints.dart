class Waypoint {
  final int id;
  final String nickname;
  final double x;
  final double y;
  final double theta;
  final String wpType;
  bool isEnabled;
  bool isSelected;

  Waypoint({
    required this.id,
    required this.nickname,
    required this.x,
    required this.y,
    required this.theta,
    required this.wpType,
    this.isEnabled = true,
    this.isSelected = false,
  });
}
