import Foundation
import UIKit

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
    let totalSteps: Int
    let distanceCovered: Double     // km (Supabase) or meters (local session)
    let averageSpeed: Double?       // m/min, nil if zero duration
    let characterImageName: String
    let completionStatus: String    // "completed" or "abandoned"
}

// MARK: - Distance formatting helper
/// Pass distance in km. Returns "450 m" below 1 km, "2.3 km" at or above.
func formatDistanceKm(_ km: Double) -> String {
    if km < 1.0 {
        return "\(Int((km * 1000).rounded())) m"
    } else {
        return String(format: "%.1f km", km)
    }
}

struct PlayerStats {
    var calories: Int
    var runTimeMinutes: Int
    var currentStreak: Int
    var personalBestCalories: Int = 0
    var personalBestDistance: Double = 0.0
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

    var stats = PlayerStats(calories: 0, runTimeMinutes: 0, currentStreak: 0, personalBestCalories: 0, personalBestDistance: 0.0)

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
        steps: Int,
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
            totalSteps: steps,
            distanceCovered: distanceCovered,
            averageSpeed: averageSpeed,
            characterImageName: charImg,
            completionStatus: completionStatus
        )

        gameHistory.append(newSession)
        stats.calories += calories
        stats.runTimeMinutes += duration

        print("📊 Local stats updated! Syncing with Supabase...")
        print("   Track: \(track) (\(trackId)) | Character: \(characterId)")
        print("   Duration: \(duration)m | Calories: \(calories) | Distance: \(String(format: "%.1f", distanceCovered))m")
        print("   Jumps: \(jumps) | Crouches: \(crouches) | Left: \(leftLeans) | Right: \(rightLeans) | Steps: \(steps)")

        let distanceKm = distanceCovered / 1000.0

        Task {
            do {
                guard let userId = UserDefaults.standard.string(forKey: "supabaseUserID") else {
                    print("⚠️ No Supabase User ID found locally. Session saved locally only.")
                    return
                }

                let insert = SessionInsert(
                    user_id: userId,
                    track_id: trackId,
                    character_id: characterId,
                    duration_minutes: duration,
                    calories_burned: calories,
                    distance_covered: distanceKm,
                    average_speed: averageSpeed.map { $0 * 0.06 },
                    total_jumps: jumps,
                    total_crouches: crouches,
                    total_left_leans: leftLeans,
                    total_right_leans: rightLeans,
                    total_steps: steps,
                    completion_status: completionStatus
                )

                let created = try await SupabaseManager.shared.createSession(session: insert)
                if let sessionId = created.id {
                    try await SupabaseManager.shared.completeSession(sessionId: sessionId, caloriesBurned: calories)
                    print("✅ Game Session successfully saved to Supabase!")
                }
            } catch {
                print("❌ Failed to sync session to Supabase: \(error.localizedDescription)")
            }
        }
    }
}
