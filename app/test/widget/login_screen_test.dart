import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:susthiti/core/errors/failures.dart';
import 'package:susthiti/core/services/api_client.dart';
import 'package:susthiti/core/services/token_storage.dart';
import 'package:susthiti/data/providers.dart';
import 'package:susthiti/data/repositories/auth_repository.dart';
import 'package:susthiti/features/authentication/login_screen.dart';

import '../helpers.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repo;
  setUp(() {
    repo = MockAuthRepository();
    when(() => repo.restore()).thenAnswer((_) async => null);
  });

  Future<void> pump(WidgetTester tester) => pumpScreen(tester, const LoginScreen(), overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        apiClientProvider.overrideWithValue(ApiClient(tokenStorage: MemoryTokenStorage())),
      ]);

  testWidgets('validates before calling the server', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Password is required.'), findsOneWidget);
    verifyNever(() => repo.login(any(), any()));
  });

  testWidgets('shows the server message on failed sign-in', (tester) async {
    when(() => repo.login(any(), any())).thenThrow(const AuthenticationFailure('Incorrect email or password.'));
    await pump(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'demo.patient@susthiti.test');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong-password1');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Incorrect email or password.'), findsOneWidget);
  });

  testWidgets('offers patient self-registration only', (tester) async {
    await pump(tester);
    expect(find.text('Create a patient account'), findsOneWidget);
    expect(find.textContaining('Doctor accounts are created by your SUSTHITI administrator'), findsOneWidget);
  });
}
