import Foundation
import Security

@MainActor
public class KeychainSessionStore: ObservableObject {
    public static let shared = KeychainSessionStore()
    
    private static let serviceName = "com.calebwickham.downtify"
    private static let sessionAccount = "downtify_paired_session"
    
    @Published public private(set) var session: Session?
    @Published public private(set) var lastSignOutReason: SignOutReason?
    
    public init() {
        self.session = Self.loadSessionFromKeychain()
    }
    
    public func save(session: Session) {
        Self.saveSessionToKeychain(session)
        self.session = session
        self.lastSignOutReason = nil
    }
    
    public func clear(reason: SignOutReason = .user) {
        Self.deleteSessionFromKeychain()
        self.session = nil
        self.lastSignOutReason = reason
    }
    
    public func onRevoked(token: String) {
        if session?.token == token {
            clear(reason: .revoked)
        }
    }
    
    // MARK: - Keychain Security APIs
    private static func saveSessionToKeychain(_ session: Session) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        deleteSessionFromKeychain()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: sessionAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private static func loadSessionFromKeychain() -> Session? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: sessionAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(Session.self, from: data)
    }
    
    private static func deleteSessionFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: sessionAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}
