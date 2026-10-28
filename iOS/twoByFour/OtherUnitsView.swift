import SwiftUI
import TwoByFourKit
import UIKit

/// Every way to write an answer. Tap one to copy it.
struct OtherUnitsView: View {
    let result: FormattedResult
    @State private var copied: String?

    var body: some View {
        NavigationStack {
            List([result.primary] + result.alternates, id: \.text) { value in
                Button {
                    UIPasteboard.general.string = value.text
                    copied = value.text
                } label: {
                    HStack {
                        Text(value.isExact ? "=" : "≈")
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(value.isExact ? "exactly" : "about")
                        Text(value.text)
                            .font(.system(size: 19, design: .monospaced))
                            .foregroundStyle(.primary)
                        Spacer(minLength: 16)
                        Image(systemName: copied == value.text ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Other units")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
