# ActionTrail

**Current version: 1.5.5**

ActionTrail is a lightweight **World of Warcraft: Forever** addon for visualizing your own recent actions and debugging GSE/WoWLazyMacros sequences.

It is designed as a diagnostic tool: ActionTrail observes what the WoW client reports for your character and displays it. It does **not** cast spells, press buttons, or automate gameplay.

## Features

- Moving history of your recent spell/action icons
- Configurable icon count and size
- Optional fade-out and combat-only visibility
- Optional Wand Shoot, Auto Shot, and melee entries
- Special handling for auto-repeat abilities such as **Shoot (SpellID 5019)**
- Optional GSE debug panel with click number, GSE step, detected spell, and click-to-cast timing
- German and English interface, including minimap tooltip text
- Movable minimap button with dedicated ActionTrail icon
- GSE executor rescan and hook diagnostics

## Installation

1. Download the current ActionTrail ZIP.
2. Extract the `ActionTrail` folder into the appropriate WoW Forever `Interface/AddOns/` folder.
3. Start or reload WoW.
4. Type `/at` to open the settings.

## Language

Use:

- `/at lang de` — German
- `/at lang en` — English

The active language is also selectable from the ActionTrail settings window.

## Useful commands

- `/at` — open settings
- `/at unlock` / `/at lock`
- `/at size 16-64`
- `/at count 1-10`
- `/at minimap on|off`
- `/at wand on|off`
- `/at autoshot on|off`
- `/at melee on|off`
- `/at auto on|off`
- `/at combat on|off`
- `/at fade on|off`
- `/at fadetime 2-20`
- `/at gsedebug on|off`
- `/at gseempty on|off`
- `/at gsescan`
- `/at gseclear`
- `/at status`

## GSE diagnostics

ActionTrail does not change a GSE sequence or its secure attributes. The optional debug mode observes GSE executor button clicks and correlates them with the subsequent spell/action reported by the WoW client.

Example:

```text
G156  step 1  Sinister Strike  +77ms
G121  step 1  Sinister Strike  +93ms
```

`/at gsescan` forces a fresh scan for GSE executor buttons. `/at status` reports the number of hooked GSE executors.

## Compatibility

Developed and tested for **WoW Forever** (Interface `16001`).

## Privacy / telemetry

ActionTrail contains no telemetry, analytics, account tracking, or network communication.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

ActionTrail is released under the **MIT License**. See [LICENSE](LICENSE).

## Disclaimer

ActionTrail is an independent addon and is not affiliated with or endorsed by Blizzard Entertainment or the GSE/WoWLazyMacros projects.

World of Warcraft, game names, spell names, icons, and other game assets are property of Blizzard Entertainment.
