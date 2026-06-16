import Foundation
import SwiftUI

struct PetStateFile: Codable {
    var name: String
    var species: String
    var lifetimeTokens: Int
    var sessionTokens: Int
    var hunger: Double
    var happiness: Double
    var lastFedAt: String
    var lastSeenAt: String
    var mealsServed: Int
    var evolutions: Int

    enum CodingKeys: String, CodingKey {
        case name, species, hunger, happiness, evolutions
        case lifetimeTokens = "lifetime_tokens"
        case sessionTokens = "session_tokens"
        case lastFedAt = "last_fed_at"
        case lastSeenAt = "last_seen_at"
        case mealsServed = "meals_served"
    }
}

struct StageInfo {
    let level: Int
    let name: String
    let minTokens: Int
}

struct SpeciesInfo: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let trait: String
}

enum PetLogic {
    static let species: [SpeciesInfo] = [
        .init(id: "sparkite", name: "Sparkite", emoji: "⚡", trait: "Loves fast completions"),
        .init(id: "deepite", name: "Deepite", emoji: "🌊", trait: "Thrives on long context"),
        .init(id: "codite", name: "Codite", emoji: "💎", trait: "Evolves through edits"),
        .init(id: "shellite", name: "Shellite", emoji: "🔥", trait: "Powered by terminal runs"),
        .init(id: "mcpite", name: "MCPite", emoji: "🔗", trait: "Connects to everything"),
    ]

    static let defaultSpecies = "sparkite"
    static let stages: [StageInfo] = [
        .init(level: 0, name: "Egg", minTokens: 0),
        .init(level: 1, name: "Hatchling", minTokens: 5_000),
        .init(level: 2, name: "Juvenile", minTokens: 50_000),
        .init(level: 3, name: "Adult", minTokens: 500_000),
        .init(level: 4, name: "Mega", minTokens: 5_000_000),
    ]

    static let speciesColors: [String: Color] = [
        "sparkite": Color(red: 0.90, green: 0.75, blue: 0.48),
        "deepite": Color(red: 0.35, green: 0.61, blue: 0.91),
        "codite": Color(red: 0.58, green: 0.53, blue: 0.95),
        "shellite": Color(red: 0.89, green: 0.58, blue: 0.30),
        "mcpite": Color(red: 0.95, green: 0.55, blue: 0.65),
    ]

    static func stage(for tokens: Int) -> StageInfo {
        stages.last(where: { tokens >= $0.minTokens }) ?? stages[0]
    }

    static func nextStage(after stage: StageInfo) -> StageInfo? {
        stages.first(where: { $0.level == stage.level + 1 })
    }

    static func mood(hunger: Double, happiness: Double) -> String {
        if hunger < 20 || happiness < 20 { return "Faint" }
        if hunger < 40 { return "Hungry" }
        if happiness < 40 { return "Grumpy" }
        if hunger > 85 && happiness > 85 { return "Thriving" }
        return "Content"
    }

    static func applyDecay(_ state: inout PetStateFile, now: Date = .now) {
        guard let lastSeen = parseDate(state.lastSeenAt) else { return }
        let hours = max(0, now.timeIntervalSince(lastSeen) / 3600)
        state.hunger = max(0, state.hunger - 4 * hours)
        state.happiness = max(0, state.happiness - 2 * hours)
        state.lastSeenAt = ISO8601DateFormatter.flex.string(from: now)
    }

    static func parseDate(_ value: String) -> Date? {
        if let d = ISO8601DateFormatter.flex.date(from: value) { return d }
        return ISO8601DateFormatter().date(from: value)
    }

    static func evolveProgress(tokens: Int, stage: StageInfo) -> (Int, Int?) {
        guard let next = nextStage(after: stage) else { return (100, nil) }
        let span = max(1, next.minTokens - stage.minTokens)
        let pct = Int(((Double(tokens - stage.minTokens) / Double(span)) * 100).rounded())
        return (min(100, max(0, pct)), next.minTokens)
    }

    static func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fk", Double(count) / 1_000) }
        return "\(count)"
    }

    static func formatMoney(cents: Int) -> String {
        let dollars = Double(cents) / 100.0
        if cents % 100 == 0 {
            return "$\(Int(dollars))"
        }
        return String(format: "$%.2f", dollars)
    }
}

extension ISO8601DateFormatter {
    static let flex: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

enum MoodKey { case happy, neutral, sad, faint }

enum Sprites {
    static func moodKey(hunger: Double, happiness: Double, mood: String) -> MoodKey {
        if mood == "Faint" || hunger < 20 || happiness < 20 { return .faint }
        if mood == "Hungry" || mood == "Grumpy" || hunger < 40 || happiness < 40 { return .sad }
        if mood == "Thriving" { return .happy }
        return .neutral
    }

