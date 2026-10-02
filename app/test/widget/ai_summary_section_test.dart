import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:susthiti/core/errors/failures.dart';
import 'package:susthiti/data/models/ai_summary.dart';
import 'package:susthiti/features/ai/ai_summary_section.dart';

import '../helpers.dart';

AISummary summary({bool stale = false}) => AISummary.fromJson({
      'id': 's1',
      'kind': 'individual_report',
      'content': {
        'report_information': 'Blood test',
        'summary': 'TEST ONLY summary text.',
        'key_findings': ['HbA1c recorded as 6.1%'],
        'disclaimer': 'SUSTHITI provides AI-assisted informational insights and does not replace professional medical diagnosis.',
      },
      'generated_at': '2026-09-24T08:00:00Z',
      'model': 'gemini-2.5-flash',
      'provider': 'google_ai_studio',
      'is_stale': stale,
    });

Widget section({required AsyncValue<AISummary?> value, required Future<AISummary> Function() onGenerate, VoidCallback? onGenerated}) => Scaffold(
      body: SingleChildScrollView(
        child: AiSummarySection(
          title: 'AI Report Summary',
          value: value,
          onGenerate: onGenerate,
          onGenerated: onGenerated ?? () {},
          loadingMessage: 'Reading your report...',
          emptyMessage: 'No summary yet.',
          failureReassurance: 'Your original report is still available.',
        ),
      ),
    );

void main() {
  testWidgets('empty state offers Generate and reports success', (tester) async {
    var generated = false;
    await pumpScreen(tester, user: testPatient, section(value: const AsyncData(null), onGenerate: () async => summary(), onGenerated: () => generated = true));
    expect(find.text('No summary yet.'), findsOneWidget);
    expect(find.text('AI-generated'), findsOneWidget);
    await tester.tap(find.text('Generate Summary'));
    await tester.pumpAndSettle();
    expect(generated, isTrue);
  });

  testWidgets('invalid AI output shows reassurance and Try Again', (tester) async {
    await pumpScreen(tester, user: testPatient, section(value: const AsyncData(null), onGenerate: () async => throw const AIServiceFailure('Bad output', code: 'ai_invalid_response')));
    await tester.tap(find.text('Generate Summary'));
    await tester.pumpAndSettle();
    expect(find.text("We couldn't generate the summary right now."), findsOneWidget);
    expect(find.text('Your original report is still available.'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
  });

  testWidgets('AI not configured does not offer a pointless retry', (tester) async {
    await pumpScreen(tester, user: testPatient, section(value: const AsyncData(null), onGenerate: () async => throw const AIServiceFailure('Not configured', code: 'ai_not_configured')));
    await tester.tap(find.text('Generate Summary'));
    await tester.pumpAndSettle();
    expect(find.text('AI features are not set up on this server yet.'), findsOneWidget);
    expect(find.text('Try Again'), findsNothing);
  });

  testWidgets('stored summary shows structured content, disclaimer, PDF and staleness', (tester) async {
    await pumpScreen(tester, user: testPatient, section(value: AsyncData(summary(stale: true)), onGenerate: () async => summary()));
    expect(find.textContaining('TEST ONLY summary text.'), findsOneWidget);
    expect(find.textContaining('New information has been added'), findsOneWidget);
    expect(find.text('Download PDF'), findsOneWidget);
    expect(find.text('Regenerate'), findsOneWidget);
    expect(find.textContaining('does not replace professional medical diagnosis'), findsOneWidget);
  });

  testWidgets('admins can read and download a summary but never generate one', (tester) async {
    await pumpScreen(tester, user: testAdmin, section(value: const AsyncData(null), onGenerate: () async => summary()));
    expect(find.text('Generate Summary'), findsNothing);
    expect(find.textContaining('Administrators can view AI summaries'), findsOneWidget);

    await pumpScreen(tester, user: testAdmin, section(value: AsyncData(summary()), onGenerate: () async => summary()));
    expect(find.text('Download PDF'), findsOneWidget);
    expect(find.text('Regenerate'), findsNothing);
  });
}
