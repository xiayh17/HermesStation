# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
swift build                        # debug build
./scripts/package-app.sh           # build + bundle into dist/HermesStation.app
open dist/HermesStation.app        # launch the app
pkill -f HermesStation             # kill running instance before relaunch
```

No tests, no linter, no Xcode project. The project uses Swift Package Manager (`Package.swift`) with Swift 6.2, targeting macOS 14+. Links `libsqlite3` at the system level.

## Architecture

This is a **macOS menu bar app** (`LSUIElement`) that monitors and controls a Hermes gateway instance. It runs as a background-only app with a popover UI from the menu bar icon.

### Object Graph

```
HermesStationApp (@main)
 ├── SettingsStore        — reads/writes ~/Library/Application Support/HermesStation/settings.json
 ├── HermesProfileStore   — reads Hermes config.yaml + .env; writes via `hermes config set` CLI
 └── GatewayStore         — polls gateway_state.json + state.db on a timer; drives service control via launcher script
```

All three stores are `@MainActor ObservableObject`s, injected via `@EnvironmentObject`. `SettingsStore` is the root dependency — both `HermesProfileStore` and `GatewayStore` subscribe to its `$settings` publisher.

### Key Data Flow

- **Path derivation**: `AppSettings` → `HermesPaths` computes all filesystem paths (hermesHome, logs, state DB, LaunchAgent plist, etc.) from profile name + project root.
- **Gateway status**: `GatewayStore.makeSnapshot()` reads `gateway_state.json` (JSON), checks `launchctl list` for service status, and queries `state.db` (SQLite) for sessions.
- **External commands**: All subprocess execution goes through `CommandRunner` (async `Process` wrapper). Gateway control uses the launcher shell script; Hermes config changes use the `hermes` CLI.
- **Provider mapping**: `HermesProviderDescriptor` maps provider IDs to their API key env vars and base URL env vars. This determines which `.env` keys to read/write.

### UI Structure

- `MenuContentView` — the popover shown when clicking the menu bar icon (status, service controls, sessions, utilities)
- `SettingsView` — separate `NSWindow` managed by `SettingsWindowController` (singleton). Uses `TabView` with three tabs: General (app config), Model (provider/model/API key), Environment (paths/cwd).
- `SettingsWindowController` — wraps an `NSWindow` that toggles activation policy between `.accessory` and `.regular` so the app gains a Dock icon while settings are open.

### Persistence

| Data | Location | Format |
|------|----------|--------|
| App settings | `~/Library/Application Support/HermesStation/settings.json` | JSON (Codable) |
| Hermes config | `{hermesHome}/config.yaml` | YAML (hand-parsed) |
| Hermes secrets | `{hermesHome}/.env` | dotenv (hand-parsed) |
| Session data | `{hermesHome}/state.db` | SQLite3 (C API, read-only) |
| Gateway state | `{hermesHome}/gateway_state.json` | JSON (Decodable) |
