import Foundation
import UIKit
import Security

// MARK: - Game Data Models
struct GameSession {
    let date: Date
    let durationMinutes: Int
    let caloriesBurned: Int
    let trackName: String
    let trackId: String
    let characterId: String
    let totalJumps: Int
    let totalCrouches: Int
    let totalLeftLeans: Int
    let totalRightLeans: Int
    let distanceCovered: Double     // meters
    let averageSpeed: Double?       // m/min, nil if zero duration
    let characterImageName: String
    let completionStatus: String    // "completed" or "abandoned"
}

struct PlayerStats {
    var calories: Int
    var runTimeMinutes: Int
    var currentStreak: Int
}

struct Player {
    let id: String
    let name: String
    let description: String
    let fullBodyImageName: String
    let thumbnailImageName: String
    let backgroundImageName: String
    let videoName: String?
    let videoScale: CGFloat
    let videoOffsetX: CGFloat
    let videoOffsetY: CGFloat
    var isSelected: Bool
    var isLocked: Bool

    var statsImageName: String {
        switch videoName {
        case "c1_animated": return "Todays_stats_pink"
        case "c2_animated": return "Todays_stats_orange"
        case "c3_animated": return "Todays_stats_green"
        default: return "Todays_stats_pink"
        }
    }
}

class GameData {
    static let shared = GameData()
    private init() {}

    var stats = PlayerStats(calories: 0, runTimeMinutes: 0, currentStreak: 0)

    var players: [Player] = [
        Player(id: "p1", name: "Glitch", description: "System error: Too cute.", fullBodyImageName: "character1", thumbnailImageName: "character1", backgroundImageName: "CharacterBg1", videoName: "c1_animated", videoScale: 1.05, videoOffsetX: -170, videoOffsetY: -30, isSelected: true, isLocked: false),
        Player(id: "p2", name: "Torque", description: "Forged in heavy metal.", fullBodyImageName: "character2", thumbnailImageName: "character2", backgroundImageName: "CharacterBg2", videoName: "c2_animated", videoScale: 1.05, videoOffsetX: -170, videoOffsetY: 0, isSelected: false, isLocked: false),
        Player(id: "p3", name: "Vanguard", description: "Shadows are the weapon.", fullBodyImageName: "character5", thumbnailImageName: "character5", backgroundImageName: "CharacterBg5", videoName: "c3_animated", videoScale: 1.05, videoOffsetX: -170, videoOffsetY: -30, isSelected: false, isLocked: false),
        Player(id: "p4", name: "Cipher", description: "Hacking reality's source code.", fullBodyImageName: "character4", thumbnailImageName: "character4", backgroundImageName: "CharacterBg4", videoName: "c1_animated", videoScale: 1.05, videoOffsetX: -170, videoOffsetY: 0, isSelected: false, isLocked: false),
        Player(id: "p5", name: "Sprout", description: "Blooming in the void.", fullBodyImageName: "character3", thumbnailImageName: "character3", backgroundImageName: "CharacterBg3", videoName: "c3_animated", videoScale: 1.05, videoOffsetX: -170, videoOffsetY: -30, isSelected: false, isLocked: false),
        Player(id: "p6", name: "Nova", description: "Starlight trapped in glass.", fullBodyImageName: "character6", thumbnailImageName: "character6", backgroundImageName: "CharacterBg6", videoName: "c2_animated", videoScale: 1.05, videoOffsetX: -170, videoOffsetY: -30, isSelected: false, isLocked: false)
    ]

    var gameHistory: [GameSession] = []

    var lastSession: GameSession? {
        return gameHistory.sorted(by: { $0.date < $1.date }).last
    }

    var personalBest: GameSession? {
        return gameHistory.max(by: { $0.caloriesBurned < $1.caloriesBurned })
    }

    func getSelectedPlayer() -> Player {
        return players.first(where: { $0.isSelected }) ?? players[0]
    }

    func getSelectedIndex() -> Int {
        return players.firstIndex(where: { $0.isSelected }) ?? 0
    }

    func selectPlayer(at index: Int) -> Bool {
        guard index >= 0 && index < players.count else { return false }
        if players[index].isLocked { return false }
        for i in 0..<players.count { players[i].isSelected = (i == index) }
        return true
    }

