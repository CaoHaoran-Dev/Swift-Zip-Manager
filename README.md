# Swift Zip Manager

macOS archive file manager, built with Swift + SwiftUI.

> Current Version: 1.0.0-Beta.7 · In Development

## Features

- Extract / Create ZIP, TAR, GZ, 7Z, RAR
- Encrypted archives (ZIP / 7Z / RAR with password protection)
- Archive content browsing (List / Grid view)
- Single file extract / Extract all / Delete files from archive
- File browser with sidebar (Desktop, Documents, Downloads, Home, Volumes)
- Drag & drop support for adding files to new archives
- Recent files history
- One-click install 7zz and RAR tools
- Auto update check via GitHub API
- Multi-language support (English, 简体中文, 繁體中文)
- Developer mode (debug tools, experimental features, advanced settings)
- Keyboard shortcuts support

## Tech Stack

- Swift 5 + SwiftUI
- Process / Pipe (command-line tool invocation)
- CryptoKit (AES-256-GCM encryption)
- macOS 13.5+

## Installation

Download the DMG from Releases and drag the App into Applications folder.

> If you see a security warning on first launch, go to "System Settings > Privacy & Security" and click "Open Anyway".

## Usage

**Keyboard Shortcuts**

| Shortcut | Action |
|----------|--------|
| `⌘A` | New Archive |
| `⌘O` | Open Archive |
| `⌘E` | Extract Selected |
| `⌘⇧E` | Extract All |
| `⌘,` | Open Settings |
| `⌘?` | Open Help |
| `⌘W` | Close Window |
| `⌘R` | Show in Finder |

**Quick Start**

1. Click "Open Archive" or press `⌘O` to open an existing archive
2. Click "New Archive" or press `⌘A` to create a new archive
   - Drag files from Finder into the window, or click "Add Files"
   - Select format from dropdown (ZIP, TAR, GZ, 7Z, RAR)
   - Optionally set a password for encryption
   - Destination path is remembered for next time
3. Browse archive contents in list or grid view
4. Select files and use `⌘E` to extract, or right-click for more options
5. Double-click folders to navigate, double-click archives to open

**External Tools**

- 7zz is required for ZIP, 7Z, RAR extraction and 7Z creation
- RAR tool is required for RAR creation
- Both tools can be installed from Settings > Tools

**Developer Mode**

Tap the version number in About page 5 times to enable.

## Known Issues

- None

## License

MIT License

[简体中文](Docs/README.zh.md)
