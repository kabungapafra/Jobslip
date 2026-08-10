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

  const LogoPicker({super.key, required this.logoPath, required this.onChanged, this.size = 56});

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
          // No fill behind an actual logo — many logos are transparent-bg
          // PNGs and a colored tile behind them looks like a rendering
          // bug. The placeholder state still needs a visible box.
          color: hasLogo ? null : AppTheme.chipBackground,
          borderRadius: BorderRadius.circular(10),
          border: hasLogo ? null : Border.all(color: AppTheme.border),
        ),
        child: hasLogo
            // contain, not cover — a non-square logo (wide wordmark, tall
            // mark, etc.) must show in full, never cropped at the edges.
            ? Image.file(File(path), fit: BoxFit.contain, width: size, height: size)
            : Text('tap to\nadd logo',
                textAlign: TextAlign.center,
                style: AppTheme.mono(fontSize: 8, color: AppTheme.subtleText)),
      ),
    );
  }
}
