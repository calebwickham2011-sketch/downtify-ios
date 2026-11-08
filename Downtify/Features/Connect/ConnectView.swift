import SwiftUI

public struct ConnectView: View {
    @ObservedObject var discovery = ServerDiscovery.shared
    @ObservedObject var sessionStore = KeychainSessionStore.shared
    
    @State private var serverAddress = ""
    @State private var username = ""
    @State private var password = ""
    @State private var pairingCode = ""
    
    @State private var isBusy = false
    @State private var showScanner = false
    @State private var errorMessage: String?
    @State private var connectedInfo: ServerInfo?
    @State private var activeBaseUrl: String?
    
    // Auth mode: .credentials or .code
    @State private var authMode: AuthMode = .credentials
    
    enum AuthMode {
        case credentials
        case pairingCode
    }
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Brand Logo
                    VStack(spacing: 8) {
                        Image(systemName: "music.note.house.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(DowntifyColor.primary.gradient)
                            .padding(.top, 16)
                        
                        Text("Connect to Downtify")
                            .font(DowntifyFont.hero)
                            .foregroundColor(DowntifyColor.textPrimary)
                        
                        Text("Sign in or pair with your self-hosted music server")
                            .font(DowntifyFont.body)
                            .foregroundColor(DowntifyColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    
                    if let error = errorMessage {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(DowntifyColor.error)
                            Text(error)
                                .font(DowntifyFont.label)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: DowntifyShape.cardRadius, style: .continuous)
                                .fill(DowntifyColor.error.opacity(0.2))
                                .stroke(DowntifyColor.error.opacity(0.4), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                    }
                    
                    // Step 1: Server Selection / Input
                    if connectedInfo == nil {
                        VStack(alignment: .leading, spacing: 16) {
                            // Found Servers on Wi-Fi
                            if !discovery.servers.isEmpty {
                                Text("Found on your network")
                                    .font(DowntifyFont.sectionTitle)
                                    .foregroundColor(DowntifyColor.textPrimary)
                                    .padding(.horizontal, 16)
                                
                                LazyVStack(spacing: 10) {
                                    ForEach(discovery.servers) { srv in
                                        Button(action: { selectServer(srv.baseUrl) }) {
                                            HStack(spacing: 12) {
                                                Image(systemName: DowntifyIcons.server)
                                                    .foregroundColor(DowntifyColor.primary)
                                                    .font(.system(size: 20))
                                                
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(srv.name)
                                                        .font(DowntifyFont.cardTitle)
                                                        .foregroundColor(DowntifyColor.textPrimary)
                                                    Text(srv.address)
                                                        .font(DowntifyFont.cardSubtitle)
                                                        .foregroundColor(DowntifyColor.textSecondary)
                                                }
                                                
                                                Spacer()
                                                
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(DowntifyColor.textTertiary)
                                            }
                                            .padding(14)
                                            .background(
                                                RoundedRectangle(cornerRadius: DowntifyShape.cardRadius, style: .continuous)
                                                    .fill(DowntifyColor.surfaceRaised)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.horizontal, 16)
                                    }
                                }
                            }
                            
                            // Manual Address Input
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Or type server address")
                                    .font(DowntifyFont.sectionTitle)
                                    .foregroundColor(DowntifyColor.textPrimary)
                                
                                HStack(spacing: 10) {
                                    Image(systemName: "network")
                                        .foregroundColor(DowntifyColor.textSecondary)
                                    
                                    TextField("192.168.1.100:8000", text: $serverAddress)
                                        .font(DowntifyFont.body)
                                        .foregroundColor(DowntifyColor.textPrimary)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                        .keyboardType(.URL)
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: DowntifyShape.cardRadius, style: .continuous)
                                        .fill(DowntifyColor.surfaceRaised)
                                )
                                
                                Button(action: { checkAddressAndProceed(serverAddress) }) {
                                    HStack {
                                        Spacer()
                                        if isBusy {
                                            ProgressView()
                                                .tint(.black)
                                        } else {
                                            Text("Connect to Server")
                                                .font(DowntifyFont.bodyBold)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 14)
                                    .background(
                                        Capsule()
                                            .fill(serverAddress.isEmpty ? DowntifyColor.surfaceHighlight : DowntifyColor.primary)
                                    )
                                    .foregroundColor(serverAddress.isEmpty ? DowntifyColor.textTertiary : .black)
                                }
                                .disabled(serverAddress.isEmpty || isBusy)
                            }
                            .padding(.horizontal, 16)
                            
                            // QR Scanner Quick Button
                            VStack(spacing: 12) {
                                Button(action: { showScanner = true }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "qrcode.viewfinder")
                                            .font(.system(size: 20))
                                        Text("Scan Web Pairing QR Code")
                                            .font(DowntifyFont.bodyBold)
                                    }
                                    .foregroundColor(DowntifyColor.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: DowntifyShape.cardRadius, style: .continuous)
                                            .fill(DowntifyColor.surfaceRaised)
                                    )
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    } else {
                        // Step 2: Sign-In / Pairing Code Form
                        VStack(alignment: .leading, spacing: 20) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(connectedInfo?.name ?? "Downtify Server")
                                        .font(DowntifyFont.sectionTitle)
                                        .foregroundColor(DowntifyColor.textPrimary)
                                    Text(activeBaseUrl ?? "")
                                        .font(DowntifyFont.caption)
                                        .foregroundColor(DowntifyColor.textSecondary)
                                }
                                Spacer()
                                Button("Change") {
                                    connectedInfo = nil
                                    activeBaseUrl = nil
                                    errorMessage = nil
                                }
                                .font(DowntifyFont.label)
                                .foregroundColor(DowntifyColor.primary)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: DowntifyShape.cardRadius, style: .continuous)
                                    .fill(DowntifyColor.surfaceRaised)
                            )
                            
