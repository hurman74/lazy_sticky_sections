import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lazy_sticky_sections/lazy_sticky_sections.dart';

// The test surface is 800x600. Headers are 40 pixels and items 50, so a
// section of 5 items is 290 pixels and section `s` starts at `290 * s`.
const double headerExtent = 40;
const double itemExtent = 50;
const double sectionExtent = headerExtent + 5 * itemExtent;

Widget header(int section, {Axis axis = Axis.vertical}) => SizedBox(
  height: axis == Axis.vertical ? headerExtent : null,
  width: axis == Axis.horizontal ? headerExtent : null,
  child: Text('Header $section'),
);

Widget pinned(int section, {Axis axis = Axis.vertical}) => SizedBox(
  height: axis == Axis.vertical ? headerExtent : null,
  width: axis == Axis.horizontal ? headerExtent : null,
  child: Text('Pinned $section'),
);

Widget item(int section, int index, {Axis axis = Axis.vertical}) => SizedBox(
  height: axis == Axis.vertical ? itemExtent : null,
  width: axis == Axis.horizontal ? itemExtent : null,
  child: Text('Item $section.$index'),
);

SliverLazyStickySections sections({
  int sectionCount = 10,
  int Function(int section)? itemCount,
  bool sticky = true,
  Axis axis = Axis.vertical,
  ValueChanged<int?>? onCurrentSectionChanged,
  SectionHeaderBuilder? pinnedHeaderBuilder,
}) {
  return SliverLazyStickySections(
    sectionCount: sectionCount,
    itemCount: itemCount ?? (_) => 5,
    sticky: sticky,
    onCurrentSectionChanged: onCurrentSectionChanged,
    headerBuilder: (context, section) => header(section, axis: axis),
    pinnedHeaderBuilder:
        pinnedHeaderBuilder ??
        (context, section) => pinned(section, axis: axis),
    itemBuilder: (context, section, index) => item(section, index, axis: axis),
  );
}

Widget scrollView({
  required List<Widget> slivers,
  ScrollController? controller,
  Axis axis = Axis.vertical,
  bool reverse = false,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: CustomScrollView(
      controller: controller,
      scrollDirection: axis,
      reverse: reverse,
      slivers: slivers,
    ),
  );
}

Future<void> jumpTo(
  WidgetTester tester,
  ScrollController controller,
  double offset,
) async {
  controller.jumpTo(offset);
  await tester.pump();
}

