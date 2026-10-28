import Foundation
#if os(macOS)
import SystemConfiguration
#endif

/// Who is sending logs and from what, so reports can be told apart.
public struct Identity: Equatable, Sendable {
    public let username: String
    public let fullName: String
    public let computer: String
    public let platform: String
    public let osVersion: String
    /// The hardware model, e.g. `Mac16,7` or `iPhone17,1`.
    public let model: String

    public static func current() -> Identity {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let version = "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        #if os(macOS)
        return Identity(username: NSUserName(), fullName: NSFullUserName(),
                        computer: SCDynamicStoreCopyComputerName(nil, nil) as String? ?? ProcessInfo.processInfo.hostName,
                        platform: "macOS", osVersion: version, model: sysctl("hw.model"))
        #else
        // iOS keeps the owner's name and the device's name to itself.
        let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"]
        return Identity(username: "", fullName: "", computer: "", platform: "iOS", osVersion: version,
                        model: simulated ?? sysctl("hw.machine"))
        #endif
    }

    /// `hw.model` names a Mac; on iPhone it's the logic board, so `hw.machine`.
    private static func sysctl(_ name: String) -> String {
        var size = 0
        sysctlbyname(name, nil, &size, nil, 0)
        var bytes = [CChar](repeating: 0, count: max(size, 1))
        guard sysctlbyname(name, &bytes, &size, nil, 0) == 0 else { return "unknown" }
        return String(cString: bytes)
    }
}

/// Sends a debug report to twoByFour's server (`POST /v1/logs`), which
/// answers with a short reference for it.
public enum LogSender {
    public static let server = URL(string: "https://twobyfour.kylefritz.co")!

    public struct Build: Sendable {
        public let version: String
        public let commit: String
        public let channel: String

        public init(version: String, commit: String, channel: String) {
            self.version = version
            self.commit = commit
            self.channel = channel
        }
    }

    public struct Failure: LocalizedError {
        public let status: Int
        public let message: String
        public var errorDescription: String? { "The server answered \(status): \(message)" }
    }

    static func request(to server: URL, note: String, report: String, identity: Identity, build: Build) -> URLRequest {
        var request = URLRequest(url: server.appendingPathComponent("v1/logs"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("twoByFour/\(build.version)", forHTTPHeaderField: "User-Agent")
        let body: [String: Any] = [
            "user": ["username": identity.username, "fullName": identity.fullName, "computer": identity.computer],
            "device": ["platform": identity.platform, "osVersion": identity.osVersion, "model": identity.model],
            "app": ["version": build.version, "commit": build.commit, "channel": build.channel],
            "note": note,
            "report": report,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    /// Sends the report and returns the server's reference for it.
    public static func send(to server: URL = server, note: String, report: String, identity: Identity = .current(),
                            build: Build) async throws -> String {
        let (data, response) = try await URLSession.shared.data(
            for: request(to: server, note: note, report: report, identity: identity, build: build))
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard status == 201, let id = json?["id"] as? String else {
            throw Failure(status: status, message: json?["error"] as? String ?? "no reference")
        }
        return id
    }
}
