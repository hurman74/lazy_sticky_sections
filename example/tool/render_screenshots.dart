// Renders the README images into ../doc/. Run from the example directory:
//
//   flutter test tool/render_screenshots.dart
//
// It uses the real Roboto and Material Icons fonts from the Flutter SDK so the
// images look like the app on a device. The widget counts in comparison.png
// are measured from the widget trees, not typed in.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lazy_sticky_sections/lazy_sticky_sections.dart';
import 'package:lazy_sticky_sections_example/main.dart';

const double _pixelRatio = 2;
final Directory _docDir = Directory('../doc');

Future<void> _loadFonts() async {
  final String flutterRoot = Platform.environment['FLUTTER_ROOT']!;
  final String fonts = '$flutterRoot/bin/cache/artifacts/material_fonts';
  Future<ByteData> read(String name) async =>
      ByteData.sublistView(File('$fonts/$name').readAsBytesSync());
  await (FontLoader('Roboto')
        ..addFont(read('Roboto-Regular.ttf'))
        ..addFont(read('Roboto-Medium.ttf')))
      .load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(read('MaterialIcons-Regular.otf'))).load();
}

final ThemeData _theme = ThemeData(
  colorSchemeSeed: Colors.indigo,
  fontFamily: 'Roboto',
);

const List<String> _months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _dayLabel(int section) {
  final DateTime day = DateTime(2026, 10, 14).subtract(Duration(days: section));
  return '${day.day} ${_months[day.month - 1]} ${day.year}';
}

/// A phone-sized screen with rounded corners around [child].
Widget _phone(Widget child, {double width = 360, double height = 640}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFDADCE0), width: 2),
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(18), child: child),
  );
}

Widget _caption(String text, {String? detail, Color? detailColor}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      children: <Widget>[
        Text(
          text,
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (detail != null)
          Text(
            detail,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              height: 1.4,
              color: detailColor ?? const Color(0xFF5F6368),
            ),
          ),
      ],
    ),
  );
}

/// Pumps [scene] on a white canvas of [size] and returns it as a PNG.
Future<Uint8List> _render(WidgetTester tester, Size size, Widget scene) async {
  final GlobalKey boundary = GlobalKey();
  tester.view.physicalSize = size * _pixelRatio;
  tester.view.devicePixelRatio = _pixelRatio;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _theme,
      home: RepaintBoundary(
        key: boundary,
        child: Material(
          color: Colors.white,
          child: Center(child: scene),
        ),
      ),
    ),
  );
  // Let post-frame callbacks (onCurrentSectionChanged) rebuild once.
  await tester.pump();
  return _snapshot(tester, boundary);
}

Future<Uint8List> _snapshot(WidgetTester tester, GlobalKey boundary) async {
  final RenderRepaintBoundary render =
      boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final ByteData? png = await tester.runAsync<ByteData?>(() async {
    final ui.Image image = await render.toImage(pixelRatio: _pixelRatio);
    return image.toByteData(format: ui.ImageByteFormat.png);
  });
  return png!.buffer.asUint8List();
}

void _write(String name, List<int> bytes) {
  File('${_docDir.path}/$name')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes);
}

// Comparison data: ten years of days with 3 to 199 messages each. Today is
// short and yesterday long, so both are on the first screen.
const int _days = 3650;
int _heavyCount(int day) => 3 + (day * 97) % 197;

Widget _chatScreen(String title, Widget body) {
  return Scaffold(
    appBar: AppBar(title: Text(title)),
    body: body,
  );
}

Widget _header(BuildContext context, int day) =>
    DayHeader(label: _dayLabel(day), messageCount: _heavyCount(day));

Widget _message(BuildContext context, int day, int index) => MessageTile(
  text: 'Message ${index + 1} of ${_heavyCount(day)}',
  mine: (day + index).isEven,
);

/// Workaround 1: one SliverMainAxisGroup with a pinned header per day.
Widget _groupPerDay() {
  return CustomScrollView(
    slivers: <Widget>[
      for (int day = 0; day < _days; day++)
        SliverMainAxisGroup(
          slivers: <Widget>[
            PinnedHeaderSliver(
              child: Builder(
                builder: (BuildContext context) => ColoredBox(
                  color: Theme.of(context).colorScheme.surface,
                  child: _header(context, day),
                ),
              ),
            ),
            SliverList.builder(
              itemCount: _heavyCount(day),
              itemBuilder: (BuildContext context, int index) =>
                  _message(context, day, index),
            ),
          ],
        ),
    ],
  );
}

/// Workaround 2: a lazy ListView whose children are whole days.
Widget _listOfDays() {
  return ListView.builder(
    itemCount: _days,
    itemBuilder: (BuildContext context, int day) => Column(
      children: <Widget>[
        _header(context, day),
        for (int i = 0; i < _heavyCount(day); i++) _message(context, day, i),
      ],
    ),
  );
}

Widget _lazySections() {
  return LazyStickySectionsView(
    sectionCount: _days,
    itemCount: _heavyCount,
    headerBuilder: _header,
    pinnedHeaderBuilder: (BuildContext context, int day) => DayHeader(
      label: _dayLabel(day),
      messageCount: _heavyCount(day),
      elevated: true,
    ),
    itemBuilder: _message,
  );
}

/// Counts the day headers and messages currently in the widget tree.
({int headers, int messages}) _countBuilt() {
  return (
    headers: find.byType(DayHeader, skipOffstage: false).evaluate().length,
    messages: find.byType(MessageTile, skipOffstage: false).evaluate().length,
  );
}

