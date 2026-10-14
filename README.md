# lazy_sticky_sections

Grouped Flutter lists with **sticky section headers**, where both the sections _and_ the items
inside them are built lazily.

Describe your content with a section count, an item count per section and two builders. Only
what is on screen gets built: not the headers of far-away sections, and not the items of a long
section. The current section's header stays pinned to the top until the next one pushes it
away.

Built for very long grouped lists: years of chat history with a header per day, a contact list
with a header per letter, or a log with a header per hour.

## Install

```sh
flutter pub add lazy_sticky_sections
```

## Usage

### As a scroll view

```dart
import 'package:lazy_sticky_sections/lazy_sticky_sections.dart';

LazyStickySectionsView(
  sectionCount: days.length,
  itemCount: (section) => days[section].messages.length,
  headerBuilder: (context, section) => DayHeader(day: days[section]),
  itemBuilder: (context, section, index) =>
      MessageTile(message: days[section].messages[index]),
)
```

### As a sliver, below a pinned app bar

```dart
CustomScrollView(
  slivers: [
    const SliverAppBar.large(pinned: true, title: Text('Contacts')),
    SliverLazyStickySections(
      sectionCount: letters.length,
      itemCount: (section) => contactsByLetter[letters[section]]!.length,
      headerBuilder: (context, section) => LetterHeader(letters[section]),
      itemBuilder: (context, section, index) =>
          ContactTile(contactsByLetter[letters[section]]![index]),
    ),
  ],
)
```

Headers pin just below the app bar, not behind it.

### A different look for the pinned header

```dart
SliverLazyStickySections(
  // ...
  headerBuilder: (context, section) => DayHeader(day: days[section]),
  pinnedHeaderBuilder: (context, section) =>
      DayHeader(day: days[section], elevated: true),
)
```

### Following the current section

```dart
LazyStickySectionsView(
  // ...
  onCurrentSectionChanged: (section) => setState(() => _currentDay = section),
)
```

The callback runs after layout, so calling `setState` from it is safe. It reports `null` when
none of the sections are at the top.

### Collapsible sections

Return `0` from `itemCount` for a collapsed section. Its header stays, and its items are
never built.

### API at a glance

| Argument | Purpose |
| --- | --- |
| `sectionCount` | Number of sections. |
| `itemCount(section)` | Number of items in a section, not counting its header. |
| `headerBuilder(context, section)` | Builds each section's header in the list. |
| `itemBuilder(context, section, index)` | Builds each item. |
| `pinnedHeaderBuilder` | Optional builder for the pinned copy of the header. |
| `sticky` | Set to `false` to let headers scroll away. |
| `onCurrentSectionChanged` | Called after a frame in which the section at the top changed. |

`SectionIndex` exposes the mapping between `(section, item)` positions and flat child indexes,
in case you need it elsewhere.

## Why this package

Flutter has no lazy way to build a list of lists
([flutter/flutter#160075](https://github.com/flutter/flutter/issues/160075)). The usual
workarounds each give up laziness at one level:

- **One `SliverMainAxisGroup` (or one sticky-header sliver) per section** builds items lazily,
  but every section's sliver is created up front. With thousands of sections, each rebuild gets
  slow.
- **A `ListView` whose items are whole sections** builds sections lazily, but each section is
  built in full, including items that are far off screen.
- **Grouped list packages that take a flat list of elements** need the whole data set in memory
  and grouped in advance, and are not slivers you can combine with other slivers.

This package keeps a single lazy `SliverList` of headers and items, maps each index to its
section with a binary search, and paints the pinned header as an overlay. It is:

- **Lazy at both levels.** Builders run only for visible (and cached) headers and items.
- **A real sliver.** Mix it with app bars, other lists and grids in one `CustomScrollView`, in
  any scroll direction.
- **Pinned correctly.** The header sits below pinned slivers, gets pushed by the next header,
  leaves with the last section, and receives taps ahead of the content under it.
- **Accessible.** The pinned header is a visual copy; screen readers see each header once, in
  order.
- **Pure Flutter.** No platform code and no dependencies beyond the Flutter SDK.

## Limitations

- `itemCount` is called for every section each time the widget builds, to know where each
  section starts. That is cheap for counts already in memory, even for many thousands of
  sections, but don't do expensive work inside it.
- Items can have any height, so the list behaves like `SliverList`: jumping far away with
  `jumpTo` or a dragged scrollbar lays out the items in between, and the total scroll extent is
  an estimate until they have been laid out. There is no "scroll to section" helper yet.
- The pinned header is a separate widget from the header in the list, so the two don't share
  state.
- Headers always come first in their section in scroll order. With `reverse: true` they pin to
  the bottom and appear below their items, which suits some layouts but not a bottom-anchored
  chat with dates above the messages.
- There are no sticky section footers.

## License

MIT
