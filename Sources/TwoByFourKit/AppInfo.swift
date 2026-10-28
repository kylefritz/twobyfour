import Foundation

/// Names this app goes by on GitHub and on disk.
public enum AppInfo {
    public static let repository = "kylefritz/twobyfour"
    public static let bundleIdentifier = "io.github.kylefritz.twobyfour"
    /// GitHub's latest release, which skips prereleases.
    public static let latestReleaseURL = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
    /// Recent releases of every kind, for the beta channel.
    public static let releasesListURL = URL(string: "https://api.github.com/repos/\(repository)/releases?per_page=30")!
    /// `~/Library/Logs/twoByFour/twoByFour.log`; on iPhone, the same path
    /// inside the app's container.
    public static var logFile: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/twoByFour/twoByFour.log")
    }
}
