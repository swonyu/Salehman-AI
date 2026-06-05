import SwiftUI
import AppKit

/// GitHub Copilot device-flow sign-in sheet. Requests a device code, shows it,
/// opens github.com/login/device, and polls until the user authorizes — then
/// stores the GitHub token (Keychain) and calls `onSignedIn`.
struct CopilotSignInView: View {
    @Environment(\.dismiss) private var dismiss
    var onSignedIn: () -> Void

    @State private var device: CopilotAuth.DeviceCode?
    @State private var status = "Requesting a device code from GitHub…"
    @State private var working = true
    @State private var pollTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.badge.gearshape.fill")
                .font(.system(size: 34)).foregroundStyle(DS.Palette.accent)
            Text("Sign in to GitHub Copilot").font(.title2.weight(.bold))
            Text("Requires an active Copilot subscription on your GitHub account.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)

            if let d = device {
                VStack(spacing: 6) {
                    Text("Your one-time code").font(.caption).foregroundStyle(.secondary)
                    Text(d.userCode)
                        .font(.system(size: 30, weight: .bold, design: .monospaced))
                        .textSelection(.enabled)
                    HStack(spacing: 10) {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(d.userCode, forType: .string)
                        } label: { Label("Copy", systemImage: "doc.on.doc") }
                            .buttonStyle(.bordered)
                        Button {
                            if let url = URL(string: d.verificationURI) { NSWorkspace.shared.open(url) }
                        } label: { Label("Open GitHub", systemImage: "arrow.up.forward.app") }
                            .buttonStyle(.borderedProminent)
                    }
                    .controlSize(.small)
                }
                .padding(.vertical, 4)
            }

            HStack(spacing: 8) {
                if working { ProgressView().controlSize(.small) }
                Text(status).font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Cancel") { pollTask?.cancel(); dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(24)
        .frame(width: 380)
        .task { await start() }
        .onDisappear { pollTask?.cancel() }
    }

    private func start() async {
        guard let d = await CopilotAuth.shared.requestDeviceCode() else {
            status = "Couldn't reach GitHub. Check your network and try again."
            working = false
            return
        }
        device = d
        status = "Enter the code at github.com/login/device, then return here."
        if let url = URL(string: d.verificationURI) { NSWorkspace.shared.open(url) }

        pollTask = Task {
            let ok = await CopilotAuth.shared.pollForToken(deviceCode: d.deviceCode, interval: d.interval)
            await MainActor.run {
                working = false
                if ok {
                    status = "Signed in ✓"
                    onSignedIn()
                    dismiss()
                } else {
                    status = "Sign-in didn't complete. Close and try again."
                }
            }
        }
    }
}
