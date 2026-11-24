import SwiftUI

@main
struct DowntifyApp: App {
    @StateObject private var theme = ThemeManager.shared
    @StateObject private var sessionStore = KeychainSessionStore.shared
    @State private var isShowingSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main Application Content
                Group {
                    if sessionStore.session != nil {
                        ContentView()
                    } else {
                        ConnectView()
                    }
                }

                // Native SwiftUI Splash Overlay
                if isShowingSplash {
                    SplashScreenView {
                        withAnimation(.easeOut(duration: 0.45)) {
                            isShowingSplash = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(999)
                }
            }
            .preferredColorScheme(theme.isDarkMode ? .dark : .light)
        }
    }
}

// MARK: - Native SwiftUI Splash Screen matching Downtify branding
public struct SplashScreenView: View {
    public let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.82
    @State private var opacity: Double = 0.0
    @State private var textOpacity: Double = 0.0

    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            DowntifyColor.backgroundDark
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Downtify green disc with dark shield
                Image("SplashLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 140, height: 140)
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .shadow(color: DowntifyColor.primary.opacity(0.35), radius: 24, x: 0, y: 8)

                VStack(spacing: 6) {
                    Text("Downtify")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Your music, from your server.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(DowntifyColor.textSecondary)
                }
                .opacity(textOpacity)

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                scale = 1.0
                opacity = 1.0
            }
            withAnimation(.easeIn(duration: 0.4).delay(0.2)) {
                textOpacity = 1.0
            }
            // Auto dismiss after 1.1s
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
                onDismiss()
            }
        }
        .onTapGesture {
            onDismiss()
        }
    }
}
