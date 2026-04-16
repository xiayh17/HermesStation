# Hermes Station Menu Bar

Native macOS menu bar app for monitoring and operating Hermes gateway profiles.

## Current scope

- Supports multiple local Hermes profiles, with one active profile at a time
- Reads gateway runtime status from the active profile's Hermes home, for example:
  - `/Users/xiayh/Projects/install_hermers/.hermes-home/profiles/yong/gateway_state.json`
- Controls the gateway via the active profile's launcher command, for example:
  - `/Users/xiayh/Projects/install_hermers/run-hermes-local.sh -p yong gateway ...`

## Features in the current build

- Gateway service state
- Platform connection state
- Active agent count
- Session count and recent sessions
- LaunchAgent install / start / stop / restart
- Open logs / workspace / Hermes home
- Quick profile switching from the menu bar
- Settings window for multi-profile management, gateway paths, polling interval, and model defaults

## Build

```bash
cd /Users/xiayh/Projects/hermes-station-menubar
swift build
```

## Package as a macOS app

```bash
cd /Users/xiayh/Projects/hermes-station-menubar
./scripts/package-app.sh
```

This creates:

```text
dist/HermesStationMenuBar.app
```

## Run the app bundle

```bash
open /Users/xiayh/Projects/hermes-station-menubar/dist/HermesStationMenuBar.app
```
