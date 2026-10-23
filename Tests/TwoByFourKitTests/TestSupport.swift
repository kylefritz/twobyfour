import Foundation
import Testing

struct TestFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

/// Polls until `condition` holds or the timeout passes.
@MainActor
func eventually(_ what: String, timeout: Double = 15, _ condition: () async -> Bool) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if await condition() { return }
        try await Task.sleep(nanoseconds: 50_000_000)
    }
    throw TestFailure("timed out waiting for: \(what)")
}