String _format(int n) {
  final String digits = n.toString();
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

// GIF data: short days, so headers pass by often.
int _lightCount(int day) => 2 + (day * 7) % 5;

class _HistoryDemo extends StatefulWidget {
  const _HistoryDemo({required this.controller});

  final ScrollController controller;

  @override
  State<_HistoryDemo> createState() => _HistoryDemoState();
}

class _HistoryDemoState extends State<_HistoryDemo> {
  int? _current;

  @override
  Widget build(BuildContext context) {
    final int? current = _current;
    return _chatScreen(
      current == null ? 'History' : _dayLabel(current),
      LazyStickySectionsView(
        controller: widget.controller,
        sectionCount: _days,
        itemCount: _lightCount,
        onCurrentSectionChanged: (int? section) =>
            setState(() => _current = section),
        headerBuilder: (BuildContext context, int day) =>
            DayHeader(label: _dayLabel(day), messageCount: _lightCount(day)),
        pinnedHeaderBuilder: (BuildContext context, int day) => DayHeader(
          label: _dayLabel(day),
          messageCount: _lightCount(day),
          elevated: true,
        ),
        itemBuilder: (BuildContext context, int day, int index) => MessageTile(
          text: index.isEven ? 'See you at 6?' : 'Sounds good!',
          mine: (day + index).isEven,
        ),
      ),
    );
  }
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('comparison', (WidgetTester tester) async {
    final int totalMessages = <int>[
      for (int day = 0; day < _days; day++) _heavyCount(day),
    ].reduce((int a, int b) => a + b);

    Future<({int headers, int messages})> measure(Widget body) async {
      tester.view.physicalSize = const Size(360, 640) * _pixelRatio;
      tester.view.devicePixelRatio = _pixelRatio;
      await tester.pumpWidget(
        MaterialApp(theme: _theme, home: _chatScreen('History', body)),
      );
      await tester.pump();
      return _countBuilt();
    }

    final groups = await measure(_groupPerDay());
    final days = await measure(_listOfDays());
    final lazy = await measure(_lazySections());

    const Color bad = Color(0xFFC5221F);
    const Color good = Color(0xFF137333);
    Widget panel(
      String title,
      String how,
      ({int headers, int messages}) built,
      Widget body, {
      required bool headersOk,
      required bool messagesOk,
    }) {
      return Column(
        children: <Widget>[
          _caption(title, detail: how),
          _phone(_chatScreen('History', body), width: 320, height: 560),
          const SizedBox(height: 12),
          Text(
            '${_format(built.headers)} day '
            '${built.headers == 1 ? 'header' : 'headers'} built',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: headersOk ? good : bad,
            ),
          ),
          Text(
            '${_format(built.messages)} messages built',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: messagesOk ? good : bad,
            ),
          ),
        ],
      );
    }

    final Uint8List png = await _render(
      tester,
      const Size(1180, 860),
      Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _caption(
              'The same chat: ${_format(_days)} days, '
              '${_format(totalMessages)} messages',
              detail: 'Widgets in the tree on the first screen',
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 36,
              children: <Widget>[
                panel(
                  'A sliver group per day',
                  'SliverMainAxisGroup + PinnedHeaderSliver',
                  groups,
                  _groupPerDay(),
                  headersOk: false,
                  // Each day's list builds its first message to size itself.
                  messagesOk: false,
                ),
                panel(
                  'A ListView of whole days',
                  'Each day is one Column; headers not sticky',
                  days,
                  _listOfDays(),
                  headersOk: true,
                  messagesOk: false,
                ),
                panel(
                  'LazyStickySectionsView',
                  'Lazy headers and lazy messages',
                  lazy,
                  _lazySections(),
                  headersOk: true,
                  messagesOk: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
    _write('comparison.png', png);
  });

  testWidgets('slivers', (WidgetTester tester) async {
    Widget state(String title, String detail, double offset) {
      return Column(
        children: <Widget>[
          _caption(title, detail: detail),
          _phone(
            PrimaryScrollController(
              controller: ScrollController(initialScrollOffset: offset),
              child: const Scaffold(body: ContactsPage()),
            ),
            width: 340,
            height: 600,
          ),
        ],
      );
    }

    final Uint8List png = await _render(
      tester,
      const Size(820, 720),
      Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 40,
          children: <Widget>[
            state('At the top', 'Inside a CustomScrollView', 0),
            state('Scrolled', 'B pushes the pinned A away', 2790),
          ],
        ),
      ),
    );
    _write('slivers.png', png);
  });

  testWidgets('demo gif', (WidgetTester tester) async {
    final ScrollController controller = ScrollController();
    final GlobalKey boundary = GlobalKey();
    tester.view.physicalSize = const Size(400, 720) * _pixelRatio;
    tester.view.devicePixelRatio = _pixelRatio;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _theme,
        home: RepaintBoundary(
          key: boundary,
          child: Material(
            color: Colors.white,
            child: Center(child: _phone(_HistoryDemo(controller: controller))),
          ),
        ),
      ),
    );
    await tester.pump();

    final img.GifEncoder gif = img.GifEncoder(
      numColors: 128,
      dither: img.DitherKernel.none,
      samplingFactor: 4,
    );
    Future<void> addFrame(int duration) async {
      final img.Image frame = img.decodePng(await _snapshot(tester, boundary))!;
      gif.addFrame(
        img.copyResize(
          frame,
          width: 400,
          interpolation: img.Interpolation.average,
        ),
        duration: duration,
      );
    }

    await addFrame(100);
    const int frames = 80;
    const double step = 7;
    for (int i = 1; i <= frames; i++) {
      controller.jumpTo(i * step);
      await tester.pump();
      // The title follows onCurrentSectionChanged, one frame later.
      await tester.pump();
      await addFrame(i == frames ? 150 : 5);
    }
    _write('demo.gif', gif.finish()!);
  });
}
