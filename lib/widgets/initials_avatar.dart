import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class InitialsAvatar extends StatelessWidget {
  final String initials;
  final double size;

  const InitialsAvatar({super.key, required this.initials, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.chipBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        initials,
        style: AppTheme.mono(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.subtleText),
      ),
    );
  }
}
