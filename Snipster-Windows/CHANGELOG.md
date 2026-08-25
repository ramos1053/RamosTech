# Changelog

## 1.1.0 — 2026-08-25

### Added
- Manage Snippets shows a small colored dot next to each snippet, matching its assigned tag's color.
- A "Group by tag" option in Manage Snippets clusters the list under a collapsible header per tag (plus one for snippets with no tag).
- Each tag group has its own disclosure triangle to hide or show just that group's snippets, plus Expand All / Collapse All buttons to do it for every group at once.
- Whether grouping is on and which groups are left collapsed are now remembered as app preferences, restored the next time Manage Snippets is opened — including after a full restart.

### Fixed
- Fixed a crash in Manage Tags when deleting a tag — most reliably reproduced by deleting the last remaining tag — caused by reading the selected tag's Id after removing it from the list had already reassigned the selection out from under that read. The crash was caught by the app's global exception handler rather than taking the process down, but it aborted mid-click and could leave the whole app silently unresponsive to further clicks until it was restarted.
- As defense in depth against that same class of problem recurring, the global exception handler now explicitly releases any stuck WPF mouse capture after logging an unhandled exception.

## 1.0.0 — 2026-08-24

Initial release. See [README](README.md) for the full feature set.
