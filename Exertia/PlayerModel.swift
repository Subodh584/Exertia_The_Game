import Foundation
import UIKit

// MARK: - Game Data Models
struct GameSession {
    let date: Date
    let durationMinutes: Int
    let caloriesBurned: Int
    let trackName: String
    let totalJumps: Int
    let totalCrouches: Int
    let characterImageName: String
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
    
    var stats = PlayerStats(calories: 180, runTimeMinutes: 23, currentStreak: 4)

    var players: [Player] = [
        Player(id: "p1", name: "Glitch", description: "System error: Too cute.", fullBodyImageName: "character1", thumbnailImageName: "character1", backgroundImageName: "CharacterBg1", videoName: "c1_animated", videoScale: 1.05, videoOffsetX: -170, videoOffsetY: -30, isSelected: true, isLocked: false),
        Player(id: "p2", name: "Torque", description: "Forged in heavy metal.", fullBodyImageName: "character2", thumbnailImageName: "character2", backgroundImageName: "CharacterBg2", videoName: "c2_animated", videoScale: 1.05, videoOffsetX: -170, videoOffsetY: 0, isSelected: false, isLocked: false),
        Player(id: "p3", name: "Vanguard", description: "Shadows are the weapon.", fullBodyImageName: "character5", thumbnailImageName: "character5", backgroundImageName: "CharacterBg5", videoName: "c3_animated", videoScale: 1.05, videoOffsetX: -170, videoOffsetY: -30, isSelected: false, isLocked: false),
        Player(id: "p4", name: "Cipher", description: "Hacking reality's source code.", fullBodyImageName: "character4", thumbnailImageName: "character4", backgroundImageName: "CharacterBg4", videoName: "c1_animated", videoScale: 1.05, videoOffsetX: -170, videoOffsetY: 0, isSelected: false, isLocked: false),
        Player(id: "p5", name: "Sprout", description: "Blooming in the void.", fullBodyImageName: "character3", thumbnailImageName: "character3", backgroundImageName: "CharacterBg3", videoName: "c3_animated", videoScale: 1.05, videoOffsetX: -170, videoOffsetY: -30, isSelected: false, isLocked: false),
        Player(id: "p6", name: "Nova", description: "Starlight trapped in glass.", fullBodyImageName: "character6", thumbnailImageName: "character6", backgroundImageName: "CharacterBg6", videoName: "c2_animated", videoScale: 1.05, videoOffsetX: -170, videoOffsetY: -30, isSelected: false, isLocked: false)
    ]

