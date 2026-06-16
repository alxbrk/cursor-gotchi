# Changelog

All notable changes to Cursor Gotchi are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
- **Usage alerts.** macOS notifications when Cursor usage crosses **70%** and **90%** of the
  billing cycle (once per cycle each). Toggle on/off in Settings.
- **In-app settings panel.** Rename your pet, pick a species, and toggle usage/evolution
  alerts — no CLI required. Open via the **Settings** button in the floating panel.
- **Light theme for the menu bar panel.** The floating panel now adapts to the
  macOS system appearance, switching live between dark and light mode. A new
  `PanelTheme` helper drives all panel colors — backgrounds, text shades,
  progress-bar tracks, buttons, and the pixel sprite outline/mouth.

### Changed
- **Unified panel chrome.** The floating window is now a single borderless card with
  an integrated header, close button, and shadow — no broken macOS title bar gaps.
- **Header-only drag.** The panel can be moved from the title bar without blocking
  clicks on settings controls below.

### Fixed
- **Startup crash** when incompatible window collection behaviors were combined
  (`canJoinAllSpaces` + `moveToActiveSpace`).
- **Invisible panel** after the settings UI was added (SwiftUI content had no fixed
  height inside the hosting controller).
- **Settings toggles** not reflecting on/off state — `@Published` now updates when
  preferences change.
- **Name field not editable** in the borderless panel — the window can now become key
  (`KeyablePanel`) and uses a native AppKit text field for reliable keyboard input.
