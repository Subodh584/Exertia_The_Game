//
//  PlayerModel.swift
//  Exertia
//
//  Created by admin62 on 25/11/25.
//

import Foundation

// 1. The Blueprint for a single player
struct Player {
    let name: String
    let description: String
    let fullBodyImageName: String   // Name of the big image in Assets
    let thumbnailImageName: String  // Name of the small square image in Assets
    let backgroundImageName: String // Name of the background wallpaper
}


// 2. The Data Source
// This holds the list of all 6 players shown in your screenshot
class GameData {
    static let players: [Player] = [
        
        // Player 1: The Main Robot (Unit R-01)
        Player(
            name: "Eco Ranger",
            description: "Utilizes nature-based bio-tech.",
            fullBodyImageName: "character1",
            thumbnailImageName: "character1",
            backgroundImageName: "CharacterBg1"
        ),
        
        // Player 2: The Small Robot
        Player(
            name: "Unit R-01",
            description: "A balanced android unit designed for versatility in combat.",
            fullBodyImageName: "character2",
            thumbnailImageName: "character2",
            backgroundImageName: "CharacterBg2" // Reusing bg or use a new one
        ),
        
        // Player 3: The Mechanic (Orange Suit)
        Player(
            name: "Mechanic",
            description: "Expert in repairs and defensive structures.",
            fullBodyImageName: "character3",
            thumbnailImageName: "character3",
            backgroundImageName: "CharacterBg3"
        ),
        
        // Player 4: The Dark Knight
        Player(
            name: "Void Walker",
            description: "High agility stealth unit from the outer rim.",
            fullBodyImageName: "character4",
            thumbnailImageName: "character4",
            backgroundImageName: "CharacterBg4"
        ),
        
        // Player 5: The Green Astronaut
        Player(
            name: "Eco Ranger",
            description: "Specialist in terraforming and bio-survival.",
            fullBodyImageName: "character5",
            thumbnailImageName: "character5",
            backgroundImageName: "CharacterBg5"
        ),
        
        // Player 6: The Purple Spaceman
        Player(
            name: "Cosmo",
            description: "Gravity manipulation specialist.",
            fullBodyImageName: "character6",
            thumbnailImageName: "character6",
            backgroundImageName: "CharacterBg6"
        )
    ]
}
