import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'section_index.dart';

/// Builds (or removes, when [section] is null) the pinned header box child.
///
/// Called from inside layout, through [RenderObject.invokeLayoutCallback].
typedef PinnedHeaderUpdater = void Function(int? section);

/// The render object behind `SliverLazyStickySections`.
///
/// It has two children:
///
///  * [list], a [RenderSliverMultiBoxAdaptor] that lays out every header and
///    item lazily, in one flat sequence described by [sectionIndex].
///  * [header], a box that shows the header of the section at the leading
///    edge. It is built during layout, once the current section is known, and
///    painted on top of [list].
///
/// The geometry of this sliver is the geometry of [list]; the pinned header
/// never takes up scroll extent of its own.
class RenderSliverStickySections extends RenderSliver with RenderSliverHelpers {
  /// Creates the render object for a sticky sections sliver.
  RenderSliverStickySections({
    required SectionIndex sectionIndex,
    bool sticky = true,
    this.onCurrentSectionChanged,
  }) : _sectionIndex = sectionIndex,
       _sticky = sticky;

  /// How flat child indexes map to sections.
  SectionIndex get sectionIndex => _sectionIndex;
  SectionIndex _sectionIndex;
  set sectionIndex(SectionIndex value) {
    if (identical(value, _sectionIndex)) {
      return;
    }
    _sectionIndex = value;
    markNeedsLayout();
  }

  /// Whether the current section's header is pinned to the leading edge.
  bool get sticky => _sticky;
  bool _sticky;
  set sticky(bool value) {
    if (value == _sticky) {
      return;
    }
    _sticky = value;
    markNeedsLayout();
  }

  /// Called after a frame in which the current section changed.
  ValueChanged<int?>? onCurrentSectionChanged;

  /// Set by the element to build the pinned header during layout.
  PinnedHeaderUpdater? headerUpdater;

  bool _needsHeaderBuild = true;
  int? _builtSection;

  /// Asks for the pinned header to be rebuilt during the next layout, even if
  /// the current section stays the same.
  void markNeedsHeaderBuild() {
    _needsHeaderBuild = true;
    markNeedsLayout();
  }

  /// The sliver that lays out every header and item.
  RenderSliverMultiBoxAdaptor? get list => _list;
  RenderSliverMultiBoxAdaptor? _list;
  set list(RenderSliverMultiBoxAdaptor? value) {
    if (_list != null) {
      dropChild(_list!);
    }
    _list = value;
    if (value != null) {
      adoptChild(value);
    }
  }

  /// The box that shows the pinned header, if any.
  RenderBox? get header => _header;
  RenderBox? _header;
  set header(RenderBox? value) {
    if (_header != null) {
      dropChild(_header!);
    }
    _header = value;
    if (value != null) {
      adoptChild(value);
    }
  }

  /// The section at the leading edge after the last layout, or null if none
  /// of this sliver's content is there.
  int? get currentSection => _currentSection;
  int? _currentSection;
  int? _reportedSection;
  bool _reportScheduled = false;

  bool _headerVisible = false;

  /// The pinned header's distance from the start of this sliver's content.
  double _headerScrollOffset = 0;

