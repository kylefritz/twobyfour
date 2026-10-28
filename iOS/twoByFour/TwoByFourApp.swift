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
    /// UI tests point `TWOBYFOUR_SHEETS_DIR` at a scratch folder.
    let store = SheetStore(directory: ProcessInfo.processInfo.environment["TWOBYFOUR_SHEETS_DIR"]
        .map { URL(fileURLWithPath: $0) } ?? SheetStore.defaultDirectory)
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

    /// Deletes `sheet`; there's always at least one sheet to show.
    func delete(_ sheet: Sheet) {
        Log.shared.write("deleted sheet \"\(sheet.name)\"")
        store.delete(id: sheet.id)
        if store.sheets.isEmpty { store.create(name: "Scratch") }
        if selection == sheet.id || !store.sheets.contains(where: { $0.id == selection }) {
            selection = store.sheets.first?.id
        }
    }

    var openSheet: Sheet? {
        store.sheets.first { $0.id == selection }
    }

    /// This build, from Info.plist: CI sets the version, build number and commit.
    let build: LogSender.Build = {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let number = info["CFBundleVersion"] as? String ?? "?"
        return LogSender.Build(version: "\(version) (\(number))", commit: info["TwoByFourCommit"] as? String ?? "",
                               channel: "testflight")
    }()

    /// The build, the open sheet with its answers, and the end of the log.
    func debugReport() -> String {
        Diagnostics.report(version: build.version, commit: build.commit, preview: "", sheet: openSheet,
                           log: Log.shared.tail(300))
    }
}

struct ContentView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var store: SheetStore
    @State private var showingSheets = false
    @State private var sendingLogs = false
    @State private var renaming: Sheet?
    @State private var newName = ""

    init(model: AppModel) {
        self.model = model
        self.store = model.store
    }

    var body: some View {
        NavigationStack {
            if let sheet = model.openSheet {
                SheetScreen(store: store, sheet: sheet)
                    .id(sheet.id)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button { showingSheets = true } label: { Label("Sheets", systemImage: "list.bullet") }
                        }
                        ToolbarItem(placement: .topBarTrailing) { menu(for: sheet) }
                    }
            }
        }
        .sheet(isPresented: $showingSheets) { SheetsView(model: model, store: store) }
        .sheet(isPresented: $sendingLogs) { SendLogsView(report: model.debugReport, build: model.build) }
        .renameAlert(sheet: $renaming, name: $newName, store: store)
    }

    private func menu(for sheet: Sheet) -> some View {
        Menu {
            Picker("Round to", selection: Binding(get: { sheet.precision }, set: { precision in
                Log.shared.write("sheet \"\(sheet.name)\" now rounds to \(precision.label)")
                // Read it fresh: typing may have saved since this menu was built.
                guard var edited = store.sheets.first(where: { $0.id == sheet.id }) else { return }
                edited.precision = precision
                store.update(edited)
            })) {
                ForEach(Precision.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.menu)
            Button("Rename…", systemImage: "pencil") {
                newName = sheet.name
                renaming = sheet
            }
            Divider()
            Button("Send Logs…", systemImage: "paperplane") { sendingLogs = true }
            Button("Copy Debug Report", systemImage: "doc.on.clipboard") {
                Log.shared.write("copied a debug report")
                UIPasteboard.general.string = model.debugReport()
            }
        } label: {
            Label("More", systemImage: "ellipsis.circle")
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
