import 'package:flutter_test/flutter_test.dart';
import 'package:lazy_sticky_sections/lazy_sticky_sections.dart';

void main() {
  group('SectionIndex', () {
    // Sections with 2, 0 and 3 items:
    // 0:h0 1:i0.0 2:i0.1 3:h1 4:h2 5:i2.0 6:i2.1 7:i2.2
    final index = SectionIndex(
      sectionCount: 3,
      itemCount: (section) => const [2, 0, 3][section],
    );

    test('counts headers and items', () {
      expect(index.sectionCount, 3);
      expect(index.childCount, 8);
      expect(index.itemCountOf(0), 2);
      expect(index.itemCountOf(1), 0);
      expect(index.itemCountOf(2), 3);
    });

    test('maps sections to flat indexes', () {
      expect(index.headerIndexOf(0), 0);
      expect(index.headerIndexOf(1), 3);
      expect(index.headerIndexOf(2), 4);
      expect(index.itemIndexOf(0, 1), 2);
      expect(index.itemIndexOf(2, 0), 5);
      expect(index.itemIndexOf(2, 2), 7);
    });

    test('maps flat indexes to sections', () {
      expect(
        [for (var i = 0; i < 8; i++) index.sectionOf(i)],
        [0, 0, 0, 1, 2, 2, 2, 2],
      );
      expect(
        [for (var i = 0; i < 8; i++) index.itemOf(i)],
        [-1, 0, 1, -1, -1, 0, 1, 2],
      );
      expect(
        [for (var i = 0; i < 8; i++) index.isHeader(i)],
        [true, false, false, true, true, false, false, false],
      );
    });

    test('round-trips every position of a large index', () {
      final large = SectionIndex(
        sectionCount: 5000,
        itemCount: (section) => section % 7,
      );
      for (var section = 0; section < large.sectionCount; section++) {
        final header = large.headerIndexOf(section);
        expect(large.sectionOf(header), section);
        expect(large.isHeader(header), isTrue);
        for (var item = 0; item < large.itemCountOf(section); item++) {
          final flat = large.itemIndexOf(section, item);
          expect(large.sectionOf(flat), section);
          expect(large.itemOf(flat), item);
        }
      }
      expect(
        large.childCount,
        5000 + List.generate(5000, (s) => s % 7).fold(0, (a, b) => a + b),
      );
    });

    test('handles no sections', () {
      final empty = SectionIndex(sectionCount: 0, itemCount: (_) => 3);
      expect(empty.sectionCount, 0);
      expect(empty.childCount, 0);
      expect(() => empty.sectionOf(0), throwsRangeError);
    });

    test('rejects negative counts', () {
      expect(
        () => SectionIndex(sectionCount: -1, itemCount: (_) => 0),
        throwsArgumentError,
      );
      expect(
        () => SectionIndex(sectionCount: 2, itemCount: (s) => s == 1 ? -1 : 0),
        throwsArgumentError,
      );
    });

    test('rejects out of range lookups', () {
      expect(() => index.sectionOf(-1), throwsRangeError);
      expect(() => index.sectionOf(8), throwsRangeError);
      expect(() => index.headerIndexOf(3), throwsRangeError);
      expect(() => index.itemIndexOf(1, 0), throwsRangeError);
      expect(() => index.itemIndexOf(0, 2), throwsRangeError);
    });

    test('reads each item count once', () {
      final calls = <int>[];
      SectionIndex(
        sectionCount: 4,
        itemCount: (section) {
          calls.add(section);
          return 1;
        },
      );
      expect(calls, [0, 1, 2, 3]);
    });
  });
}