    // MARK: - API Synced Session Handler
    func addSession(
        duration: Int,
        calories: Int,
        track: String,
        trackId: String,
        characterId: String,
        jumps: Int,
        crouches: Int,
        leftLeans: Int,
        rightLeans: Int,
        distanceCovered: Double,
        averageSpeed: Double?,
        completionStatus: String = "completed"
    ) {
        let charImg = getSelectedPlayer().thumbnailImageName
        let newSession = GameSession(
            date: Date(),
            durationMinutes: duration,
            caloriesBurned: calories,
            trackName: track,
            trackId: trackId,
            characterId: characterId,
            totalJumps: jumps,
            totalCrouches: crouches,
            totalLeftLeans: leftLeans,
            totalRightLeans: rightLeans,
            distanceCovered: distanceCovered,
            averageSpeed: averageSpeed,
            characterImageName: charImg,
            completionStatus: completionStatus
        )

        gameHistory.append(newSession)
        stats.calories += calories
        stats.runTimeMinutes += duration

        print("📊 Local stats updated! Attempting to sync with Django...")
        print("   Track: \(track) (\(trackId)) | Character: \(characterId)")
        print("   Duration: \(duration)m | Calories: \(calories) | Distance: \(String(format: "%.1f", distanceCovered))m")
        print("   Jumps: \(jumps) | Crouches: \(crouches) | Left: \(leftLeans) | Right: \(rightLeans)")

        let distanceKm = distanceCovered / 1000.0

        Task {
            do {
                guard let userId = UserDefaults.standard.string(forKey: "djangoUserID") else {
                    print("⚠️ No Django User ID found locally. Session saved locally only.")
                    return
                }

                // 1. Create the session with track + character
                let apiSession = try await APIManager.shared.createSession(
                    userId: userId, trackId: trackId, characterId: characterId
                )

                if let sessionId = apiSession.id {
                    // 2. PATCH session with full stats
                    let _ = try await APIManager.shared.updateSession(
                        sessionId: sessionId,
                        distanceCovered: distanceKm,
                        caloriesBurned: calories,
                        durationMinutes: duration,
                        averageSpeed: averageSpeed.map { $0 * 0.06 }, // m/min → km/h
                        totalJumps: jumps,
                        totalCrouches: crouches
                    )
                    // 3. Complete the session (triggers streak + badge logic)
                    let _ = try await APIManager.shared.completeSession(sessionId: sessionId)
                    print("✅ Game Session successfully saved to Django Database!")
                }
            } catch {
                print("❌ Failed to sync session to Django: \(error.localizedDescription)")
            }
        }
    }
}


// MARK: - ==========================================
// MARK: - HACKATHON FIX: API MANAGER IN SAME FILE
// MARK: - ==========================================

// MARK: - Login Error Types
enum LoginError: Error {
    case emptyUsername
    case emptyPassword
    case invalidCredentials  // 401 from server
    case userNotFound        // username doesn't exist
    case networkError        // connectivity / server down
    case sessionExpired      // refresh token also expired
}

// MARK: - Login Response (JWT)
struct LoginResponse: Codable {
    let access: String
    let refresh: String
    let user: DjangoUser
}

// MARK: - Token Refresh Response
struct TokenRefreshResponse: Codable {
    let access: String
    let refresh: String?   // optional — present when ROTATE_REFRESH_TOKENS=True
}

struct PaginatedUserResponse: Codable {
    let count: Int
    let next: String?
    let previous: String?
    let results: [DjangoUser]
}

struct DjangoUser: Codable {
    let id: String
    let username: String
    let email: String?
    let displayName: String?
    let dailyTargetDistance: Double?
    let dailyTargetCalories: Int?
    let currentWeight: Double?
    let targetWeight: Double?
    let currentStreak: Int?
    let longestStreak: Int?
    let isOnline: Bool?
    let lastSeen: String?
    let lastStreakDate: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case displayName = "display_name"
        case dailyTargetDistance = "daily_target_distance"
        case dailyTargetCalories = "daily_target_calories"
        case currentWeight = "current_weight"
        case targetWeight = "target_weight"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case isOnline = "is_online"
        case lastSeen = "last_seen"
        case lastStreakDate = "last_streak_date"
    }
}

