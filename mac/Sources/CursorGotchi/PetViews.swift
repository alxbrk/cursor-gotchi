import SwiftUI

enum SpriteBounds {
    static func of(_ rows: [String]) -> (minX: Int, minY: Int, maxX: Int, maxY: Int)? {
        var minX = Int.max
        var minY = Int.max
        var maxX = -1
        var maxY = -1
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() where ch != "." {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= 0 else { return nil }
        return (minX, minY, maxX, maxY)
    }
}

struct PixelSpriteView: View {
    let rows: [String]
    let bodyColor: Color
    var pixelSize: CGFloat = 5
    var outlineColor: Color = Color(white: 0.88)
    var mouthColor: Color = Color(white: 0.55)

    var body: some View {
        Canvas { context, size in
            for (y, row) in rows.enumerated() {
                for (x, ch) in row.enumerated() {
                    guard ch != ".", let color = color(for: ch) else { continue }
                    let rect = CGRect(
                        x: CGFloat(x) * pixelSize,
                        y: CGFloat(y) * pixelSize,
                        width: pixelSize - 0.5,
                        height: pixelSize - 0.5
                    )
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: 16 * pixelSize, height: 16 * pixelSize)
    }

    private func color(for ch: Character) -> Color? {
        switch ch {
        case "O", "E", "X": return outlineColor
        case "B": return bodyColor
        case "H": return .white
        case "M": return mouthColor
        default: return bodyColor
        }
    }
}

/// Menu bar variant: crops empty sprite padding and scales to fill the icon slot.
struct TrimmedPixelSpriteView: View {
    let rows: [String]
    let bodyColor: Color
    var targetSize: CGFloat = 18
    var outlineColor: Color = Color(white: 0.88)
    var mouthColor: Color = Color(white: 0.55)

    var body: some View {
        if let bounds = SpriteBounds.of(rows) {
            let contentWidth = bounds.maxX - bounds.minX + 1
            let contentHeight = bounds.maxY - bounds.minY + 1
            let pixelSize = min(
                targetSize / CGFloat(contentWidth),
                targetSize / CGFloat(contentHeight)
            )
            let drawWidth = CGFloat(contentWidth) * pixelSize
            let drawHeight = CGFloat(contentHeight) * pixelSize

            Canvas { context, _ in
                for y in bounds.minY...bounds.maxY {
                    let row = rows[y]
                    for x in bounds.minX...bounds.maxX {
                        let index = row.index(row.startIndex, offsetBy: x)
                        let ch = row[index]
                        guard ch != ".", let color = color(for: ch) else { continue }
                        let rect = CGRect(
                            x: CGFloat(x - bounds.minX) * pixelSize,
                            y: CGFloat(y - bounds.minY) * pixelSize,
                            width: pixelSize - 0.35,
                            height: pixelSize - 0.35
                        )
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
            .frame(width: drawWidth, height: drawHeight)
            .frame(width: targetSize, height: targetSize)
        }
    }

    private func color(for ch: Character) -> Color? {
        switch ch {
        case "O", "E", "X": return outlineColor
        case "B": return bodyColor
        case "H": return .white
        case "M": return mouthColor
        default: return bodyColor
        }
    }
}

struct StatBar: View {
    let label: String
    let value: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                Spacer()
                Text("\(Int(value.rounded()))")
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(Color(white: 0.72))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(white: 0.22))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(tint)
                        .frame(width: geo.size.width * CGFloat(min(100, max(0, value)) / 100))
                }
            }
            .frame(height: 8)
        }
    }
}

struct PetPanelView: View {
    @ObservedObject var store: PetStore
    @ObservedObject var usageStore: UsageStore
    var onRefresh: () -> Void = {}
    var onQuit: () -> Void = {}

