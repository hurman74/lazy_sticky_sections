import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'render_sliver_sticky_sections.dart';
import 'section_index.dart';

/// Builds the header of [section].
typedef SectionHeaderBuilder =
    Widget Function(BuildContext context, int section);

/// Builds item [index] of [section].
typedef SectionItemBuilder =
    Widget Function(BuildContext context, int section, int index);

/// A sliver of sections, each a header followed by items, where headers and
/// items are both built lazily and the current section's header sticks to
/// the leading edge.
///
/// You describe the content with counts and builders, so nothing is built
/// until it scrolls into view (or into the cache extent): not the headers of
/// far-away sections, and not the items of a long section. This makes it
/// suitable for very long grouped lists, such as a chat history with a header
/// per day, a contact list with a header per letter or a log with a header
/// per hour.
///
/// While a section is scrolled past the leading edge, a copy of its header
/// (built with [pinnedHeaderBuilder], or [headerBuilder] if that is null)
/// stays pinned there, until the next section's header pushes it away. If
/// another pinned sliver, such as a pinned `SliverAppBar`, covers the leading
/// edge, the header pins just below it.
///
/// ```dart
/// CustomScrollView(
///   slivers: [
///     SliverLazyStickySections(
///       sectionCount: days.length,
///       itemCount: (section) => days[section].messages.length,
///       headerBuilder: (context, section) => DayHeader(day: days[section]),
///       itemBuilder: (context, section, index) =>
///           MessageTile(message: days[section].messages[index]),
///     ),
///   ],
/// )
/// ```
///
/// [itemCount] is called once for every section each time this widget
/// builds, to work out where each section starts. That is cheap for counts
/// you already have in memory, even for many thousands of sections. Widgets
/// are only built for visible sections.
///
/// The pinned header is a separate widget from the header in the list, so
/// they don't share state. Only the header in the list is exposed to
/// accessibility services.
///
/// See also:
///
///  * `LazyStickySectionsView`, a scrollable box widget built on this sliver.
///  * [SectionIndex], which maps between sections and flat child indexes.
class SliverLazyStickySections extends StatelessWidget {
  /// Creates a sliver of [sectionCount] sticky sections.
  ///
  /// [sectionCount] and the values returned by [itemCount] must not be
  /// negative.
  ///
  /// [addAutomaticKeepAlives], [addRepaintBoundaries] and [addSemanticIndexes]
  /// are passed to the [SliverChildBuilderDelegate] of the underlying list;
  /// see its documentation for details.
  const SliverLazyStickySections({
    super.key,
    required this.sectionCount,
    required this.itemCount,
    required this.headerBuilder,
    required this.itemBuilder,
    this.pinnedHeaderBuilder,
    this.sticky = true,
    this.onCurrentSectionChanged,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
  }) : assert(sectionCount >= 0);

  /// The number of sections.
  final int sectionCount;

  /// Returns the number of items in a section, not counting its header.
  ///
  /// Called once for every section each time this widget builds.
  final int Function(int section) itemCount;

  /// Builds the header at the start of each section.
  ///
  /// Only called for headers that are visible or within the cache extent.
  final SectionHeaderBuilder headerBuilder;

  /// Builds the items of each section.
  ///
  /// Only called for items that are visible or within the cache extent.
  final SectionItemBuilder itemBuilder;

  /// Builds the header that is pinned to the leading edge.
  ///
  /// Use it to give the pinned header a different look, such as a shadow or
  /// an opaque background. If null, [headerBuilder] is used. The pinned
  /// header may have a different size from the header in the list.
  final SectionHeaderBuilder? pinnedHeaderBuilder;

  /// Whether the current section's header sticks to the leading edge.
  ///
  /// If false, headers scroll with their sections like any other child.
  final bool sticky;

  /// Called after a frame in which the section at the leading edge changed.
  ///
  /// The value is null when none of this sliver's content is at the leading
  /// edge, for example when the sliver has been scrolled out of view or the
  /// content above it is still visible. The callback runs after layout, so it
  /// may call `setState`.
  final ValueChanged<int?>? onCurrentSectionChanged;

  /// Whether to wrap each child in an [AutomaticKeepAlive].
  final bool addAutomaticKeepAlives;