// MARK: - JWT Token Manager
class TokenManager {
    static let shared = TokenManager()
    private init() {}

    private let service = "com.exertia.jwt"
    private let accessAccount = "access_token"
    private let refreshAccount = "refresh_token"

    /// Migrate tokens from UserDefaults to Keychain (one-time, for existing users)
    func migrateFromUserDefaultsIfNeeded() {
        let udAccessKey = "jwt_access_token"
        let udRefreshKey = "jwt_refresh_token"
        if let access = UserDefaults.standard.string(forKey: udAccessKey),
           let refresh = UserDefaults.standard.string(forKey: udRefreshKey),
           readKeychain(account: accessAccount) == nil {
            save(access: access, refresh: refresh)
            UserDefaults.standard.removeObject(forKey: udAccessKey)
            UserDefaults.standard.removeObject(forKey: udRefreshKey)
            print("🔐 Migrated tokens from UserDefaults to Keychain")
        }
    }

    var accessToken: String? {
        get { readKeychain(account: accessAccount) }
        set {
            if let value = newValue { writeKeychain(account: accessAccount, value: value) }
            else { deleteKeychain(account: accessAccount) }
        }
    }

    var refreshToken: String? {
        get { readKeychain(account: refreshAccount) }
        set {
            if let value = newValue { writeKeychain(account: refreshAccount, value: value) }
            else { deleteKeychain(account: refreshAccount) }
        }
    }

    func save(access: String, refresh: String) {
        accessToken = access
        refreshToken = refresh
        print("🔐 Tokens saved to Keychain")
    }

    func clear() {
        deleteKeychain(account: accessAccount)
        deleteKeychain(account: refreshAccount)
        print("🔐 Tokens cleared from Keychain")
    }

    var hasTokens: Bool {
        return refreshToken != nil
    }

    // MARK: - Keychain Helpers
    private func writeKeychain(account: String, value: String) {
        let data = Data(value.utf8)
        // Delete existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func readKeychain(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteKeychain(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

struct DjangoSession: Codable {
    let id: String?
    let user: String?
    let username: String?
    let trackId: String?
    let characterId: String?
    let durationMinutes: Int?
    let caloriesBurned: Int?
    let distanceCovered: Double?
    let averageSpeed: Double?
    let totalJumps: Int?
    let totalCrouches: Int?
    let completionStatus: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case user
        case username
        case trackId = "track_id"
        case characterId = "character_id"
        case durationMinutes = "duration_minutes"
        case caloriesBurned = "calories_burned"
        case distanceCovered = "distance_covered"
        case averageSpeed = "average_speed"
        case totalJumps = "total_jumps"
        case totalCrouches = "total_crouches"
        case completionStatus = "completion_status"
        case createdAt = "created_at"
    }
}

struct DjangoUserStats: Codable {
    let totalSessions: Int
    let totalMinutes: Int
    let totalCalories: Int
    let totalDistance: Double
    let completedSessions: Int
    let personalBestDistance: Double
    let personalBestCalories: Int
    let friendCount: Int

    enum CodingKeys: String, CodingKey {
        case totalSessions = "total_sessions"
        case totalMinutes = "total_minutes"
        case totalCalories = "total_calories"
        case totalDistance = "total_distance"
        case completedSessions = "completed_sessions"
        case personalBestDistance = "personal_best_distance"
        case personalBestCalories = "personal_best_calories"
        case friendCount = "friend_count"
    }
}

struct DjangoFriendship: Codable {
    let id: String
    let requester: String
    let requesterUsername: String
    let receiver: String
    let receiverUsername: String
    let status: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case requester
        case requesterUsername = "requester_username"
        case receiver
        case receiverUsername = "receiver_username"
        case status
        case createdAt = "created_at"
    }
}

// MARK: - Streak Calendar Model
struct DailyProgress: Codable {
    let id: String
    let date: String          // "2026-03-18"
    let totalDistance: Double
    let totalCalories: Int
    let totalDurationMins: Int
    let targetMet: Bool

