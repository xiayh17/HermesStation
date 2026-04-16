import SwiftUI
import AppKit

@MainActor
struct PopoverChartTrigger<Content: View>: NSViewRepresentable {
    @Binding var isPresented: Bool
    @ViewBuilder let content: () -> Content

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if isPresented, !context.coordinator.popover.isShown {
            let controller = NSHostingController(rootView: content())
            let size = controller.sizeThatFits(in: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
            controller.preferredContentSize = size
            context.coordinator.popover.contentViewController = controller
            context.coordinator.popover.show(relativeTo: nsView.bounds, of: nsView, preferredEdge: .maxX)
        } else if !isPresented, context.coordinator.popover.isShown {
            context.coordinator.popover.close()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    class Coordinator {
        let popover: NSPopover

        init() {
            self.popover = NSPopover()
            self.popover.behavior = .transient
            self.popover.animates = true
        }
    }
}
