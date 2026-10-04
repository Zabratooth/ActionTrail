# ActionTrail

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
- Movable minimap button

## Installation

1. Download the latest release ZIP.
2. Extract the `ActionTrail` folder into:
   `World of Warcraft/_classic_/Interface/AddOns/`
   (use the appropriate WoW Forever AddOns folder for your installation.)
3. Start/reload WoW.
4. Type `/at` to open the settings.

## Language

Use:

- `/at lang de` — German
- `/at lang en` — English

Changing the language reloads the UI so every menu and tooltip is refreshed consistently.

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
- `/at gseclear`
- `/at status`

## GSE diagnostics

ActionTrail does not change a GSE sequence or its secure attributes. The optional debug mode observes GSE executor button clicks and correlates them with the subsequent spell/action reported by the WoW client.

Example:

```text
G40  step 1  Shadow Word: Pain  +103ms
G39  step 1  Shoot [5019]      +244ms
```

This makes it useful for checking whether a sequence advances as expected, whether an action was actually accepted by the client, and how auto-repeat abilities behave.

## Compatibility

Developed and tested for **WoW Forever** (Interface `16001`).

## Privacy / telemetry

ActionTrail contains no telemetry, analytics, account tracking, or network communication.

## License

ActionTrail is released under the **MIT License**. See [LICENSE](LICENSE).

## Disclaimer

ActionTrail is an independent addon and is not affiliated with or endorsed by Blizzard Entertainment or the GSE/WoWLazyMacros projects.

World of Warcraft, game names, spell names, icons, and other game assets are property of Blizzard Entertainment.
