import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:bed_space/data/models/building_model.dart';
import 'package:bed_space/data/models/expense_model.dart';
import 'package:bed_space/data/models/payment_model.dart';
import 'package:bed_space/data/models/property_financials.dart';
import 'package:bed_space/data/models/room_model.dart';
import 'package:bed_space/data/models/tenant_model.dart';
import 'package:bed_space/data/repositories/management_repository.dart';
import 'package:bed_space/presentation/blocs/management/management_bloc.dart';
import 'package:bed_space/presentation/screens/property_portfolio_screen.dart';

RoomModel space(String id, String number,
        {String building = 'b1', String? parent}) =>
    RoomModel.fromJson({
      'room_id': id,
      'room_number': number,
      'building_id': building,
      'parent_room_id': parent,
      'monthly_rent': 9999
    });
TenantModel tenant(String id, String room, {bool active = true}) =>
    TenantModel.fromJson({
      'tenant_id': id,
      'tenant_name': 'Tenant $id',
      'room_id': room,
      'building_id': room == 'other' ? 'b2' : 'b1',
      'active': active ? 'TRUE' : 'FALSE',
    });
final spaces = [
  space('parent', '101'),
  space('sub', 'A', parent: 'parent'),
  space('sibling', '102'),
  space('other', '201', building: 'b2')
];
final tenants = [
  tenant('t1', 'parent'),
  tenant('t2', 'sub', active: false),
  tenant('t3', 'sibling'),
  tenant('t4', 'other')
];
final payments = [
  for (final pair in [
    ('t1', 100.0),
    ('t2', 200.0),
    ('t3', 300.0),
    ('t4', 400.0)
  ])
    PaymentModel(
        tenantId: pair.$1,
        amount: pair.$2,
        paymentMonth: '2026-11',
        paidDate: DateTime(2026, 12, 1)),
  PaymentModel(
      tenantId: 't2',
      amount: 50,
      paymentMonth: '2026-10',
      paidDate: DateTime(2026, 11, 1)),
];
final expenses = [
  ExpenseModel(
      roomId: 'parent',
      expenseType: ExpenseType.rent,
      amount: 30,
      date: DateTime(2026, 11, 1)),
  ExpenseModel(
      roomId: 'sub',
      expenseType: ExpenseType.refund,
      amount: 20,
      date: DateTime(2026, 11, 2)),
  ExpenseModel(
      roomId: 'sibling',
      expenseType: ExpenseType.internet,
      amount: 10,
      date: DateTime(2026, 11, 3)),
  ExpenseModel(
      roomId: 'other',
      expenseType: ExpenseType.rent,
      amount: 40,
      date: DateTime(2026, 11, 4)),
  ExpenseModel(
      roomId: 'sub',
      expenseType: ExpenseType.cleaning,
      amount: 5,
      date: DateTime(2026, 10, 1)),
];
final buildings = [
  BuildingModel(
      buildingId: 'b1',
      buildingName: 'Palm Residence',
      address: '',
      totalRooms: 99),
  BuildingModel(
      buildingId: 'b2',
      buildingName: 'Marina House',
      address: '',
      totalRooms: 99)
];

class _Repository extends Fake implements ManagementRepository {}

class _Bloc extends ManagementBloc {
  _Bloc() : super(repository: _Repository()) {
    emit(ManagementLoaded(
        buildings: buildings,
        rooms: spaces,
        tenants: tenants,
        payments: payments,
        expenses: expenses));
  }
}

void main() {
  final report = PropertyFinancials(
      rooms: spaces,
      tenants: tenants,
      payments: payments,
      expenses: expenses,
      month: '2026-11');
  test('Building includes all rooms and subrooms exactly once', () {
    final totals = report.totals(report.roomIds(buildingId: 'b1'));
    expect(totals.income, 600);
    expect(totals.expenses, 60);
    expect(totals.net, 540);
  });
  test('Room includes its own activity plus subrooms, not sibling rooms', () {
    final totals = report.totals(report.roomIds(roomId: 'parent'));
    expect(totals.income, 300);
    expect(totals.expenses, 50);
    expect(totals.net, 250);
    final own =
        report.totals(report.roomIds(roomId: 'parent', includeSubrooms: false));
    expect(own.income, 100);
    expect(own.expenses, 30);
  });
  test(
      'Subroom isolates activity, retains checked out tenant payments and counts refunds once',
      () {
    final totals = report.totals(report.roomIds(roomId: 'sub'));
    expect(totals.income, 200);
    expect(totals.expenses, 20);
    expect(totals.net, 180);
  });
  test('All time includes other months and totals reconcile across buildings',
      () {
    final all = PropertyFinancials(
        rooms: spaces,
        tenants: tenants,
        payments: payments,
        expenses: expenses);
    final total = all.totals(all.roomIds());
    expect(total.income, 1050);
    expect(total.expenses, 105);
    expect(total.net, 945);
    expect(report.roomIds(roomId: 'missing'), isEmpty);
  });

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    for (final font in [
      ('Inter', 'Inter.ttf'),
      ('HedvigLetters', 'HedvigLettersSerif.ttf'),
      ('GeistMono', 'GeistMono.ttf')
    ]) {
      await (FontLoader(font.$1)
            ..addFont(rootBundle.load('assets/fonts/${font.$2}')))
          .load();
    }
  });
  for (final size in [const Size(360, 800), const Size(1440, 1100)]) {
    testWidgets(
        'Drill down building, room, subroom with responsive layout at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bloc = _Bloc();
      addTearDown(bloc.close);
      final router = GoRouter(initialLocation: '/rooms', routes: [
        GoRoute(
            path: '/rooms',
            builder: (_, state) => PropertyPortfolioScreen(
                period: state.uri.queryParameters['period'],
                buildingId: state.uri.queryParameters['building'],
                roomId: state.uri.queryParameters['room'])),
      ]);
      addTearDown(router.dispose);
      final capture = GlobalKey();
      await tester.pumpWidget(BlocProvider<ManagementBloc>.value(
          value: bloc,
          child: RepaintBoundary(
              key: capture,
              child: MaterialApp.router(
                  debugShowCheckedModeBanner: false, routerConfig: router))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All time').last);
      await tester.pumpAndSettle();
      if (const bool.fromEnvironment('CAPTURE_PORTFOLIO')) {
        await tester.runAsync(() async {
          final boundary = capture.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('build/portfolio_${size.width.toInt()}.png')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.scrollUntilVisible(find.text('Palm Residence'), 350,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Palm Residence'));
      await tester.pumpAndSettle();
      expect(find.text('Rooms in this building'), findsOneWidget);
      expect(find.text('Building details'), findsOneWidget);
      expect(find.text('Branch of Room 101 | This subroom only'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Room 101'), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Room 101'));
      await tester.pumpAndSettle();
      expect(find.text('Room breakdown'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Subroom A'), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subroom A'));
      await tester.pumpAndSettle();
      expect(find.text('Income and expenses for this subroom only.'),
          findsOneWidget);
      expect(find.text('Room breakdown'), findsNothing);
      expect(find.text('All time'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
