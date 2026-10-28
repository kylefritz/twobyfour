import SwiftUI
import TwoByFourKit

@main
struct TwoByFourApp: App {
    @StateObject private var model = AppModel()

    init() {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"
        let os = ProcessInfo.processInfo.operatingSystemVersion
        Log.shared.write("launched \(version) (\(build)) on iOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)")
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
    }
}

/// The sheets and which one is open. The open sheet is remembered across
/// launches, so the app opens where it was left.
@MainActor
final class AppModel: ObservableObject {
    let store = SheetStore(directory: SheetStore.defaultDirectory)
    @Published var selection: UUID? {
        didSet { UserDefaults.standard.set(selection?.uuidString, forKey: "lastSheet") }
    }

    init() {
        if store.sheets.isEmpty { store.create(name: "Scratch") }
        let last = UserDefaults.standard.string(forKey: "lastSheet").flatMap(UUID.init(uuidString:))
        selection = store.sheets.contains { $0.id == last } ? last : store.sheets.first?.id
    }

    func newSheet() {
        selection = store.create().id
    }

    var openSheet: Sheet? {
        store.sheets.first { $0.id == selection }
    }
}

struct ContentView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var store: SheetStore

    init(model: AppModel) {
        self.model = model
        self.store = model.store
    }

    var body: some View {
        NavigationStack {
            if let sheet = model.openSheet {
                SheetScreen(store: store, sheet: sheet)
                    .id(sheet.id)
            }
        }
    }
}

/// One sheet: the notepad. Typing saves half a second after the last key,
/// and right away when the app goes to the background.
struct SheetScreen: View {
    @ObservedObject var store: SheetStore
    let sheet: Sheet
    @State private var text = ""
    @State private var pendingSave: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NotepadEditor(text: $text, precision: sheet.precision)
            .ignoresSafeArea(.container, edges: .bottom)
            .navigationTitle(sheet.name)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { text = sheet.text }
            .onChange(of: text) { _, newText in
                guard newText != sheet.text else { return }
                pendingSave?.cancel()
                pendingSave = Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    guard !Task.isCancelled else { return }
                    save()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { saveNow() }
            }
            .onDisappear { saveNow() }
    }

    private func saveNow() {
        pendingSave?.cancel()
        save()
    }

    private func save() {
        guard text != sheet.text else { return }
        for change in Diagnostics.changes(from: sheet.text, to: text, precision: sheet.precision) {
            Log.shared.write("\(sheet.name) \(change)")
        }
        var edited = sheet
        edited.text = text
        store.update(edited)
    }
}