    var gameHistory: [GameSession] = [
        GameSession(date: Date().addingTimeInterval(-86400 * 2), durationMinutes: 10, caloriesBurned: 80, trackName: "Planet X", totalJumps: 45, totalCrouches: 12, characterImageName: "character1"),
        GameSession(date: Date().addingTimeInterval(-86400), durationMinutes: 25, caloriesBurned: 200, trackName: "Planet Y", totalJumps: 120, totalCrouches: 40, characterImageName: "character4"),
        GameSession(date: Date(), durationMinutes: 12, caloriesBurned: 96, trackName: "Warzone", totalJumps: 55, totalCrouches: 20, characterImageName: "character2")
    ]
    
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
    func addSession(duration: Int, calories: Int, track: String, jumps: Int, crouches: Int) {
        let charImg = getSelectedPlayer().thumbnailImageName
        let newSession = GameSession(date: Date(), durationMinutes: duration, caloriesBurned: calories, trackName: track, totalJumps: jumps, totalCrouches: crouches, characterImageName: charImg)
        
        gameHistory.append(newSession)
        stats.calories += calories
        stats.runTimeMinutes += duration
        
        print("📊 Local stats updated! Attempting to sync with Django...")
        
        Task {
            do {
                guard let userId = UserDefaults.standard.string(forKey: "djangoUserID") else {
                    print("⚠️ No Django User ID found locally. Session saved locally only.")
                    return
                }
                
                let apiSession = try await APIManager.shared.createSession(userId: userId)
                
                if let sessionId = apiSession.id {
                    let _ = try await APIManager.shared.completeSession(sessionId: sessionId, caloriesBurned: calories)
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

struct PaginatedUserResponse: Codable {
    let count: Int
    let next: String?
    let previous: String?
    let results: [DjangoUser]
}

struct DjangoUser: Codable {
    let id: String
    let username: String
    let displayName: String?
    let dailyTargetMins: Int?
    let dailyTargetCalories: Int?
    let isOnline: Bool?
    let lastSeen: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case dailyTargetMins = "daily_target_mins"
        case dailyTargetCalories = "daily_target_calories"
        case isOnline = "is_online"
        case lastSeen = "last_seen"
    }
}

struct DjangoSession: Codable {
    let id: String?
    let user: String?
    let username: String?
    let trackId: String?
    let durationMinutes: Int?
    let caloriesBurned: Int?
    let completionStatus: String?
    let createdAt: String?
    
    // Legacy fields for backward compatibility
    let startTime: String?
    let endTime: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case user
        case username
        case trackId = "track_id"
        case durationMinutes = "duration_minutes"
        case caloriesBurned = "calories_burned"
        case completionStatus = "completion_status"
        case createdAt = "created_at"
        case startTime = "start_time"
        case endTime = "end_time"
    }
}

struct DjangoUserStats: Codable {
    let totalSessions: Int
    let totalMinutes: Int
    let totalCalories: Int
    let completedSessions: Int
    let friendCount: Int
    
    enum CodingKeys: String, CodingKey {
        case totalSessions = "total_sessions"
        case totalMinutes = "total_minutes"
        case totalCalories = "total_calories"
        case completedSessions = "completed_sessions"
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

struct PaginatedFriendshipResponse: Codable {
    let count: Int
    let next: String?
    let previous: String?
    let results: [DjangoFriendship]
}

class APIManager {
    static let shared = APIManager()
    private let baseURL = "https://exertia-backend.onrender.com/api"
    
    private init() {}
    
    private func makeRequest<T: Codable>(endpoint: String, method: String, body: Data? = nil, responseType: T.Type) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let body = body { request.httpBody = body }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown Error"
            print("❌ API Error [\(httpResponse.statusCode)]: \(errorString)")
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }

    func createUser(username: String, displayName: String) async throws -> DjangoUser {
        let payload: [String: Any] = [
            "username": username,
            "display_name": displayName,
            "daily_target_mins": 60,
            "daily_target_calories": 300,
            "is_online": true
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        return try await makeRequest(endpoint: "/users/", method: "POST", body: body, responseType: DjangoUser.self)
    }
    
    func loginUser(username: String) async throws -> DjangoUser? {
            // 1. Fetch the list of users from Django
            let response = try await makeRequest(endpoint: "/users/", method: "GET", responseType: PaginatedUserResponse.self)
            
            // 2. Search the list for the matching username (case-insensitive to be safe)
            if let user = response.results.first(where: { $0.username.lowercased() == username.lowercased() }) {
                return user
            }
            
            return nil // Return nil if the user doesn't exist
        }
    
    func getUser(userId: String) async throws -> DjangoUser {
            return try await makeRequest(endpoint: "/users/\(userId)/", method: "GET", responseType: DjangoUser.self)
        }
    
    func setUserOnline(userId: String) async throws {
        let _ = try await makeRequest(endpoint: "/users/\(userId)/go-online/", method: "POST", responseType: [String: String].self)
        print("✅ User \(userId) is ONLINE in Django")
    }
    
    func createSession(userId: String) async throws -> DjangoSession {
        let payload = ["user": userId]
        let body = try JSONSerialization.data(withJSONObject: payload)
        return try await makeRequest(endpoint: "/sessions/", method: "POST", body: body, responseType: DjangoSession.self)
    }
    
    func completeSession(sessionId: String, caloriesBurned: Int) async throws -> DjangoSession {
        let payload = ["calories_burned": caloriesBurned]
        let body = try JSONSerialization.data(withJSONObject: payload)
        return try await makeRequest(endpoint: "/sessions/\(sessionId)/complete/", method: "POST", body: body, responseType: DjangoSession.self)
    }
    
    // MARK: - User Stats
    func getUserStats(userId: String) async throws -> DjangoUserStats {
        return try await makeRequest(endpoint: "/users/\(userId)/stats/", method: "GET", responseType: DjangoUserStats.self)
    }
    
    // MARK: - User Sessions
    func getUserSessions(userId: String) async throws -> [DjangoSession] {
        return try await makeRequest(endpoint: "/users/\(userId)/sessions/", method: "GET", responseType: [DjangoSession].self)
    }
    
    // MARK: - User Friends (accepted only)
    func getUserFriends(userId: String) async throws -> [DjangoFriendship] {
        return try await makeRequest(endpoint: "/users/\(userId)/friends/", method: "GET", responseType: [DjangoFriendship].self)
    }
    
    // MARK: - Set User Offline
    func setUserOffline(userId: String) async throws {
        let _ = try await makeRequest(endpoint: "/users/\(userId)/go-offline/", method: "POST", responseType: [String: String].self)
        print("✅ User \(userId) is OFFLINE in Django")
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
    
    // MARK: - Abandon Session
    func abandonSession(sessionId: String) async throws -> DjangoSession {
        return try await makeRequest(endpoint: "/sessions/\(sessionId)/abandon/", method: "POST", responseType: DjangoSession.self)
    }
    
    // MARK: - Lookup user by username from all users
    func findUserByUsername(_ username: String) async throws -> DjangoUser? {
        let response = try await makeRequest(endpoint: "/users/", method: "GET", responseType: PaginatedUserResponse.self)
        return response.results.first(where: { $0.username.lowercased() == username.lowercased() })
    }
}
