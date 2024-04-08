import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class DetectedArea extends CustomPainter {
  final List<TextBlock> textBlocks;
  const DetectedArea({required this.textBlocks});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final block in textBlocks) {
      final rect = block.boundingBox;
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
