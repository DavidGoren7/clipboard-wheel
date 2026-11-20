import AppKit
import SwiftUI
import ClipboardWheelCore

final class WheelViewModel: ObservableObject {
    @Published var items: [ClipItem] = []
    @Published var hoveredIndex: Int?
    @Published var canPin = true
    @Published var isPresented = false

    static let sampleItems: [ClipItem] = [
        ("Hold ⌘V to open the wheel", false),
        ("Let go over a slice to paste it", false),
        ("Right-click a slice to pin it", true),
        ("hello@example.com", false),
        ("Let go in the middle to cancel", false),
    ].map { ClipItem(content: .text($0.0), pinned: $0.1, lastUsed: Date()) }
}

/// The wheel: a glass disc split into one slice per item, with the hovered slice lit up.
struct WheelView: View {
    @ObservedObject var model: WheelViewModel
    let imageProvider: (String) -> NSImage?

    private let outer = WheelController.outerRadius
    private let inner = WheelController.deadZoneRadius
    private var geometry: WheelGeometry {
        WheelGeometry(sliceCount: model.items.count, deadZoneRadius: inner)
    }

    var body: some View {
        ZStack {
            glassDisc
            if model.items.isEmpty {
                Text("Nothing copied yet")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .offset(y: -(inner + outer) / 2)
            } else {
                hoverHighlight
                separators
                labels
            }
            hub
        }
        .frame(width: WheelPanel.side, height: WheelPanel.side)
        .scaleEffect(model.isPresented ? 1 : 0.85)
        .opacity(model.isPresented ? 1 : 0)
        .animation(.spring(duration: 0.18, bounce: 0.25), value: model.isPresented)
    }

    // MARK: - Parts

    @ViewBuilder private var glassDisc: some View {
        let disc = Circle().frame(width: outer * 2, height: outer * 2)
        if #available(macOS 26.0, *) {
            Color.clear
                .frame(width: outer * 2, height: outer * 2)
                .glassEffect(.regular, in: Circle())
                .shadow(color: .black.opacity(0.18), radius: 14, y: 4)
        } else {
            disc
                .foregroundStyle(.ultraThinMaterial)
                .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                .shadow(color: .black.opacity(0.18), radius: 14, y: 4)
        }
    }

    @ViewBuilder private var hoverHighlight: some View {
        if let index = model.hoveredIndex, index < model.items.count {
            let bounds = geometry.bounds(ofSlice: index)
            let sector = AnnularSector(
                startAngle: bounds.start, endAngle: bounds.end,
                innerRadius: inner + 3, outerRadius: outer - 3
            )
            sector
                .fill(Color.accentColor.opacity(0.28), style: FillStyle(eoFill: true))
                .overlay(sector.stroke(Color.accentColor.opacity(0.55), lineWidth: 1.5))
                .animation(.easeOut(duration: 0.08), value: index)
        }
    }

    @ViewBuilder private var separators: some View {
        if model.items.count > 1 {
            Path { path in
                let c = CGPoint(x: WheelPanel.side / 2, y: WheelPanel.side / 2)
                for index in 0..<model.items.count {
                    let angle = geometry.bounds(ofSlice: index).start
                    path.move(to: Self.point(c, angle: angle, radius: inner))
                    path.addLine(to: Self.point(c, angle: angle, radius: outer))
                }
            }
            .stroke(.primary.opacity(0.14), lineWidth: 1)
        }
    }

    /// Labels sit in the middle of the ring.
    private var labelRadius: CGFloat { (inner + outer) / 2 }

    private var labels: some View {
        let c = CGPoint(x: WheelPanel.side / 2, y: WheelPanel.side / 2)
        return ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
            SliceLabel(
                item: item,
                isHovered: index == model.hoveredIndex,
                showsPin: model.canPin && item.pinned,
                maxWidth: labelWidth(atAngle: geometry.centerAngle(ofSlice: index)),
                maxLines: labelLines,
                imageProvider: imageProvider
            )
            .position(Self.point(c, angle: geometry.centerAngle(ofSlice: index), radius: labelRadius))
        }
    }

    private var hub: some View {
        ZStack {
            Circle()
                .fill(.primary.opacity(0.05))
                .overlay(Circle().strokeBorder(.primary.opacity(0.12), lineWidth: 1))
            Image(systemName: model.hoveredIndex == nil ? "xmark" : "doc.on.clipboard")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(width: inner * 2 - 8, height: inner * 2 - 8)
    }

    // MARK: - Layout helpers

    /// Width a label can use without crossing into the next slice or past the rim.
    /// Top and bottom labels are limited by the slice's width; side labels by the rim.
    private func labelWidth(atAngle angle: Double) -> CGFloat {
        let count = model.items.count
        let x = abs(sin(angle)) * labelRadius
        let y = abs(cos(angle)) * labelRadius
        let rimLimit = outer - 10
        let rimRoom = 2 * ((rimLimit * rimLimit - y * y).squareRoot() - x)
        let sliceRoom = count > 2 ? 2 * labelRadius * sin(.pi / CGFloat(count)) - 8 : .greatestFiniteMagnitude
        return max(60, min(120, sliceRoom, rimRoom))
    }

    private var labelLines: Int {
        switch model.items.count {
        case ...4: 4
        case ...9: 3
        default: 2
        }
    }

    /// A point at a clockwise-from-top angle and radius, in the view's y-down coordinates.
    static func point(_ center: CGPoint, angle: Double, radius: CGFloat) -> CGPoint {
        CGPoint(x: center.x + sin(angle) * radius, y: center.y - cos(angle) * radius)
    }
}

