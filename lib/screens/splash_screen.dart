import 'package:flutter/material.dart';

import '../models/settings.dart';

/// Shown while [AppState] loads from disk. Background matches the native
/// splash (brand teal) so there's no flash-to-white handoff.
///
/// Sequence, in order and without overlap:
///   1. the dot falls in and bounces up and down, settling after three hops
///   2. the "j" swoosh fades in beneath it
///   3. a short hold, then it hands off to the dashboard
///
/// The dot and swoosh PNGs share one 1276x1340 canvas (dot near the top,
/// swoosh below it), so drawing them centred in the same box lines the mark
/// up exactly. Only the dot is translated; the swoosh stays put.
class SplashScreen extends StatefulWidget {
  final bool ready;
  final VoidCallback onFinished;

  const SplashScreen({super.key, required this.ready, required this.onFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  /// How far above its resting place the dot starts, in logical pixels.
  /// Kept short so the dot is on the mark quickly -- a long fall reads as
  /// dead time on top of the engine's own cold-start delay.
  static const double _dropFrom = -140;

  /// Peak height of each successive bounce. Decaying amplitude is what reads
  /// as gravity; ending on a small hop keeps the settle from looking abrupt.
  static const List<double> _bouncePeaks = [-72, -32, -12];

  late final AnimationController _controller;
  late final Animation<double> _dotY;
  late final Animation<double> _swooshOpacity;
  late final Animation<double> _swooshScale;
  bool _finishScheduled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

    // Phase 1 -- the bounce. Falls are eased in (accelerating toward the
    // ground), rises are eased out (decelerating at the apex), so each hop
    // has real weight to it.
    final bounce = <TweenSequenceItem<double>>[
      TweenSequenceItem(
        tween: Tween(begin: _dropFrom, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 24,
      ),
    ];
    for (final peak in _bouncePeaks) {
      bounce.add(TweenSequenceItem(
        tween: Tween(begin: 0.0, end: peak).chain(CurveTween(curve: Curves.easeOut)),
        weight: peak.abs() / 4,
      ));
      bounce.add(TweenSequenceItem(
        tween: Tween(begin: peak, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: peak.abs() / 4,
      ));
    }
    _dotY = TweenSequence(bounce).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.58)),
    );

    // Phase 2 -- the swoosh, starting only once the dot has come to rest.
    _swooshOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.60, 0.84, curve: Curves.easeOut)),
    );
    _swooshScale = Tween<double>(begin: 0.82, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.60, 0.88, curve: Curves.easeOutBack)),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _maybeFinish();
    });

    // Cold start can take a while to paint the first frame (engine/shader
    // warm-up). Starting forward() here would burn that delay out of the
    // animation's own clock, so by the time anything is on screen the dot
    // has already "finished" bouncing off-screen. Wait for the first real
    // frame instead, so the bounce is what the user actually sees move.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void didUpdateWidget(covariant SplashScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeFinish();
  }

  void _maybeFinish() {
    if (_finishScheduled) return;
    if (_controller.status != AnimationStatus.completed) return;
    if (!widget.ready) return;
    _finishScheduled = true;
    // The hand-off waits for the frame to end. _maybeFinish is reached from
    // didUpdateWidget, which runs *during* the build phase — calling back
    // synchronously there asks the app above us to rebuild while it is
    // already building, which Flutter rejects outright.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brand = kBrandColors.first.color;
    const logoSize = 140.0;

    return Scaffold(
      backgroundColor: brand,
      body: Center(
        child: SizedBox(
          width: logoSize,
          height: logoSize,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: _swooshOpacity.value.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: _swooshScale.value,
                      child: const _LogoLayer('assets/icon/logo_swoosh_white.png', logoSize),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(0, _dotY.value),
                    child: const _LogoLayer('assets/icon/logo_dot_white.png', logoSize),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LogoLayer extends StatelessWidget {
  final String asset;
  final double size;

  const _LogoLayer(this.asset, this.size);

  @override
  Widget build(BuildContext context) {
    return Image.asset(asset, width: size, height: size, fit: BoxFit.contain);
  }
}
