import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'sliver_lazy_sticky_sections.dart';

/// A scrollable list of sections with sticky headers, where headers and
/// items are both built lazily.
///
/// This is a [CustomScrollView] that holds one [SliverLazyStickySections].
/// To combine sections with other slivers, such as an app bar, use
/// [SliverLazyStickySections] directly.
///
/// ```dart
/// LazyStickySectionsView(
///   sectionCount: letters.length,
///   itemCount: (section) => contactsByLetter[letters[section]]!.length,
///   headerBuilder: (context, section) => LetterHeader(letters[section]),
///   itemBuilder: (context, section, index) =>
///       ContactTile(contactsByLetter[letters[section]]![index]),
/// )
/// ```
class LazyStickySectionsView extends StatelessWidget {
  /// Creates a scrollable list of [sectionCount] sticky sections.
  ///
  /// See [SliverLazyStickySections] for the section arguments and
  /// [ScrollView] for the scrolling arguments.
  const LazyStickySectionsView({
    super.key,
    required this.sectionCount,
    required this.itemCount,
    required this.headerBuilder,
    required this.itemBuilder,
    this.pinnedHeaderBuilder,
    this.sticky = true,
    this.onCurrentSectionChanged,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.primary,
    this.physics,
    this.padding,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
  }) : assert(sectionCount >= 0);

  /// The number of sections.
  final int sectionCount;

  /// Returns the number of items in a section, not counting its header.
  ///
  /// See [SliverLazyStickySections.itemCount].
  final int Function(int section) itemCount;

  /// Builds the header at the start of each section.
  final SectionHeaderBuilder headerBuilder;

  /// Builds the items of each section.
  final SectionItemBuilder itemBuilder;

  /// Builds the header that is pinned to the leading edge.
  ///
  /// See [SliverLazyStickySections.pinnedHeaderBuilder].
  final SectionHeaderBuilder? pinnedHeaderBuilder;

  /// Whether the current section's header sticks to the leading edge.
  final bool sticky;

  /// Called after a frame in which the section at the leading edge changed.
  ///
  /// See [SliverLazyStickySections.onCurrentSectionChanged].
  final ValueChanged<int?>? onCurrentSectionChanged;

  /// The axis along which the view scrolls.
  final Axis scrollDirection;

  /// Whether the view scrolls in the reading direction.
  ///
  /// When true, the leading edge is at the bottom (or the end), so that is
  /// where headers stick, and each header comes after its items visually.
  final bool reverse;

  /// An object that can be used to control the position of the view.
  final ScrollController? controller;

  /// Whether this is the primary scroll view associated with the parent
  /// [PrimaryScrollController].
  final bool? primary;

  /// How the view responds to user input.
  final ScrollPhysics? physics;

  /// The amount of space by which to inset the sections.
  ///
  /// Headers pin to the leading edge of the padded area.
  final EdgeInsetsGeometry? padding;

  /// Whether to wrap each child in an [AutomaticKeepAlive].
  final bool addAutomaticKeepAlives;

  /// Whether to wrap each child in a [RepaintBoundary].
  final bool addRepaintBoundaries;

  /// Whether to wrap each child in an [IndexedSemantics].
  final bool addSemanticIndexes;

  /// Determines the way that drag start behavior is handled.
  final DragStartBehavior dragStartBehavior;

  /// Defines how the view dismisses the keyboard automatically.
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  /// Restoration ID to save and restore the scroll offset.
  final String? restorationId;

  /// How to clip the content.
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    Widget sliver = SliverLazyStickySections(
      sectionCount: sectionCount,
      itemCount: itemCount,
      headerBuilder: headerBuilder,
      itemBuilder: itemBuilder,
      pinnedHeaderBuilder: pinnedHeaderBuilder,
      sticky: sticky,
      onCurrentSectionChanged: onCurrentSectionChanged,
      addAutomaticKeepAlives: addAutomaticKeepAlives,
      addRepaintBoundaries: addRepaintBoundaries,
      addSemanticIndexes: addSemanticIndexes,
    );
    if (padding != null) {
      sliver = SliverPadding(padding: padding!, sliver: sliver);
    }
    return CustomScrollView(
      scrollDirection: scrollDirection,
      reverse: reverse,
      controller: controller,
      primary: primary,
      physics: physics,
      dragStartBehavior: dragStartBehavior,
      keyboardDismissBehavior: keyboardDismissBehavior,
      restorationId: restorationId,
      clipBehavior: clipBehavior,
      slivers: [sliver],
    );
  }
}
