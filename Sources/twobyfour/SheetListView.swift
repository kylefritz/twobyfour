import SwiftUI
import TwoByFourKit

struct ContentView: View {
    @ObservedObject var state: AppState
    @ObservedObject private var store: SheetStore

    init(state: AppState) {
        self.state = state
        self.store = state.store
    }

    var body: some View {
        NavigationSplitView {
            SheetListView(state: state, store: store)
                .navigationSplitViewColumnWidth(min: 160, ideal: 200)
        } detail: {
            if let id = state.selection, let sheet = store.sheets.first(where: { $0.id == id }) {
                SheetDetailView(store: store, sheet: sheet)
                    .id(id)
            } else {
                Text("No sheet selected").foregroundStyle(.secondary)
            }
        }
    }
}

struct SheetListView: View {
    @ObservedObject var state: AppState
    @ObservedObject var store: SheetStore
    @State private var renaming: Sheet?
    @State private var newName = ""

    var body: some View {
        List(selection: $state.selection) {
            ForEach(store.sheets) { sheet in
                Text(sheet.name)
                    .tag(sheet.id)
                    .contextMenu {
                        Button("Rename…") {
                            newName = sheet.name
                            renaming = sheet
                        }
                        Button("Delete", role: .destructive) { delete(sheet) }
                    }
            }
        }
        .toolbar {
            Button { state.newSheet() } label: { Label("New Sheet", systemImage: "plus") }
        }
        .alert("Rename Sheet", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Rename") {
                if var sheet = renaming, !newName.trimmingCharacters(in: .whitespaces).isEmpty {
                    sheet.name = newName
                    store.update(sheet)
                }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
    }

    private func delete(_ sheet: Sheet) {
        store.delete(id: sheet.id)
        if state.selection == sheet.id { state.selection = store.sheets.first?.id }
        if store.sheets.isEmpty { state.newSheet() }
    }
}

/// One sheet: the notepad and its rounding choice.
struct SheetDetailView: View {
    @ObservedObject var store: SheetStore
    let sheet: Sheet

    var body: some View {
        TextEditor(text: Binding(get: { sheet.text }, set: { text in
            var edited = sheet
            edited.text = text
            store.update(edited)
        }))
        .font(.system(size: 14, design: .monospaced))
        .navigationTitle(sheet.name)
        .toolbar {
            Picker("Round to", selection: Binding(get: { sheet.precision }, set: { precision in
                var edited = sheet
                edited.precision = precision
                store.update(edited)
            })) {
                ForEach(Precision.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .help("Round lengths to the nearest mark")
        }
    }
}
