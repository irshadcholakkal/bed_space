import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bed_space/data/models/bed_model.dart';
import 'package:bed_space/data/repositories/management_repository.dart';
import 'package:bed_space/presentation/blocs/management/management_bloc.dart';
import 'package:bed_space/presentation/screens/rooms_screen.dart';
import 'property_financials_test.dart' as fixture;

class _Repository extends Fake implements ManagementRepository {}

class _Bloc extends ManagementBloc {
  _Bloc() : super(repository: _Repository()) {
    emit(ManagementLoaded(
        buildings: fixture.buildings,
        rooms: fixture.spaces,
        beds: [
          BedModel(
              roomId: 'parent',
              bedType: BedType.lower,
              status: BedStatus.occupied),
          BedModel(
              roomId: 'sub', bedType: BedType.upper, status: BedStatus.vacant),
          BedModel(
              roomId: 'other',
              bedType: BedType.lower,
              status: BedStatus.occupied),
        ]));
  }
}

void main() {
  for (final size in [const Size(360, 800), const Size(1440, 1000)]) {
    testWidgets('Rooms list combines search and availability at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bloc = _Bloc();
      addTearDown(bloc.close);
      await tester.pumpWidget(MaterialApp(
          home: BlocProvider<ManagementBloc>.value(
              value: bloc, child: const RoomsScreen())));
      await tester.pumpAndSettle();
      expect(find.text('All (4)'), findsOneWidget);
      await tester.tap(find.text('Available (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Room 101 / Subroom A'), findsOneWidget);
      expect(find.text('Room 101'), findsNothing);
      expect(find.text('1 / 1 beds available'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Marina');
      await tester.pumpAndSettle();
      expect(find.text('No matching rooms'), findsOneWidget);
      await tester.ensureVisible(find.text('Full (1)'));
      await tester.tap(find.text('Full (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Room 201'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('Full (2)'), findsOneWidget);
      await tester.ensureVisible(find.text('No beds (1)'));
      await tester.tap(find.text('No beds (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Room 102'), findsOneWidget);
      expect(find.text('0 / 0 beds available'), findsOneWidget);
      await tester.tap(find.byTooltip('Add building, room or tenant'));
      await tester.pumpAndSettle();
      expect(find.text('Add Building'), findsOneWidget);
      expect(find.text('Add Rooms'), findsOneWidget);
      expect(find.text('Add Tenant'), findsOneWidget);
      await tester.tap(find.text('Add Building'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Building Name'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
