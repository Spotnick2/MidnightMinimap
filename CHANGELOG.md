# Midnight MiniMap Changelog

## Unreleased
- Forever: Blizzard's day/night disc is hidden, since it sat on the Midnight border. `/mm daycycle` shows it again.
- Forever: Blizzard's calendar button stays above the header, like the clock.
- Also published on Wago Addons, and as a GitHub Release with the release.json addon managers such as WowUp read.
- Forever: the coordinates follow Blizzard's Player Minimap Coordinates and Coordinates by Tenths settings, and replace Blizzard's own text instead of adding a second readout. `/mm coords` toggles Blizzard's setting; a v1.1.0 coordinates toggle that was on turns it on once.
- Forever: the border, coordinates and mail indicator no longer move with the minimap when another addon briefly borrows it (NodeRadar's scan mode).

## v1.1.0
- Add World of Warcraft: Forever support (Interface 16001) alongside TBC Anniversary.
- Style Forever's Edit Mode minimap without moving or reparenting Blizzard's minimap cluster.
- Add a Forever header, tracking button, mail indicator, and optional coordinates.
- Keep minimap movement and scaling in Blizzard's Edit Mode on Forever.
- This Forever port has been checked offline against the 1.60.1.70450 UI source and Lua 5.1, but has not been tested in game.

## v1.0
- Initial release