  /// The pinned header's distance from this sliver's leading paint edge.
  double _headerPaintOffset = 0;

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! ParentData) {
      child.parentData = ParentData();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _list?.attach(owner);
    _header?.attach(owner);
  }

  @override
  void detach() {
    super.detach();
    _list?.detach();
    _header?.detach();
  }

  @override
  void redepthChildren() {
    if (_list != null) {
      redepthChild(_list!);
    }
    if (_header != null) {
      redepthChild(_header!);
    }
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    if (_list != null) {
      visitor(_list!);
    }
    if (_header != null) {
      visitor(_header!);
    }
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    // The pinned header repeats a header that is also in the list, so only
    // the list is exposed to accessibility services.
    if (_list != null) {
      visitor(_list!);
    }
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() => [
    if (_list != null) _list!.toDiagnosticsNode(name: 'list'),
    if (_header != null) _header!.toDiagnosticsNode(name: 'header'),
  ];

  @override
  void performLayout() {
    final list = _list;
    if (list == null) {
      geometry = SliverGeometry.zero;
      _setCurrentSection(null);
      _headerVisible = false;
      return;
    }

    list.layout(constraints, parentUsesSize: true);
    final listGeometry = list.geometry!;
    geometry = listGeometry;
    if (listGeometry.scrollOffsetCorrection != null) {
      return;
    }

    // The line that the header pins to, measured from the start of this
    // sliver's content. Slivers before this one (such as a pinned app bar)
    // may cover the first `overlap` pixels.
    final pinLine = constraints.scrollOffset + math.max(constraints.overlap, 0);

    // The laid out children cover the visible part of the list without gaps,
    // so the child at the pin line is the last one that starts at or before
    // it.
    RenderBox? atPin;
    if (pinLine < listGeometry.scrollExtent) {
      for (
        var child = list.firstChild;
        child != null;
        child = list.childAfter(child)
      ) {
        if (list.childScrollOffset(child)! > pinLine) {
          break;
        }
        atPin = child;
      }
    }

    if (atPin == null || listGeometry.paintExtent <= 0) {
      _setCurrentSection(null);
      _updateHeader(null);
      _headerVisible = false;
      return;
    }

    final section = _sectionIndex.sectionOf(list.indexOf(atPin));
    _setCurrentSection(section);

    if (!_sticky) {
      _updateHeader(null);
      _headerVisible = false;
      return;
    }

    // Where the section's own header is, if it is laid out. Children outside
    // the cache extent are not.
    final headerIndex = _sectionIndex.headerIndexOf(section);
    double? inlineHeaderOffset;
    for (
      RenderBox? child = atPin;
      child != null;
      child = list.childBefore(child)
    ) {
      final index = list.indexOf(child);
      if (index == headerIndex) {
        inlineHeaderOffset = list.childScrollOffset(child);
        break;
      }
      if (index < headerIndex) {
        break;
      }
    }

    // When the section's own header sits exactly on the pin line, it is
    // already where the pinned header would be, so don't build it twice.
    if (inlineHeaderOffset != null &&
        inlineHeaderOffset >= pinLine - precisionErrorTolerance) {
      _updateHeader(null);
      _headerVisible = false;
      return;
    }

    _updateHeader(section);
    final header = _header;
    if (header == null) {
      _headerVisible = false;
      return;
    }
    header.layout(constraints.asBoxConstraints(), parentUsesSize: true);
    final headerExtent = _extentOf(header);

    // Where the section ends: at the next section's header, or at the end of
    // the list. If the next header isn't laid out, it is too far away to
    // matter.
    final nextHeaderIndex = section + 1 < _sectionIndex.sectionCount
        ? _sectionIndex.headerIndexOf(section + 1)
        : null;
    double? sectionEnd;
    for (
      RenderBox? child = atPin;
      child != null;
      child = list.childAfter(child)
    ) {
      final index = list.indexOf(child);
      if (index == nextHeaderIndex) {
        sectionEnd = list.childScrollOffset(child);
        break;
      }
      if (nextHeaderIndex != null && index > nextHeaderIndex) {
        break;
      }
    }
    if (nextHeaderIndex == null) {
      sectionEnd = listGeometry.scrollExtent;
    }

    var headerOffset = pinLine;
    if (sectionEnd != null && sectionEnd - headerExtent < headerOffset) {
      // The next header (or the end of the list) pushes this one away.
      headerOffset = sectionEnd - headerExtent;
    }
    if (inlineHeaderOffset != null && headerOffset < inlineHeaderOffset) {
      // A pinned header taller than its whole section stays with the section.
      headerOffset = inlineHeaderOffset;
    }
    _headerScrollOffset = headerOffset;
    _headerPaintOffset = headerOffset - constraints.scrollOffset;
    _headerVisible = true;
  }

  double _extentOf(RenderBox box) => switch (constraints.axis) {
    Axis.vertical => box.size.height,
    Axis.horizontal => box.size.width,
  };

  void _updateHeader(int? section) {
    if (!_needsHeaderBuild && section == _builtSection) {
      return;
    }
    final updater = headerUpdater;
    if (updater == null) {
      return;
    }
    invokeLayoutCallback<SliverConstraints>((_) => updater(section));
    _needsHeaderBuild = false;
    _builtSection = section;
  }

  void _setCurrentSection(int? section) {
    _currentSection = section;
    if (onCurrentSectionChanged == null ||
        section == _reportedSection ||
        _reportScheduled) {
      return;
    }
    _reportScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _reportScheduled = false;
      if (!attached || _currentSection == _reportedSection) {
        return;
      }
      _reportedSection = _currentSection;
      onCurrentSectionChanged?.call(_currentSection);
    }, debugLabel: 'SliverLazyStickySections.onCurrentSectionChanged');
  }

  @override
  double childMainAxisPosition(RenderObject child) {
    if (identical(child, _header)) {
      return _headerPaintOffset;
    }
    return 0;
  }

  @override
  double childScrollOffset(RenderObject child) {
    if (identical(child, _header)) {
      return _headerScrollOffset;
    }
    return 0;
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    if (identical(child, _header)) {
      applyPaintTransformForBoxChild(child as RenderBox, transform);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final list = _list;
    if (list != null && list.geometry!.visible) {
      context.paintChild(list, offset);
    }
    final header = _header;
    if (_headerVisible && header != null && geometry!.visible) {
      context.paintChild(header, offset + _headerPaintOrigin(header));
    }
  }

  Offset _headerPaintOrigin(RenderBox header) {
    final direction = applyGrowthDirectionToAxisDirection(
      constraints.axisDirection,
      constraints.growthDirection,
    );
    final paintExtent = geometry!.paintExtent;
    return switch (direction) {
      AxisDirection.down => Offset(0, _headerPaintOffset),
      AxisDirection.right => Offset(_headerPaintOffset, 0),
      AxisDirection.up => Offset(
        0,
        paintExtent - _headerPaintOffset - header.size.height,
      ),
      AxisDirection.left => Offset(
        paintExtent - _headerPaintOffset - header.size.width,
        0,
      ),
    };
  }

  @override
  bool hitTestChildren(
    SliverHitTestResult result, {
    required double mainAxisPosition,
    required double crossAxisPosition,
  }) {
    final header = _header;
    if (_headerVisible &&
        header != null &&
        hitTestBoxChild(
          BoxHitTestResult.wrap(result),
          header,
          mainAxisPosition: mainAxisPosition,
          crossAxisPosition: crossAxisPosition,
        )) {
      return true;
    }
    final list = _list;
    if (list != null && list.geometry!.hitTestExtent > 0) {
      return list.hitTest(
        result,
        mainAxisPosition: mainAxisPosition,
        crossAxisPosition: crossAxisPosition,
      );
    }
    return false;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<SectionIndex>('sections', sectionIndex));
    properties.add(
      FlagProperty('sticky', value: sticky, ifFalse: 'not sticky'),
    );
    properties.add(IntProperty('currentSection', currentSection));
  }
}
