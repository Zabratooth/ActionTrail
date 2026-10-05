# Changelog

## 1.5.15
- Fixed `gseHookCount` initialization when GSE executors are hooked.
- Restored the original ActionTrail minimap icon design using a WoW-compatible 64x64 TGA loaded without file extension.
- No other functional changes.

## 1.5.12
- Fixed the minimap button showing a solid green placeholder.
- Minimap icon now explicitly loads `ActionTrailIcon.tga` on the ARTWORK layer.
- Slightly adjusted icon size/crop; drag and click behavior unchanged.

## 1.5.11
- Fixed the corrupted Lua source/package published for 1.5.10.
- Restored the complete working GSE executor scan.
- No intended feature changes beyond restoring the tested 1.5.10 behavior.

## 1.5.11
- Fixed the corrupted Lua source/package published for 1.5.10.
- Restored the complete working GSE executor scan.
- No intended feature changes beyond restoring the tested 1.5.10 behavior.

## 1.5.10
- Shortened the action-error toggle label so it fits cleanly in the right-hand options column.
- German: `Aktionsfehler ausblenden`
- English: `Hide action errors`

## 1.5.9
- Hid the long internal GSE executor frame name from normal debug rows.
- Added optional **Technische GSE-Infos anzeigen / Show technical GSE info**.
- Reduced debug-line width and improved readability.

## 1.5.8
- Reworked the options layout to use the available window width more efficiently.
- Moved the action-error toggle into the right-hand column.
- Shifted GSE debug controls upward.
- Kept the existing window height.

## 1.5.7
- Added optional suppression of red WoW action-error messages (`UI_ERROR_MESSAGE`).
- Covers common macro/GSE spam such as `Ability is not ready yet`, `Not enough energy`, and `Out of range`.
- Added `/at errors off` and `/at errors on`.
- Setting persists across reload/login.

## 1.5.6
- GSE debug now records active keyboard modifiers at click time.
- Displays `SHIFT`, `ALT`, `CTRL`, and modifier combinations only when used.

## 1.5.5
- Redesigned the DE/EN language controls.
- Added clearer selected-language state and hover feedback.
- Improved spacing near the close button.

## 1.5.4
- Improved GSE executor detection for alternate/newer executor frames.
- Added support for `step`-only executor detection and `clickbutton` targets.
- Added `/at gsescan`.
- `/at status` reports the number of hooked GSE executors.

## 1.5.3
- Updated addon icon and version metadata.

## 1.5.2
- Fixed startup failure introduced in 1.5.1.
- Restored working German/English localization.

## 1.5.1
- Initial localization work for German/English UI.

## 1.5.0
- Added GSE debug overlay and minimap controls.
- Added Wand Shoot / Auto Shot / melee history options.
- Added configurable history, fade, combat-only mode, positioning, and reset controls.
