import SwiftUI

struct StatusBarLabel: View {
    @ObservedObject var store: PetStore
    @ObservedObject var usageStore: UsageStore

    var body: some View {
        HStack(spacing: 4) {
            MenuBarIcon(store: store)
            Text(usageStore.usage?.menuLabel ?? "…")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(balanceColor)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(height: 18)
        .help(usageStore.usage?.detailLine ?? "Cursor usage balance")
    }

    private var balanceColor: Color {
        guard let usage = usageStore.usage else { return Color(white: 0.55) }
        if usage.error != nil { return Color(white: 0.55) }
        let pct = usage.usedPercent ?? 0
        if pct >= 90 { return Color(red: 0.95, green: 0.45, blue: 0.40) }
        if pct >= 70 { return Color(red: 0.95, green: 0.70, blue: 0.30) }
        return Color(red: 0.45, green: 0.82, blue: 0.55)
    }
}
