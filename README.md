# ActionTrail

## ⬇ Download

**[Download ActionTrail 1.5.11 ZIP](https://github.com/Zabratooth/ActionTrail/raw/refs/heads/main/dist/ActionTrail-1.5.11.zip)**

Extract the ZIP and copy the included `ActionTrail` folder to your WoW Forever `Interface/AddOns/` folder.

ActionTrail is a lightweight action-history and GSE diagnostics addon for **WoW Forever**. It shows recent actions as a compact icon trail and can optionally display a live GSE debug history. The addon only observes what the client and GSE do; it does **not** cast spells, automate gameplay, or modify GSE's secure executor.

## Screenshots

### GSE debug

![ActionTrail GSE debug](docs/actiontrail-debug.jpg)

### Options

**English**

![ActionTrail options EN](docs/actiontrail-options-en.jpg)

**Deutsch**

![ActionTrail options DE](docs/actiontrail-options-de.jpg)

## Features

- Sliding history of recent player casts/actions
- Configurable icon count and icon size
- Optional combat-only display
- Optional fade-out
- Minimap button with draggable position
- Auto-repeat handling for:
  - Wand Shoot
  - Auto Shot
  - normal melee attacks
- GSE diagnostics:
  - GSE trigger history
  - running click number
  - active modifiers (`SHIFT`, `ALT`, `CTRL`)
  - cast latency
  - optional no-cast entries
  - configurable debug history length
  - optional technical GSE executor information
- Optional suppression of red action-error spam such as:
  - `Ability is not ready yet`
  - `Not enough energy`
  - `Out of range`
- German / English UI
- No network access, analytics, telemetry, or external services

## Installation

> Do **not** use GitHub's **Code → Download ZIP** for normal addon installation. That downloads the whole repository. Use the addon ZIP linked at the top instead.

1. Download `ActionTrail-1.5.11.zip`.
2. Extract the ZIP. It contains a single `ActionTrail` folder.
3. Copy that folder into the appropriate WoW Forever `Interface/AddOns` folder.
4. Start WoW Forever or use `/reload`.
5. Use `/at` to open the options.

```text
Interface/
└─ AddOns/
   └─ ActionTrail/
      ├─ ActionTrail.lua
      ├─ ActionTrail.toc
      ├─ ActionTrailIcon.png
      ├─ ActionTrailIcon.tga
      ├─ README.md
      └─ LICENSE
```

## Useful commands

```text
/at
/at lang de
/at lang en
/at gsedebug on
/at gsedebug off
/at gsescan
/at gseclear
/at errors off
/at errors on
/at minimap on
/at minimap off
/at status
```

`/at errors off` hides WoW action-error messages. `/at errors on` restores them.

## GSE debug example

```text
G90 [SHIFT] step 1 | Gouge +105ms
G38 [CTRL]  step 1 | Sinister Strike +99ms
G19 [ALT]   step 1 | Slice and Dice +10ms
G10         step 1 | Sinister Strike +94ms
```

The long internal GSE executor frame name is hidden by default and can be enabled with **Show technical GSE info**.

## Compatibility

- WoW Forever
- Interface: `16001`
- Current addon version: **1.5.11**

## Privacy

ActionTrail runs entirely inside the game client. It contains no telemetry, analytics, network requests, or account tracking.

## License

MIT License. See [LICENSE](LICENSE).

## Disclaimer

ActionTrail is an independent community addon. It is not affiliated with or endorsed by Blizzard Entertainment, GSE, or WoWLazyMacros.
