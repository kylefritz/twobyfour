import AppKit
import SwiftUI
import TwoByFourKit

/// Help → Send Logs…: an optional note, then the debug report goes to
/// twoByFour's server and a reference comes back.
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Send Logs").font(.headline)
            if let reference {
                Text("Sent. Thanks! Your reference is **\(reference)**.")
                HStack {
                    Spacer()
                    Button("Copy Reference") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(reference, forType: .string)
                    }
                    Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
                }
            } else {
                Text("Sends the open sheet with its answers and the recent log, along with \(identity.username) on \(identity.computer), macOS \(identity.osVersion) (\(identity.model)) and this app's version.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("What happened? (optional)").font(.callout)
                TextEditor(text: $note)
                    .font(.body)
                    .frame(minHeight: 80)
                    .border(Color(nsColor: .separatorColor))
                if let failure {
                    Text("Couldn't send: \(failure)").foregroundStyle(.red).font(.callout)
                }
                HStack {
                    if sending { ProgressView().controlSize(.small) }
                    Spacer()
                    Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                    Button("Send") { send() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(sending)
                }
            }
        }
        .padding(20)
        .frame(width: 440)
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