void main() {
  testWidgets('does not pin a header that is already at the top', (
    tester,
  ) async {
    await tester.pumpWidget(scrollView(slivers: [sections()]));

    expect(find.text('Header 0'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Header 0')).dy, 0);
    expect(find.textContaining('Pinned'), findsNothing);
  });

  testWidgets('pins the current section header to the top', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      scrollView(controller: controller, slivers: [sections()]),
    );

    await jumpTo(tester, controller, 100);
    expect(find.text('Pinned 0'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Pinned 0')).dy, 0);

    await jumpTo(tester, controller, sectionExtent * 3 + 120);
    expect(find.text('Pinned 0'), findsNothing);
    expect(find.text('Pinned 3'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Pinned 3')).dy, 0);
  });

  testWidgets('the next header pushes the pinned header away', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      scrollView(controller: controller, slivers: [sections()]),
    );

    // Header 1 is 20 pixels below the top, so it overlaps the pinned
    // header 0 by 20 pixels and pushes it up by that much.
    await jumpTo(tester, controller, sectionExtent - 20);
    expect(tester.getTopLeft(find.text('Header 1')).dy, 20);
    expect(tester.getTopLeft(find.text('Pinned 0')).dy, -20);

    // Further away, header 0 sits at the top again.
    await jumpTo(tester, controller, sectionExtent - 60);
    expect(tester.getTopLeft(find.text('Pinned 0')).dy, 0);

    // Once header 1 reaches the top, it takes over.
    await jumpTo(tester, controller, sectionExtent);
    expect(find.textContaining('Pinned'), findsNothing);
    expect(tester.getTopLeft(find.text('Header 1')).dy, 0);
  });

  testWidgets('the end of the sliver pushes the last header away', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      scrollView(
        controller: controller,
        slivers: [
          sections(),
          const SliverToBoxAdapter(child: SizedBox(height: 1000)),
        ],
      ),
    );

    await jumpTo(tester, controller, sectionExtent * 10 - 20);
    expect(tester.getTopLeft(find.text('Pinned 9')).dy, -20);

    await jumpTo(tester, controller, sectionExtent * 10 + 10);
    expect(find.textContaining('Pinned'), findsNothing);
  });

  testWidgets('pins below a pinned sliver before it', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      scrollView(
        controller: controller,
        slivers: [
          const PinnedHeaderSliver(child: SizedBox(height: 60)),
          sections(),
        ],
      ),
    );

    await jumpTo(tester, controller, 100);
    expect(tester.getTopLeft(find.text('Pinned 0')).dy, 60);

    // Header 1 is 20 pixels below the pinned sliver.
    await jumpTo(tester, controller, sectionExtent - 20);
    expect(tester.getTopLeft(find.text('Header 1')).dy, 80);
    expect(tester.getTopLeft(find.text('Pinned 0')).dy, 40);
  });

  testWidgets('pins only once the sliver reaches the top', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      scrollView(
        controller: controller,
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 200)),
          sections(),
        ],
      ),
    );

    await jumpTo(tester, controller, 150);
    expect(tester.getTopLeft(find.text('Header 0')).dy, 50);
    expect(find.textContaining('Pinned'), findsNothing);

    await jumpTo(tester, controller, 250);
    expect(tester.getTopLeft(find.text('Pinned 0')).dy, 0);
  });

  testWidgets('sticky: false lets headers scroll away', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      scrollView(controller: controller, slivers: [sections(sticky: false)]),
    );

    await jumpTo(tester, controller, 100);
    expect(find.textContaining('Pinned'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Header 0', skipOffstage: false)).dy,
      -100,
    );
  });

  testWidgets('builds only the visible headers and items', (tester) async {
    final builtHeaders = <int>{};
    final builtItems = <int>{};
    await tester.pumpWidget(
      scrollView(
        slivers: [
          SliverLazyStickySections(
            sectionCount: 100000,
            itemCount: (_) => 1000,
            headerBuilder: (context, section) {
              builtHeaders.add(section);
              return header(section);
            },
            itemBuilder: (context, section, index) {
              builtItems.add(section);
              return item(section, index);
            },
          ),
        ],
      ),
    );

    expect(builtHeaders, {0});
    expect(builtItems, {0});
    expect(find.text('Item 0.0'), findsOneWidget);
    expect(find.text('Item 0.30'), findsNothing);
  });

  testWidgets('works with many short sections', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final built = <int>{};
    await tester.pumpWidget(
      scrollView(
        controller: controller,
        slivers: [
          SliverLazyStickySections(
            sectionCount: 2000,
            itemCount: (section) => section % 3,
            headerBuilder: (context, section) {
              built.add(section);
              return header(section);
            },
            pinnedHeaderBuilder: (context, section) => pinned(section),
            itemBuilder: (context, section, index) => item(section, index),
          ),
        ],
      ),
    );

    // Sections 0, 1 and 2 take 40, 90 and 140 pixels, 270 in total.
    await jumpTo(tester, controller, 270 * 3 + 50);
    expect(find.text('Pinned 10'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Pinned 10')).dy, 0);
    expect(built.length, lessThan(40));
  });

  testWidgets('a section with no items still has its header', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      scrollView(
        controller: controller,
        slivers: [sections(itemCount: (section) => section == 1 ? 0 : 5)],
      ),
    );

    expect(find.text('Header 1'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Header 1')).dy, sectionExtent);
    expect(tester.getTopLeft(find.text('Header 2')).dy, sectionExtent + 40);

    // Header 1 is half scrolled away, and header 2 pushes the pinned copy
    // so that it never covers header 2.
    await jumpTo(tester, controller, sectionExtent + 20);
    expect(tester.getTopLeft(find.text('Pinned 1')).dy, -20);
    expect(tester.getTopLeft(find.text('Header 2')).dy, 20);
  });

  testWidgets('a pinned header taller than its section stays with it', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      scrollView(
        controller: controller,
        slivers: [
          sections(
            itemCount: (section) => section == 1 ? 0 : 5,
            pinnedHeaderBuilder: (context, section) =>
                SizedBox(height: 100, child: Text('Pinned $section')),
          ),
        ],
      ),
    );

    await jumpTo(tester, controller, sectionExtent + 20);
    expect(tester.getTopLeft(find.text('Pinned 1')).dy, -20);
  });

  testWidgets('handles zero sections', (tester) async {
    await tester.pumpWidget(scrollView(slivers: [sections(sectionCount: 0)]));
    expect(find.byType(Text), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pins to the left in a horizontal list', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      scrollView(
        controller: controller,
        axis: Axis.horizontal,
        slivers: [sections(axis: Axis.horizontal)],
      ),
    );

    await jumpTo(tester, controller, 100);
    expect(tester.getTopLeft(find.text('Pinned 0')).dx, 0);

    await jumpTo(tester, controller, sectionExtent - 10);
    expect(tester.getTopLeft(find.text('Header 1')).dx, 10);
    expect(tester.getTopLeft(find.text('Pinned 0')).dx, -30);
  });

  testWidgets('pins to the bottom in a reversed list', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      scrollView(controller: controller, reverse: true, slivers: [sections()]),
    );

    await jumpTo(tester, controller, 100);
    final pinnedBox = find.ancestor(
      of: find.text('Pinned 0'),
      matching: find.byType(SizedBox),
    );
    expect(tester.getBottomLeft(pinnedBox).dy, 600);

    // Header 1 is 20 pixels above the bottom edge.
    await jumpTo(tester, controller, sectionExtent - 20);
    final header1 = find.ancestor(
      of: find.text('Header 1'),
      matching: find.byType(SizedBox),
    );
    expect(tester.getBottomLeft(header1).dy, 580);
    expect(tester.getBottomLeft(pinnedBox).dy, 620);
  });

  testWidgets('taps reach the pinned header, not what is under it', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final taps = <String>[];
    await tester.pumpWidget(
      scrollView(
        controller: controller,
        slivers: [
          SliverLazyStickySections(
            sectionCount: 3,
            itemCount: (_) => 5,
            headerBuilder: (context, section) => header(section),
            pinnedHeaderBuilder: (context, section) => GestureDetector(
              onTap: () => taps.add('pinned $section'),
              child: pinned(section),
            ),
            itemBuilder: (context, section, index) => GestureDetector(
              onTap: () => taps.add('item $section.$index'),
              child: item(section, index),
            ),
          ),
        ],
      ),
    );

    // Item 0.1 spans 90..140, so at offset 100 it is under the pinned header.
    await jumpTo(tester, controller, 100);
    await tester.tapAt(const Offset(10, 10));
    expect(taps, ['pinned 0']);

    // Item 0.3 spans 190..240, so it is 90..140 on screen.
    await tester.tapAt(const Offset(10, 100));
    expect(taps, ['pinned 0', 'item 0.3']);
  });

  testWidgets('reports the current section after layout', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final reported = <int?>[];
    await tester.pumpWidget(
      scrollView(
        controller: controller,
        slivers: [
          sections(onCurrentSectionChanged: reported.add),
          const SliverToBoxAdapter(child: SizedBox(height: 1000)),
        ],
      ),
    );
    expect(reported, [0]);

    await jumpTo(tester, controller, 100);
    expect(reported, [0]);

    await jumpTo(tester, controller, sectionExtent * 2);
    expect(reported, [0, 2]);

    await jumpTo(tester, controller, sectionExtent * 10 + 100);
    expect(reported, [0, 2, null]);
  });

  testWidgets('the current section callback may call setState', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    int? current;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              SizedBox(height: 20, child: Text('Current $current')),
              Expanded(
                child: CustomScrollView(
                  controller: controller,
                  slivers: [
                    sections(
                      onCurrentSectionChanged: (section) =>
                          setState(() => current = section),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Current 0'), findsOneWidget);

    await jumpTo(tester, controller, sectionExtent * 4 + 10);
    await tester.pump();
    expect(find.text('Current 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rebuilds the pinned header when the widget changes', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    Widget build(String label) => scrollView(
      controller: controller,
      slivers: [
        sections(
          pinnedHeaderBuilder: (context, section) =>
              SizedBox(height: 40, child: Text('$label $section')),
        ),
      ],
    );

    await tester.pumpWidget(build('First'));
    await jumpTo(tester, controller, 100);
    expect(find.text('First 0'), findsOneWidget);

    await tester.pumpWidget(build('Second'));
    expect(find.text('First 0'), findsNothing);
    expect(find.text('Second 0'), findsOneWidget);
  });

  testWidgets('follows changes to the section counts', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      scrollView(controller: controller, slivers: [sections(sectionCount: 2)]),
    );
    await jumpTo(tester, controller, 100);
    expect(find.text('Pinned 0'), findsOneWidget);

    // Section 0 now has 10 items, so offset 100 is still in it, and 400 is
    // too.
    await tester.pumpWidget(
      scrollView(
        controller: controller,
        slivers: [sections(sectionCount: 2, itemCount: (s) => s == 0 ? 10 : 5)],
      ),
    );
    await jumpTo(tester, controller, 400);
    expect(find.text('Pinned 0'), findsOneWidget);
    expect(find.text('Item 0.7'), findsOneWidget);
  });

  testWidgets('pinned headers inherit from the context', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      DefaultTextStyle(
        style: const TextStyle(fontSize: 13),
        child: scrollView(
          controller: controller,
          slivers: [
            sections(
              pinnedHeaderBuilder: (context, section) => SizedBox(
                height: 40,
                child: Text(
                  'Size ${DefaultTextStyle.of(context).style.fontSize}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await jumpTo(tester, controller, 100);
    expect(find.text('Size 13.0'), findsOneWidget);
  });

  testWidgets('the pinned header is hidden from semantics', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      scrollView(controller: controller, slivers: [sections()]),
    );
    await jumpTo(tester, controller, 100);

    expect(find.text('Pinned 0'), findsOneWidget);
    expect(find.bySemanticsLabel('Pinned 0'), findsNothing);
    expect(find.bySemanticsLabel('Item 0.2'), findsOneWidget);
    handle.dispose();
  });

  group('LazyStickySectionsView', () {
    testWidgets('scrolls and pins', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LazyStickySectionsView(
            controller: controller,
            sectionCount: 5,
            itemCount: (_) => 5,
            headerBuilder: (context, section) => header(section),
            pinnedHeaderBuilder: (context, section) => pinned(section),
            itemBuilder: (context, section, index) => item(section, index),
          ),
        ),
      );

      expect(tester.getTopLeft(find.text('Header 0')).dy, 0);
      await jumpTo(tester, controller, sectionExtent + 30);
      expect(tester.getTopLeft(find.text('Pinned 1')).dy, 0);
    });

    testWidgets('pins inside the padding', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LazyStickySectionsView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            sectionCount: 5,
            itemCount: (_) => 5,
            headerBuilder: (context, section) => header(section),
            pinnedHeaderBuilder: (context, section) => pinned(section),
            itemBuilder: (context, section, index) => item(section, index),
          ),
        ),
      );

      expect(tester.getTopLeft(find.text('Header 0')), const Offset(16, 24));
      await jumpTo(tester, controller, 24 + 100);
      expect(tester.getTopLeft(find.text('Pinned 0')), const Offset(16, 0));
    });
  });
}
