import SwiftUI

public enum StreamQualityPreset: String, CaseIterable, Identifiable {
    case original = "Original (Lossless / Direct)"
    case kbps320  = "320 kbps (Very High)"
    case kbps256  = "256 kbps (High)"
    case kbps192  = "192 kbps (Medium)"
    case kbps160  = "160 kbps (Standard)"
    case kbps128  = "128 kbps (Low)"
    case kbps96   = "96 kbps (Data Saver)"

    public var id: String { rawValue }

    public var shortLabel: String {
        switch self {
        case .original: return "Original"
        case .kbps320:  return "320 kbps"
        case .kbps256:  return "256 kbps"
        case .kbps192:  return "192 kbps"
        case .kbps160:  return "160 kbps"
        case .kbps128:  return "128 kbps"
        case .kbps96:   return "96 kbps"
        }
    }
}

public enum LoudnessProfilePreset: String, CaseIterable, Identifiable {
    case normal  = "Normal"
    case louder  = "Louder (+6 dB)"
    case maximum = "Maximum (+12 dB)"

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .normal:  return "Target -18 LUFS (Balanced, standard dynamic range)"
        case .louder:  return "Target -12 LUFS (Recommended for noisy environments)"
        case .maximum: return "Target -6 LUFS (Peak limited, maximum volume)"
        }
    }
}

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var sessionStore = KeychainSessionStore.shared

    // Playback settings persisted in UserDefaults
    @AppStorage("playback_wifi_quality") private var wifiQuality: String = StreamQualityPreset.original.rawValue
    @AppStorage("playback_cellular_quality") private var cellularQuality: String = StreamQualityPreset.kbps160.rawValue
    @AppStorage("playback_loudness_profile") private var loudnessProfile: String = LoudnessProfilePreset.normal.rawValue

    // Latency & state
    @State private var latencyMs: Int? = nil
    @State private var isPinging: Bool = false
    @State private var showSignOutAlert: Bool = false
    @State private var showSwitchServerAlert: Bool = false
    @State private var showCopiedBanner: Bool = false
    @State private var showLicenseSheet: Bool = false

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                // MARK: 1. Server Section
                serverSection

                // MARK: 2. Playback Section
                playbackSection

                // MARK: 3. Appearance Section
                appearanceSection

                // MARK: 4. Storage & Maintenance
                storageAndMaintenanceSection

                // MARK: 5. About Downtify
                aboutSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(theme.currentBackground.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(DowntifyFont.bodyBold)
                    .foregroundColor(DowntifyColor.primary)
                }
            }
            .confirmationDialog(
                "Sign Out",
                isPresented: $showSignOutAlert,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    sessionStore.clear(reason: .user)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out? You will need to pair or sign in again to access your music.")
            }
            .confirmationDialog(
                "Switch Server",
                isPresented: $showSwitchServerAlert,
                titleVisibility: .visible
            ) {
                Button("Switch Server / Re-pair", role: .destructive) {
                    sessionStore.clear(reason: .user)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will disconnect from your current server and open the pairing screen.")
            }
            .sheet(isPresented: $showLicenseSheet) {
                LicenseView()
            }
            .overlay(alignment: .top) {
                if showCopiedBanner {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                        Text("Device token copied to clipboard")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.85))
                    .clipShape(Capsule())
                    .padding(.top, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .task {
                await measureServerLatency()
            }
        }
    }

    // MARK: - Server Section
    private var serverSection: some View {
        Section("Downtify Server") {
            if let session = sessionStore.session {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(DowntifyColor.primary.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: DowntifyIcons.server)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(DowntifyColor.primary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.serverName.isEmpty ? "Connected Server" : session.serverName)
                                .font(DowntifyFont.cardTitle)
                                .foregroundColor(DowntifyColor.textPrimary)
                            Text(session.baseUrl)
                                .font(DowntifyFont.caption)
                                .foregroundColor(DowntifyColor.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        latencyBadge
                    }

                    if !session.username.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(DowntifyColor.textSecondary)
                            Text("Account: \(session.username)")
                                .font(DowntifyFont.caption)
                                .foregroundColor(DowntifyColor.textSecondary)
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.vertical, 4)

                Button {
                    showSwitchServerAlert = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Switch Server / Re-pair")
                    }
                    .foregroundColor(DowntifyColor.primary)
                }

                Button(role: .destructive) {
                    showSignOutAlert = true
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign Out")
                    }
                }
            } else {
                Text("Not connected to a server")
                    .font(DowntifyFont.body)
                    .foregroundColor(DowntifyColor.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var latencyBadge: some View {
        if isPinging {
            ProgressView()
                .scaleEffect(0.7)
        } else if let ms = latencyMs {
            HStack(spacing: 5) {
                Circle()
                    .fill(ms < 150 ? Color.green : (ms < 400 ? Color.yellow : Color.red))
                    .frame(width: 7, height: 7)
                Text("\(ms) ms")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(DowntifyColor.textSecondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(DowntifyColor.surface)
            .clipShape(Capsule())
        }
    }

    // MARK: - Playback Section
    private var playbackSection: some View {
        Section("Playback & Audio") {
            Picker("Wi-Fi Streaming", selection: $wifiQuality) {
                ForEach(StreamQualityPreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset.rawValue)
                }
            }

            Picker("Cellular Streaming", selection: $cellularQuality) {
                ForEach(StreamQualityPreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset.rawValue)
                }
            }

            Picker("Loudness Normalization", selection: $loudnessProfile) {
                ForEach(LoudnessProfilePreset.allCases) { profile in
                    Text(profile.rawValue).tag(profile.rawValue)
                }
            }

            if let profile = LoudnessProfilePreset(rawValue: loudnessProfile) {
                Text(profile.description)
                    .font(DowntifyFont.caption)
                    .foregroundColor(DowntifyColor.textSecondary)
            }
        }
    }

    // MARK: - Appearance Section
    private var appearanceSection: some View {
        Section("Appearance") {
            Toggle("Dark Mode", isOn: $theme.isDarkMode)
                .tint(DowntifyColor.primary)

            Toggle("Pure Black (OLED)", isOn: $theme.isAmoledEnabled)
                .tint(DowntifyColor.primary)
                .disabled(!theme.isDarkMode)

            VStack(alignment: .leading, spacing: 10) {
                Text("Accent Color")
                    .font(DowntifyFont.body)
                    .foregroundColor(DowntifyColor.textPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(DowntifyAccentColor.allCases) { accent in
                            Button {
                                withAnimation(.spring(response: 0.25)) {
                                    theme.selectedAccent = accent
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(accent.color)
                                        .frame(width: 36, height: 36)

                                    if theme.selectedAccent == accent {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.black)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Storage & Maintenance Section
    private var storageAndMaintenanceSection: some View {
        Section("Storage & Maintenance") {
            NavigationLink(destination: StorageManagementView()) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "internaldrive.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.blue)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Storage Management")
                            .font(DowntifyFont.body)
                            .foregroundColor(DowntifyColor.textPrimary)
                        Text("Offline downloads, cache size & quotas")
                            .font(DowntifyFont.caption)
                            .foregroundColor(DowntifyColor.textSecondary)
                    }
                }
            }

            NavigationLink(destination: TrashView()) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "trash.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.orange)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Music Trash")
                            .font(DowntifyFont.body)
                            .foregroundColor(DowntifyColor.textPrimary)
                        Text("View and restore soft-deleted tracks")
                            .font(DowntifyFont.caption)
                            .foregroundColor(DowntifyColor.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - About Downtify Section
    private var aboutSection: some View {
        Section("About Downtify") {
            HStack {
                Text("Client Version")
                Spacer()
                Text("1.0.0 (Build 1)")
                    .foregroundColor(DowntifyColor.textSecondary)
            }

            if let token = sessionStore.session?.token, !token.isEmpty {
                Button {
                    UIPasteboard.general.string = token
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.spring(response: 0.3)) {
                        showCopiedBanner = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation { showCopiedBanner = false }
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Device Token")
                                .font(DowntifyFont.body)
                                .foregroundColor(DowntifyColor.textPrimary)
                            Text(String(token.prefix(16)) + "••••••••")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(DowntifyColor.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14))
                            .foregroundColor(DowntifyColor.primary)
                    }
                }
                .buttonStyle(.plain)
            }

            Link(destination: URL(string: "https://github.com/calebwickham2011-sketch/downtify-ios")!) {
                HStack {
                    Text("GitHub Repository")
                        .foregroundColor(DowntifyColor.textPrimary)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12))
                        .foregroundColor(DowntifyColor.textSecondary)
                }
            }

            Button {
                showLicenseSheet = true
            } label: {
                HStack {
                    Text("License (GPL-3.0)")
                        .foregroundColor(DowntifyColor.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(DowntifyColor.textTertiary)
                }
            }
        }
    }

    private func measureServerLatency() async {
        guard let session = sessionStore.session,
              let url = URL(string: session.baseUrl) else { return }

        isPinging = true
        let start = CFAbsoluteTimeGetCurrent()
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 4.0
            _ = try await URLSession.shared.data(for: request)
            let elapsed = Int((CFAbsoluteTimeGetCurrent() - start) * 1000.0)
            await MainActor.run {
                self.latencyMs = max(1, elapsed)
                self.isPinging = false
            }
        } catch {
            await MainActor.run {
                self.latencyMs = nil
                self.isPinging = false
            }
        }
    }
}

// MARK: - License Viewer Modal
public struct LicenseView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var licenseText: String = ""

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                Text(licenseText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(DowntifyColor.textSecondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(DowntifyColor.backgroundDark.ignoresSafeArea())
            .navigationTitle("GNU GPL v3.0 License")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let url = URL(string: "https://www.gnu.org/licenses/gpl-3.0.txt") {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(DowntifyColor.primary)
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(DowntifyFont.bodyBold)
                    .foregroundColor(DowntifyColor.primary)
                }
            }
            .onAppear {
                loadLicense()
            }
        }
    }

    private func loadLicense() {
        if let path = Bundle.main.path(forResource: "license", ofType: "txt"),
           let text = try? String(contentsOfFile: path, encoding: .utf8) {
            licenseText = text
            return
        }
        // Fallback default license preamble
        licenseText = """
                    GNU GENERAL PUBLIC LICENSE
                       Version 3, 29 June 2007

 Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
 Everyone is permitted to copy and distribute verbatim copies
 of this license document, but changing it is not allowed.

                            Preamble

  The GNU General Public License is a free, copyleft license for
software and other kinds of works.

  The licenses for most software and other practical works are designed
to take away your freedom to share and change the works.  By contrast,
the GNU General Public License is intended to guarantee your freedom to
share and change all versions of a program--to make sure it remains free
software for all its users.  We, the Free Software Foundation, use the
GNU General Public License for most of our software; it applies also to
any other work released this way by its authors.  You can apply it to
your programs, too.
"""
    }
}
