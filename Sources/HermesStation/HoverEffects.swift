import SwiftUI

struct HoverPlate: ViewModifier {
    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = 6

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isHovering ? plateColor : Color.clear)
                    .animation(.easeOut(duration: 0.12), value: isHovering)
            )
            .overlay(
                HoverTrackingArea(isHovering: $isHovering)
            )
    }

    private var plateColor: Color {
        switch colorScheme {
        case .dark:
            return Color(nsColor: .labelColor).opacity(0.06)
        default:
            return Color(nsColor: .black).opacity(0.095)
        }
    }
}

struct HoverScale: ViewModifier {
    @State private var isHovering = false
    var scale: CGFloat = 1.02

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovering ? scale : 1.0)
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .overlay(
                HoverTrackingArea(isHovering: $isHovering)
            )
    }
}

private struct HoverTrackingArea: NSViewRepresentable {
    @Binding var isHovering: Bool

    func makeNSView(context: Context) -> NSView {
        let view = TrackingView()
        view.onHoverChanged = { hovering in
            DispatchQueue.main.async {
                self.isHovering = hovering
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class TrackingView: NSView {
        var onHoverChanged: ((Bool) -> Void)?
        private var trackingArea: NSTrackingArea?

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let trackingArea {
                removeTrackingArea(trackingArea)
            }
            let area = NSTrackingArea(
                rect: .zero,
                options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(area)
            self.trackingArea = area
        }

        override func mouseEntered(with event: NSEvent) {
            onHoverChanged?(true)
        }

        override func mouseExited(with event: NSEvent) {
            onHoverChanged?(false)
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            return nil
        }
    }
}

extension View {
    func hoverPlate(cornerRadius: CGFloat = 6) -> some View {
        modifier(HoverPlate(cornerRadius: cornerRadius))
    }

    func hoverScale(_ scale: CGFloat = 1.02) -> some View {
        modifier(HoverScale(scale: scale))
    }
}
