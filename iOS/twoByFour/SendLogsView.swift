import SwiftUI
import TwoByFourKit
import UIKit

/// Send Logs: an optional note, then the debug report goes to twoByFour's
/// server and a reference comes back.
struct SendLogsView: View {
    let report: () -> String
    let build: LogSender.Build
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    @State private var sending = false
    @State private var reference: String?
    @State private var failure: String?
    private let identity = Identity.current()

    var body: some View {
        NavigationStack {
            Form {
                if let reference {
                    Section {
                        Text("Sent. Thanks! Your reference is **\(reference)**.")
                        Button("Copy Reference") { UIPasteboard.general.string = reference }
                    }
                } else {
                    Section {
                        Text("Sends the open sheet with its answers and the recent log, along with this \(identity.model) on iOS \(identity.osVersion) and this app's version.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Section("What happened? (optional)") {
                        TextEditor(text: $note).frame(minHeight: 100)
                    }
                    if let failure {
                        Section {
                            Text("Couldn't send: \(failure)").foregroundStyle(.red).font(.callout)
                        }
                    }
                }
            }
            .navigationTitle("Send Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if reference == nil {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        if sending {
                            ProgressView()
                        } else {
                            Button("Send") { send() }
                        }
                    }
                } else {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
            }
        }
    }

    private func send() {
        sending = true
        failure = nil
        let text = report()
        Task {
            do {
                let id = try await LogSender.send(note: note, report: text, identity: identity, build: build)
                Log.shared.write("sent logs, reference \(id)")
                reference = id
            } catch {
                Log.shared.write("couldn't send logs: \(error.localizedDescription)")
                failure = error.localizedDescription
            }
            sending = false
        }
    }
}
