import Foundation
import SQLite3

enum UsageFetcher {
    private static let stateDB = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/state.vscdb")
    private static let usageURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".cursor/token-gotchi/usage.json")
    private static let usageAPI = URL(string: "https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage")!
    private static let planAPI = URL(string: "https://api2.cursor.sh/aiserver.v1.DashboardService/GetPlanInfo")!

    static func sync() -> UsageSnapshot {
        let snapshot = fetch()
        write(snapshot)
        return snapshot
    }

    static func loadCached() -> UsageSnapshot? {
        guard FileManager.default.fileExists(atPath: usageURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: usageURL)
            return try JSONDecoder().decode(UsageSnapshot.self, from: data)
        } catch {
            AppLogger.log("usage decode failed: \(error.localizedDescription)")
            return nil
        }
    }

    private static func write(_ snapshot: UsageSnapshot) {
        let dir = usageURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: usageURL, options: .atomic)
        }
    }

    private static func fetch() -> UsageSnapshot {
        let now = ISO8601DateFormatter().string(from: Date())
        guard let token = readAccessToken() else {
            return UsageSnapshot(
                fetchedAt: now,
                shortLabel: "Sign in",
                error: "Cursor is not signed in on this Mac."
            )
        }

        do {
            let usagePayload = try postJSON(url: usageAPI, token: token)
            let planPayload = (try? postJSON(url: planAPI, token: token)) ?? [:]
            return parse(usage: usagePayload, plan: planPayload, fetchedAt: now)
        } catch {
            AppLogger.log("usage fetch failed: \(error.localizedDescription)")
            if let cached = loadCached() { return cached }
            return UsageSnapshot(
                fetchedAt: now,
                shortLabel: "—",
                error: "Could not fetch Cursor usage."
            )
        }
    }

    private static func readAccessToken() -> String? {
        guard FileManager.default.fileExists(atPath: stateDB.path) else { return nil }
        var db: OpaquePointer?
        guard sqlite3_open_v2(stateDB.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let db else { return nil }
        defer { sqlite3_close(db) }

        let sql = "SELECT value FROM ItemTable WHERE key = 'cursorAuth/accessToken';"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else { return nil }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW,
              let cString = sqlite3_column_text(statement, 0) else { return nil }
        return String(cString: cString)
    }

    private static func postJSON(url: URL, token: String) throws -> [String: Any] {
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.httpMethod = "POST"
        request.httpBody = Data("{}".utf8)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")

        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<[String: Any], Error> = .failure(URLError(.unknown))

        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            if let error {
                result = .failure(error)
                return
            }
            guard let data,
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                result = .failure(URLError(.badServerResponse))
                return
            }
            result = .success(object)
        }.resume()

        _ = semaphore.wait(timeout: .now() + 10)
        switch result {
        case .success(let object): return object
        case .failure(let error): throw error
        }
    }

    private static func parse(usage: [String: Any], plan: [String: Any], fetchedAt: String) -> UsageSnapshot {
        let planInfo = plan["planInfo"] as? [String: Any] ?? [:]
        let planUsage = usage["planUsage"] as? [String: Any] ?? [:]

        let limit = planUsage["limit"] as? Int
        let usedPercentValue = (planUsage["totalPercentUsed"] as? Double)
            ?? (planUsage["totalPercentUsed"] as? Int).map(Double.init)
        let usedPercent = usedPercentValue.map { Int(max(0, $0.rounded())) }

        return UsageSnapshot(
            fetchedAt: fetchedAt,
            planName: planInfo["planName"] as? String,
            includedLimitCents: limit,
            usedPercent: usedPercent,
            totalSpendCents: planUsage["totalSpend"] as? Int,
            includedSpendCents: planUsage["includedSpend"] as? Int,
            bonusSpendCents: planUsage["bonusSpend"] as? Int,
            displayMessage: usage["displayMessage"] as? String,
            shortLabel: usedPercent.map { "\($0)%" } ?? "—",
            billingCycleEnd: usage["billingCycleEnd"].map { String(describing: $0) },
            error: nil
        )
    }
}
