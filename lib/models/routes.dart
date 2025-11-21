class RoutePoint {
  final int pts;
  final String dir; // F, R
  final String layer; // E, J, I, L

  RoutePoint({
    required this.pts,
    required this.dir,
    required this.layer,
  });

  String get directionName => dir == 'F' ? 'Forward' : 'Reverse';
  String get controllerName {
    switch (layer) {
      case 'E':
        return 'Pure Pursuit';
      case 'J':
        return 'Curve Turn';
      case 'I':
        return 'Inplace';
      case 'L':
        return 'Last (BFS/DFS)';
      default:
        return 'Unknown';
    }
  }
}

class Route {
  final String name;
  final List<RoutePoint> points;
  final double stoppingDistance;
  bool isEnabled;

  Route({
    required this.name,
    required this.points,
    required this.stoppingDistance,
    this.isEnabled = true,
  });
}