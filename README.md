# Hotdock

A lightweight macOS menu bar utility that lets you switch between dock applications using keyboard shortcuts.

## Features

- **Keyboard shortcuts**: Press `Ctrl + number` to toggle dock apps by position
- **Multi-digit support**: For docks with more than 9 items, press `Ctrl + 1 + 3` (within 400ms) to toggle position 13
- **Visual badges**: Hold `Ctrl` to see position numbers overlaid on dock icons
- **Full dock support**: Works with apps, folders, and files in your dock

## Installation

### Option 1: Download Release

Download the latest `Hotdock-X.X.X.dmg` from [Releases](https://github.com/bartbriek/hotdock/releases), open it, and drag Hotdock to Applications.

**Note:** Since the app is not code-signed, macOS may show a "damaged" warning. To fix this, run in Terminal:

```bash
xattr -cr /Applications/Hotdock.app
```

Or right-click the app → "Open" → Click "Open" in the dialog.


### Option 2: Build from Source

```bash
git clone https://github.com/bartbriek/hotdock.git
cd hotdock
./scripts/build.sh
open .build/Hotdock-1.0.0.dmg
```

## Usage

1. **Launch Hotdock** - A dock icon appears in your menu bar
2. **Grant Accessibility permission** when prompted (required for keyboard shortcuts)
3. **Hold Ctrl** to see position numbers on dock icons
4. **Press Ctrl + number** to toggle that app:
   - If running and active: hides the app
   - If running but inactive: brings to front
   - If not running: launches the app

### Multi-digit shortcuts

For positions 10+, type digits quickly while holding Ctrl:

- `Ctrl + 1 + 0` = position 10
- `Ctrl + 1 + 3` = position 13
- `Ctrl + 2 + 5` = position 25

Digits are combined after 400ms of no input or when Ctrl is released.

## Permissions

Hotdock requires **Accessibility permission** to:
- Capture global keyboard shortcuts
- Read dock icon positions

To grant permission:
1. Open **System Settings** > **Privacy & Security** > **Accessibility**
2. Enable **Hotdock**

## Menu Bar

Click the menu bar icon to:
- See current shortcuts
- **Refresh Dock** - Update positions after dock changes
- **Quit Hotdock**

## Requirements

- macOS 12.0 (Monterey) or later
- Accessibility permission


### Building

```bash
./scripts/build.sh 1.0.0

# Output: .build/Hotdock-1.0.0.dmg
```

## License

MIT
