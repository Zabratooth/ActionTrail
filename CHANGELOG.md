# Changelog

All notable public changes to ActionTrail are documented here.

## 1.5.5 — 2026-10-04

- Redesigned the **DE / EN language selector** in the settings window.
- The active language is now clearly highlighted.
- Improved spacing, hover feedback, and visual consistency of the language buttons.
- Kept the restored GSE debug behavior from 1.5.4 unchanged.

## 1.5.4 — 2026-10-04

- Fixed missing GSE debug output with some executor variants.
- Expanded GSE executor discovery to support frames that expose `step` without `ms`.
- Added support for following `clickbutton` targets when locating GSE executors.
- Added `/at gsescan` for a manual GSE executor rescan.
- `/at status` now reports the number of hooked GSE executors.

## 1.5.3 — 2026-10-04

- Replaced the minimap icon with a simpler, high-contrast ActionTrail `A` icon designed for small minimap display.

## 1.5.2 — 2026-10-04

- Fixed an initialization error introduced by the language system in 1.5.1.
- Restored normal addon loading, `/at`, and minimap functionality.

## 1.5.1 — 2026-10-04

- Added switchable **German / English** interface text.
- Added translated minimap tooltip and settings labels.
- Added `/at lang de` and `/at lang en`.

## 1.5.0 — 2026-10-04

- Prepared ActionTrail for public release under the **Zabratooth** author identity.
- Added MIT licensing and public documentation.
- Added the custom ActionTrail addon icon.
- Retained action history, auto-repeat handling, minimap controls, and optional GSE diagnostics from the development builds.