    enum CodingKeys: String, CodingKey {
        case id, date
        case totalDistance = "total_distance"
        case totalCalories = "total_calories"
        case totalDurationMins = "total_duration_mins"
        case targetMet = "target_met"
    }
}

// MARK: - Badge Models
struct DjangoBadge: Codable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let badgeType: String
    let targetValue: Double

    enum CodingKeys: String, CodingKey {
        case id, name, description, icon
        case badgeType = "badge_type"
        case targetValue = "target_value"
    }
}

struct DjangoUserBadge: Codable {
    let id: String
    let badge: DjangoBadge
    let currentProgress: Double
    let isCompleted: Bool
    let completedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, badge
        case currentProgress = "current_progress"
        case isCompleted = "is_completed"
        case completedAt = "completed_at"
    }
}

struct PaginatedFriendshipResponse: Codable {
    let count: Int
    let next: String?
    let previous: String?
    let results: [DjangoFriendship]
}

class APIManager {
    static let shared = APIManager()
    private let baseURL = "https://exertia-backend.onrender.com/api"
    private var isRefreshing = false

    private init() {}

    // MARK: - Core request with automatic token refresh on 401
    private func makeRequest<T: Codable>(endpoint: String, method: String, body: Data? = nil, requiresAuth: Bool = true, responseType: T.Type) async throws -> T {
        let (data, httpResponse) = try await executeRequest(endpoint: endpoint, method: method, body: body, requiresAuth: requiresAuth)

        // If 401 and we have a refresh token, try refreshing
        if httpResponse.statusCode == 401 && requiresAuth {
            let refreshed = await attemptTokenRefresh()
            if refreshed {
                // Retry the original request with new token
                let (retryData, retryResponse) = try await executeRequest(endpoint: endpoint, method: method, body: body, requiresAuth: true)
                if !(200...299).contains(retryResponse.statusCode) {
                    let errorString = String(data: retryData, encoding: .utf8) ?? "Unknown Error"
                    print("❌ API Error [\(retryResponse.statusCode)] after refresh: \(errorString)")
                    throw URLError(.badServerResponse)
                }
                return try JSONDecoder().decode(T.self, from: retryData)
            } else {
                // Refresh failed — session expired. Don't redirect here; let callers handle it.
                throw LoginError.sessionExpired
            }
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown Error"
            print("❌ API Error [\(httpResponse.statusCode)]: \(errorString)")
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Raw HTTP executor (no status check)
    private func executeRequest(endpoint: String, method: String, body: Data? = nil, requiresAuth: Bool = true) async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if requiresAuth, let token = TokenManager.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = body { request.httpBody = body }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, httpResponse)
    }

    // MARK: - Token Refresh
    // Returns: true=success, false=token genuinely expired (401/403), throws=server/network error
    enum RefreshResult { case success, expired, serverError }

    func attemptTokenRefresh() async -> Bool {
        switch await refreshTokenResult() {
        case .success: return true
        case .expired: return false
        case .serverError: return false   // caller should NOT clear tokens on server error
        }
    }

