import SwiftUI

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var sessionStore = KeychainSessionStore.shared
    
    @State private var streamQuality = "Automatic (High)"
    @State private var loudnessNormalization = "Normal"
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                // Server Connection
                Section("Downtify Server") {
                    if let session = sessionStore.session {
                        HStack {
                            Image(systemName: DowntifyIcons.server)
                                .foregroundColor(DowntifyColor.primary)
                                .frame(width: 28)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.serverName.isEmpty ? "Connected Server" : session.serverName)
                                    .font(DowntifyFont.bodyBold)
                                Text(session.baseUrl)
                                    .font(DowntifyFont.caption)
                                    .foregroundColor(DowntifyColor.textSecondary)
                                if !session.username.isEmpty {
                                    Text("Account: \(session.username)")
                                        .font(DowntifyFont.caption)
                                        .foregroundColor(DowntifyColor.primary)
                                }
                            }
                            
                            Spacer()
                            
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                        }
                    } else {
                        Text("Not connected to a server")
                            .font(DowntifyFont.body)
                            .foregroundColor(DowntifyColor.textSecondary)
                    }
                    
                    Button("Switch Server / Re-pair") {
                        sessionStore.clear(reason: .user)
                        dismiss()
                    }
                    .foregroundColor(DowntifyColor.primary)
                    
                    Button("Sign Out", role: .destructive) {
                        sessionStore.clear(reason: .user)
                        dismiss()
                    }
                }
                
                // Appearance
                Section("Appearance") {
                    Toggle("Pure Black (AMOLED)", isOn: $theme.isAmoledEnabled)
                        .tint(DowntifyColor.primary)
                    
                    HStack {
                        Text("Theme")
                        Spacer()
                        Text("Dark Mode")
                            .foregroundColor(DowntifyColor.textSecondary)
                    }
                    
                    HStack {
                        Text("Typography")
                        Spacer()
                        Text("Google Sans Rounded")
                            .foregroundColor(DowntifyColor.textSecondary)
                    }
                }
                
                // Playback
                Section("Playback & Audio") {
                    HStack {
                        Text("Streaming Quality")
                        Spacer()
                        Text(streamQuality)
                            .foregroundColor(DowntifyColor.textSecondary)
                    }
                    
                    HStack {
                        Text("Loudness Normalization")
                        Spacer()
                        Text(loudnessNormalization)
                            .foregroundColor(DowntifyColor.textSecondary)
                    }
                }
                
                // Storage & Cache
                Section("Storage") {
                    HStack {
                        Text("Audio Cache Size")
                        Spacer()
                        Text("142 MB")
                            .font(DowntifyFont.dataValue)
                            .foregroundColor(DowntifyColor.textSecondary)
                    }
                    
                    Button("Clear Local Cache", role: .destructive) {}
                }
                
                // About
                Section("About Downtify") {
                    HStack {
                        Text("Client Version")
                        Spacer()
                        Text("1.0.0 (iOS)")
                            .foregroundColor(DowntifyColor.textSecondary)
                    }
                    
                    Link("GitHub Repository", destination: URL(string: "https://github.com/calebwickham2011-sketch/downtify-ios")!)
                    
                    HStack {
                        Text("License")
                        Spacer()
                        Text("GPL-3.0")
                            .foregroundColor(DowntifyColor.textSecondary)
                    }
                }
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
        }
    }
}
