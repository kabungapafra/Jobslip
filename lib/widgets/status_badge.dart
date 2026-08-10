import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final String statusKey;

  const StatusBadge({super.key, required this.label, required this.statusKey});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.badgeBg(statusKey),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTheme.mono(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.badgeFg(statusKey),
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class TypeTag extends StatelessWidget {
  final String label;
  const TypeTag({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.chipBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTheme.mono(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.subtleText,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
