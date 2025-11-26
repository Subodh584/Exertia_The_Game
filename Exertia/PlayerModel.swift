//
//  PlayerModel.swift
//  Exertia
//
//  Created by admin62 on 25/11/25.
//

import Foundation

struct GameSession {
    let date: Date
    let durationMinutes: Int
    let caloriesBurned: Int
    let trackName: String
}

// MARK: - 1. Player Stats Model (User's current stats)
struct PlayerStats {
    var calories: Int           // For headerCaloriesLabel & statsCaloriesLabel
    var runTimeMinutes: Int     // For runTimeLabel
    var currentStreak: Int      // For streakLabel (Stars/Streak count)
}

// MARK: - 2. The Blueprint for a single player
struct Player {
    let id: String
    let name: String
    let description: String
    let fullBodyImageName: String   // Name of the big image in Assets
    let thumbnailImageName: String  // Name of the small square image in Assets
    let backgroundImageName: String // Name of the background wallpaper
    
    // Video Animation Properties (for Home screen background)
    let videoName: String?          // Name of the mp4 file (without extension)
    let videoScale: CGFloat         // 1.0 = Normal, 1.2 = Zoomed In
    let videoOffsetX: CGFloat       // -50 = Move Left, 50 = Move Right
    let videoOffsetY: CGFloat       // -30 = Move Up, 30 = Move Down
    
    var isSelected: Bool
    var isLocked: Bool
    
    // MARK: - Computed Property: Stats Image based on Video
    /// Dynamically returns the stats image based on the video animation
    /// c1_animated -> Todays_stats_pink
    /// c2_animated -> Todays_stats_orange
    /// c3_animated -> Todays_stats_green
    var statsImageName: String {
        switch videoName {
        case "c1_animated":
            return "Todays_stats_pink"
        case "c2_animated":
            return "Todays_stats_orange"
        case "c3_animated":
            return "Todays_stats_green"
        default:
            return "Todays_stats_pink" // Default fallback
        }
    }
}

// MARK: - 3. The Data Source (Singleton)
// This holds the list of all 6 players and manages selection state
class GameData {
    
    // Singleton instance - use this everywhere
    static let shared = GameData()
    
    // Private init to enforce singleton pattern
    private init() {}
    
    // MARK: - Player Stats (User's current stats for Home screen)
    var stats = PlayerStats(
        calories: 180,
        runTimeMinutes: 23,
        currentStreak: 4
    )
    
    // The mutable list of players
    var players: [Player] = [
        
        // Player 1: Eco Ranger (Green)
        Player(
            id: "p1",
            name: "Glitch",
            description: "System error: Too cute.",
            fullBodyImageName: "character1",
            thumbnailImageName: "character1",
            backgroundImageName: "CharacterBg1",
            videoName: "c1_animated",      // -> Todays_stats_green
            videoScale: 1.05,
            videoOffsetX: -170,
            videoOffsetY: -30,
            isSelected: true,  // Default selected
            isLocked: false
        ),
        
        // Player 2: Unit R-01 (Robot - Pink)
        Player(
            id: "p2",
            name: "Torque",
            description: "Forged in heavy metal.",
            fullBodyImageName: "character2",
            thumbnailImageName: "character2",
            backgroundImageName: "CharacterBg2",
            videoName: "c2_animated",      // -> Todays_stats_pink
            videoScale: 1.05,
            videoOffsetX: -170,
            videoOffsetY: 0,
            isSelected: false,
            isLocked: false
        ),
        
        // Player 3: Mechanic (Orange Suit)
        Player(
            id: "p3",
            name: "Vanguard",
            description: "Shadows are the weapon.",
            fullBodyImageName: "character5",
            thumbnailImageName: "character5",
            backgroundImageName: "CharacterBg5",
            videoName: "c3_animated",      // -> Todays_stats_orange
            videoScale: 1.05,
            videoOffsetX: -170,
            videoOffsetY: -30,
            isSelected: false,
            isLocked: false
        ),
        
        // Player 4: Void Walker (Dark Knight)
        Player(
            id: "p4",
            name: "Cipher",
            description: "Hacking reality's source code.",
            fullBodyImageName: "character4",
            thumbnailImageName: "character4",
            backgroundImageName: "CharacterBg4",
            videoName: "c1_animated",      // -> Todays_stats_pink
            videoScale: 1.05,
            videoOffsetX: -170,
            videoOffsetY: 0,
            isSelected: false,
            isLocked: false
        ),
        
        // Player 5: Eco Ranger (Green Astronaut)
        Player(
            id: "p5",
            name: "Sprout",
            description: "Blooming in the void.",
            fullBodyImageName: "character3",
            thumbnailImageName: "character3",
            backgroundImageName: "CharacterBg3",
            videoName: "c3_animated",      // -> Todays_stats_green
            videoScale: 1.05,
            videoOffsetX: -170,
            videoOffsetY: -30,
            isSelected: false,
            isLocked: false
        ),
        
        // Player 6: Cosmo (Purple Spaceman)
        Player(
            id: "p6",
            name: "Nova",
            description: "Starlight trapped in glass.",
            fullBodyImageName: "character6",
            thumbnailImageName: "character6",
            backgroundImageName: "CharacterBg6",
            videoName: "c2_animated",      // -> Todays_stats_orange
            videoScale: 1.05,
            videoOffsetX: -170,
            videoOffsetY: -30,
            isSelected: false,
            isLocked: false
        )
    ]
    
