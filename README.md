# MidnightMinimap

**MidnightMinimap** is a lightweight World of Warcraft addon that gives the minimap a Midnight / Dragonflight-inspired look. It supports **TBC Anniversary** and has an **untested-in-game port for World of Warcraft: Forever**.

## Important attribution

**MidnightMinimap is a fork/spin-off of Dragonflight UI Classic, made specifically to keep only the minimap portion.**

It exists because I wanted the minimap look from **Dragonflight UI Classic** without installing the rest of that UI package.

Original addon: [Dragonflight UI Classic](https://www.curseforge.com/wow/addons/dragonflight-ui-classic)

Credit goes to **Karl-Heinz Schneider** for the original DragonflightUI work and the minimap styling and assets this addon is based on. If you want the full UI experience, please use Dragonflight UI Classic instead.

## What the addon does

MidnightMinimap restyles the default minimap with:

- A custom round border and styled header with zone text and an optional clock
- A restyled tracking button and mail indicator
- Optional player coordinates
- Saved visibility choices

On **TBC Anniversary**, it also applies a custom round mask, supports mouse wheel zoom, and saves the minimap's position and scale. The frame can be moved and locked with mouse shortcuts.

On **Forever**, it keeps Blizzard's round mask, mouse wheel zoom, minimap ping, tracking menu, and calendar controls. The addon draws its border and header around Blizzard's Edit Mode minimap; **Edit Mode manages its position and scale**. Its border, coordinates and mail indicator hang from the minimap's container, not from the minimap itself, so an addon that briefly moves the minimap (NodeRadar's scan mode) doesn't take them along.

## Commands

Use `/midnightminimap` or `/mm`.

| Command | TBC Anniversary | Forever |
| --- | --- | --- |
| `/mm coords` | Toggle coordinates | Toggle Blizzard's Player Minimap Coordinates setting |
| `/mm header` | Toggle the header | Toggle the header |
| `/mm clock` | Toggle the clock | Toggle the clock |
| `/mm zone` | Toggle zone text | Toggle zone text |
| `/mm reset` | Reset addon settings, position, and scale | Reset addon visibility choices |
| `/mm lock` | Toggle frame lock | Directs you to Edit Mode |
| `/mm scale <n>` | Set scale from 0.5 to 3.0 | Directs you to Edit Mode |

On both clients, `/mm coord` and `/mm xy` also toggle coordinates.

On Forever, the coordinates follow Blizzard's own settings in Options > Interface: **Player Minimap Coordinates** shows them and **Coordinates by Tenths** sets their precision. The addon shows them in its own style in place of Blizzard's text, so there is one readout and one setting.

## Moving the minimap

- **TBC Anniversary:** Shift + Drag to move the minimap. Shift + Right-Click to lock or unlock it.
- **Forever:** Use Blizzard's Edit Mode to move or scale the minimap. The addon follows the Edit Mode minimap.

## Scope

This addon is intentionally focused on the minimap. It does not aim to recreate the entire Dragonflight UI Classic addon.

## Compatibility

- **TBC Anniversary:** Interface 20505.
- **World of Warcraft: Forever:** Interface 16001. The Forever port was checked against Blizzard's 1.60.1.70450 UI source and passed Lua 5.1 syntax and offline startup checks. **It has not been tested in game because the beta ended.**

## Credits

- **MidnightMinimap** by Spotnick
- Based on / forked from **Dragonflight UI Classic**
- Original DragonflightUI minimap styling and related assets by **Karl-Heinz Schneider**