    /// Low-level refresh that distinguishes expired token from server errors.
    /// Retries once on 5xx (Render free tier cold-start can take ~2s).
    func refreshTokenResult(attempt: Int = 1) async -> RefreshResult {
        guard !isRefreshing else {
            // Another refresh is already in-flight — wait briefly then report server-side error
            // so the caller (SplashVC) does NOT clear tokens
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            return .serverError
        }
        guard let refreshToken = TokenManager.shared.refreshToken else { return .expired }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let payload = ["refresh": refreshToken]
            let body = try JSONSerialization.data(withJSONObject: payload)
            let (data, httpResponse) = try await executeRequest(
                endpoint: "/auth/refresh/", method: "POST", body: body, requiresAuth: false
            )

            switch httpResponse.statusCode {
            case 200...299:
                let tokenResp = try JSONDecoder().decode(TokenRefreshResponse.self, from: data)
                let newRefresh = tokenResp.refresh ?? refreshToken
                TokenManager.shared.save(access: tokenResp.access, refresh: newRefresh)
                print("🔄 JWT tokens refreshed successfully")
                return .success

            case 401, 403:
                // Token is genuinely invalid/blacklisted — must log in again
                print("❌ Refresh token rejected (status \(httpResponse.statusCode)) — token expired")
                return .expired

            default:
                // 500/503 etc. — server error, possibly Render cold-start
                print("⚠️ Refresh got status \(httpResponse.statusCode) (attempt \(attempt))")
                if attempt < 3 {
                    isRefreshing = false
                    try? await Task.sleep(nanoseconds: 2_500_000_000)  // wait 2.5s for server to wake
                    return await refreshTokenResult(attempt: attempt + 1)
                }
                return .serverError
            }
        } catch {
            print("❌ Token refresh network error: \(error)")
            return .serverError
        }
    }

    // MARK: - Session Expired Handler — forces redirect to login from any screen
    func handleSessionExpired() {
        TokenManager.shared.clear()
        UserDefaults.standard.removeObject(forKey: "djangoUserID")

        DispatchQueue.main.async {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = scene.windows.first else { return }
            let sb = UIStoryboard(name: "Main", bundle: nil)
            if let loginVC = sb.instantiateViewController(withIdentifier: "LoginViewController") as? LoginViewController {
                loginVC.modalPresentationStyle = .fullScreen
                window.rootViewController = loginVC
                window.makeKeyAndVisible()
            }
        }
    }

    // MARK: - Create User (registration — no auth required)
    func createUser(username: String, displayName: String,
                    email: String = "", password: String = "") async throws -> DjangoUser {
        var payload: [String: Any] = [
            "username": username,
            "display_name": displayName,
            "daily_target_distance": 5.0,
            "daily_target_calories": 300
        ]
        if !email.isEmpty    { payload["email"]    = email }
        if !password.isEmpty { payload["password"] = password }
        let body = try JSONSerialization.data(withJSONObject: payload)
        return try await makeRequest(endpoint: "/users/", method: "POST", body: body, requiresAuth: false, responseType: DjangoUser.self)
    }

    // MARK: - Login with Username + Password → JWT (uses /api/auth/login/)
    func loginWithCredentials(username: String, password: String) async throws -> DjangoUser {
        let payload: [String: Any] = ["username": username, "password": password]
        let body = try JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, httpResponse) = try await executeRequest(endpoint: "/auth/login/", method: "POST", body: body, requiresAuth: false)

            switch httpResponse.statusCode {
            case 200...299:
                let loginResp = try JSONDecoder().decode(LoginResponse.self, from: data)
                TokenManager.shared.save(access: loginResp.access, refresh: loginResp.refresh)
                print("🔑 JWT tokens saved. Access: \(loginResp.access.prefix(20))…")
                return loginResp.user
            case 401:
                throw LoginError.invalidCredentials
            case 404:
                throw LoginError.userNotFound
            default:
                let msg = String(data: data, encoding: .utf8) ?? ""
                print("❌ Login HTTP \(httpResponse.statusCode): \(msg)")
                throw LoginError.invalidCredentials
            }
        } catch let e as LoginError {
            throw e
        } catch {
            throw LoginError.networkError
        }
    }

    // MARK: - Get User Profile
    func getUser(userId: String) async throws -> DjangoUser {
        return try await makeRequest(endpoint: "/users/\(userId)/", method: "GET", responseType: DjangoUser.self)
    }

    // MARK: - Set User Online/Offline
    func setUserOnline(userId: String) async throws {
        let _ = try await makeRequest(endpoint: "/users/\(userId)/go-online/", method: "POST", responseType: [String: String].self)
        print("✅ User \(userId) is ONLINE in Django")
    }

    func setUserOffline(userId: String) async throws {
        let _ = try await makeRequest(endpoint: "/users/\(userId)/go-offline/", method: "POST", responseType: [String: String].self)
        print("✅ User \(userId) is OFFLINE in Django")
    }

    // MARK: - Session Management
    func createSession(userId: String, trackId: String = "track_001", characterId: String = "p1") async throws -> DjangoSession {
        let payload: [String: Any] = [
            "user": userId,
            "track_id": trackId,
            "character_id": characterId
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        return try await makeRequest(endpoint: "/sessions/", method: "POST", body: body, responseType: DjangoSession.self)
    }

    func updateSession(sessionId: String, distanceCovered: Double, caloriesBurned: Int,
                       durationMinutes: Int, averageSpeed: Double?, totalJumps: Int,
                       totalCrouches: Int) async throws -> DjangoSession {
        var payload: [String: Any] = [
            "distance_covered": distanceCovered,
            "calories_burned": caloriesBurned,
            "duration_minutes": durationMinutes,
            "total_jumps": totalJumps,
            "total_crouches": totalCrouches
        ]
        if let speed = averageSpeed { payload["average_speed"] = speed }
        let body = try JSONSerialization.data(withJSONObject: payload)
        return try await makeRequest(endpoint: "/sessions/\(sessionId)/", method: "PATCH", body: body, responseType: DjangoSession.self)
    }

    func completeSession(sessionId: String) async throws -> DjangoSession {
        return try await makeRequest(endpoint: "/sessions/\(sessionId)/complete/", method: "POST", responseType: DjangoSession.self)
    }

    func abandonSession(sessionId: String) async throws -> DjangoSession {
        return try await makeRequest(endpoint: "/sessions/\(sessionId)/abandon/", method: "POST", responseType: DjangoSession.self)
    }

    // MARK: - User Stats
    func getUserStats(userId: String) async throws -> DjangoUserStats {
        return try await makeRequest(endpoint: "/users/\(userId)/stats/", method: "GET", responseType: DjangoUserStats.self)
    }

    // MARK: - User Badges
    func getUserBadges(userId: String) async throws -> [DjangoUserBadge] {
        return try await makeRequest(endpoint: "/users/\(userId)/badges/", method: "GET", responseType: [DjangoUserBadge].self)
    }

    // MARK: - Streak Calendar (last 90 days)
    func getStreakCalendar(userId: String, days: Int = 90) async throws -> [DailyProgress] {
        return try await makeRequest(endpoint: "/users/\(userId)/streak-calendar/?days=\(days)", method: "GET", responseType: [DailyProgress].self)
    }

    // MARK: - User Sessions
    func getUserSessions(userId: String) async throws -> [DjangoSession] {
        return try await makeRequest(endpoint: "/users/\(userId)/sessions/", method: "GET", responseType: [DjangoSession].self)
    }

    // MARK: - User Friends (accepted only)
    func getUserFriends(userId: String) async throws -> [DjangoFriendship] {
        return try await makeRequest(endpoint: "/users/\(userId)/friends/", method: "GET", responseType: [DjangoFriendship].self)
    }

    // MARK: - Update User
    func updateUser(userId: String, payload: [String: Any]) async throws -> DjangoUser {
        let body = try JSONSerialization.data(withJSONObject: payload)
        return try await makeRequest(endpoint: "/users/\(userId)/", method: "PATCH", body: body, responseType: DjangoUser.self)
    }

    // MARK: - Friend Requests
    func sendFriendRequest(requesterId: String, receiverId: String) async throws -> DjangoFriendship {
        let payload = ["requester": requesterId, "receiver": receiverId]
        let body = try JSONSerialization.data(withJSONObject: payload)
        return try await makeRequest(endpoint: "/friendships/", method: "POST", body: body, responseType: DjangoFriendship.self)
    }

    func acceptFriendship(friendshipId: String) async throws -> DjangoFriendship {
        return try await makeRequest(endpoint: "/friendships/\(friendshipId)/accept/", method: "POST", responseType: DjangoFriendship.self)
    }

    func declineFriendship(friendshipId: String) async throws -> DjangoFriendship {
        return try await makeRequest(endpoint: "/friendships/\(friendshipId)/decline/", method: "POST", responseType: DjangoFriendship.self)
    }

    // MARK: - Lookup user by username from all users
    func findUserByUsername(_ username: String) async throws -> DjangoUser? {
        let response = try await makeRequest(endpoint: "/users/", method: "GET", responseType: PaginatedUserResponse.self)
        return response.results.first(where: { $0.username.lowercased() == username.lowercased() })
    }
}