    var gameHistory: [GameSession] = [
            
            // 1. Two days ago (A warm-up run)
            // 10 mins * 8 = 80 cal
            GameSession(
                date: Date().addingTimeInterval(-86400 * 2),
                durationMinutes: 10,
                caloriesBurned: 80,
                trackName: "Planet X"
            ),

            // 2. Yesterday (This is your PERSONAL BEST)
            // Longest duration (25 mins) = Highest calories (200)
            GameSession(
                date: Date().addingTimeInterval(-86400),
                durationMinutes: 25,
                caloriesBurned: 200,
                trackName: "Planet Y"
            ),

            // 3. Today (This is your LAST SESSION)
            // Matches your home screen stats (12 mins)
            // 12 mins * 8 = 96 cal
            GameSession(
                date: Date(),
                durationMinutes: 12,
                caloriesBurned: 96,
                trackName: "Warzone"
            )
        ]
    
    // Logic: Returns the session with the most recent Date
        var lastSession: GameSession? {
            return gameHistory.sorted(by: { $0.date < $1.date }).last
        }
    // Logic: Returns the session with the highest Calories
        var personalBest: GameSession? {
            return gameHistory.max(by: { $0.caloriesBurned < $1.caloriesBurned })
        }
    
    func addSession(duration: Int, calories: Int, track: String) {
            let newSession = GameSession(date: Date(), durationMinutes: duration, caloriesBurned: calories, trackName: track)
            gameHistory.append(newSession)
            
            // Also update the total stats
            stats.calories += calories
            stats.runTimeMinutes += duration
            // (You can add streak logic here later)
        }
    
    // MARK: - Helper Functions
    
    /// Returns the currently selected player
    func getSelectedPlayer() -> Player {
        if let selected = players.first(where: { $0.isSelected }) {
            return selected
        }
        // Fallback to first player if none selected
        return players[0]
    }
    
    /// Returns the index of the currently selected player
    func getSelectedIndex() -> Int {
        return players.firstIndex(where: { $0.isSelected }) ?? 0
    }
    
    /// Selects a player by index
    /// - Parameter index: The index of the player to select
    /// - Returns: true if selection was successful, false if player is locked
    func selectPlayer(at index: Int) -> Bool {
        guard index >= 0 && index < players.count else {
            return false
        }
        
        // Check if locked
        if players[index].isLocked {
            print("❌ Cannot select \(players[index].name), it is locked!")
            return false
        }
        
        // Deselect all, then select the chosen one
        for i in 0..<players.count {
            players[i].isSelected = (i == index)
        }
        
        print("✅ Selected: \(players[index].name)")
        return true
    }
    
    /// Selects a player by ID
    /// - Parameter id: The unique ID of the player to select
    /// - Returns: true if selection was successful, false otherwise
    func selectPlayer(id: String) -> Bool {
        guard let index = players.firstIndex(where: { $0.id == id }) else {
            return false
        }
        return selectPlayer(at: index)
    }
}
