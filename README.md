# drpurr-tweaks

A collection of small UI tweaks for **WoW Forever** (interface 16001). Each tweak has its own on/off toggle.

Settings: **Esc → Options → AddOns → drpurr-tweaks** (saved account-wide).

## Tweaks

### General
- **Mouse button labels (M4/M5)**: shows Mouse Button 4/5 keybinds on Blizzard action bars as `M4`/`M5`.

### Tooltip
- **Anchor tooltip to mouse**: tooltips that normally appear in Blizzard's default bottom-right spot follow the cursor instead.
  - Anchor corner: Bottom Left / Bottom Right / Top Left / Top Right (the side of the cursor the tooltip opens on)
  - Offset X / Offset Y (−50 to 50)
- **Skin tooltips**: background, border and font from LibSharedMedia-3.0.
  - Background texture, color, opacity
  - Border texture, color, opacity, size
  - Font, font size, font outline
- **Smart border color**: colours the border by item quality, NPC reaction or player class.

## Install

Copy the `drpurr-tweaks` folder into `World of Warcraft/<client>/Interface/AddOns/`.

## Libraries

Embedded in `Libs/`: LibStub, CallbackHandler-1.0, LibSharedMedia-3.0.
