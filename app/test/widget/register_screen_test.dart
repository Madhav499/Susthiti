import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:susthiti/core/errors/failures.dart';
import 'package:susthiti/core/services/api_client.dart';
import 'package:susthiti/core/services/token_storage.dart';
import 'package:susthiti/core/widgets/feedback.dart';
import 'package:susthiti/core/widgets/form_fields.dart';
import 'package:susthiti/data/models/user.dart';
import 'package:susthiti/data/providers.dart';
import 'package:susthiti/data/repositories/auth_repository.dart';
import 'package:susthiti/features/authentication/auth_controller.dart';
import 'package:susthiti/features/authentication/auth_layout.dart';
import 'package:susthiti/features/authentication/register_screen.dart';

import '../helpers.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  setUpAll(() => registerFallbackValue(DateTime(2000)));

  late MockAuthRepository repo;
  setUp(() {
    repo = MockAuthRepository();
    when(() => repo.restore()).thenAnswer((_) async => null);
  });

  Future<void> pump(WidgetTester tester) => pumpScreen(tester, const RegisterScreen(), overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        apiClientProvider.overrideWithValue(ApiClient(tokenStorage: MemoryTokenStorage())),
      ]);

  Future<void> fillForm(WidgetTester tester) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Asha Patel');
    await tester.enterText(fields.at(1), 'asha@example.org');
    await tester.enterText(fields.at(2), '9876543210');
    await tester.enterText(fields.at(3), 'Password1');
    await tester.tap(find.descendant(of: find.byType(DateTimeField), matching: find.byType(InkWell)).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Male'));
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
  }

  // The button itself: while a request runs it shows a spinner instead of its label.
  Future<void> tapCreate(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(BusyButton));
    await tester.tap(find.byType(BusyButton));
  }

  testWidgets('an unreachable server keeps the form, says so, and sends one request per tap', (tester) async {
    final pending = Completer<AuthSession>();
    when(() => repo.register(fullName: any(named: 'fullName'), email: any(named: 'email'), password: any(named: 'password'),
        dateOfBirth: any(named: 'dateOfBirth'), gender: any(named: 'gender'), phone: any(named: 'phone'))).thenAnswer((_) => pending.future);
    await pump(tester);
    await fillForm(tester);

    await tapCreate(tester);
    await tester.pump();
    expect(find.text('Create account'), findsNothing); // busy: spinner shown
    await tapCreate(tester); // a second tap while the first is still running
    await tester.pump();
    verify(() => repo.register(fullName: 'Asha Patel', email: 'asha@example.org', password: 'Password1',
        dateOfBirth: any(named: 'dateOfBirth'), gender: 'Male', phone: '9876543210')).called(1);

    pending.completeError(const NetworkFailure("Can't reach SUSTHITI's server. Please check your connection and try again."));
    await tester.pumpAndSettle();
    expect(find.textContaining("Can't reach SUSTHITI's server"), findsOneWidget);
    expect(find.text('Asha Patel'), findsOneWidget); // nothing to retype
    expect(find.text('asha@example.org'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget); // the button is usable again
  });

  testWidgets('a confirmed response signs the new patient in', (tester) async {
    when(() => repo.register(fullName: any(named: 'fullName'), email: any(named: 'email'), password: any(named: 'password'),
            dateOfBirth: any(named: 'dateOfBirth'), gender: any(named: 'gender'), phone: any(named: 'phone')))
        .thenAnswer((_) async => const AuthSession(token: 't', user: testPatient));
    await pump(tester);
    await fillForm(tester);
    await tapCreate(tester);
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(RegisterScreen)));
    expect(container.read(authControllerProvider).value?.role, UserRole.patient);
  });

  testWidgets('development builds show the server and can test it', (tester) async {
    Future<String?> unreachable() async => 'No answer. Is this device on the same Wi-Fi as the PC?';
    await pumpScreen(tester, Scaffold(body: DevServerCheck(check: unreachable)));
    expect(find.textContaining('Development server:'), findsOneWidget);
    await tester.tap(find.text('Test connection'));
    await tester.pumpAndSettle();
    expect(find.textContaining('same Wi-Fi as the PC'), findsOneWidget);

    Future<String?> reachable() async => null;
    await tester.pumpWidget(const SizedBox());
    await pumpScreen(tester, Scaffold(body: DevServerCheck(check: reachable)));
    await tester.tap(find.text('Test connection'));
    await tester.pumpAndSettle();
    expect(find.text('Reachable'), findsOneWidget);
  });
}
