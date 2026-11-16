import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bed_space/data/models/room_model.dart';
import 'package:bed_space/data/repositories/management_repository.dart';
import 'package:bed_space/presentation/blocs/management/management_bloc.dart';
import 'package:bed_space/presentation/widgets/room_edit_sheet.dart';

final room = RoomModel(
    roomId: 'room',
    buildingId: 'building',
    roomNumber: '101',
    totalCapacity: 2,
    lowerBedsCount: 1,
    upperBedsCount: 1,
    lowerBedRent: 700,
    upperBedRent: 600,
    utilityCostMonthly: 40,
    monthlyRent: 1500);

class _Repository extends Fake implements ManagementRepository {
  RoomModel? saved;
  bool fail = false;
  @override
  Future<void> updateRoom(RoomModel value) async {
    if (fail) throw StateError('Cannot reduce capacity: spaces are occupied.');
    saved = value;
  }
}

class _Bloc extends ManagementBloc {
  _Bloc(_Repository repository) : super(repository: repository) {
    emit(ManagementLoaded(rooms: [room]));
  }
}

void main() {
  for (final size in [const Size(360, 800), const Size(1200, 1000)]) {
    testWidgets(
        'edit room to a single studio and handle rejected capacity at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _Repository()..fail = true;
      final bloc = _Bloc(repository);
      addTearDown(bloc.close);
      await tester.pumpWidget(MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ManagementRepository>.value(value: repository),
          ],
          child: BlocProvider<ManagementBloc>.value(
              value: bloc,
              child: MaterialApp(
                  home: Builder(
                      builder: (context) => Scaffold(
                          body: TextButton(
                              onPressed: () => showRoomEditSheet(context, room),
                              child: const Text('Edit'))))))));
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<RoomType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Studio').last);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Lower beds'), findsNothing);
      expect(
          find.widgetWithText(TextFormField, 'Upper bed rent'), findsNothing);
      await tester.ensureVisible(
          find.widgetWithText(TextFormField, 'Monthly unit rent'));
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Monthly unit rent'), '2200');
      await tester.ensureVisible(find.text('Save changes'));
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.textContaining('spaces are occupied'), findsOneWidget);
      expect(repository.saved, isNull);
      repository.fail = false;
      await tester.ensureVisible(find.text('Save changes'));
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(repository.saved!.roomType, RoomType.studio);
      expect(repository.saved!.totalCapacity, 1);
      expect(repository.saved!.lowerBedsCount, 1);
      expect(repository.saved!.upperBedsCount, 0);
      expect(repository.saved!.lowerBedRent, 2200);
      expect(repository.saved!.monthlyRent, 1500);
      expect(find.text('Edit room, beds & rent'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
