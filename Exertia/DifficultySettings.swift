//
//  DifficultySettings.swift
//  VisionExample
//
//  Created for Difficulty Level Management
//

import Foundation

/// Singleton class to manage difficulty settings across the app
class DifficultySettings {
    static let shared = DifficultySettings()
    
    private init() {}
    
    // MARK: - Types
    
    enum Difficulty: String, CaseIterable {
        case easy = "Easy"
        case medium = "Medium"
        case hard = "Hard"
        
        var description: String {
            switch self {
            case .easy:
                return "Smaller movements required.\nGreat for beginners!"
            case .medium:
                return "Balanced challenge.\nRecommended for most players."
            case .hard:
                return "Larger movements required.\nFor fitness enthusiasts!"
            }
        }
        
        var emoji: String {
            switch self {
            case .easy: return "🟢"
            case .medium: return "🟡"
            case .hard: return "🔴"
            }
        }
    }
    
    // MARK: - Properties
    
    private(set) var currentDifficulty: Difficulty = .medium
    
    /// Whether to skip the demo/calibration and go directly to game
    private(set) var skipDemo: Bool = false
    
    // MARK: - Difficulty Values
    
    /// SpotRunning refDistance values
    var spotRunningRefDistance: CGFloat {
        switch currentDifficulty {
        case .easy: return 30.0
        case .medium: return 50.0
        case .hard: return 70.0
        }
    }
    
    /// LeanDetector left threshold (angle below which = lean right)
    var leanRightThreshold: CGFloat {
        switch currentDifficulty {
        case .easy: return 75.0   // Less lean required
        case .medium: return 70.0
        case .hard: return 60.0   // More lean required
        }
    }
    
    /// LeanDetector right threshold (angle above which = lean left)
    var leanLeftThreshold: CGFloat {
        switch currentDifficulty {
        case .easy: return 105.0  // Less lean required
        case .medium: return 110.0
        case .hard: return 120.0  // More lean required
        }
    }
    
    /// CrouchDetector crouchThreshold
    var crouchThreshold: CGFloat {
        switch currentDifficulty {
        case .easy: return 120.0   // Less crouch required (higher angle)
        case .medium: return 135.0
        case .hard: return 150.0   // More crouch required (even higher angle means easier detection)
        }
    }
    
    // MARK: - Methods
    
    /// Set the current difficulty level
    func setDifficulty(_ difficulty: Difficulty) {
        currentDifficulty = difficulty
        print("🎮 Difficulty set to: \(difficulty.rawValue)")
        print("   SpotRunning refDistance: \(spotRunningRefDistance)")
        print("   Lean thresholds: \(leanRightThreshold)° / \(leanLeftThreshold)°")
        print("   Crouch threshold: \(crouchThreshold)°")
        
        // Post notification for any listeners
        NotificationCenter.default.post(
            name: .difficultyDidChange,
            object: nil,
            userInfo: ["difficulty": difficulty]
        )
    }
    
    /// Set whether to skip the demo
    func setSkipDemo(_ skip: Bool) {
        skipDemo = skip
        print("🎮 Skip demo: \(skip)")
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let difficultyDidChange = Notification.Name("difficultyDidChange")
}