    var body: some View {
        VStack(spacing: 16) {
            UsageBalanceCard(usage: usageStore.usage)

            if let state = store.state {
                Text("\(store.stage.name) · \(store.mood)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(white: 0.62))

                PixelSpriteView(
                    rows: Sprites.rows(
                        stage: store.stage.level,
                        mood: Sprites.moodKey(
                            hunger: state.hunger,
                            happiness: state.happiness,
                            mood: store.mood
                        ),
                        frame: store.animFrame
                    ),
                    bodyColor: store.bodyColor
                )
                .padding(.vertical, 4)

                VStack(spacing: 12) {
                    StatBar(label: "HUN", value: state.hunger, tint: Color(red: 0.89, green: 0.58, blue: 0.30))
                    StatBar(label: "HAP", value: state.happiness, tint: Color(red: 0.25, green: 0.64, blue: 0.40))
                }

                if let next = PetLogic.nextStage(after: store.stage) {
                    let (pct, _) = PetLogic.evolveProgress(tokens: state.lifetimeTokens, stage: store.stage)
                    Text("EVO \(pct)% · \(PetLogic.formatTokens(state.lifetimeTokens)) / \(PetLogic.formatTokens(next.minTokens))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color(white: 0.45))
                }

                Text("\(state.name) · fed \(PetLogic.formatTokens(state.lifetimeTokens))")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(white: 0.40))
            } else {
                Text("No pet found")
                    .foregroundStyle(.secondary)
                Text("Run ./scripts/install.sh")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 8) {
                PanelButton(title: "Refresh", systemImage: "arrow.clockwise", action: onRefresh)
                PanelButton(title: "Quit", systemImage: "power", action: onQuit)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(width: 240)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.16, green: 0.16, blue: 0.16))
        )
    }
}

struct PanelButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(white: 0.82))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(white: hovering ? 0.26 : 0.18))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct UsageBalanceCard: View {
    let usage: UsageSnapshot?

    private func barColor(_ pct: Double) -> Color {
        if pct >= 0.9 { return Color(red: 0.95, green: 0.45, blue: 0.40) }
        if pct >= 0.7 { return Color(red: 0.95, green: 0.70, blue: 0.30) }
        return Color(red: 0.35, green: 0.61, blue: 0.91)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Usage")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(white: 0.72))
                Spacer()
                if let plan = usage?.planName {
                    Text(plan)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(white: 0.45))
                }
            }

            if let usage, let pct = usage.usedPercent {
                let fraction = min(1, Double(pct) / 100.0)

                (Text("\(pct)%")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.white)
                 + Text("  used")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(white: 0.5)))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(white: 0.22))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(barColor(fraction))
                            .frame(width: max(4, geo.size.width * fraction))
                    }
                }
                .frame(height: 8)

                if let reset = usage.resetText {
                    Text(reset)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(white: 0.5))
                }
            } else if let message = usage?.error, !message.isEmpty {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 0.95, green: 0.55, blue: 0.45))
            } else {
                Text("Fetching from Cursor…")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(white: 0.45))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(white: 0.12))
        )
        .help(usage?.detailLine ?? "Cursor usage")
    }
}

struct MenuBarIcon: View {
    @ObservedObject var store: PetStore
    @Environment(\.colorScheme) private var colorScheme

    private var outlineColor: Color {
        colorScheme == .dark ? Color(white: 0.88) : Color(red: 0.16, green: 0.16, blue: 0.16)
    }

    var body: some View {
        if let state = store.state {
            TrimmedPixelSpriteView(
                rows: Sprites.rows(
                    stage: store.stage.level,
                    mood: Sprites.moodKey(
                        hunger: state.hunger,
                        happiness: state.happiness,
                        mood: store.mood
                    ),
                    frame: store.animFrame
                ),
                bodyColor: store.bodyColor,
                targetSize: 18,
                outlineColor: outlineColor,
                mouthColor: colorScheme == .dark ? Color(white: 0.55) : Color(red: 0.29, green: 0.19, blue: 0.19)
            )
        } else {
            Image(systemName: "egg.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.primary)
                .frame(width: 18, height: 18)
        }
    }
}
