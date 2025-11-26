import 'package:flutter/material.dart';

class ImgMarker extends CustomPainter {
  final List<Offset> points;
  ImgMarker(this.points);
  @override
  void paint(Canvas canvas, Size size) {
    final Paint markerPoint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.stroke;

    for (var p in points) {
      canvas.drawCircle(p, 5, markerPoint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
