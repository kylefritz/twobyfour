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
        }
    }
}

/// The sheets and which one is open.
@MainActor
final class AppState: ObservableObject {
    let store = SheetStore(directory: SheetStore.defaultDirectory)
    @Published var selection: UUID?
    @Published var tryingBuild = false

    init() {
        if store.sheets.isEmpty { store.create(name: "Scratch") }
        selection = store.sheets.first?.id
    }

    func newSheet() {
        selection = store.create().id
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKey: HotKey?
    let updates = UpdateController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        hotKey = HotKey { Self.bringToFront() }
        updates.start()
    }

    /// Activates the app and shows the notepad, reopening its window if it
    /// was closed (through the Window menu item SwiftUI adds for it).
    static func bringToFront() {
        NSApp.activate()
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue.hasPrefix("main") == true }) {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let windowMenu = NSApp.mainMenu?.items.first { $0.submenu === NSApp.windowsMenu }?.submenu
        if let item = windowMenu?.items.first(where: { $0.title == "twoByFour" }),
           let index = windowMenu?.index(of: item) {
            windowMenu?.performActionForItem(at: index)
        }
    }
}
