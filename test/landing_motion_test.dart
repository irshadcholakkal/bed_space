import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bed_space/presentation/widgets/landing_motion.dart';

void main() {
  testWidgets('Heading enters in stages and settles without a permanent ticker',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: LandingWordEntrance(
                text: 'Space management for teams',
                style: TextStyle(fontSize: 40)))));
    final opacity = find.descendant(
        of: find.byType(LandingWordEntrance), matching: find.byType(Opacity));
    expect(
        tester.widgetList<Opacity>(opacity).every((w) => w.opacity == 0), true);
    await tester.pump(const Duration(milliseconds: 300));
    final middle =
        tester.widgetList<Opacity>(opacity).map((w) => w.opacity).toList();
    expect(middle.first, greaterThan(middle.last));
    await tester.pumpAndSettle();
    expect(
        tester.widgetList<Opacity>(opacity).every((w) => w.opacity == 1), true);
  });

  testWidgets('Reduced motion shows all heading words immediately',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!),
        home: const Scaffold(
            body: LandingWordEntrance(
                text: 'Space management for teams',
                style: TextStyle(fontSize: 40)))));
    final opacity = find.descendant(
        of: find.byType(LandingWordEntrance), matching: find.byType(Opacity));
    expect(
        tester.widgetList<Opacity>(opacity).every((w) => w.opacity == 1), true);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Offscreen sections reveal as the page scrolls into view',
      (tester) async {
    final scroll = ScrollController();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                controller: scroll,
                child: Column(children: [
                  const SizedBox(height: 900),
                  LandingReveal(
                      scroll: scroll,
                      child: const SizedBox(
                          height: 200, child: Text('Section content')))
                ])))));
    final opacity = find.descendant(
        of: find.byType(LandingReveal), matching: find.byType(Opacity));
    expect(tester.widget<Opacity>(opacity).opacity, 0);
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(opacity).opacity, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    scroll.dispose();
  });
}
