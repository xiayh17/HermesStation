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
            )
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.12)) {
                    isHovering = hovering
                }
            }
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
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.12)) {
                    isHovering = hovering
                }
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
