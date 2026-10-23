import AppKit
import SwiftUI
import TwoByFourKit

/// The updater and what this build is, for the views.
@MainActor
final class UpdateController: ObservableObject {
    let updater: Updater
    let version: String
    /// "PR #42" on a pull request's preview build, else empty.
    let preview: String
    let commit: String
    private var timer: Timer?

    init() {
        let info = Bundle.main.infoDictionary ?? [:]
        version = info["CFBundleShortVersionString"] as? String ?? "dev"
        preview = info["TwoByFourPreview"] as? String ?? ""
        commit = info["TwoByFourCommit"] as? String ?? ""
        updater = Updater(releasesURL: AppInfo.latestReleaseURL, releasesListURL: AppInfo.releasesListURL,
                          bundleURL: Bundle.main.bundleURL, currentVersion: version,
                          log: Log.shared, channel: { UpdateChannel.current() })
    }

    /// Checks now and every six hours.
    func start() {
        Task { await updater.check() }
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.updater.check() }
        }
    }

    /// Installs the ready build, then relaunches into it.
    func restartToUpdate() {
        do {
            relaunch(try updater.install())
        } catch {
            NSWorkspace.shared.open(URL(string: "https://github.com/\(AppInfo.repository)/releases/latest")!)
        }
    }

    private func relaunch(_ bundle: URL) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        // Waits for this process to exit before opening the new copy.
        task.arguments = ["-c", "while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$0\"", bundle.path]
        try? task.run()
        NSApp.terminate(nil)
    }
}

/// "Restart to update" or "download it yourself", under the notepad.
struct UpdateBanner: View {
    @ObservedObject var updater: Updater
    let restart: () -> Void

    var body: some View {
        if !updater.bannerDismissed {
            switch updater.state {
            case let .ready(version, notes):
                banner("twoByFour \(version) is ready.", notes: notes) {
                    Button("Restart to Update", action: restart).buttonStyle(.borderedProminent)
                }
            case let .manual(version, page, reason):
                banner("twoByFour \(version) is out, but it can't install itself: \(reason).", notes: nil) {
                    if let page { Link("Download", destination: page) }
                }
            default:
                EmptyView()
            }
        }
    }

    private func banner(_ text: String, notes: URL?, @ViewBuilder action: () -> some View) -> some View {
        HStack {
            Image(systemName: "arrow.down.circle")
            Text(text)
            if let notes { Link("What's new", destination: notes) }
            Spacer()
            action()
            Button { updater.dismissBanner() } label: { Image(systemName: "xmark") }
                .buttonStyle(.borderless)
                .help("Hide until the next version")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

/// The version, and which pull request when this is a preview build.
struct VersionFooter: View {
    @ObservedObject var controller: UpdateController

    var body: some View {
        HStack(spacing: 6) {
            if !controller.preview.isEmpty {
                Text(controller.preview)
                    .font(.caption.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.orange.opacity(0.25)))
            }
            Text(controller.version == "dev" && !controller.commit.isEmpty
                 ? "dev \(controller.commit)" : controller.version)
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

/// Swap to a pull request's preview build, or back to beta or stable.
struct TryBuildView: View {
    @ObservedObject var controller: UpdateController
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @State private var working = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Try a Build").font(.headline)
            Text("Enter a pull request number to try its preview, or `beta` or `stable` to go back. twoByFour restarts into it.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            TextField("42, beta or stable", text: $input)
                .onSubmit(start)
                .disabled(working)
            if let message {
                Text(message).font(.callout).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                if working { ProgressView().controlSize(.small) }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Try It", action: start)
                    .keyboardShortcut(.defaultAction)
                    .disabled(working || SwitchTarget(input) == nil)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private func start() {
        guard let target = SwitchTarget(input) else {
            message = "Enter a number like 42, or beta or stable."
            return
        }
        working = true
        message = nil
        Task {
            do {
                _ = try await controller.updater.switchTo(target)
                controller.restartToUpdate()
            } catch let error as SwitchError {
                message = error.description
            } catch {
                message = error.localizedDescription
            }
            working = false
        }
    }
}

struct SettingsView: View {
    @AppStorage(UpdateChannel.defaultsKey) private var channel = UpdateChannel.stable.rawValue

    var body: some View {
        Form {
            Picker("Updates", selection: $channel) {
                Text("Releases").tag(UpdateChannel.stable.rawValue)
                Text("Every beta").tag(UpdateChannel.beta.rawValue)
            }
            .pickerStyle(.radioGroup)
            Text("Betas are built from every change to the main branch.")
                .font(.caption)
                .foregroundStyle(.secondary)
            LabeledContent("Bring to front", value: HotKey.defaultLabel)
        }
        .padding(20)
        .frame(width: 360)
    }
}
