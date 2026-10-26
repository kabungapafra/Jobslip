import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:digiflect_quotes/main.dart';

class _FakePathProvider extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    final dir = await Directory.systemTemp.createTemp('digiflect_test');
    return dir.path;
  }
}

void main() {
  PathProviderPlatform.instance = _FakePathProvider();

  testWidgets('Fresh install: splash -> branding onboarding -> skip -> dashboard', (
    WidgetTester tester,
  ) async {
    // Real dart:io file access (used by the offline JSON store) needs the
    // real event loop, which tester.pump() alone does not drive.
    await tester.runAsync(() async {
      await tester.pumpWidget(const DigiflectApp());
      await Future.delayed(const Duration(milliseconds: 150));
      await tester.pump();
      // Fast-forward the splash's AnimationController (bounce/assemble) to
      // completion; the hand-off fires directly off the controller so no
      // extra real-time wait is needed here.
      await tester.pump(const Duration(milliseconds: 2100));
      await tester.pump();
      // Let the AnimatedSwitcher cross-fade/scale into the onboarding screen finish.
      await tester.pump(const Duration(milliseconds: 500));
    });

    // A brand-new install has no saved data yet, so it lands on the
    // one-time branding screen instead of a dashboard seeded with fake
    // sample paperwork.
    expect(find.text('Skip for now'), findsOneWidget);
    expect(find.text('Nothing here yet'), findsNothing);

    await tester.tap(find.text('Skip for now'));
    await tester.runAsync(() async {
      // completeOnboarding() writes the store file before notifying, and
      // that write is deliberately atomic (temp file + rename), so it costs
      // two real filesystem round-trips. Wait for the dashboard to actually
      // arrive rather than guessing a fixed delay, which silently turns a
      // slower disk into a failing test.
      for (var i = 0; i < 60; i++) {
        await Future.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        if (find.text('OWED TO YOU').evaluate().isNotEmpty) break;
      }
      await tester.pump(const Duration(milliseconds: 300));
    });

    // The v2 home screen leads with what the business is owed, and says so
    // even when there is nothing on the books yet.
    expect(find.text('OWED TO YOU'), findsOneWidget);
    expect(find.text('Nothing here yet'), findsOneWidget);
  });
}
