import Foundation
import Testing
@testable import TwoByFourKit

@Suite struct LogSenderTests {
    let identity = Identity(username: "kyle", fullName: "Kyle Fritz", computer: "Kyle's MacBook Pro",
                            platform: "macOS", osVersion: "26.6.2", model: "Mac16,7")
    let build = LogSender.Build(version: "0.1.1-beta.3", commit: "abc1234", channel: "beta")

    @Test func theUploadSaysWhoWhatAndWhichBuild() throws {
        let request = LogSender.request(to: URL(string: "https://example.com")!, note: "105\" looked wrong",
                                        report: "the report", identity: identity, build: build)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://example.com/v1/logs")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = try JSONSerialization.jsonObject(with: try #require(request.httpBody)) as? [String: Any]
        #expect(body?["note"] as? String == "105\" looked wrong")
        #expect(body?["report"] as? String == "the report")
        #expect(body?["user"] as? [String: String] == [
            "username": "kyle", "fullName": "Kyle Fritz", "computer": "Kyle's MacBook Pro",
        ])
        #expect(body?["device"] as? [String: String] == ["platform": "macOS", "osVersion": "26.6.2", "model": "Mac16,7"])
        #expect(body?["app"] as? [String: String] == ["version": "0.1.1-beta.3", "commit": "abc1234", "channel": "beta"])
    }

    @Test func thisMacIsDescribed() {
        let me = Identity.current()
        #expect(me.username == NSUserName())
        #expect(me.platform == "macOS")
        #expect(me.osVersion.split(separator: ".").count >= 2)
        #expect(!me.model.isEmpty)
        #expect(!me.computer.isEmpty)
    }

    @Test func sendingReturnsTheServersReference() async throws {
        let server = try TestHTTPServer()
        defer { server.stop() }
        server.route("/v1/logs", status: 201, body: Data(#"{"id":"k7q2mx4dab"}"#.utf8))
        let id = try await LogSender.send(to: server.url(""), note: "", report: "log", identity: identity, build: build)
        #expect(id == "k7q2mx4dab")
    }

    @Test func aRefusalIsAnError() async throws {
        let server = try TestHTTPServer()
        defer { server.stop() }
        server.route("/v1/logs", status: 413, body: Data(#"{"error":"report too large"}"#.utf8))
        await #expect(throws: LogSender.Failure.self) {
            try await LogSender.send(to: server.url(""), note: "", report: "log", identity: identity, build: build)
        }
    }
}
