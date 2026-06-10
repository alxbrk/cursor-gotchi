import Foundation
import Combine

struct UsageSnapshot: Codable {
    let fetchedAt: String
    var planName: String?
    var includedLimitCents: Int?
    var usedPercent: Int?
    var totalSpendCents: Int?
    var includedSpendCents: Int?
    var bonusSpendCents: Int?
    var displayMessage: String?
    var shortLabel: String
    var billingCycleEnd: String?
    var error: String?

    enum CodingKeys: String, CodingKey {
        case fetchedAt = "fetched_at"
        case planName = "plan_name"
        case includedLimitCents = "included_limit_cents"
        case usedPercent = "used_percent"
        case totalSpendCents = "total_spend_cents"
        case includedSpendCents = "included_spend_cents"
        case bonusSpendCents = "bonus_spend_cents"
        case displayMessage = "display_message"
        case shortLabel = "short_label"
        case billingCycleEnd = "billing_cycle_end"
        case error
    }

    init(
        fetchedAt: String,
        planName: String? = nil,
        includedLimitCents: Int? = nil,
        usedPercent: Int? = nil,
        totalSpendCents: Int? = nil,
        includedSpendCents: Int? = nil,
        bonusSpendCents: Int? = nil,
        displayMessage: String? = nil,
        shortLabel: String = "—",
        billingCycleEnd: String? = nil,
        error: String? = nil
    ) {
        self.fetchedAt = fetchedAt
        self.planName = planName
        self.includedLimitCents = includedLimitCents
        self.usedPercent = usedPercent
        self.totalSpendCents = totalSpendCents
        self.includedSpendCents = includedSpendCents
        self.bonusSpendCents = bonusSpendCents
        self.displayMessage = displayMessage
        self.shortLabel = shortLabel
        self.billingCycleEnd = billingCycleEnd
        self.error = error
    }

    var menuLabel: String {
        if let pct = usedPercent { return "\(pct)%" }
        if !shortLabel.isEmpty, shortLabel != "—" { return shortLabel }
        return "…"
    }

    /// "resets in 12 days" / "resets tomorrow" / "resets today".
    var resetText: String? {
        guard let billingCycleEnd, let ms = Double(billingCycleEnd) else { return nil }
        let end = Date(timeIntervalSince1970: ms / 1000.0)
        let seconds = end.timeIntervalSinceNow
        guard seconds > 0 else { return "resets soon" }
        let days = Int(ceil(seconds / 86_400))
        if days <= 0 { return "resets today" }
        if days == 1 { return "resets tomorrow" }
        return "resets in \(days) days"
    }

    /// Detailed dollar breakdown — shown only on hover.
    var detailLine: String {
        if let error, !error.isEmpty { return error }
        var parts: [String] = []
        if let planName, !planName.isEmpty { parts.append("\(planName) · billed $20/mo flat") }
        if let spend = totalSpendCents {
            if let included = includedSpendCents, let bonus = bonusSpendCents {
                parts.append("\(PetLogic.formatMoney(cents: spend)) used (\(PetLogic.formatMoney(cents: included)) included + \(PetLogic.formatMoney(cents: bonus)) free bonus)")
            } else {
                parts.append("\(PetLogic.formatMoney(cents: spend)) used")
            }
        }
        if let pct = usedPercent { parts.append("\(pct)% of monthly usage") }
        if let reset = resetText { parts.append(reset) }
        if parts.isEmpty { return displayMessage ?? "Usage unavailable" }
        return parts.joined(separator: "\n")
    }
}

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var usage: UsageSnapshot?

    private var refreshTimer: Timer?
    private var fetchInFlight = false

    init() {
        usage = UsageFetcher.loadCached()
    }

    func startAutoRefresh(every seconds: TimeInterval = 60) {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
        Task { @MainActor in
            await refresh()
        }
    }

    func reload() {
        usage = UsageFetcher.loadCached()
    }

    func refresh() async {
        guard !fetchInFlight else { return }
        fetchInFlight = true
        defer { fetchInFlight = false }

        let snapshot = await Task.detached(priority: .utility) {
            UsageFetcher.sync()
        }.value
        usage = snapshot
        AppLogger.log("usage updated: \(snapshot.menuLabel)")
    }
}
