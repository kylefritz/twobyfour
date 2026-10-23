import AppKit
import SwiftUI
import TwoByFourKit

@main
struct TwoByFourApp: App {
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
    }

    var body: some Scene {
        Window("twoByFour", id: "main") {
            ContentView(state: state)
                .frame(minWidth: 560, minHeight: 360)
        }
        .defaultSize(width: 820, height: 560)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Sheet") { state.newSheet() }
                    .keyboardShortcut("n")
            }
        }
    }
}

/// The sheets and which one is open.
@MainActor
final class AppState: ObservableObject {
    let store = SheetStore(directory: SheetStore.defaultDirectory)
    @Published var selection: UUID?

    init() {
        if store.sheets.isEmpty { store.create(name: "Scratch") }
        selection = store.sheets.first?.id
    }

    func newSheet() {
        selection = store.create().id
    }
}