  /// Whether to wrap each child in a [RepaintBoundary].
  final bool addRepaintBoundaries;

  /// Whether to wrap each child in an [IndexedSemantics].
  final bool addSemanticIndexes;

  @override
  Widget build(BuildContext context) {
    final index = SectionIndex(
      sectionCount: sectionCount,
      itemCount: itemCount,
    );
    return _StickySections(
      sectionIndex: index,
      sticky: sticky,
      onCurrentSectionChanged: onCurrentSectionChanged,
      pinnedHeaderBuilder: pinnedHeaderBuilder ?? headerBuilder,
      list: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, flatIndex) {
            final section = index.sectionOf(flatIndex);
            final item = flatIndex - index.headerIndexOf(section) - 1;
            if (item < 0) {
              return headerBuilder(context, section);
            }
            return itemBuilder(context, section, item);
          },
          childCount: index.childCount,
          addAutomaticKeepAlives: addAutomaticKeepAlives,
          addRepaintBoundaries: addRepaintBoundaries,
          addSemanticIndexes: addSemanticIndexes,
        ),
      ),
    );
  }
}

class _StickySections extends RenderObjectWidget {
  const _StickySections({
    required this.sectionIndex,
    required this.sticky,
    required this.onCurrentSectionChanged,
    required this.pinnedHeaderBuilder,
    required this.list,
  });

  final SectionIndex sectionIndex;
  final bool sticky;
  final ValueChanged<int?>? onCurrentSectionChanged;
  final SectionHeaderBuilder pinnedHeaderBuilder;
  final Widget list;

  @override
  RenderObjectElement createElement() => _StickySectionsElement(this);

  @override
  RenderSliverStickySections createRenderObject(BuildContext context) {
    return RenderSliverStickySections(
      sectionIndex: sectionIndex,
      sticky: sticky,
      onCurrentSectionChanged: onCurrentSectionChanged,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSliverStickySections renderObject,
  ) {
    renderObject
      ..sectionIndex = sectionIndex
      ..sticky = sticky
      ..onCurrentSectionChanged = onCurrentSectionChanged;
  }
}

enum _Slot { list, header }

class _StickySectionsElement extends RenderObjectElement {
  _StickySectionsElement(_StickySections super.widget);

  Element? _list;
  Element? _header;

  @override
  _StickySections get widget => super.widget as _StickySections;

  @override
  RenderSliverStickySections get renderObject =>
      super.renderObject as RenderSliverStickySections;

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    _list = updateChild(_list, widget.list, _Slot.list);
    renderObject.headerUpdater = _updateHeader;
  }

  @override
  void update(_StickySections newWidget) {
    super.update(newWidget);
    _list = updateChild(_list, widget.list, _Slot.list);
    renderObject.markNeedsHeaderBuild();
  }

  @override
  void unmount() {
    renderObject.headerUpdater = null;
    super.unmount();
  }

  void _updateHeader(int? section) {
    owner!.buildScope(this, () {
      _header = updateChild(
        _header,
        section == null
            ? null
            : KeyedSubtree(
                key: ValueKey<int>(section),
                child: Builder(
                  builder: (context) =>
                      widget.pinnedHeaderBuilder(context, section),
                ),
              ),
        _Slot.header,
      );
    });
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    if (_list != null) {
      visitor(_list!);
    }
    if (_header != null) {
      visitor(_header!);
    }
  }

  @override
  void forgetChild(Element child) {
    if (identical(child, _list)) {
      _list = null;
    } else if (identical(child, _header)) {
      _header = null;
    }
    super.forgetChild(child);
  }

  @override
  void insertRenderObjectChild(RenderObject child, _Slot slot) {
    switch (slot) {
      case _Slot.list:
        renderObject.list = child as RenderSliverMultiBoxAdaptor;
      case _Slot.header:
        renderObject.header = child as RenderBox;
    }
  }

  @override
  void moveRenderObjectChild(RenderObject child, _Slot oldSlot, _Slot newSlot) {
    assert(false, 'The children of sticky sections never move.');
  }

  @override
  void removeRenderObjectChild(RenderObject child, _Slot slot) {
    switch (slot) {
      case _Slot.list:
        renderObject.list = null;
      case _Slot.header:
        renderObject.header = null;
    }
  }
}
