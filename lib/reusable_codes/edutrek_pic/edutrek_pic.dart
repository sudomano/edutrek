// lib/reusable_widgets/rounded_image_widget.dart
import 'package:flutter/material.dart';

class RoundedImage extends StatelessWidget {
  final String imagePath;
  final double height;
  final double width;
  final double borderRadius;

  const RoundedImage({
    Key? key,
    required this.imagePath,
    this.height = 200.0,
    this.width = 400.0,
    this.borderRadius = 16.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        imagePath,
        height: height,
        width: width,
        fit: BoxFit.cover,
      ),
    );
  }
}