    static func rows(stage: Int, mood: MoodKey, frame: Int) -> [String] {
        let base: [String]
        switch stage {
        case 0: base = egg
        case 1:
            switch mood {
            case .faint: base = hatchFaint
            case .sad: base = hatchSad
            default: base = hatchHappy
            }
        case 2: base = mood == .sad ? juvSad : juvHappy
        case 3: base = mood == .sad ? adultSad : adultHappy
        default: base = megaHappy
        }
        if frame % 2 == 1 && mood != .faint && stage > 0 {
            return Array(repeating: "................", count: 1) + base.dropLast()
        }
        return base
    }

    private static let egg = Array(repeating: "................", count: 3) + [
        "......OOOO......", ".....OHHHO......", "....OHHHHHO.....",
        "...OHHHHHHHO....", "...OHHHHHHHO....", "...OHHHHHHHO....",
        "...OHHHHHHHO....", "...OHHHHHHHO....", "...OHHHHHHHO....",
        "....OHHHHHO.....", ".....OHHHO......", "......OOO.......",
    ] + Array(repeating: "................", count: 3)

    private static let hatchHappy = pad([
        "......OOOO......", ".....OBBBBO.....", "....OBBBBBBO....",
        "...OBBEBBBEBO...", "...OBBBBMBBO....", "...OBBBBBBBO....",
        "....OBBBBBBO....", ".....OBBBBO.....", "......OBBBO.....",
        "......O..O......", ".....OO..OO.....",
    ])

    private static let hatchSad = pad([
        "......OOOO......", ".....OBBBBO.....", "....OBBBBBBO....",
        "...OBBEBBBEBO...", "...OBBBMMMBBO...", "...OBBBBBBBO....",
        "....OBBBBBBO....", ".....OBBBBO.....", "......OBBBO.....",
        "......O..O......", ".....OO..OO.....",
    ])

    private static let hatchFaint = pad([
        "......OOOO......", ".....OBBBBO.....", "...OBBBBBBBBBO..",
        "..OBBEXXXEBBO...", "..OBBBBMBBO.....", "...OBBBBBO......",
        "....OBBBBBO.....", ".....OO..OO.....",
    ], top: 3)

    private static let juvHappy = pad([
        "......OOOO......", ".....OHHHHO.....", "....OBBBBBBO....",
        "...OBBEBBBEBO...", "...OBBBBMBBO....", "...OBBBBBBBO....",
        "..OBBBBBBBBBO...", "..OBBBBBBBBBO...", "...OBBBBBBBO....",
        "....OB..BOB.....", "....O....O......", "...OO....OO.....",
    ])

    private static let juvSad = pad([
        "......OOOO......", ".....OHHHHO.....", "....OBBBBBBO....",
        "...OBBEBBBEBO...", "...OBBBMMMBBO...", "...OBBBBBBBO....",
        "..OBBBBBBBBBO...", "..OBBBBBBBBBO...", "...OBBBBBBBO....",
        "....OB..BOB.....", "....O....O......", "...OO....OO.....",
    ])

    private static let adultHappy = pad([
        ".....OO..OO.....", "....OHHHHHHHO...", "...OBBBBBBBBO...",
        "..OBBEBBBBEBO...", "..OBBBBMBBBBO...", "..OBBBBBBBBBO...",
        ".OBBBBBBBBBBBO..", ".OBBBBBBBBBBBO..", "..OBBBBBBBBBO...",
        "...OBBBBBBBBO...", "..OBO.....OBO...", "..OOO.....OOO...",
    ], bottom: 4)

    private static let adultSad = pad([
        ".....OO..OO.....", "....OHHHHHHHO...", "...OBBBBBBBBO...",
        "..OBBEBBBBEBO...", "..OBBBMMMMBBO...", "..OBBBBBBBBBO...",
        ".OBBBBBBBBBBBO..", ".OBBBBBBBBBBBO..", "..OBBBBBBBBBO...",
        "...OBBBBBBBBO...", "..OBO.....OBO...", "..OOO.....OOO...",
    ], bottom: 4)

    private static let megaHappy = pad([
        "....O.HH.HO.....", "...OHHHHHHHO....", "..OBBBBBBBBBO...",
        ".OBBEBBBBBBEBO..", ".OBBBBMMBBBBBO..", "OBBBBBBBBBBBBBO.",
        "OBBBBBBBBBBBBBO.", ".OBBBBBBBBBBBBO.", "..OBBBBBBBBBO...",
        "...OBO...OBO....", "..OOO...OOO.....",
    ], bottom: 5)

    private static func pad(_ rows: [String], top: Int = 1, bottom: Int = 1) -> [String] {
        var result = Array(repeating: "................", count: top)
        result.append(contentsOf: rows)
        while result.count < 16 {
            result.append("................")
        }
        return Array(result.prefix(16))
    }
}
