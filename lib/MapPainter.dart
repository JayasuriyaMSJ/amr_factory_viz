import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:amr_factory_viz/models/waypoints.dart';
import 'package:amr_factory_viz/models/routes.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:flutter/services.dart';

class MapPainter extends CustomPainter {
  final ui.Image? mapImage;
  final double mapResolution; // meters per pixel
  final Offset mapOrigin; // map origin in meters
  final List<Waypoint> waypoints;
  final List<Route> routes;
  final Waypoint? selectedWaypoint;
  final bool showRoutes;
  final List<Offset> zonePoints;
  

  MapPainter({
    required this.mapImage,
    required this.mapResolution,
    required this.mapOrigin,
    required this.waypoints,
    required this.routes,
    required this.selectedWaypoint,
    required this.showRoutes,
    required this.zonePoints,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw map image if available
    if (mapImage != null) {
      final srcRect = Rect.fromLTWH(
        0,
        0,
        mapImage!.width.toDouble(),
        mapImage!.height.toDouble(),
      );
      final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);
      canvas.drawImageRect(mapImage!, srcRect, dstRect, Paint());
    } else {
      // Draw placeholder background
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.grey[300]!,
      );
    }

    // Draw routes first (so they appear behind waypoints)
    if (showRoutes) {
      _drawRoutes(canvas, size);
    }

    // Draw waypoints
    _drawWaypoints(canvas, size);

