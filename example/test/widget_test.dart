import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lazy_sticky_sections/lazy_sticky_sections.dart';
import 'package:lazy_sticky_sections_example/main.dart';

void main() {
  testWidgets('history pins the day header and shows it in the title', (
    tester,
  ) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pump();
    expect(find.text('History · 14 Oct 2026'), findsOneWidget);

    await tester.drag(
      find.byType(LazyStickySectionsView),
      const Offset(0, -3000),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('History · '), findsOneWidget);
    expect(find.text('History · 14 Oct 2026'), findsNothing);
  });

  testWidgets('contacts pin the letter below the app bar', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.tap(find.text('Contacts').last);
    await tester.pumpAndSettle();
    // Letter headers are the only single-letter texts with an explicit style;
    // the avatars use the default one.
    final letterHeaders = find.byWidgetPredicate(
      (widget) =>
          widget is Text && widget.data?.length == 1 && widget.style != null,
    );
    expect(letterHeaders, findsOneWidget);

    await tester.drag(find.text('Ada 2'), const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(find.text('Ada 1'), findsNothing);

    // Whichever letter is current sits just below the collapsed app bar
    // (64 pixels tall), inside its 8 pixels of padding.
    final appBarBottom = tester
        .getBottomLeft(
          find.descendant(
            of: find.byType(SliverAppBar),
            matching: find.byType(AppBar),
          ),
        )
        .dy;
    final tops = [
      for (final element in letterHeaders.evaluate())
        tester.getTopLeft(find.byWidget(element.widget)).dy,
    ];
    expect(tops, contains(appBarBottom + 8));
    expect(tester.takeException(), isNull);
  });
}
