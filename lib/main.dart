import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/branding_onboarding_screen.dart';
import 'screens/root_shell.dart';
import 'screens/splash_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const DigiflectApp());
}

class DigiflectApp extends StatefulWidget {
  const DigiflectApp({super.key});

  @override
  State<DigiflectApp> createState() => _DigiflectAppState();
}

class _DigiflectAppState extends State<DigiflectApp> {
  late final AppState _appState;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _appState = AppState();
    _appState.load();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _appState,
      child: Consumer<AppState>(
        builder: (context, appState, _) {
          return MaterialApp(
            title: 'JobSlip',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(appState.settings.brandColor),
            home: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                // The splash "opens" into the dashboard: scale up slightly
                // while fading, like the mark expanding into the app.
                final scale = Tween<double>(begin: 0.92, end: 1.0).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: scale, child: child),
                );
              },
              child: _showSplash
                  ? SplashScreen(
                      key: const ValueKey('splash'),
                      // Hold the splash until the saved data is in.
                      ready: appState.loaded,
                      onFinished: () => setState(() => _showSplash = false),
                    )
                  : appState.needsOnboarding
                      ? const BrandingOnboardingScreen(key: ValueKey('onboarding'))
                      : const RootShell(key: ValueKey('dashboard')),
            ),
          );
        },
      ),
    );
  }
}
