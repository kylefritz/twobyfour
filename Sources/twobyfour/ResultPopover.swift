import AppKit
import SwiftUI
import TwoByFourKit

/// Every way to write an answer. Click one to copy it.
struct ResultPopover: View {
    let result: FormattedResult
    let close: () -> Void
    @State private var copied: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach([result.primary] + result.alternates, id: \.text) { value in
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value.text, forType: .string)
                    copied = value.text
                    Task {
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        close()
                    }
                } label: {
                    HStack {
                        Text(value.isExact ? "=" : "≈")
                            .foregroundStyle(.secondary)
                            .help(value.isExact ? "Exact" : "Rounded")
                        Text(value.text)
                            .font(.system(size: 14, design: .monospaced))
                        Spacer(minLength: 16)
                        Image(systemName: copied == value.text ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, 3)
            }
            Text("Click to copy")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(12)
        .frame(minWidth: 200)
    }
}
