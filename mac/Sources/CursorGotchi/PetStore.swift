import Foundation
import SwiftUI

@MainActor
final class PetStore: ObservableObject {
    @Published private(set) var state: PetStateFile?
    @Published var animFrame = 0

    private let stateURL: URL
    private var lastStageLevel: Int?
    weak var settingsStore: AppSettingsStore?

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
        PetLogic.speciesColors[state?.species ?? PetLogic.defaultSpecies] ?? .blue
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
            AppLogger.log("pet reload failed: \(error.localizedDescription)")
        }
    }

    func updateName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var current = state ?? defaultState()
        current.name = trimmed
        persistAndPublish(current)
        AppLogger.log("pet renamed to \(trimmed)")
    }

    func updateSpecies(_ speciesID: String) {
        guard PetLogic.species.contains(where: { $0.id == speciesID }) else { return }
        var current = state ?? defaultState()
        current.species = speciesID
        persistAndPublish(current)
    }

    private func defaultState() -> PetStateFile {
        let now = ISO8601DateFormatter.flex.string(from: .now)
        return PetStateFile(
            name: "Toko",
            species: PetLogic.defaultSpecies,
            lifetimeTokens: 0,
            sessionTokens: 0,
            hunger: 80,
            happiness: 80,
            lastFedAt: now,
            lastSeenAt: now,
            mealsServed: 0,
            evolutions: 0
        )
    }

    private func persistAndPublish(_ state: PetStateFile) {
        do {
            try persist(state)
            self.state = state
        } catch {
            AppLogger.log("pet save failed: \(error.localizedDescription)")
        }
    }

    private func persist(_ state: PetStateFile) throws {
        let dir = stateURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: stateURL, options: .atomic)
    }

    private func checkEvolution(_ state: PetStateFile) {
        let level = PetLogic.stage(for: state.lifetimeTokens).level
        defer { lastStageLevel = level }
        guard let last = lastStageLevel, level > last else { return }
        guard settingsStore?.settings.evolutionAlertsEnabled ?? true else { return }
        let stageName = PetLogic.stage(for: state.lifetimeTokens).name
        NotificationService.postEvolution(name: state.name, stageName: stageName)
    }
}

extension PetStore {
    func requestNotifications() {
        NotificationService.requestAuthorization()
    }
}
