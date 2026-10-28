import AppKit
import SwiftUI
import TwoByFourKit

@main
struct TwoByFourApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var state = AppState()

    init() {
        // Build step: `twobyfour --write-iconset <dir>` draws the app icon and exits.
        if let flag = CommandLine.arguments.firstIndex(of: "--write-iconset"), flag + 1 < CommandLine.arguments.count {
            do {
                try AppIcon.writeIconset(to: URL(fileURLWithPath: CommandLine.arguments[flag + 1]))
                exit(0)
            } catch {
                FileHandle.standardError.write(Data("couldn't write the iconset: \(error)\n".utf8))
                exit(1)
            }
        }
        // `twobyfour --write-ios-icon <png>` draws the iPhone app's icon and exits.
        if let flag = CommandLine.arguments.firstIndex(of: "--write-ios-icon"), flag + 1 < CommandLine.arguments.count {
            do {
                try AppIcon.writeIOSIcon(to: URL(fileURLWithPath: CommandLine.arguments[flag + 1]))
                exit(0)
            } catch {
                FileHandle.standardError.write(Data("couldn't write the iPhone icon: \(error)\n".utf8))
                exit(1)
            }
        }
        if let flag = CommandLine.arguments.firstIndex(of: "--snapshot-notepad"), flag + 1 < CommandLine.arguments.count {
            do {
                try Snapshot.notepad(to: URL(fileURLWithPath: CommandLine.arguments[flag + 1]),
                                     light: CommandLine.arguments.contains("--light"))
                exit(0)
            } catch {
                FileHandle.standardError.write(Data("couldn't draw the snapshot: \(error)\n".utf8))
                exit(1)
            }
        }
    }

    var body: some Scene {
        Window("twoByFour", id: "main") {
            VStack(spacing: 0) {
                ContentView(state: state)
                UpdateBanner(updater: delegate.updates.updater) { delegate.updates.restartToUpdate() }
                VersionFooter(controller: delegate.updates)
            }
            .frame(minWidth: 560, minHeight: 360)
            .sheet(isPresented: $state.tryingBuild) { TryBuildView(controller: delegate.updates) }
            .sheet(isPresented: $state.sendingLogs) {
                SendLogsView(report: { state.debugReport(updates: delegate.updates) },
                             build: LogSender.Build(version: delegate.updates.version, commit: delegate.updates.commit,
                                                    channel: UpdateChannel.current().rawValue))
            }
        }
        .defaultSize(width: 820, height: 560)

        Settings { SettingsView() }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Sheet") { state.newSheet() }
                    .keyboardShortcut("n")
            }
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { Task { await delegate.updates.updater.check() } }
                Button("Try a Build…") { state.tryingBuild = true }
            }
            CommandGroup(replacing: .help) {
                Button("Send Logs…") { state.sendingLogs = true }
                Button("Copy Debug Report") { state.copyDebugReport(updates: delegate.updates) }
                Button("Show Log in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([AppInfo.logFile])
                }
            }
        }
    }
}

/// The sheets and which one is open.
@MainActor
final class AppState: ObservableObject {
    let store = SheetStore(directory: SheetStore.defaultDirectory)
    @Published var selection: UUID?
    @Published var tryingBuild = false
    @Published var sendingLogs = false

    init() {
        if store.sheets.isEmpty { store.create(name: "Scratch") }
        selection = store.sheets.first?.id
    }

    func newSheet() {
        selection = store.create().id
        Log.shared.write("new sheet")
    }

    /// Puts the build, the open sheet with its answers and the end of the
    /// log on the clipboard, ready to paste into a chat or an issue.
    func copyDebugReport(updates: UpdateController) {
        Log.shared.write("copied a debug report")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(debugReport(updates: updates), forType: .string)
    }

    /// The build, the open sheet with its answers, and the end of the log.
    func debugReport(updates: UpdateController) -> String {
        Diagnostics.report(version: updates.version, commit: updates.commit, preview: updates.preview,
                           sheet: store.sheets.first { $0.id == selection }, log: Log.shared.tail(300))
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKey: HotKey?
    let updates = UpdateController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        let build = [updates.version, updates.commit, updates.preview].filter { !$0.isEmpty }.joined(separator: " ")
        Log.shared.write("launched \(build) on \(os), channel \(UpdateChannel.current().rawValue)")
        NSSetUncaughtExceptionHandler { exception in
            Log.shared.write("crashed: \(exception.name.rawValue): \(exception.reason ?? "")\n\(exception.callStackSymbols.joined(separator: "\n"))")
            Log.shared.flush()
        }
        hotKey = HotKey {
            Log.shared.write("global shortcut pressed")
            Self.bringToFront()
        }
        if hotKey != nil { Log.shared.write("global shortcut \(HotKey.defaultLabel) registered") }
        updates.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        Log.shared.write("quit")
        Log.shared.flush()
    }

    /// Activates the app and shows the notepad, reopening its window if it
    /// was closed (through the Window menu item SwiftUI adds for it).
    static func bringToFront() {
        NSApp.activate()
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue.hasPrefix("main") == true }) {
            window.makeKeyAndOrderFront(nil)
            return
        }
        Log.shared.write("reopening the closed notepad window")
        let windowMenu = NSApp.mainMenu?.items.first { $0.submenu === NSApp.windowsMenu }?.submenu
        if let item = windowMenu?.items.first(where: { $0.title == "twoByFour" }),
           let index = windowMenu?.index(of: item) {
            windowMenu?.performActionForItem(at: index)
        }
    }
}
