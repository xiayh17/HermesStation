# HermesStation

A native macOS menu bar app for monitoring and operating [Hermes](https://github.com/xiayh17/hermes) gateway profiles.

[![macOS](https://img.shields.io/badge/macOS-14.0+-333333?logo=apple)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.2-F05138?logo=swift)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Download

Download the latest release from the [Releases](https://github.com/xiayh17/HermesStation/releases) page.

## Features

- **Gateway service state** — Monitor gateway status directly from the menu bar
- **Platform connection state** — See which platforms are connected, disconnected, or connecting at a glance
- **Active agent count** — Track how many agents are currently running
- **Session count and recent sessions** — View 24-hour and 7-day usage statistics
- **Service controls** — Install, start, stop, restart, or repair the gateway LaunchAgent
- **Quick profile switching** — Switch between multiple Hermes profiles instantly from the menu bar
- **Settings** — Configure multi-profile management, gateway paths, polling intervals, and model defaults

## Requirements

- macOS 14.0+
- Swift 6.2
- A local Hermes installation

## Build from source

```bash
git clone https://github.com/xiayh17/HermesStation.git
cd HermesStation
swift build
```

## Package as a macOS app

```bash
./scripts/package-app.sh
```

This creates:

```
dist/HermesStationMenuBar.app
```

You can then open it with:

```bash
open dist/HermesStationMenuBar.app
```

## Architecture

This is a macOS menu bar app (`LSUIElement`) that monitors and controls a Hermes gateway instance. It runs as a background-only app with a popover UI from the menu bar icon.

### Core Stores

| Store | Responsibility |
|-------|----------------|
| `SettingsStore` | Reads/writes `~/Library/Application Support/HermesStationMenuBar/settings.json` |
| `HermesProfileStore` | Reads Hermes `config.yaml` + `.env`; writes via `hermes config set` CLI |
| `GatewayStore` | Polls `gateway_state.json` + `state.db` on a timer; drives service control via launcher script |

### Data Flow

- **Path derivation**: `AppSettings` → `HermesPaths` computes all filesystem paths from profile name + project root
- **Gateway status**: `GatewayStore.makeSnapshot()` reads `gateway_state.json`, checks `launchctl list`, and queries `state.db` (SQLite) for sessions
- **External commands**: All subprocess execution goes through `CommandRunner` (async `Process` wrapper)

## License

MIT License — see [LICENSE](LICENSE) for details.
