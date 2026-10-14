## 0.1.1

- README: add an animated demo, a comparison with the usual workarounds (widgets built on the
  first screen) and a sliver example image. No code changes.

## 0.1.0

- Initial release.
- `SliverLazyStickySections`: a sliver of sections (a header followed by items) where both the
  headers and the items are built lazily, from a section count, an item count per section and
  builders.
- The current section's header is pinned to the leading edge, pushed away by the next header,
  and placed below pinned slivers such as a pinned `SliverAppBar`.
- `pinnedHeaderBuilder` to give the pinned header its own look, `sticky` to turn pinning off,
  and `onCurrentSectionChanged` to follow the section at the leading edge.
- `LazyStickySectionsView`, a ready-made scroll view built on the sliver.
- `SectionIndex`, which maps between sections and flat child indexes.
