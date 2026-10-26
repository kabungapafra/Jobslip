import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The business's logo, or its initial on an ink square when no logo has
/// been added. Used in the home header, in Setup, and as the stand-in on
/// the PDF, so the app and the paperwork always show the same mark.
class BrandMark extends StatelessWidget {
  final String? logoPath;
  final String businessName;
  final double size;
  final double radius;

  const BrandMark({
    super.key,
    required this.logoPath,
    required this.businessName,
    this.size = 38,
    this.radius = 12,
  });

  String get _initial {
    final trimmed = businessName.trim();
    return trimmed.isEmpty ? 'J' : trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final path = logoPath;
    final hasLogo = path != null && File(path).existsSync();

    if (hasLogo) {
      return SizedBox(
        width: size,
        height: size,
        // contain, not cover - a wide wordmark or a tall mark must show in
        // full rather than be cropped at the edges.
        child: Image.file(File(path), fit: BoxFit.contain),
      );
    }

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: AppTheme.ink, borderRadius: BorderRadius.circular(radius)),
      child: Text(
        _initial,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: size * 0.42),
      ),
    );
  }
}
