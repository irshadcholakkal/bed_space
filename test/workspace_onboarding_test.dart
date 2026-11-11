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
  Future<String?> signInSilently() async => 'token';
  @override
  Future<String?> getCurrentUserEmail() async => 'owner@example.com';
}

class _Repository extends SheetRepository {
  @override
  Future<String?> getSheetId() async => null;
  @override
  Future<bool> isSheetIdForUser(String email) async => false;
  @override
  Future<void> saveToken(String token) async {}
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
      final auth =
          AuthBloc(authService: _Google(), sheetRepository: repository);
      final sheet = SheetBloc(sheetRepository: repository);
      addTearDown(auth.close);
      addTearDown(sheet.close);
      final ready =
          auth.stream.firstWhere((s) => s is AuthAuthenticatedWithoutSheet);
      auth.add(const AuthCheckRequested());
      await ready;
      await tester.pumpWidget(MaterialApp(
          home: MultiBlocProvider(providers: [
        BlocProvider.value(value: auth),
        BlocProvider.value(value: sheet),
      ], child: const LoginScreen())));
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
      expect(tester.takeException(), isNull);
    });
  }
}
