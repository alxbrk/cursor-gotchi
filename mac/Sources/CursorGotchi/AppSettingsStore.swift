import Foundation
import Combine

struct AppSettings: Codable {
    var usageAlertsEnabled: Bool = true
    var evolutionAlertsEnabled: Bool = true
    /// Billing cycle end (ms epoch string) for which usage alerts were tracked.
    var alertCycleKey: String?
    /// Thresholds already notified this cycle (e.g. 70, 90).
    var usageAlertsFired: [Int] = []

    enum CodingKeys: String, CodingKey {
        case usageAlertsEnabled = "usage_alerts_enabled"
        case evolutionAlertsEnabled = "evolution_alerts_enabled"
        case alertCycleKey = "alert_cycle_key"
        case usageAlertsFired = "usage_alerts_fired"
    }
}

@MainActor
final class AppSettingsStore: ObservableObject {
    @Published private(set) var settings: AppSettings

    private let settingsURL: URL

    init() {
        settingsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cursor/token-gotchi/settings.json")
        settings = Self.load(from: settingsURL)
    }

    func setUsageAlertsEnabled(_ enabled: Bool) {
        settings.usageAlertsEnabled = enabled
        save()
    }

    func setEvolutionAlertsEnabled(_ enabled: Bool) {
        settings.evolutionAlertsEnabled = enabled
        save()
    }

    /// Returns thresholds newly crossed this update (empty if none).
    func recordUsageAlertIfNeeded(usedPercent: Int, billingCycleEnd: String?) -> [Int] {
        guard settings.usageAlertsEnabled else { return [] }

        let cycleKey = billingCycleEnd ?? "unknown"
        if settings.alertCycleKey != cycleKey {
            settings.alertCycleKey = cycleKey
            settings.usageAlertsFired = []
        }

        var newlyFired: [Int] = []
        for threshold in [70, 90] where usedPercent >= threshold {
            if !settings.usageAlertsFired.contains(threshold) {
                settings.usageAlertsFired.append(threshold)
                newlyFired.append(threshold)
            }
        }

        if !newlyFired.isEmpty { save() }
        return newlyFired
    }

    private func save() {
        let dir = settingsURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(settings) {
            try? data.write(to: settingsURL, options: .atomic)
        }
    }

    private static func load(from url: URL) -> AppSettings {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let loaded = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return loaded
    }
}
