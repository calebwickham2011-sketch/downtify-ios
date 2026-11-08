import Foundation
import UIKit

public enum PairingResult: Error {
    case success(Session)
    case wrongCode
    case wrongPassword
    case signInDisabled
    case tooManyAttempts(Int)
    case incompatible(String)
    case unreachable(String)
    case failure(String)
}

public class PairingClient {
    public static let shared = PairingClient()
    
    private struct PairRequestBody: Codable {
        let code: String
        let deviceName: String
        let platform: String
        
        enum CodingKeys: String, CodingKey {
            case code
            case deviceName = "device_name"
            case platform
        }
    }
    
    private struct SignInRequestBody: Codable {
        let username: String
        let password: String
        let deviceName: String
        let platform: String
        
        enum CodingKeys: String, CodingKey {
            case username
            case password
            case deviceName = "device_name"
            case platform
        }
    }
    
    private struct ServerPairResponse: Codable {
        let token: String
        let device: DeviceDto
        let server: PairedServerDto
        let user: UserDto?
        
        struct DeviceDto: Codable {
            let id: String
            let name: String?
        }
        struct PairedServerDto: Codable {
            let serverId: String?
            let name: String?
            let version: String?
            enum CodingKeys: String, CodingKey {
                case serverId = "server_id"
                case name
                case version
            }
        }
        struct UserDto: Codable {
            let username: String?
            let role: String?
        }
    }
    
    public func fetchServerInfo(baseUrl: String) async -> Result<ServerInfo, PairingResult> {
        guard let url = URL(string: "\(baseUrl)/api/server/info") else {
            return .failure(.unreachable("Invalid server URL"))
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 8
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.unreachable("No response from server"))
            }
            if http.statusCode == 200 {
                let info = try JSONDecoder().decode(ServerInfo.self, from: data)
                if info.compatibility != .ok {
                    return .failure(.incompatible("Incompatible Downtify server: \(info.product) v\(info.version)"))
                }
                return .success(info)
            } else {
                return .failure(.unreachable("Server returned status \(http.statusCode)"))
            }
        } catch {
            return .failure(.unreachable(error.localizedDescription))
        }
    }
    
    public func pair(baseUrl: String, code: String) async -> PairingResult {
        guard let url = URL(string: "\(baseUrl)/api/auth/pair") else {
            return .unreachable("Invalid URL")
        }
        let deviceName = await UIDevice.current.name
        let body = PairRequestBody(code: code.trimmingCharacters(in: .whitespacesAndNewlines), deviceName: deviceName, platform: "ios")
        guard let bodyData = try? JSONEncoder().encode(body) else {
            return .failure("Encoding error")
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = bodyData
        req.timeoutInterval = 10
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else { return .unreachable("No response") }
            if http.statusCode == 200 {
                let resp = try JSONDecoder().decode(ServerPairResponse.self, from: data)
                let session = Session(
                    baseUrl: baseUrl,
                    serverId: resp.server.serverId ?? "",
                    serverName: resp.server.name ?? "Downtify Server",
                    deviceId: resp.device.id,
                    token: resp.token,
                    username: resp.user?.username ?? ""
                )
                return .success(session)
            } else if http.statusCode == 401 {
                return .wrongCode
            } else if http.statusCode == 429 {
                return .tooManyAttempts(60)
            } else {
                return .failure("Pairing failed (status \(http.statusCode))")
            }
        } catch {
            return .unreachable(error.localizedDescription)
        }
    }
    
    public func signIn(baseUrl: String, username: String, password: String) async -> PairingResult {
        guard let url = URL(string: "\(baseUrl)/api/auth/token") else {
            return .unreachable("Invalid URL")
        }
        let deviceName = await UIDevice.current.name
        let body = SignInRequestBody(
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            deviceName: deviceName,
            platform: "ios"
        )
        guard let bodyData = try? JSONEncoder().encode(body) else {
            return .failure("Encoding error")
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = bodyData
        req.timeoutInterval = 10
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else { return .unreachable("No response") }
            if http.statusCode == 200 {
                let resp = try JSONDecoder().decode(ServerPairResponse.self, from: data)
                let session = Session(
                    baseUrl: baseUrl,
                    serverId: resp.server.serverId ?? "",
                    serverName: resp.server.name ?? "Downtify Server",
                    deviceId: resp.device.id,
                    token: resp.token,
                    username: resp.user?.username ?? username
                )
                return .success(session)
            } else if http.statusCode == 401 {
                return .wrongPassword
            } else if http.statusCode == 409 {
                return .signInDisabled
            } else if http.statusCode == 429 {
                return .tooManyAttempts(60)
            } else {
                return .failure("Sign in failed (status \(http.statusCode))")
            }
        } catch {
            return .unreachable(error.localizedDescription)
        }
    }
}
