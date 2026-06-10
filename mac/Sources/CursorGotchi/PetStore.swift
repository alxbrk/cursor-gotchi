import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class PetStore: ObservableObject {
    @Published private(set) var state: PetStateFile?
    @Published var animFrame = 0

    private let stateURL: URL
    private var lastStageLevel: Int?

    init() {
        stateURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cursor/token-gotchi/state.json")
        reload()
    }

    var stage: StageInfo {
        guard let state else { return PetLogic.stages[0] }
        return PetLogic.stage(for: state.lifetimeTokens)
    }

    var mood: String {
        guard let state else { return "…" }
        return PetLogic.mood(hunger: state.hunger, happiness: state.happiness)
    }

    var bodyColor: Color {
        PetLogic.speciesColors[state?.species ?? "deepite"] ?? .blue
    }

    func reload() {
        guard FileManager.default.fileExists(atPath: stateURL.path) else {
            state = nil
            return
        }
        do {
            let data = try Data(contentsOf: stateURL)
            var loaded = try JSONDecoder().decode(PetStateFile.self, from: data)
            PetLogic.applyDecay(&loaded)
            try persist(loaded)
            checkEvolution(loaded)
            state = loaded
        } catch {
            // Keep last good state if file is mid-write.
        }
    }

    private func persist(_ state: PetStateFile) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: stateURL, options: .atomic)
    }

    private func checkEvolution(_ state: PetStateFile) {
        let level = PetLogic.stage(for: state.lifetimeTokens).level
        defer { lastStageLevel = level }
        guard let last = lastStageLevel, level > last else { return }
        let stageName = PetLogic.stage(for: state.lifetimeTokens).name
        let content = UNMutableNotificationContent()
        content.title = "Cursor Gotchi evolved!"
        content.subtitle = stageName
        content.body = "\(state.name) reached \(stageName)"
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

extension PetStore {
    func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}
