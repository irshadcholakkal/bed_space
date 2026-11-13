import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bed_space/data/services/google_auth_service.dart';
import 'package:bed_space/data/repositories/sheet_repository.dart';
import 'package:bed_space/presentation/blocs/auth/auth_bloc.dart';
import 'package:bed_space/presentation/blocs/sheet/sheet_bloc.dart';
import 'package:bed_space/presentation/screens/login_screen.dart';

class _Google extends GoogleAuthService {
  @override
  String? get accountUserId => 'customer';
  @override
  Future<String?> signInSilently() async => 'token';
  @override
  Future<String?> getCurrentUserEmail() async => 'owner@example.com';
}

class _Repository extends SheetRepository {
  String? createdSheetId;
  @override
  Future<String?> getUserEmail() async => null;
  @override
  Future<String?> getCachedSheetId() async => null;
  @override
  Future<String?> getSheetId() async => createdSheetId;
  @override
  Future<bool> isSheetIdForUser(String email) async => createdSheetId != null;
  @override
  Future<void> saveToken(String token) async {}
}

class _SheetCreation extends SheetBloc {
  _SheetCreation(SheetRepository repository)
      : super(sheetRepository: repository);
  final requests = <SheetCreateRequested>[];
  @override
  void add(SheetEvent event) {
    if (event is SheetCreateRequested) requests.add(event);
  }

  void fail() => emit(const SheetError('Drive unavailable. Retry.'));
  void succeed() => emit(const SheetCreated(sheetId: 'created-sheet'));
}

void main() {
  for (final size in [const Size(360, 800), const Size(1440, 900)]) {
    testWidgets('Business setup requires details before creation at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _Repository();
      final google = _Google();
      final auth = AuthBloc(authService: google, sheetRepository: repository);
      final sheet = _SheetCreation(repository);
      addTearDown(auth.close);
      addTearDown(sheet.close);
      final ready =
          auth.stream.firstWhere((s) => s is AuthAuthenticatedWithoutSheet);
      auth.add(const AuthCheckRequested());
      await ready;
      expect(
          (auth.state as AuthAuthenticatedWithoutSheet).accessToken, isEmpty);
      await tester.pumpWidget(MaterialApp(
          home: MultiBlocProvider(providers: [
        BlocProvider.value(value: auth),
        BlocProvider<SheetBloc>.value(value: sheet),
      ], child: LoginScreen(googleAuthService: google))));
      await tester.pumpAndSettle();
      expect(sheet.state, isA<SheetInitial>());
      await tester.ensureVisible(find.text('Create my workspace'));
      await tester.tap(find.text('Create my workspace'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your business name'), findsOneWidget);
      expect(find.text('Enter a valid phone number with country code'),
          findsOneWidget);
      expect(sheet.state, isA<SheetInitial>());
      await tester.enterText(find.byType(TextFormField).at(0), 'Palm Living');
      await tester.enterText(
          find.byType(TextFormField).at(1), '+971 50 123 4567');
      expect(tester.state<FormState>(find.byType(Form)).validate(), isTrue);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create my workspace'));
      await tester.tap(find.text('Create my workspace'));
      await tester.pump();
      expect(sheet.requests, hasLength(1));
      expect(sheet.requests.single.businessName, 'Palm Living');
      expect(sheet.requests.single.userEmail, 'owner@example.com');
      expect(sheet.requests.single.accessToken, 'token');
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      sheet.fail();
      await tester.pumpAndSettle();
      expect(find.text('Drive unavailable. Retry.'), findsOneWidget);
      expect(find.text('Palm Living'), findsOneWidget);
      await tester.ensureVisible(find.text('Create my workspace'));
      await tester.tap(find.text('Create my workspace'));
      await tester.pump();
      expect(sheet.requests, hasLength(2));
      repository.createdSheetId = 'created-sheet';
      sheet.succeed();
      await tester.pumpAndSettle();
      expect(auth.state, isA<AuthAuthenticated>());
      expect((auth.state as AuthAuthenticated).sheetId, 'created-sheet');
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
