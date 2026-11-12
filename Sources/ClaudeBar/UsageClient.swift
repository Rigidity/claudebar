import Foundation

enum UsageError: LocalizedError {
    case noCredentials
    case unauthorized
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .noCredentials: return "No Claude Code login found. Run `claude` and log in."
        case .unauthorized: return "Token expired. Run `claude` once to refresh it."
        case .http(let code): return "Usage request failed (HTTP \(code))."
        }
    }
}

/// Raw shape of `GET https://api.anthropic.com/api/oauth/usage` (only the fields we use).
struct UsageResponse: Decodable {
    struct Window: Decodable {
        let utilization: Double?
        let resets_at: String?
    }

    struct Limit: Decodable {
        struct Scope: Decodable {
            struct Model: Decodable { let display_name: String? }
            let model: Model?
        }

        let kind: String?
        let group: String?
        let percent: Double?
        let resets_at: String?
        let scope: Scope?
    }

    let five_hour: Window?
    let seven_day: Window?
    let limits: [Limit]?
}

enum UsageClient {
    static func fetch() async throws -> UsageResponse {
        let token = try readAccessToken()

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("claude-code/2.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 || status == 403 { throw UsageError.unauthorized }
        guard (200..<300).contains(status) else { throw UsageError.http(status) }
        return try JSONDecoder().decode(UsageResponse.self, from: data)
    }

    /// Reads the OAuth token Claude Code stores. Re-read on every fetch so we pick up
    /// tokens Claude Code has refreshed. Shelling out to `security` avoids a keychain
    /// prompt every time this ad-hoc signed app is rebuilt.
    private static func readAccessToken() throws -> String {
        if let data = try? keychainItem(service: "Claude Code-credentials"), let token = parseToken(data) {
            return token
        }
        let file = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/.credentials.json")
        if let data = try? Data(contentsOf: file), let token = parseToken(data) {
            return token
        }
        throw UsageError.noCredentials
    }

    private static func keychainItem(service: String) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", service, "-w"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw UsageError.noCredentials }
        return data
    }

    private static func parseToken(_ data: Data) -> String? {
        struct Credentials: Decodable {
            struct OAuth: Decodable { let accessToken: String }
            let claudeAiOauth: OAuth?
        }
        return (try? JSONDecoder().decode(Credentials.self, from: data))?.claudeAiOauth?.accessToken
    }
}
