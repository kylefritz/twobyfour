import Foundation

extension Log {
    /// The app's log: `~/Library/Logs/twoByFour/twoByFour.log`.
    public static let shared = Log(file: AppInfo.logFile)
}

/// What gets written down so a problem can be traced afterwards: what was
/// typed and what came back, and a report to paste into a bug or a chat.
public enum Diagnostics {
    /// One log line per answer in `new` that `old` didn't show: an edited
    /// line, or an unchanged one whose answer moved because a variable did.
    public static func changes(from old: String, to new: String, precision: Precision) -> [String] {
        var before: [String: Int] = [:]
        for entry in entries(old, precision: precision) {
            before[entry.text, default: 0] += 1
        }
        return entries(new, precision: precision).compactMap { entry in
            if let seen = before[entry.text], seen > 0 {
                before[entry.text] = seen - 1
                return nil
            }
            return "line \(entry.line): \(entry.text)"
        }
    }

    /// Plain text to paste into a chat: the build, the Mac, the open sheet
    /// with every answer, and the end of the log.
    public static func report(version: String, commit: String, preview: String, sheet: Sheet?,
                              log: [String]) -> String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        var build = "twoByFour \(version)"
        if !commit.isEmpty { build += " (\(commit))" }
        if !preview.isEmpty { build += " \(preview)" }
        var out = "\(build)\n"
        let osVersion = "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        #if os(macOS)
        out += "macOS \(osVersion), update channel: \(UpdateChannel.current().rawValue)\n"
        #else
        out += "iOS \(osVersion) (\(Identity.current().model))\n"
        #endif
        out += "Generated \(ISO8601DateFormatter().string(from: Date()))\n\n"
        if let sheet {
            out += "Sheet \"\(sheet.name)\", rounding to \(sheet.precision.label):\n```\n"
            for entry in entries(sheet.text, precision: sheet.precision) {
                out += "line \(entry.line): \(entry.text)\n"
            }
            out += "```\n\n"
        }
        out += "Log (last \(log.count) lines):\n```\n"
        for line in log { out += line + "\n" }
        out += "```\n"
        return out
    }

    /// Every line that shows something, 1-based, as `typed → answer`.
    private static func entries(_ text: String, precision: Precision) -> [(line: Int, text: String)] {
        let lines = SheetEvaluator.lines(text)
        return NotepadModel.rows(for: text, precision: precision).compactMap { row in
            let typed = lines[row.line].trimmingCharacters(in: .whitespaces)
            switch row.display {
            case .none: return nil
            case .result: return (row.line + 1, "\(typed) → \(row.display.label!)")
            case .error(let message): return (row.line + 1, "\(typed) → error: \(message)")
            }
        }
    }
}
