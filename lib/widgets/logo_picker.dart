import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../theme/app_theme.dart';

/// Tap to pick a logo image from the gallery, long-press to remove it.
/// Copies the picked file into the app's own local storage so it survives
/// even if the OS picker used a transient cache location — everything
/// stays on-device, no network involved.
class LogoPicker extends StatelessWidget {
  final String? logoPath;
  final ValueChanged<String?> onChanged;
  final double size;

  const LogoPicker({super.key, required this.logoPath, required this.onChanged, this.size = 64});

  Future<void> _pick() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (picked == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final ext = picked.path.split('.').last;
    final dest = File('${dir.path}/business_logo.$ext');
    await dest.writeAsBytes(await picked.readAsBytes());
    onChanged(dest.path);
  }

  @override
  Widget build(BuildContext context) {
    final path = logoPath;
    final hasLogo = path != null && File(path).existsSync();

    return GestureDetector(
      onTap: _pick,
      onLongPress: hasLogo ? () => onChanged(null) : null,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          // A real logo sits on white: many are transparent-background PNGs
          // and a tinted tile behind them looks like a rendering fault.
          color: hasLogo ? Colors.white : AppTheme.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.strongBorder, width: 1.5),
        ),
        child: hasLogo
            // contain, not cover - a non-square logo (wide wordmark, tall
            // mark) must show in full, never cropped at the edges.
            ? Image.file(File(path), fit: BoxFit.contain, width: size, height: size)
            : const Text(
                'Add\nlogo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.mutedText,
                ),
              ),
      ),
    );
  }
}