                            // Auth Switcher
                            Picker("Auth Mode", selection: $authMode) {
                                Text("Password Sign In").tag(AuthMode.credentials)
                                Text("Pairing Code").tag(AuthMode.pairingCode)
                            }
                            .pickerStyle(.segmented)
                            
                            if authMode == .credentials {
                                // Username & Password
                                VStack(spacing: 12) {
                                    HStack {
                                        Image(systemName: "person.fill")
                                            .foregroundColor(DowntifyColor.textSecondary)
                                        TextField("Username", text: $username)
                                            .font(DowntifyFont.body)
                                            .foregroundColor(DowntifyColor.textPrimary)
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled()
                                    }
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: DowntifyShape.cardRadius, style: .continuous)
                                            .fill(DowntifyColor.surfaceRaised)
                                    )
                                    
                                    HStack {
                                        Image(systemName: "lock.fill")
                                            .foregroundColor(DowntifyColor.textSecondary)
                                        SecureField("Password", text: $password)
                                            .font(DowntifyFont.body)
                                            .foregroundColor(DowntifyColor.textPrimary)
                                    }
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: DowntifyShape.cardRadius, style: .continuous)
                                            .fill(DowntifyColor.surfaceRaised)
                                    )
                                    
                                    Button(action: performSignIn) {
                                        HStack {
                                            Spacer()
                                            if isBusy {
                                                ProgressView().tint(.black)
                                            } else {
                                                Text("Sign In")
                                                    .font(DowntifyFont.bodyBold)
                                            }
                                            Spacer()
                                        }
                                        .padding(.vertical, 14)
                                        .background(Capsule().fill(DowntifyColor.primary))
                                        .foregroundColor(.black)
                                    }
                                    .disabled(username.isEmpty || password.isEmpty || isBusy)
                                }
                            } else {
                                // 8-character Pairing Code
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Enter 8-Character Pairing Code")
                                        .font(DowntifyFont.cardTitle)
                                        .foregroundColor(DowntifyColor.textPrimary)
                                    
                                    Text("Generate one in Downtify Web: Settings → Apps → Pair a phone")
                                        .font(DowntifyFont.caption)
                                        .foregroundColor(DowntifyColor.textSecondary)
                                    
                                    HStack {
                                        Image(systemName: "key.fill")
                                            .foregroundColor(DowntifyColor.textSecondary)
                                        TextField("e.g. A1B2C3D4", text: $pairingCode)
                                            .font(DowntifyFont.bodyBold)
                                            .foregroundColor(DowntifyColor.textPrimary)
                                            .autocorrectionDisabled()
                                            .textInputAutocapitalization(.characters)
                                    }
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: DowntifyShape.cardRadius, style: .continuous)
                                            .fill(DowntifyColor.surfaceRaised)
                                    )
                                    
                                    Button(action: performPairing) {
                                        HStack {
                                            Spacer()
                                            if isBusy {
                                                ProgressView().tint(.black)
                                            } else {
                                                Text("Pair Device")
                                                    .font(DowntifyFont.bodyBold)
                                            }
                                            Spacer()
                                        }
                                        .padding(.vertical, 14)
                                        .background(Capsule().fill(DowntifyColor.primary))
                                        .foregroundColor(.black)
                                    }
                                    .disabled(pairingCode.count < 6 || isBusy)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    Spacer(minLength: 40)
                }
            }
            .background(DowntifyColor.backgroundDark.ignoresSafeArea())
            .sheet(isPresented: $showScanner) {
                QRScannerView(
                    onScanned: { scannedText in
                        showScanner = false
                        handleScannedQR(scannedText)
                    },
                    onCancel: {
                        showScanner = false
                    }
                )
            }
            .onAppear {
                discovery.start()
            }
            .onDisappear {
                discovery.stop()
            }
        }
    }
    
    // MARK: - Actions
    private func selectServer(_ baseUrl: String) {
        checkAddressAndProceed(baseUrl)
    }
    
    private func checkAddressAndProceed(_ raw: String) {
        guard let normalized = ServerAddress.normalize(raw) else {
            errorMessage = "Please enter a valid IP address or URL"
            return
        }
        isBusy = true
        errorMessage = nil
        Task {
            let res = await PairingClient.shared.fetchServerInfo(baseUrl: normalized)
            await MainActor.run {
                isBusy = false
                switch res {
                case .success(let info):
                    self.connectedInfo = info
                    self.activeBaseUrl = normalized
                    // Default to credentials if supported, else pairing code
                    self.authMode = info.capabilities.passwordSignIn ? .credentials : .pairingCode
                case .failure(let err):
                    switch err {
                    case .incompatible(let msg): self.errorMessage = msg
                    case .unreachable(let msg): self.errorMessage = "Could not reach server: \(msg)"
                    default: self.errorMessage = "Failed to connect to server"
                    }
                }
            }
        }
    }
    
    private func performSignIn() {
        guard let baseUrl = activeBaseUrl else { return }
        isBusy = true
        errorMessage = nil
        Task {
            let res = await PairingClient.shared.signIn(baseUrl: baseUrl, username: username, password: password)
            await MainActor.run {
                isBusy = false
                handlePairingResult(res)
            }
        }
    }
    
    private func performPairing() {
        guard let baseUrl = activeBaseUrl else { return }
        isBusy = true
        errorMessage = nil
        Task {
            let res = await PairingClient.shared.pair(baseUrl: baseUrl, code: pairingCode)
            await MainActor.run {
                isBusy = false
                handlePairingResult(res)
            }
        }
    }
    
    private func handleScannedQR(_ qrText: String) {
        guard let payload = PairingPayload.parse(qrText) else {
            errorMessage = "Scanned code is not a valid Downtify pairing QR"
            return
        }
        isBusy = true
        errorMessage = nil
        Task {
            let res = await PairingClient.shared.pair(baseUrl: payload.baseUrl, code: payload.code)
            await MainActor.run {
                isBusy = false
                handlePairingResult(res)
            }
        }
    }
    
    private func handlePairingResult(_ res: PairingResult) {
        switch res {
        case .success(let session):
            sessionStore.save(session: session)
        case .wrongPassword:
            errorMessage = "Invalid username or password"
        case .wrongCode:
            errorMessage = "Pairing code is invalid, expired, or already used"
        case .signInDisabled:
            errorMessage = "Password sign-in is disabled on this server. Please use a pairing code."
            authMode = .pairingCode
        case .tooManyAttempts(let sec):
            errorMessage = "Too many attempts. Please try again in \(sec) seconds."
        case .incompatible(let msg):
            errorMessage = msg
        case .unreachable(let msg):
            errorMessage = "Server unreachable: \(msg)"
        case .failure(let msg):
            errorMessage = msg
        }
    }
}
