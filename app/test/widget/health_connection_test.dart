import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:susthiti/core/constants/app_assets.dart';
import 'package:susthiti/core/theme/app_theme.dart';
import 'package:susthiti/data/datasources/health_platform.dart';
import 'package:susthiti/data/models/health.dart';
import 'package:susthiti/data/models/tracking.dart';
import 'package:susthiti/data/providers.dart';
import 'package:susthiti/features/authentication/splash_screen.dart';
import 'package:susthiti/features/lifestyle/lifestyle_screen.dart';
import 'package:susthiti/features/lifestyle/trend_card.dart';
import 'package:susthiti/features/wearables/health_connect_screen.dart';
import 'package:susthiti/features/wearables/health_connection.dart';

import '../helpers.dart';
import '../unit/health_test.dart' show FakeHealthPlatform, MockWearableRepository, connection;

void main() {
  setUpAll(() => registerFallbackValue(<String>[]));

  late MockWearableRepository repo;
  setUp(() {
    repo = MockWearableRepository();
    when(() => repo.connect(any(), grantedMetrics: any(named: 'grantedMetrics'), platform: any(named: 'platform'))).thenAnswer((_) async => connection());
    when(() => repo.sync(any(), samples: any(named: 'samples'), grantedMetrics: any(named: 'grantedMetrics')))
        .thenAnswer((_) async => SyncOutcome(device: connection(lastSynced: DateTime.now()), imported: 12));
    when(() => repo.devices()).thenAnswer((_) async => const []);
  });

  Future<void> pumpConnect(WidgetTester tester, HealthPlatform platform) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(initialLocation: '/start', routes: [
      GoRoute(path: '/start', builder: (context, _) => Scaffold(body: TextButton(onPressed: () => context.push('/connect'), child: const Text('open')))),
      GoRoute(path: '/connect', builder: (_, _) => const HealthConnectScreen()),
    ]);
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [healthPlatformProvider.overrideWithValue(platform), wearableRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('explains the data first and asks for permission only after Continue', (tester) async {
    final platform = FakeHealthPlatform();
    await pumpConnect(tester, platform);
    expect(find.textContaining('to show your lifestyle trends'), findsOneWidget);
    expect(find.text('Blood pressure where supported'), findsOneWidget);
    expect(platform.requested, isEmpty); // nothing requested silently

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(platform.requested, hasLength(1));
    expect(find.text('Health Data Connected'), findsOneWidget);
    expect(find.text('Just now'), findsOneWidget);
    expect(find.text('View Lifestyle Dashboard'), findsOneWidget);
  });

  testWidgets('a refusal is explained once and not asked again automatically', (tester) async {
    final platform = FakeHealthPlatform(grant: {});
    await pumpConnect(tester, platform);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text("Health data access wasn't enabled."), findsOneWidget);
    expect(find.textContaining('enable it later from Connected Devices'), findsOneWidget);
    expect(platform.requested, hasLength(1));
    verifyNever(() => repo.connect(any(), grantedMetrics: any(named: 'grantedMetrics'), platform: any(named: 'platform')));
  });

  testWidgets('web shows synced data read-only and never offers to pair a watch', (tester) async {
    await pumpScreen(
      tester,
      Scaffold(body: HealthConnectionCard(devices: [connection(lastSynced: DateTime.now().subtract(const Duration(hours: 1)))], onChanged: () {})),
      user: testPatient,
      overrides: [healthPlatformProvider.overrideWithValue(const UnsupportedHealthPlatform()), wearableRepositoryProvider.overrideWithValue(repo)],
    );
    expect(find.text('Health data'), findsOneWidget);
    expect(find.textContaining('Connected through Health Connect on Android'), findsOneWidget);
    expect(find.textContaining('Last synced'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
    expect(find.text('Connect'), findsNothing);
    expect(find.text('Sync Now'), findsNothing);
  });

  testWidgets('on a phone the card offers Connect, then Sync Now once connected', (tester) async {
    final platform = FakeHealthPlatform();
    await pumpScreen(tester, Scaffold(body: HealthConnectionCard(devices: const [], onChanged: () {})), user: testPatient,
        overrides: [healthPlatformProvider.overrideWithValue(platform), wearableRepositoryProvider.overrideWithValue(repo)]);
    expect(find.text('Connect your health data'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);

    await pumpScreen(tester, Scaffold(body: HealthConnectionCard(devices: [connection(lastSynced: DateTime.now())], onChanged: () {})), user: testPatient,
        overrides: [healthPlatformProvider.overrideWithValue(platform), wearableRepositoryProvider.overrideWithValue(repo)]);
    expect(find.text('Health data connected'), findsOneWidget);
    await tester.tap(find.text('Sync Now'));
    await tester.pumpAndSettle();
    expect(find.text('Synced just now'), findsWidgets);
    expect(HealthMetric.values, isNotEmpty);
  });

  testWidgets('missing blood pressure is blamed on the device only when one is connected', (tester) async {
    Future<void> pumpOverview(List<WearableConnection> devices) => pumpScreen(
          tester,
          const Scaffold(body: LifestyleView(patientId: 'pat1')),
          user: testDoctor,
          overrides: [
            lifestyleOverviewProvider('pat1').overrideWith((ref) async => LifestyleOverview(metrics: const {}, glucose: const GlucoseOverview(), foodEntriesToday: 0, devices: devices)),
            trendProvider.overrideWith((ref, key) async => const TrendSeries(metric: 'steps', unit: 'steps', points: [])),
          ],
        );

    await pumpOverview(const []);
    expect(find.text('Not available from connected device'), findsNothing);
    expect(find.text('Not recorded yet'), findsNWidgets(6)); // never a placeholder value

    await tester.pumpWidget(const SizedBox()); // a fresh ProviderScope for the new overrides
    await pumpOverview([connection(lastSynced: DateTime.now())]);
    expect(find.text('Not available from connected device'), findsNWidgets(2)); // blood pressure, SpO2
  });

  testWidgets('splash shows the official logo, then opens the gate', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp(theme: AppTheme.light(), home: const SplashScreen())));
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, AppAssets.logoTransparent);
    expect(container.read(splashGateProvider), isFalse);
    await tester.pump(SplashScreen.animation + const Duration(milliseconds: 50));
    expect(container.read(splashGateProvider), isFalse); // the logo is held briefly once fully shown
    await tester.pump(SplashScreen.hold + const Duration(milliseconds: 50));
    expect(container.read(splashGateProvider), isTrue);
    expect(SplashScreen.logoWidth(const Size(390, 844)), closeTo(265, 1)); // phone ~68%
    expect(SplashScreen.logoWidth(const Size(1440, 900)), inInclusiveRange(280, 420)); // desktop
  });
}
