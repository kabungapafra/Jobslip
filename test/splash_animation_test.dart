import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:digiflect_quotes/screens/splash_screen.dart';

/// Samples the splash animation frame by frame and asserts the mark actually
/// does what the design calls for: the dot bounces up and down several times,
/// comes to rest, and only then does the "j" swoosh appear.
void main() {
  testWidgets('dot bounces up and down, then the swoosh fades in', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SplashScreen(ready: true, onFinished: () {}),
    ));

    // Anchor to the dot image itself -- the tree holds several unrelated
    // Transforms, so positional lookup would sample the wrong one.
    final dotImage = find.byWidgetPredicate(
      (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName.contains('logo_dot'),
    );
    final dotTransform = find.ancestor(of: dotImage, matching: find.byType(Transform)).first;

    final dotY = <double>[];
    final swooshOpacity = <double>[];

    // 2400ms animation; sample every 40ms.
    for (var i = 0; i < 60; i++) {
      dotY.add(tester.widget<Transform>(dotTransform).transform.getTranslation().y);
      swooshOpacity.add(tester.widget<Opacity>(find.byType(Opacity).first).opacity);
      await tester.pump(const Duration(milliseconds: 40));
    }

    // The dot starts well above its resting place and off the mark.
    expect(dotY.first, lessThan(-100));

    // Count direction reversals -- a real up/down bounce reverses several
    // times. A single ease-in drop would reverse zero times.
    var reversals = 0;
    for (var i = 2; i < dotY.length; i++) {
      final prev = dotY[i - 1] - dotY[i - 2];
      final next = dotY[i] - dotY[i - 1];
      if (prev != 0 && next != 0 && prev.sign != next.sign) reversals++;
    }
    expect(reversals, greaterThanOrEqualTo(4),
        reason: 'expected multiple up-and-down hops, saw $reversals reversals');

    // The dot must come to rest at the mark.
    expect(dotY.last.abs(), lessThan(0.5));

    // Nothing of the swoosh may show while the dot is still moving.
    final settleIndex = dotY.lastIndexWhere((y) => y.abs() > 0.5);
    final opacityWhileBouncing = swooshOpacity.sublist(0, settleIndex + 1);
    expect(opacityWhileBouncing.every((o) => o == 0), isTrue,
        reason: 'swoosh started before the dot finished bouncing');

    // ...and it must be fully in by the end.
    expect(swooshOpacity.last, equals(1.0));
  });
}
