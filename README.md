# Swift Zip Manager

macOS archive file manager, built with Swift + SwiftUI.

> Current Version: 1.0.0-Beta.6 · In Development

## Features

- Extract / Create ZIP, TAR, GZ, 7Z, RAR
- Encrypted archives (ZIP / 7Z / RAR with password protection)
- Archive content browsing (List / Grid view)
- Single file extract / Extract all / Delete files
- File browser (sidebar with quick access to common directories)
- Recent files history
- One-click install 7zz and RAR tools
- Auto update check (GitHub API)
- Multi-language support (14 languages, WIP)
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

- `⌘O` Open archive, `⌘A` New archive
- `⌘E` Extract selected, `⌘⇧E` Extract all
- `⌘,` Open settings, `⌘?` Open help
- Quick access to common directories from sidebar, double-click archives to load

## Known Issues

- Multi-language support not fully implemented (only English available)

## License

MIT License

[简体中文](README.zh.md)
