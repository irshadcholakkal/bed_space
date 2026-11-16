import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bed_space/data/models/room_model.dart';
import 'package:bed_space/presentation/blocs/management/management_bloc.dart';
import 'package:bed_space/presentation/screens/rooms_management_screen.dart';
import 'subrooms_test.dart' as fixture;

void main() {
  testWidgets('create a studio with one rental unit and one rent amount',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final parent = fixture.room('parent', '101');
    final repository = fixture.RoomRepository([parent]);
    final bloc = fixture.SeededManagementBloc(repository);
    addTearDown(bloc.close);
    await tester.pumpWidget(BlocProvider<ManagementBloc>.value(
        value: bloc,
        child: MaterialApp(
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () =>
                            RoomsManagementScreen.showAddRoomDialog(context,
                                parentRoom: parent),
                        child: const Text('Add')))))));
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(DropdownButtonFormField<RoomType>));
    await tester.tap(find.byType(DropdownButtonFormField<RoomType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Studio').last);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Lower Beds'), findsNothing);
    await tester.enterText(
        find.widgetWithText(TextField, 'Subroom Number / Name'), 'Garden');
    await tester
        .ensureVisible(find.widgetWithText(TextField, 'Monthly unit rent'));
    await tester.enterText(
        find.widgetWithText(TextField, 'Monthly unit rent'), '2200');
    await tester
        .ensureVisible(find.widgetWithText(ElevatedButton, 'Add Subroom'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add Subroom'));
    await tester.pumpAndSettle();
    expect(repository.addedRoom!.roomType, RoomType.studio);
    expect(repository.addedRoom!.totalCapacity, 1);
    expect(repository.addedRoom!.lowerBedRent, 2200);
    expect(repository.beds, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
