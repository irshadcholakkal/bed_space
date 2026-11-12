import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bed_space/presentation/widgets/room_delete_dialog.dart';

void main() {
  testWidgets('Deletion cannot be confirmed until eight seconds pass',
      (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () async {
                      result = await showDialog<bool>(
                          context: context,
                          builder: (_) =>
                              const RoomDeleteDialog(roomName: 'Room 101'));
                    },
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    await tester.pump(const Duration(seconds: 7));
    expect(find.text('Delete (1 s)'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(result, isNull);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
    await tester.tap(find.text('Delete room'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
  testWidgets('Cancellation works during countdown and disposes the timer',
      (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () async {
                      result = await showDialog<bool>(
                          context: context,
                          builder: (_) =>
                              const RoomDeleteDialog(roomName: 'Subroom A'));
                    },
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 10));
    expect(result, isFalse);
    expect(tester.takeException(), isNull);
  });
}