    _drawZonePoints(canvas, size);
  }

  void _drawRoutes(Canvas canvas, Size size) {
    for (final route in routes) {
      if (!route.isEnabled) continue;

      final paint = Paint()
        ..color = _getRouteColor(route).withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;

      final arrowPaint = Paint()
        ..color = _getRouteColor(route).withOpacity(0.8)
        ..style = PaintingStyle.fill;

      // Draw path connecting waypoints
      for (int i = 0; i < route.points.length - 1; i++) {
        final currentPoint = route.points[i];
        final nextPoint = route.points[i + 1];

        final currentWp = waypoints.firstWhere(
          (wp) => wp.id == currentPoint.pts,
          orElse: () => waypoints[0],
        );
        final nextWp = waypoints.firstWhere(
          (wp) => wp.id == nextPoint.pts,
          orElse: () => waypoints[0],
        );

        final start = _worldToScreen(currentWp.x, currentWp.y, size);
        final end = _worldToScreen(nextWp.x, nextWp.y, size);

        // Draw line
        canvas.drawLine(start, end, paint);

        // Draw direction arrow in the middle
        final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
        _drawArrow(
          canvas,
          start,
          end,
          mid,
          arrowPaint,
          currentPoint.dir == 'R',
        );
      }
    }
  }

  void _drawArrow(
    Canvas canvas,
    Offset start,
    Offset end,
    Offset position,
    Paint paint,
    bool isReverse,
  ) {
    final direction = isReverse ? start - end : end - start;
    final angle = math.atan2(direction.dy, direction.dx);

    const arrowSize = 8.0;
    final path = Path();

    // Arrow tip
    path.moveTo(position.dx, position.dy);
    // Arrow left wing
    path.lineTo(
      position.dx - arrowSize * math.cos(angle - math.pi / 6),
      position.dy - arrowSize * math.sin(angle - math.pi / 6),
    );
    // Back to tip
    path.moveTo(position.dx, position.dy);
    // Arrow right wing
    path.lineTo(
      position.dx - arrowSize * math.cos(angle + math.pi / 6),
      position.dy - arrowSize * math.sin(angle + math.pi / 6),
    );

    canvas.drawPath(path, paint);
  }

  void _drawWaypoints(Canvas canvas, Size size) {
    // Draw unselected waypoints first
    for (final wp in waypoints) {
      if (!wp.isEnabled || wp == selectedWaypoint) continue;
      _drawWaypoint(canvas, size, wp, false);
    }

    // Draw selected waypoint last (on top)
    if (selectedWaypoint != null && selectedWaypoint!.isEnabled) {
      _drawWaypoint(canvas, size, selectedWaypoint!, true);
    }
  }

  // void _drawZonePoints(Canvas canvas, Size size) {
  //   final Paint markerPaint = Paint()
  //     ..color = Colors.redAccent
  //     ..style = PaintingStyle.fill;

  //   for (var point in zonePoints) {
  //     final screenPos = _worldToScreen(point.dx, point.dy, size);
  //     canvas.drawCircle(screenPos, 6, markerPaint);
  //   }
  // }

  void _drawZonePoints(Canvas canvas, Size size) {
    if (zonePoints.isEmpty) return;

    // Draw filled zone area if we have at least 3 points
    if (zonePoints.length >= 3) {
      final Path zonePath = Path();
      final screenPos = _worldToScreen(
        zonePoints[0].dx,
        zonePoints[0].dy,
        size,
      );
      zonePath.moveTo(screenPos.dx, screenPos.dy);

      for (int i = 1; i < zonePoints.length; i++) {
        final pos = _worldToScreen(zonePoints[i].dx, zonePoints[i].dy, size);
        zonePath.lineTo(pos.dx, pos.dy);
      }

      // Close the path if we have 4 points
      if (zonePoints.length == 4) {
        zonePath.close();
      }

      // Draw semi-transparent fill
      final fillPaint = Paint()
        ..color = Colors.blue.withOpacity(0.2)
        ..style = PaintingStyle.fill;
      canvas.drawPath(zonePath, fillPaint);

      // Draw border
      final borderPaint = Paint()
        ..color = Colors.blue.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawPath(zonePath, borderPaint);
    }

    // Draw lines connecting consecutive points
    if (zonePoints.length >= 2) {
      final linePaint = Paint()
        ..color = Colors.blue.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      for (int i = 0; i < zonePoints.length - 1; i++) {
        final start = _worldToScreen(zonePoints[i].dx, zonePoints[i].dy, size);
        final end = _worldToScreen(
          zonePoints[i + 1].dx,
          zonePoints[i + 1].dy,
          size,
        );
        canvas.drawLine(start, end, linePaint);
      }
    }

    // Draw zone point markers
    for (int i = 0; i < zonePoints.length; i++) {
      final screenPos = _worldToScreen(
        zonePoints[i].dx,
        zonePoints[i].dy,
        size,
      );

      // Outer circle for better visibility
      final outerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(screenPos, 8, outerPaint);

      // Inner circle
      final markerPaint = Paint()
        ..color = Colors.redAccent
        ..style = PaintingStyle.fill;
      canvas.drawCircle(screenPos, 10, markerPaint);

      // Draw point number
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'Z${i + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          screenPos.dx - textPainter.width / 2,
          screenPos.dy - textPainter.height / 2,
        ),
      );
    }
  }

  void _drawWaypoint(Canvas canvas, Size size, Waypoint wp, bool isSelected) {
    final screenPos = _worldToScreen(wp.x, wp.y, size);

    // Draw outer circle (selection indicator)
    if (isSelected) {
      final outerPaint = Paint()
        ..color = Colors.red.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(screenPos, 16, outerPaint);
    }

    // Draw main waypoint circle
    final paint = Paint()
      ..color = isSelected ? Colors.red : _getWaypointColor(wp)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(screenPos, isSelected ? 10 : 8, paint);

    // Draw border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(screenPos, isSelected ? 10 : 8, borderPaint);

    // Draw orientation indicator (small line showing theta direction)
    final orientationPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final lineLength = isSelected ? 15 : 12;
    final endX = screenPos.dx + lineLength * math.cos(wp.theta);
    final endY =
        screenPos.dy -
        lineLength *
            math.sin(wp.theta); // Negative because Y increases downward

    canvas.drawLine(screenPos, Offset(endX, endY), orientationPaint);

    // Draw waypoint ID for selected or important waypoints
    if (isSelected || wp.wpType != 'WAYPOINT') {
      final textPainter = TextPainter(
        text: TextSpan(
          text: wp.id.toString(),
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          screenPos.dx - textPainter.width / 2,
          screenPos.dy - textPainter.height / 2,
        ),
      );
    }
  }

  Offset _worldToScreen(double worldX, double worldY, Size size) {
    if (mapImage == null) {
      // Fallback: simple center-based conversion
      final centerX = size.width / 2;
      final centerY = size.height / 2;
      final scale = 10.0; // pixels per meter
      return Offset(
        centerX + worldX * scale,
        centerY - worldY * scale, // Negative because Y increases downward
      );
    }

    // Convert world coordinates to map pixel coordinates
    // Formula: pixel = (world - origin) / resolution
    final pixelX = (worldX - mapOrigin.dx) / mapResolution;
    final pixelY = (worldY - mapOrigin.dy) / mapResolution;

    // Scale to screen size
    final scaleX = size.width / mapImage!.width;
    final scaleY = size.height / mapImage!.height;

    return Offset(
      pixelX * scaleX,
      size.height - (pixelY * scaleY), // Flip Y axis
    );
  }

  Color _getWaypointColor(Waypoint wp) {
    switch (wp.wpType) {
      case 'CHARGING':
        return Colors.green;
      case 'PARKING':
        return Colors.orange;
      case 'LOADING':
        return Colors.purple;
      case 'UNLOADING':
        return Colors.amber;
      default:
        return Colors.blue;
    }
  }

  Color _getRouteColor(Route route) {
    // Generate different colors for different routes
    final hash = route.name.hashCode;
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.7, 0.5).toColor();
  }

  @override
  bool shouldRepaint(covariant MapPainter oldDelegate) {
    return oldDelegate.mapImage != mapImage ||
        oldDelegate.waypoints != waypoints ||
        oldDelegate.routes != routes ||
        oldDelegate.selectedWaypoint != selectedWaypoint ||
        oldDelegate.showRoutes != showRoutes ||
        oldDelegate.zonePoints != zonePoints;
  }
}

// Helper class to load and manage map image
class MapImageLoader {
  static Future<ui.Image?> loadMapImage(File mapFile) async {
    try {
      final bytes = await mapFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      debugPrint('Error loading map image: $e');
      return null;
    }
  }

  static MapMetadata parseMapYaml(String yamlContent) {
    final lines = yamlContent.split('\n');
    double resolution = 0.05;
    double originX = 0.0;
    double originY = 0.0;

    for (final line in lines) {
      if (line.startsWith('resolution:')) {
        resolution = double.tryParse(line.split(':')[1].trim()) ?? 0.05;
      } else if (line.startsWith('origin:')) {
        final originStr = line.substring(
          line.indexOf('[') + 1,
          line.indexOf(']'),
        );
        final parts = originStr.split(',');
        if (parts.length >= 2) {
          originX = double.tryParse(parts[0].trim()) ?? 0.0;
          originY = double.tryParse(parts[1].trim()) ?? 0.0;
        }
      }
    }

    return MapMetadata(
      resolution: resolution,
      origin: Offset(originX, originY),
    );
  }
}

class MapMetadata {
  final double resolution;
  final Offset origin;

  MapMetadata({required this.resolution, required this.origin});
}
