import SwiftUI
import TwoByFourKit

/// Every sheet, most recently edited first. Tap one to open it.
struct SheetsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var store: SheetStore
    @Environment(\.dismiss) private var dismiss
    @State private var renaming: Sheet?
    @State private var newName = ""
    @State private var deleting: Sheet?

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.sheets) { sheet in
                    Button {
                        model.selection = sheet.id
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sheet.name).foregroundStyle(.primary)
                                Text(sheet.modified, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if sheet.id == model.selection {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) { deleting = sheet }
                        Button("Rename") {
                            newName = sheet.name
                            renaming = sheet
                        }
                    }
                }
            }
            .navigationTitle("Sheets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        model.newSheet()
                        Log.shared.write("new sheet")
                        dismiss()
                    } label: { Label("New Sheet", systemImage: "plus") }
                }
            }
            .renameAlert(sheet: $renaming, name: $newName, store: store)
            .confirmationDialog("Delete \"\(deleting?.name ?? "")\"?", isPresented: Binding(
                get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let sheet = deleting { model.delete(sheet) }
                    deleting = nil
                }
            }
        }
    }
}

extension View {
    /// The Rename alert, shared by the sheets list and the sheet's menu.
    func renameAlert(sheet: Binding<Sheet?>, name: Binding<String>, store: SheetStore) -> some View {
        alert("Rename Sheet", isPresented: Binding(get: { sheet.wrappedValue != nil },
                                                   set: { if !$0 { sheet.wrappedValue = nil } })) {
            TextField("Name", text: name)
            Button("Rename") {
                let trimmed = name.wrappedValue.trimmingCharacters(in: .whitespaces)
                if var edited = sheet.wrappedValue.flatMap({ s in store.sheets.first { $0.id == s.id } }),
                   !trimmed.isEmpty {
                    Log.shared.write("renamed sheet \"\(edited.name)\" to \"\(trimmed)\"")
                    edited.name = trimmed
                    store.update(edited)
                }
                sheet.wrappedValue = nil
            }
            Button("Cancel", role: .cancel) { sheet.wrappedValue = nil }
        }
    }
}
