import SwiftUI
import AppKit

@main
struct HermesStationMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settingsStore: SettingsStore
    @StateObject private var profileStore: HermesProfileStore
    @StateObject private var store: GatewayStore

    init() {
        let settingsStore = SettingsStore()
        let profileStore = HermesProfileStore(settingsStore: settingsStore)
        _settingsStore = StateObject(wrappedValue: settingsStore)
        _profileStore = StateObject(wrappedValue: profileStore)
        _store = StateObject(wrappedValue: GatewayStore(settingsStore: settingsStore, profileStore: profileStore))
    }

    var body: some Scene {
        MenuBarExtra("HermesStation", systemImage: store.snapshot.menuBarSymbol) {
            MenuContentView()
                .environmentObject(store)
                .environmentObject(settingsStore)
                .environmentObject(profileStore)
        }
        .menuBarExtraStyle(.window)
    }
}
