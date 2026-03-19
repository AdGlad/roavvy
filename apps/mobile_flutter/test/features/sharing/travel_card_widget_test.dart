import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/sharing/travel_card_widget.dart';
import 'package:shared_models/shared_models.dart';

TravelSummary _summary({
  List<String> codes = const [],
  DateTime? earliest,
  DateTime? latest,
  int achievementCount = 0,
}) {
  return TravelSummary(
    visitedCodes: codes,
    computedAt: DateTime.utc(2024),
    earliestVisit: earliest,
    latestVisit: latest,
    achievementCount: achievementCount,
  );
}

Widget _pump(TravelSummary summary) {
  return MaterialApp(
    home: Scaffold(
      body: TravelCardWidget(summary),
    ),
  );
}

void main() {
  testWidgets('renders country count', (tester) async {
    await tester.pumpWidget(_pump(_summary(codes: ['GB', 'FR', 'DE'])));

    expect(find.text('3'), findsOneWidget);
    expect(find.text('countries visited'), findsOneWidget);
  });

  testWidgets('renders year range when dates are present', (tester) async {
    await tester.pumpWidget(
      _pump(
        _summary(
          codes: ['GB'],
          earliest: DateTime.utc(2018),
          latest: DateTime.utc(2024),
        ),
      ),
    );

    expect(find.text('2018 – 2024'), findsOneWidget);
  });

  testWidgets('renders single year when earliest and latest are the same year',
      (tester) async {
    await tester.pumpWidget(
      _pump(
        _summary(
          codes: ['GB'],
          earliest: DateTime.utc(2024, 3),
          latest: DateTime.utc(2024, 11),
        ),
      ),
    );

    expect(find.text('2024'), findsOneWidget);
  });

  testWidgets('renders em-dash when no dates', (tester) async {
    await tester.pumpWidget(_pump(_summary(codes: ['GB'])));

    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('renders achievement count of zero', (tester) async {
    await tester.pumpWidget(_pump(_summary()));

    expect(find.text('🏆 0'), findsOneWidget);
  });

  testWidgets('renders non-zero achievement count', (tester) async {
    await tester.pumpWidget(_pump(_summary(achievementCount: 5)));

    expect(find.text('🏆 5'), findsOneWidget);
  });

  testWidgets('renders Roavvy brand label', (tester) async {
    await tester.pumpWidget(_pump(_summary()));

    expect(find.text('Roavvy'), findsOneWidget);
  });
}
