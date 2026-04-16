import SwiftUI
import AppKit

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    private override init() {
        super.init()
    }

    func show(
        settingsStore: SettingsStore,
        profileStore: HermesProfileStore,
        gatewayStore: GatewayStore
    ) {
        let window = window ?? makeWindow(
            settingsStore: settingsStore,
            profileStore: profileStore,
            gatewayStore: gatewayStore
        )

        if self.window == nil {
            self.window = window
        } else {
            refreshContent(
                settingsStore: settingsStore,
                profileStore: profileStore,
                gatewayStore: gatewayStore
            )
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    private func makeWindow(
        settingsStore: SettingsStore,
        profileStore: HermesProfileStore,
        gatewayStore: GatewayStore
    ) -> NSWindow {
        let contentView = AnyView(
            SettingsView()
                .environmentObject(settingsStore)
                .environmentObject(profileStore)
                .environmentObject(gatewayStore)
        )

        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1080, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Settings"
        window.contentViewController = hostingController
        window.delegate = self
        window.minSize = NSSize(width: 980, height: 620)
        window.setFrameAutosaveName("HermesStationMenuBar.Settings")
        window.isReleasedWhenClosed = false
        window.center()

        return window
    }

    private func refreshContent(
        settingsStore: SettingsStore,
        profileStore: HermesProfileStore,
        gatewayStore: GatewayStore
    ) {
        guard let window else { return }

        let contentView = AnyView(
            SettingsView()
                .environmentObject(settingsStore)
                .environmentObject(profileStore)
                .environmentObject(gatewayStore)
        )

        if let hostingController = window.contentViewController as? NSHostingController<AnyView> {
            hostingController.rootView = contentView
        } else {
            window.contentViewController = NSHostingController(rootView: contentView)
        }
    }
}
