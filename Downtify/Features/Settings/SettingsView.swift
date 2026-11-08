import SwiftUI

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var theme = ThemeManager.shared
    
    @State private var serverAddress = "http://192.168.1.100:8000"
    @State private var streamQuality = "Automatic (High)"
    @State private var loudnessNormalization = "Normal"
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                // Server Connection
                Section("Downtify Server") {
                    HStack {
                        Image(systemName: DowntifyIcons.server)
                            .foregroundColor(DowntifyColor.primary)
                            .frame(width: 28)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Connected Server")
                                .font(DowntifyFont.bodyBold)
                            Text(serverAddress)
                                .font(DowntifyFont.caption)
                                .foregroundColor(DowntifyColor.textSecondary)
                        }
                        
                        Spacer()
                        
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                    
                    Button("Switch Server / Re-pair") {
                        // Triggers Phase 2 onboarding
                    }
                    .foregroundColor(DowntifyColor.primary)
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