/// What a slice shows: a text snippet or an image thumbnail, plus a pin if pinned.
private struct SliceLabel: View {
    let item: ClipItem
    let isHovered: Bool
    let showsPin: Bool
    let maxWidth: CGFloat
    let maxLines: Int
    let imageProvider: (String) -> NSImage?

    var body: some View {
        VStack(spacing: 3) {
            switch item.content {
            case let .text(text):
                Text(Self.snippet(text))
                    .font(.system(size: 11, weight: isHovered ? .semibold : .regular))
                    .multilineTextAlignment(.center)
                    .lineLimit(maxLines)
                    .frame(maxWidth: maxWidth)
            case let .image(fileName):
                if let image = imageProvider(fileName) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: min(maxWidth, 64), maxHeight: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
            }
            if showsPin {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .foregroundStyle(.primary)
        .scaleEffect(isHovered ? 1.06 : 1)
        .animation(.easeOut(duration: 0.1), value: isHovered)
    }

    /// One line of text with runs of spaces and newlines collapsed.
    static func snippet(_ text: String) -> String {
        String(text.split(whereSeparator: \.isWhitespace).joined(separator: " ").prefix(120))
    }
}

/// A ring slice between two radii, from `startAngle` to `endAngle` (radians, clockwise
/// from 12 o'clock). A full turn draws the whole ring; fill it with `eoFill`.
nonisolated struct AnnularSector: Shape {
    var startAngle: Double
    var endAngle: Double
    var innerRadius: CGFloat
    var outerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        if endAngle - startAngle >= 2 * .pi - 0.0001 {
            path.addEllipse(in: CGRect(x: center.x - outerRadius, y: center.y - outerRadius, width: outerRadius * 2, height: outerRadius * 2))
            path.addEllipse(in: CGRect(x: center.x - innerRadius, y: center.y - innerRadius, width: innerRadius * 2, height: innerRadius * 2))
            return path
        }
        // SwiftUI measures angles from 3 o'clock, so shift by a quarter turn.
        let start = Angle(radians: startAngle - .pi / 2)
        let end = Angle(radians: endAngle - .pi / 2)
        path.addArc(center: center, radius: outerRadius, startAngle: start, endAngle: end, clockwise: false)
        path.addArc(center: center, radius: innerRadius, startAngle: end, endAngle: start, clockwise: true)
        path.closeSubpath()
        return path
    }
}

// MARK: - Previews

private func previewModel(_ texts: [String], hovered: Int? = nil, pinned: Set<Int> = []) -> WheelViewModel {
    let model = WheelViewModel()
    model.items = texts.enumerated().map { index, text in
        ClipItem(content: .text(text), pinned: pinned.contains(index), lastUsed: Date())
    }
    model.hoveredIndex = hovered
    model.isPresented = true
    return model
}

#Preview("Empty") {
    WheelView(model: previewModel([]), imageProvider: { _ in nil })
}

#Preview("1 item") {
    WheelView(model: previewModel(["Only thing copied"], hovered: 0), imageProvider: { _ in nil })
}

#Preview("2 items") {
    WheelView(model: previewModel(["Top half", "Bottom half"], hovered: 1), imageProvider: { _ in nil })
}

#Preview("3 items") {
    WheelView(model: previewModel(["One", "Two", "Three"], hovered: 0, pinned: [2]), imageProvider: { _ in nil })
}

#Preview("4 items") {
    WheelView(model: previewModel(["Up", "Right", "Down", "Left"], hovered: 1), imageProvider: { _ in nil })
}

#Preview("8 items") {
    WheelView(
        model: previewModel(
            ["git status", "hello@example.com", "Meeting at 3pm in room 204", "https://github.com",
             "Thanks so much!", "let x = 42", "123 Main Street, Springfield", "TODO: write tests"],
            hovered: 2,
            pinned: [1, 5]
        ),
        imageProvider: { _ in nil }
    )
}
