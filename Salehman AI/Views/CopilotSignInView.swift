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
    @State private var appeared = ProcessInfo.processInfo.arguments.contains("--qa")

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                PhaseAnimator([0.08, 0.14, 0.08]) { opacity in
                    Circle()
                        .fill(DS.Palette.accent.opacity(opacity))
                        .frame(width: 72, height: 72)
                        .blur(radius: 16)
                        .allowsHitTesting(false)
                } animation: { opacity in
                    opacity > 0.11
                        ? .spring(duration: 2.4, bounce: 0.06)
                        : .easeOut(duration: 2.0)
                }
                KeyframeAnimator(initialValue: CGFloat(1.0), trigger: appeared) { scale in
                    Image(systemName: "person.2.badge.gearshape.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(DS.Palette.accent)
                        .scaleEffect(scale)
                } keyframes: { _ in
                    KeyframeTrack {
                        LinearKeyframe(0.60, duration: 0.07)
                        SpringKeyframe(1.18, duration: 0.28, spring: .snappy)
                        SpringKeyframe(1.0, duration: 0.22, spring: .bouncy)
                    }
                }
            }
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
                        } label: {
                            Label("Open GitHub", systemImage: "arrow.up.forward.app")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(DS.Palette.accent, in: Capsule())
                                .shadow(color: DS.Palette.accent.opacity(0.25), radius: 4, y: 1)
                        }
                        .buttonStyle(LuxPressStyle())
                    }
                    .controlSize(.small)
                }
                .padding(.vertical, 4)
                .transition(.opacity.combined(with: .offset(y: -4)))
            }

            HStack(spacing: 8) {
                if working {
                    ProgressView().controlSize(.small)
                        .transition(.opacity)
                }
                Text(status).font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                    .animation(DS.Motion.smooth, value: status)
            }
            .animation(DS.Motion.smooth, value: working)

            Button("Cancel") { pollTask?.cancel(); dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .animation(DS.Motion.smooth, value: device != nil)
        .padding(24)
        .frame(width: 380)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .task { await start() }
        .onAppear { withAnimation(DS.Motion.smooth) { appeared = true } }
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
