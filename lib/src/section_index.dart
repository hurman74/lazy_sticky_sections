import 'package:flutter/foundation.dart';

/// Maps between the positions of a sectioned list and the flat child indexes
/// of the underlying sliver list.
///
/// Every section takes one flat index for its header, followed by one flat
/// index per item. For sections with 2, 0 and 3 items, the flat indexes are:
///
/// | flat index | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
/// |---|---|---|---|---|---|---|---|---|
/// | position | header 0 | item 0.0 | item 0.1 | header 1 | header 2 | item 2.0 | item 2.1 | item 2.2 |
///
/// Building the index reads every section's item count once, which is
/// O(sections). Lookups are O(log sections). No widgets are built.
@immutable
class SectionIndex {
  /// Creates an index for [sectionCount] sections, where section `s` has
  /// `itemCount(s)` items.
  ///
  /// [sectionCount] and every item count must be zero or greater.
  factory SectionIndex({
    required int sectionCount,
    required int Function(int section) itemCount,
  }) {
    if (sectionCount < 0) {
      throw ArgumentError.value(
        sectionCount,
        'sectionCount',
        'must not be negative',
      );
    }
    final starts = List<int>.filled(sectionCount + 1, 0);
    var next = 0;
    for (var section = 0; section < sectionCount; section++) {
      starts[section] = next;
      final count = itemCount(section);
      if (count < 0) {
        throw ArgumentError.value(
          count,
          'itemCount($section)',
          'must not be negative',
        );
      }
      next += 1 + count;
    }
    starts[sectionCount] = next;
    return SectionIndex._(starts);
  }

  const SectionIndex._(this._starts);

  /// The flat index of each section's header, followed by [childCount].
  final List<int> _starts;

  /// The number of sections.
  int get sectionCount => _starts.length - 1;

  /// The total number of flat children: one header per section plus every
  /// item.
  int get childCount => _starts.last;

  /// The number of items in [section], not counting its header.
  int itemCountOf(int section) {
    _checkSection(section);
    return _starts[section + 1] - _starts[section] - 1;
  }

  /// The flat index of the header of [section].
  int headerIndexOf(int section) {
    _checkSection(section);
    return _starts[section];
  }

  /// The flat index of item [item] in [section].
  int itemIndexOf(int section, int item) {
    final count = itemCountOf(section);
    RangeError.checkValueInInterval(item, 0, count - 1, 'item');
    return _starts[section] + 1 + item;
  }

  /// The section that contains the flat index [index].
  int sectionOf(int index) {
    RangeError.checkValueInInterval(index, 0, childCount - 1, 'index');
    // Find the last section whose header index is at or before [index].
    var low = 0;
    var high = sectionCount - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (_starts[mid] <= index) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low;
  }

  /// The position of [index] within its section: `-1` for the header,
  /// otherwise the item index.
  int itemOf(int index) {
    final section = sectionOf(index);
    return index - _starts[section] - 1;
  }

  /// Whether the flat index [index] is a section header.
  bool isHeader(int index) => itemOf(index) == -1;

  void _checkSection(int section) {
    RangeError.checkValueInInterval(section, 0, sectionCount - 1, 'section');
  }

  @override
  String toString() =>
      'SectionIndex(sectionCount: $sectionCount, childCount: $childCount)';
}
