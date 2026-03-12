//
//  GameViewController.swift
//  Exeria_Game_Final_1
//
//  Created by admin62 on 05/02/26.
//

import UIKit
import SceneKit

class GameViewController: UIViewController, RoadManagerDelegate {
    
    // MARK: - Properties
    var sceneView: SCNView!
    var scene: SCNScene!
    var cameraNode: SCNNode!
    var playerNode: SCNNode!
    
    // Road Management
    var roadManager: RoadManager!
    
    // Game State
    var isGameRunning = false
    var playerZPosition: Float = 0
    let baseSpeed: Float = 30.0 // Normal speed
    var gameSpeed: Float = 30.0 // Current speed (can change)
    
    // Player settings
    var currentLane: Int = 1 // 0 = left, 1 = center, 2 = right
    let laneWidth: Float = 3.5 // Distance between lanes
    var isJumping: Bool = false
    var isDiving: Bool = false
    var isMovingForward: Bool = false
    var isMovingBackward: Bool = false
    
    // Jump control settings
    var jumpHeight: Float = 18.0                    // How high the player jumps (Y units)
    var jumpUpDuration: Float = 0.5               // Time to reach peak of jump (seconds)
    var jumpDownDuration: Float = 0.5             // Time to fall back down (seconds)
    var jumpForwardBoost: Float = 5.0              // Optional: Forward distance boost during jump (Z units)
    
    // Dive/Slide control settings
    var diveSquashScale: Float = 0.3               // How much to squash player when diving (1.0 = no squash)
    var diveSquashDuration: Float = 0.1            // Time to squash down (seconds)
    var diveHoldDuration: Float = 0.9              // How long to stay squashed (seconds)
    var diveRestoreDuration: Float = 0.1           // Time to restore to normal size (seconds)
    
    // MARK: - Speed Bar System
    // Speed tiers (tweak these!)
    var speedTier1: Float = 15.0                   // Slow speed
    var speedTier2: Float = 21.0                   // Medium speed
    var speedTier3: Float = 27.0                   // Max speed
    
    // Fill times (seconds to fill each division while holding forward)
    var tier1FillTime: Float = 3.0                 // Seconds to fill division 1
    var tier2FillTime: Float = 5.0                 // Seconds to fill division 2
    var tier3FillTime: Float = 8.0                // Seconds to fill division 3
    
    // Drain times (seconds to drain each division when NOT holding forward)
    var tier1DrainTime: Float = 3.0               // Seconds to drain division 1
    var tier2DrainTime: Float = 2.0               // Seconds to drain division 2
    var tier3DrainTime: Float = 1.0               // Seconds to drain division 3
    
    // Speed bar state (0.0 = empty, 3.0 = full)
    // 0.0-1.0 = tier 1, 1.0-2.0 = tier 2, 2.0-3.0 = tier 3
    var speedBarFill: Float = 0.0
    
    // Speed bar UI
    var speedBarContainerView: UIView?
    var speedBarTier1View: UIView?                 // Slow bar (green)
    var speedBarTier2View: UIView?                 // Medium bar (yellow)
    var speedBarTier3View: UIView?                 // Max bar (red)
    var speedBarTier1Fill: UIView?                 // Fill inside tier 1
    var speedBarTier2Fill: UIView?                 // Fill inside tier 2
    var speedBarTier3Fill: UIView?                 // Fill inside tier 3
    var speedBarLabel: UILabel?                    // Speed label
    
    // Speed bar visual settings
    var speedBarHeight: CGFloat = 22.0             // Height of speed bar
    var speedBarBottomMargin: CGFloat = 40.0       // Distance from bottom of screen
    var speedBarSideMargin: CGFloat = 40.0         // Distance from sides
    var speedBarCornerRadius: CGFloat = 6.0        // Corner radius
    
    // MARK: - Collision Detection System
    // Hit penalty settings
    var collisionEnabled: Bool = true              // Enable/disable collision detection
    var hitSpeedPenalty: Float = 0.8               // How much to drain from speed bar on hit (0.8 = drain 0.8 units)
    var hitCooldownTime: Float = 1.5               // Seconds of immunity after being hit
    var lastHitTime: Float = -999.0                // Track when last hit occurred
    
    // Jump helper mechanic (forgiveness for jumping over cubes)
    var jumpOverCubesEnabled: Bool = true          // Allow jumping over cube obstacles without damage
    var jumpOverCuboidsEnabled: Bool = false       // Allow jumping over cuboid obstacles (usually false - they're too tall)
    var jumpOverHoverEnabled: Bool = false         // Allow jumping over hover platforms (usually false - need to dive)
    var safeDistanceOut: Float = 12.0              // Outer boundary - max distance for jump to be valid
    var safeDistanceIn: Float = 3.0                // Inner boundary - min distance for jump to be valid (too close = damage)
    // Jump is invincible only when: safeDistanceIn <= distance <= safeDistanceOut
    
    // Bounding box visualization (for debugging)
    var showBoundingBoxes: Bool = false            // Toggle to show collision boxes
    var boundingBoxNodes: [SCNNode] = []           // Store debug box visualizations
    var showSafeJumpDistance: Bool = false         // Toggle to show safe jump distance circles
    var safeJumpDistanceNodes: [SCNNode] = []      // Store safe distance circle visualizations
    
    // Player bounding box (collision area around capsule)
    var playerBBoxWidth: Float = 1.4               // Width of player collision box (X)
    var playerBBoxHeight: Float = 2.8              // Height of player collision box (Y)
    var playerBBoxDepth: Float = 1.4               // Depth of player collision box (Z)
    var playerBBoxOffsetY: Float = 4.0             // Y offset from player position
    
    // Cube obstacle bounding box
    var cubeBBoxWidth: Float = 3.2                 // Width (X)
    var cubeBBoxHeight: Float = 6.2                // Height (Y)
    var cubeBBoxDepth: Float = 6.5                 // Depth (Z)
    var cubeBBoxOffsetX: Float = 0.0               // X offset from obstacle position
    var cubeBBoxOffsetY: Float = 0.0               // Y offset from obstacle position
    var cubeBBoxOffsetZ: Float = 0.0               // Z offset from obstacle position
    
    // Cuboid obstacle bounding box
    var cuboidBBoxWidth: Float = 4.8               // Width (X)
    var cuboidBBoxHeight: Float = 8.8              // Height (Y)
    var cuboidBBoxDepth: Float = 7.8               // Depth (Z)
    var cuboidBBoxOffsetX: Float = 0.0             // X offset from obstacle position
    var cuboidBBoxOffsetY: Float = -1.0             // Y offset from obstacle position
    var cuboidBBoxOffsetZ: Float = 0.0             // Z offset from obstacle position
    
    // Hover platform bounding box
    var hoverBBoxWidth: Float = 19.0               // Width (X)
    var hoverBBoxHeight: Float = 2.9               // Height (Y)
    var hoverBBoxDepth: Float = 14.5               // Depth (Z)
    var hoverBBoxOffsetX: Float = 0.0              // X offset from obstacle position
    var hoverBBoxOffsetY: Float = -0.0              // Y offset from obstacle position
    var hoverBBoxOffsetZ: Float = 0.0              // Z offset from obstacle position
    
    // Collision visual feedback
    var hitFlashDuration: Float = 0.2              // How long screen flashes red on hit
    var hitFlashView: UIView?                      // Red flash overlay
    var hitShakeAmount: Float = 0.1                // Camera shake intensity on hit
    
    // Player Y position offsets for each road type (fine-tune these!)
    var playerYOffsetOnSimple: Float = -0.8     // Offset when on simple road
    var playerYOffsetOnTunnel: Float = 0.2     // Offset when on tunnel road
    var playerYOffsetOnPlatform: Float = 1.35   // Offset when on platform road    
    // Camera control settings (full control!)
    var cameraOffsetX: Float = 0.0           // Camera X offset from player
    var cameraOffsetY: Float = 12.0          // Camera height above ground
    var cameraOffsetZ: Float = 15.0          // Camera distance behind player
    var cameraFollowPlayerX: Float = 0.5     // How much camera follows player X (0-1)
    var cameraTiltXDegrees: Float = -23.7    // Camera tilt down/up (degrees, negative = look down)
    var cameraTiltYDegrees: Float = 0.0      // Camera rotate left/right (degrees)
    var cameraTiltZDegrees: Float = 0.0      // Camera roll (degrees)
    var cameraFieldOfView: CGFloat = 65.0    // Field of view (degrees)
    var cameraTiltXDegreesinTunnel: Float = -18.7 // Camera tilt X when in tunnel (can be different for better view)
    var cameraOffsetYInTunnel: Float = 7.0// Camera height when in tunnel (can be different for better view)
    var cameraOffsetZInTunnel: Float = 12.0 // Camera distance behind player when in tunnel (can be different for better view)
    // Computed radians for SceneKit (don't modify these directly)
    var cameraTiltX: Float { cameraTiltXDegrees * .pi / 180 }
    var cameraTiltY: Float { cameraTiltYDegrees * .pi / 180 }
    var cameraTiltZ: Float { cameraTiltZDegrees * .pi / 180 }
    
    // Camera transition state (for smooth tunnel transitions)
    private var currentCameraOffsetY: Float = 12.0
    private var currentCameraOffsetZ: Float = 15.0
    private var currentCameraTiltXDegrees: Float = -23.7
    
    // MARK: - Curve Settings (Subway Surfers style!)
    // These are exposed here so you can easily tweak them
    var curveEnabled: Bool = true              // Enable/disable curve effect
    var curveStrength: Float = -0.0018           // How much roads curve upward (higher = more curve)
    var curveHorizontalStrength: Float = 0.001   // Horizontal curve (0 = straight)
    var curveRotationStrength: Float = 0.001  // How much roads tilt as they curve
    var curveStartDistance: Float = 65.0       // Where curve effect starts
    
    // MARK: - Planet Settings (Stylized Planet)
    var planetNode: SCNNode?                   // Reference to the planet node
     var planetXAxisPos: Float = -100.0          // Planet X position (same as player)
    var planetYAxisPos: Float = 200.0          // Planet Y position (just above player)
    var planetZAxisPos: Float = -800.0         // Planet Z position (same as player start)
    var planetSize: Float = 4.0               // Planet scale/size (similar to player capsule)
    var planetAnimationSpeed: Float = 0.03      // Animation speed multiplier (1.0 = normal, 2.0 = 2x faster, 0.5 = half speed)        
    // MARK: - Night Sky Settings (Space atmosphere!)
    var starParticleNode: SCNNode?             // Reference to star particle system
    var starCount: CGFloat = 500               // Number of stars (more = denser sky)
    var starSize: CGFloat = 1.0               // Size of each star
    var starTwinkleSpeed: CGFloat = 1.0        // How fast stars twinkle (higher = faster)
    var starBrightness: CGFloat = 1.0          // Star brightness (0-1)
    var skyTopColor: UIColor = UIColor(red: 0.0, green: 0.0, blue: 0.05, alpha: 1.0)      // Top of sky (near black)
    var skyBottomColor: UIColor = UIColor(red: 0.02, green: 0.02, blue: 0.15, alpha: 1.0) // Bottom of sky (dark blue)
    
    // MARK: - Drone System Settings (Buster Drone)
    var droneNode: SCNNode?                    // Current active drone
    var droneCargoNode: SCNNode?               // Cube being carried by drone
    var droneTemplate: SCNNode?                // Preloaded drone template
    
    // Drone spawn timing
    var droneSpawnInterval: Float = 3.0        // Seconds between drone spawns
    var lastDroneSpawnTime: TimeInterval = 0   // Track last spawn time
    var isDroneActive: Bool = false            // Is a drone currently flying?
    var droneStartedFromRight: Bool = true     // Track which side drone started from
    var dronePathProgress: Float = 0.0         // 0.0 to 1.0 progress through path
    var dronePathStartTime: TimeInterval = 0   // When current path segment started
    var dronePathPhase: Int = 0                // 0 = moving to mid, 1 = hovering, 2 = moving to end
    var droneHoverAnimationStarted: Bool = false  // Track if hover animations have started
    
    // Drone path points (relative to player position)
    var dronePoint1X: Float = 40.0             // Point 1: Right side X offset
    var dronePoint1Y: Float = 15.0             // Point 1: Height above track
    var dronePoint1Z: Float = -40.0            // Point 1: Distance ahead of player
    

    var dronePoint2lX: Float = -10.0             
    var dronePoint2lY: Float = 8.0             
    var dronePoint2lZ: Float = -30.0  

    var dronePoint2X: Float = 0.0              // Point 2: Center (in view) X offset
    var dronePoint2Y: Float = 8.0             // Point 2: Height above track
    var dronePoint2Z: Float = -30.0            // Point 2: Distance ahead of player

    var dronePoint2rX: Float = 10.0             
    var dronePoint2rY: Float = 8.0             
    var dronePoint2rZ: Float = -30.0   

    var dronePoint3X: Float = -40.0            // Point 3: Left side X offset
    var dronePoint3Y: Float = 15.0             // Point 3: Height above track
    var dronePoint3Z: Float = -40.0            // Point 3: Distance ahead of player
    
    // Drone timing (in seconds)
    var droneTimeToPoint2: TimeInterval = 2.0  // Time from point 1/3 to point 2
    var droneHoverTime: TimeInterval = 8.5     // Time to stay at point 2
    var droneTimeFromPoint2: TimeInterval = 2.0 // Time from point 2 to point 3/1
    
    // Cargo (cube) position relative to drone
    var cargoOffsetX: Float = 0.0              // Cargo X offset from drone
    var cargoOffsetY: Float = -3.0             // Cargo Y offset (below drone)
    var cargoOffsetZ: Float = -1.0              // Cargo Z offset from drone
    var cargoSize: Float = 3                 // Size of the cargo cube
    
    // Drone size
    var droneSize: Float = 4.0                  // Scale of the drone
    
    // Drone animation frame ranges (set these based on your animation)
    var droneAnimationFPS: Float = 30.0         // Frames per second of the animation
    var takeOffStart: Int = 0                   // Frame where takeoff starts
    var takeOffEnd: Int = 60                    // Frame where takeoff ends
    var boxDroppingStart: Int = 190              // Frame where box dropping starts
    var boxDroppingEnd: Int = 270              // Frame where box dropping ends
    var rotatingStart: Int = 270               // Frame where rotating starts
    var rotatingEnd: Int = 508                // Frame where rotating ends
    var flyingStart: Int = 508                 // Frame where flying starts
    var flyingEnd: Int = 700                 // Frame where flying ends (0 = loop to end)
    
    // Animation state tracking
    var currentDroneAnimationPhase: String = "none"  // Current animation phase
    
    // Debug mode for animation frame finding
    var animationDebugMode: Bool = false             // Set to true to enable debug UI
    var debugDroneNode: SCNNode?                     // Drone for debug viewing
    var debugCurrentFrame: Float = 0                 // Current frame being viewed
    var debugTotalFrames: Float = 300                // Estimated total frames (adjust as needed)
    var debugAnimationPlayers: [SCNAnimationPlayer] = []  // Store animation players
    var debugDroneURL: URL?                          // Store URL for reloading
    var debugDroneScene: SCNScene?                   // Store the loaded scene
    
    // Debug UI elements
    var debugOverlayView: UIView?
    var debugFrameLabel: UILabel?
    var debugFrameSlider: UISlider?
    var debugPlayButton: UIButton?
    var debugIsPlaying: Bool = false
    
    // MARK: - Obstacle System
    var obstaclesTemplate: SCNNode?                // Preloaded obstacles template
    var activeObstacles: [SCNNode] = []            // Currently active obstacles
    var obstacleDataMap: [SCNNode: ObstacleData] = [:]  // Track obstacle data for curve updates
    var clearedObstacles: Set<ObjectIdentifier> = []   // Obstacles successfully jumped over (invincible for these)
    
    // Obstacle data structure for curve tracking
    struct ObstacleData {
        let baseX: Float           // Original X position (lane offset)
        let baseY: Float           // Original Y position (road Y + offset)
        let baseZ: Float           // Original Z position (road Z)
        let roadBaseY: Float       // The base Y of the road segment
    }
    
    // Obstacle Generation Control
    var obstacleSpawnEveryXSegments: Int = 6       // Spawn obstacles every X road segments
    var obstacleMinDistanceBetween: Float = 20.0   // Minimum Z distance between obstacles
    var lastObstacleZ: Float = -40.0              // Track last obstacle position
    var obstacleSegmentCounter: Int = 0            // Count segments since last obstacle
    
    // Obstacle Positioning Control (relative to road chunk)
    var cubeYOffset: Float = 3.8                   // Cube height above road surface
    var cuboidYOffset: Float = 6.0                 // Cuboid height above road surface
    var hoverPlatformYOffset: Float = 6.0          // Hover platform height above road surface
    
    // ═══════════════════════════════════════════════════════════════════
    // MARK: - Pattern X Offset Controls (fine-tune each pattern!)
    // ═══════════════════════════════════════════════════════════════════
    //
    // Pattern 1: All 3 lanes have cubes → player MUST jump
    var p1_cubeLeftX:   Float = -2.65
    var p1_cubeCenterX: Float =  1
    var p1_cubeRightX:  Float =  4.2
    
    // Pattern 2: 2 cuboids block left+center → dodge to right lane
    var p2_cuboidLeftX:   Float = -3.5
    var p2_cuboidCenterX: Float =  0.0
    
    // Pattern 3: 2 cuboids block center+right → dodge to left lane
    var p3_cuboidCenterX: Float =  0.0
    var p3_cuboidRightX:  Float =  3.8
    
    // Pattern 4: 2 cuboids block left+right → stay in center lane
    var p4_cuboidLeftX:  Float = -3.5
    var p4_cuboidRightX: Float =  3.8
    
    // Pattern 5: 2 cuboids (left+center) + cube on right → dodge right AND jump
    var p5_cuboidLeftX:   Float = -3.5
    var p5_cuboidCenterX: Float =  0.2
    var p5_cubeRightX:    Float =  4.2
    
    // Pattern 6: 2 cuboids (center+right) + cube on left → dodge left AND jump
    var p6_cubeLeftX:      Float = -2.65
    var p6_cuboidCenterX:  Float =  0.2
    var p6_cuboidRightX:   Float =  3.8
    
    // Pattern 7: 2 cuboids (left+right) + cube in center → stay center AND jump
    var p7_cuboidLeftX:   Float = -3.5
    var p7_cubeCenterX:   Float =  1
    var p7_cuboidRightX:  Float =  3.8
    
    // Pattern 8: Hover platform across all lanes → player MUST dive
    var p8_hoverX: Float = 0.0
    
    // Pattern 9: Single cube center lane only (breather pattern)
    var p9_cubeCenterX: Float = 1
    
    // Pattern 10: Cuboid left + cube center + cube right → dodge left impossible, jump center/right
    var p10_cuboidLeftX:   Float = -3.5
    var p10_cubeCenterX:   Float =  1
    var p10_cubeRightX:    Float =  4.2
    
    // Pattern 11: Cube left + cube right (no center) → stay center OR jump sides
    var p11_cubeLeftX:  Float = -2.65
    var p11_cubeRightX: Float =  4.2
    
    // Pattern 12: Hover platform + cube in center below it → dive or dodge sides
    var p12_hoverX:      Float = 0.0
    var p12_cubeCenterX: Float = 1
    
    // Pattern enable/disable (set false to remove a pattern from rotation)
    var p1_enabled: Bool = true
    var p2_enabled: Bool = true
    var p3_enabled: Bool = true
    var p4_enabled: Bool = true
    var p5_enabled: Bool = true
    var p6_enabled: Bool = true
    var p7_enabled: Bool = true
    var p8_enabled: Bool = true
    var p9_enabled: Bool = true
    var p10_enabled: Bool = true
    var p11_enabled: Bool = true
    var p12_enabled: Bool = true
    
    // Obstacle Size Control
    var cubeSizeX: Float = 3.5                     // Cube width (X dimension)
    var cubeSizeY: Float = 3.5                     // Cube height (Z dimension)
    var cubeSizeZ: Float = 6.8                     // Cube depth (Y dimension)
    var cuboidSizeX: Float = 7.0                   // length
    var cuboidSizeY: Float = 7.0                  // width
    var cuboidSizeZ: Float = 8.0                   // height
    var hoverPlatformSizeX: Float = 20.0           // Hover platform width (spans all lanes)
    var hoverPlatformSizeY: Float = 5            // Hover platform thickness
    var hoverPlatformSizeZ: Float = 15.0            // Hover platform depth
    
    // Obstacle Rotation Control (in degrees - adjust to fix asset orientation)
    var cubeRotationX: Float = 0                 // Cube rotation around X axis (degrees)
    var cubeRotationY: Float = 00.0                 // Cube rotation around Y axis (degrees)
    var cubeRotationZ: Float = 00.0                 // Cube rotation around Z axis (degrees)
    var cuboidRotationX: Float = 00.0               // Cuboid rotation around X axis (degrees)
    var cuboidRotationY: Float = 00.0               // Cuboid rotation around Y axis (degrees)
    var cuboidRotationZ: Float = 00.0               // Cuboid rotation around Z axis (degrees)
    var hoverPlatformRotationX: Float = 00.0        // Hover platform rotation around X axis (degrees)
    var hoverPlatformRotationY: Float = 0        // Hover platform rotation around Y axis (degrees)
    var hoverPlatformRotationZ: Float = 0       // Hover platform rotation around Z axis (degrees)
    
    // Lane positions (calculated from laneWidth)
    private var leftLaneX: Float { Float(-1) * laneWidth }
    private var centerLaneX: Float { 0.0 }
    private var rightLaneX: Float { Float(1) * laneWidth }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize camera transition state to match starting values
        currentCameraOffsetY = cameraOffsetY
        currentCameraOffsetZ = cameraOffsetZ
        currentCameraTiltXDegrees = cameraTiltXDegrees
        
        setupScene()
        setupCamera()
        setupLighting()
        
        // Check if we should run in debug mode for animation frame finding
        if animationDebugMode {
            setupAnimationDebugMode()
        } else {
            setupNightSky()
            setupPlayer()
            setupRoadManager()
            setupPlanet()
            // setupDroneSystem()  // Disabled
            setupObstacleSystem()
            setupControls()
            setupSpeedBar()
            setupHitFlashOverlay()
            startGame()
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    // MARK: - Setup Methods
    func setupScene() {
        // Create SceneView
        sceneView = SCNView(frame: view.bounds)
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(sceneView)
        
        // Create Scene
        scene = SCNScene()
        
        // Dark night sky gradient background
        scene.background.contents = createGradientImage()
        sceneView.scene = scene
        
        // Configure SceneView
        sceneView.allowsCameraControl = false
        sceneView.showsStatistics = true // Show FPS for debugging
        sceneView.backgroundColor = UIColor.black
        sceneView.antialiasingMode = .multisampling4X
    }
    
    // MARK: - Animation Debug Mode
    func setupAnimationDebugMode() {
        print("🔧 ANIMATION DEBUG MODE ENABLED")
        
        // Allow camera control for better viewing
        sceneView.allowsCameraControl = true
        
        // Position camera higher and further back to see the drone better
        cameraNode.position = SCNVector3(0, 12, 25)
        cameraNode.eulerAngles = SCNVector3(-0.3, 0, 0)
        
        // Load drone for debug viewing
        loadDebugDrone()
        
        // Create debug UI overlay
        createDebugUI()
        
        // Start scene rendering
        sceneView.isPlaying = true
    }
    
    func loadDebugDrone() {
        let possiblePaths = [
            "Assets/Drone_remastered",
            "Drone_remastered",
            "Drone_Remastered",
            "Assets/Buster_Drone",
            "Buster_Drone"
        ]
        
        for path in possiblePaths {
            if let url = Bundle.main.url(forResource: path, withExtension: "usdz") {
                do {
                    debugDroneURL = url
                    debugDroneScene = try SCNScene(url: url, options: [
                        .checkConsistency: false,
                        .convertToYUp: true
                    ])
                    
                    // Get total animation duration
                    var maxDuration: TimeInterval = 0
                    debugDroneScene?.rootNode.enumerateChildNodes { (child, _) in
                        for key in child.animationKeys {
                            if let player = child.animationPlayer(forKey: key) {
                                maxDuration = max(maxDuration, player.animation.duration)
                                print("🎬 Found animation '\(key)' duration: \(player.animation.duration)s")
                            }
                        }
                    }
                    
                    if maxDuration > 0 {
                        debugTotalFrames = Float(maxDuration) * droneAnimationFPS
                    }
                    
                    print("🎬 Total animation duration: \(maxDuration)s, Total frames: \(debugTotalFrames)")
                    
                    // Load drone at frame 0
                    loadDroneAtFrame(0)
                    
                    print("✅ Loaded debug drone from: \(path)")
                    return
                } catch {
                    print("❌ Error loading drone: \(error.localizedDescription)")
                }
            }
        }
        
        print("⚠️ Could not load drone for debug")
    }
    
    func loadDroneAtFrame(_ frame: Float) {
        // Remove existing drone
        debugDroneNode?.removeFromParentNode()
        
        guard let droneScene = debugDroneScene else { return }
        
        // Create new drone node
        debugDroneNode = SCNNode()
        debugDroneNode?.name = "DebugDrone"
        
        // Clone all children
        for child in droneScene.rootNode.childNodes {
            let clonedChild = child.clone()
            debugDroneNode?.addChildNode(clonedChild)
        }
        
        // Scale and position drone
        debugDroneNode?.scale = SCNVector3(droneSize, droneSize, droneSize)
        debugDroneNode?.position = SCNVector3(0, 5, 0)
        
        scene.rootNode.addChildNode(debugDroneNode!)
        
        // Calculate time offset from frame
        let timeOffset = Double(frame) / Double(droneAnimationFPS)
        
        // Set all animations to the specific time and pause
        debugDroneNode?.enumerateChildNodes { (node, _) in
            for key in node.animationKeys {
                if let player = node.animationPlayer(forKey: key) {
                    // Use a modified animation with time offset
                    let animation = player.animation
                    animation.timeOffset = timeOffset
                    animation.repeatCount = 1
                    
                    node.removeAnimation(forKey: key)
                    node.addAnimation(animation, forKey: key)
                    
                    // Set player speed to nearly frozen
                    if let newPlayer = node.animationPlayer(forKey: key) {
                        newPlayer.speed = 0.0001
                    }
                }
            }
        }
    }
    
    func createDebugUI() {
        // Create overlay container
        debugOverlayView = UIView(frame: CGRect(x: 0, y: view.bounds.height - 350, width: view.bounds.width, height: 350))
        debugOverlayView?.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        debugOverlayView?.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        view.addSubview(debugOverlayView!)
        
        let padding: CGFloat = 20
        var yPos: CGFloat = 15
        
        // Title
        let titleLabel = UILabel(frame: CGRect(x: padding, y: yPos, width: 300, height: 30))
        titleLabel.text = "🎬 Animation Frame Finder"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20)
        debugOverlayView?.addSubview(titleLabel)
        yPos += 40
        
        // Current frame display
        debugFrameLabel = UILabel(frame: CGRect(x: padding, y: yPos, width: view.bounds.width - padding * 2, height: 40))
        debugFrameLabel?.text = "Frame: 0 / \(Int(debugTotalFrames))   Time: 0.00s"
        debugFrameLabel?.textColor = .cyan
        debugFrameLabel?.font = UIFont.monospacedSystemFont(ofSize: 24, weight: .bold)
        debugOverlayView?.addSubview(debugFrameLabel!)
        yPos += 45
        
        // Frame slider
        debugFrameSlider = UISlider(frame: CGRect(x: padding, y: yPos, width: view.bounds.width - padding * 2, height: 40))
        debugFrameSlider?.minimumValue = 0
        debugFrameSlider?.maximumValue = debugTotalFrames
        debugFrameSlider?.value = 0
        debugFrameSlider?.tintColor = .cyan
        debugFrameSlider?.addTarget(self, action: #selector(debugSliderChanged(_:)), for: .valueChanged)
        debugOverlayView?.addSubview(debugFrameSlider!)
        yPos += 50
        
        // Button row
        let buttonWidth: CGFloat = 70
        let buttonSpacing: CGFloat = 10
        var buttonX: CGFloat = padding
        
        // Step backward button
        let stepBackButton = createDebugButton(title: "◀◀ -10", x: buttonX, y: yPos)
        stepBackButton.addTarget(self, action: #selector(debugStepBack10), for: .touchUpInside)
        debugOverlayView?.addSubview(stepBackButton)
        buttonX += buttonWidth + buttonSpacing
        
        // Step back 1 button
        let stepBack1Button = createDebugButton(title: "◀ -1", x: buttonX, y: yPos)
        stepBack1Button.addTarget(self, action: #selector(debugStepBack1), for: .touchUpInside)
        debugOverlayView?.addSubview(stepBack1Button)
        buttonX += buttonWidth + buttonSpacing
        
        // Play/Pause button
        debugPlayButton = createDebugButton(title: "▶ Play", x: buttonX, y: yPos)
        debugPlayButton?.addTarget(self, action: #selector(debugTogglePlay), for: .touchUpInside)
        debugOverlayView?.addSubview(debugPlayButton!)
        buttonX += buttonWidth + buttonSpacing
        
        // Step forward 1 button
        let stepFwd1Button = createDebugButton(title: "+1 ▶", x: buttonX, y: yPos)
        stepFwd1Button.addTarget(self, action: #selector(debugStepForward1), for: .touchUpInside)
        debugOverlayView?.addSubview(stepFwd1Button)
        buttonX += buttonWidth + buttonSpacing
        
        // Step forward 10 button
        let stepFwdButton = createDebugButton(title: "+10 ▶▶", x: buttonX, y: yPos)
        stepFwdButton.addTarget(self, action: #selector(debugStepForward10), for: .touchUpInside)
        debugOverlayView?.addSubview(stepFwdButton)
        yPos += 50
        
        // Frame markers display
        let markersLabel = UILabel(frame: CGRect(x: padding, y: yPos, width: view.bounds.width - padding * 2, height: 80))
        markersLabel.numberOfLines = 0
        markersLabel.text = """
        📌 Set these values in code:
        takeOff: \(takeOffStart) → \(takeOffEnd)  |  boxDropping: \(boxDroppingStart) → \(boxDroppingEnd)
        rotating: \(rotatingStart) → \(rotatingEnd)  |  flying: \(flyingStart) → \(flyingEnd > 0 ? "\(flyingEnd)" : "end")
        """
        markersLabel.textColor = .yellow
        markersLabel.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        debugOverlayView?.addSubview(markersLabel)
        yPos += 85
        
        // Exit debug mode button
        let exitButton = UIButton(frame: CGRect(x: padding, y: yPos, width: 200, height: 40))
        exitButton.setTitle("✅ Exit Debug Mode", for: .normal)
        exitButton.backgroundColor = .systemGreen
        exitButton.layer.cornerRadius = 8
        exitButton.addTarget(self, action: #selector(exitDebugMode), for: .touchUpInside)
        debugOverlayView?.addSubview(exitButton)
    }
    
    func createDebugButton(title: String, x: CGFloat, y: CGFloat) -> UIButton {
        let button = UIButton(frame: CGRect(x: x, y: y, width: 70, height: 40))
        button.setTitle(title, for: .normal)
        button.backgroundColor = UIColor.darkGray
        button.layer.cornerRadius = 6
        button.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        return button
    }
    
    @objc func debugSliderChanged(_ slider: UISlider) {
        debugCurrentFrame = slider.value
        updateDebugAnimation()
    }
    
    @objc func debugStepBack10() {
        debugCurrentFrame = max(0, debugCurrentFrame - 10)
        debugFrameSlider?.value = debugCurrentFrame
        updateDebugAnimation()
    }
    
    @objc func debugStepBack1() {
        debugCurrentFrame = max(0, debugCurrentFrame - 1)
        debugFrameSlider?.value = debugCurrentFrame
        updateDebugAnimation()
    }
    
    @objc func debugStepForward1() {
        debugCurrentFrame = min(debugTotalFrames, debugCurrentFrame + 1)
        debugFrameSlider?.value = debugCurrentFrame
        updateDebugAnimation()
    }
    
    @objc func debugStepForward10() {
        debugCurrentFrame = min(debugTotalFrames, debugCurrentFrame + 10)
        debugFrameSlider?.value = debugCurrentFrame
        updateDebugAnimation()
    }
    
    @objc func debugTogglePlay() {
        debugIsPlaying = !debugIsPlaying
        debugPlayButton?.setTitle(debugIsPlaying ? "⏸ Pause" : "▶ Play", for: .normal)
        
        if debugIsPlaying {
            // Start playback timer
            Timer.scheduledTimer(withTimeInterval: 1.0 / Double(droneAnimationFPS), repeats: true) { [weak self] timer in
                guard let self = self, self.debugIsPlaying else {
                    timer.invalidate()
                    return
                }
                
                self.debugCurrentFrame += 1
                if self.debugCurrentFrame > self.debugTotalFrames {
                    self.debugCurrentFrame = 0
                }
                self.debugFrameSlider?.value = self.debugCurrentFrame
                self.updateDebugAnimation()
            }
        }
    }
    
    func updateDebugAnimation() {
        let timeOffset = Double(debugCurrentFrame) / Double(droneAnimationFPS)
        
        // Simply reload the drone at the new frame
        loadDroneAtFrame(debugCurrentFrame)
        
        // Update label
        debugFrameLabel?.text = String(format: "Frame: %d / %d   Time: %.2fs", Int(debugCurrentFrame), Int(debugTotalFrames), timeOffset)
    }
    
    @objc func exitDebugMode() {
        // Remove debug UI
        debugOverlayView?.removeFromSuperview()
        debugDroneNode?.removeFromParentNode()
        debugAnimationPlayers.removeAll()
        
        // Disable debug mode
        animationDebugMode = false
        
        // Now setup the normal game
        sceneView.allowsCameraControl = false
        setupNightSky()
        setupPlayer()
        setupRoadManager()
        setupPlanet()
        // setupDroneSystem()  // Disabled
        setupObstacleSystem()
        setupControls()
        setupSpeedBar()
        setupHitFlashOverlay()
        startGame()
        
        print("🎮 Exited debug mode, starting game")
    }
    
    func createGradientImage() -> UIImage {
        let size = CGSize(width: 1, height: 512)
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        
        let context = UIGraphicsGetCurrentContext()!
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let colors = [skyTopColor.cgColor, skyBottomColor.cgColor]
        let locations: [CGFloat] = [0.0, 1.0]
        
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations)!
        
        context.drawLinearGradient(gradient,
                                   start: CGPoint(x: 0, y: 0),
                                   end: CGPoint(x: 0, y: size.height),
                                   options: [])
        
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return image
    }
    
    func setupNightSky() {
        // Create stars as simple geometry nodes instead of particles
        // This is more stable and doesn't crash on iOS
        starParticleNode = SCNNode()
        starParticleNode?.name = "StarField"
        
        // Create individual star nodes
        let numberOfStars = min(Int(starCount), 200)  // Limit for performance
        
        for i in 0..<numberOfStars {
            // Random position on a large sphere around the player
            let radius: Float = 250.0 + Float.random(in: 0...100)
            let theta = Float.random(in: 0...(2 * Float.pi))
            let phi = Float.random(in: 0...Float.pi)
            
            // Only place stars in upper hemisphere (above horizon)
            let adjustedPhi = phi * 0.6  // Bias toward top
            
            let x = radius * sin(adjustedPhi) * cos(theta)
            let y = abs(radius * cos(adjustedPhi)) + 50  // Keep above horizon
            let z = radius * sin(adjustedPhi) * sin(theta)
            
            // Create star geometry
            let starGeometry = SCNPlane(width: CGFloat(starSize), height: CGFloat(starSize))
            let starMaterial = SCNMaterial()
            starMaterial.diffuse.contents = UIColor.white
            starMaterial.emission.contents = UIColor.white
            starMaterial.isDoubleSided = true
            starMaterial.blendMode = .add
            starGeometry.materials = [starMaterial]
            
            let starNode = SCNNode(geometry: starGeometry)
            starNode.position = SCNVector3(x, y, z)
            starNode.constraints = [SCNBillboardConstraint()]  // Always face camera
            starNode.name = "star_\(i)"
            
            // Add twinkling animation with random phase
            let randomDelay = Double.random(in: 0...3)
            let twinkleDuration = Double(3.0 / starTwinkleSpeed)
            
            let fadeOut = SCNAction.fadeOpacity(to: CGFloat(0.2 + Float.random(in: 0...0.3)), duration: twinkleDuration)
            let fadeIn = SCNAction.fadeOpacity(to: CGFloat(starBrightness), duration: twinkleDuration)
            let twinkle = SCNAction.sequence([fadeOut, fadeIn])
            let delayedTwinkle = SCNAction.sequence([SCNAction.wait(duration: randomDelay), SCNAction.repeatForever(twinkle)])
            
            starNode.runAction(delayedTwinkle)
            
            starParticleNode?.addChildNode(starNode)
        }
        
        starParticleNode?.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(starParticleNode!)
        
        // Also add some extra bright "feature" stars
        addFeatureStars()
        
        print("✨ Created night sky with \(numberOfStars) twinkling stars")
    }
    
    func addFeatureStars() {
        // Add some larger, brighter stars at specific positions
        let featureStarPositions: [(x: Float, y: Float, z: Float, size: CGFloat)] = [
            (-100, 80, -150, 0.8),
            (80, 120, -200, 1.0),
            (-60, 150, -180, 0.6),
            (120, 60, -250, 0.9),
            (-150, 100, -220, 0.7),
            (40, 180, -300, 1.2),
            (-80, 200, -350, 0.8),
            (100, 140, -280, 0.5),
        ]
        
        for (i, pos) in featureStarPositions.enumerated() {
            let starNode = SCNNode()
            
            // Create a bright star plane with simple glow
            let starPlane = SCNPlane(width: pos.size, height: pos.size)
            let starMaterial = SCNMaterial()
            starMaterial.diffuse.contents = UIColor.white
            starMaterial.emission.contents = UIColor.white
            starMaterial.emission.intensity = 2.0
            starMaterial.isDoubleSided = true
            starMaterial.blendMode = .add
            starPlane.materials = [starMaterial]
            
            starNode.geometry = starPlane
            starNode.position = SCNVector3(pos.x, pos.y, pos.z)
            starNode.constraints = [SCNBillboardConstraint()]  // Always face camera
            
            // Add individual twinkle animation
            let randomDelay = Double.random(in: 0...2)
            let twinkleDuration = Double.random(in: 1.5...3.0) / Double(starTwinkleSpeed)
            
            let fadeOut = SCNAction.fadeOpacity(to: 0.3, duration: twinkleDuration)
            fadeOut.timingMode = .easeInEaseOut
            let fadeIn = SCNAction.fadeOpacity(to: 1.0, duration: twinkleDuration)
            fadeIn.timingMode = .easeInEaseOut
            let twinkle = SCNAction.sequence([fadeOut, fadeIn])
            let delayedTwinkle = SCNAction.sequence([SCNAction.wait(duration: randomDelay), SCNAction.repeatForever(twinkle)])
            
            starNode.runAction(delayedTwinkle, forKey: "twinkle_\(i)")
            
            scene.rootNode.addChildNode(starNode)
        }
        
        print("⭐ Added \(featureStarPositions.count) bright feature stars")
    }
    
    func setupCamera() {
        // Create camera node
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = cameraFieldOfView
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 1000
        
        // Enable depth of field for cinematic look (optional)
        cameraNode.camera?.wantsDepthOfField = false
        
        // Position camera using control variables
        cameraNode.position = SCNVector3(x: cameraOffsetX, y: cameraOffsetY, z: cameraOffsetZ)
        
        // Tilt camera using control variables
        cameraNode.eulerAngles = SCNVector3(x: cameraTiltX, y: cameraTiltY, z: cameraTiltZ)
        
        scene.rootNode.addChildNode(cameraNode)
    }
    
    func setupLighting() {
        // Ambient light - dim for night atmosphere
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 150  // Dimmer for night
        ambientLight.light?.color = UIColor(red: 0.3, green: 0.3, blue: 0.5, alpha: 1.0)  // Slight blue tint
        scene.rootNode.addChildNode(ambientLight)
        
        // Main directional light (moon) - cooler, bluer light
        let moonLight = SCNNode()
        moonLight.light = SCNLight()
        moonLight.light?.type = .directional
        moonLight.light?.intensity = 600  // Softer than sun
        moonLight.light?.color = UIColor(red: 0.7, green: 0.8, blue: 1.0, alpha: 1.0)  // Cool blue-white
        moonLight.light?.castsShadow = true
        moonLight.light?.shadowMode = .deferred
        moonLight.light?.shadowColor = UIColor.black.withAlphaComponent(0.6)  // Darker shadows at night
        moonLight.light?.shadowRadius = 3.0
        moonLight.light?.shadowMapSize = CGSize(width: 2048, height: 2048)
        moonLight.light?.automaticallyAdjustsShadowProjection = true
        moonLight.eulerAngles = SCNVector3(x: -Float.pi / 3, y: Float.pi / 6, z: 0)
        scene.rootNode.addChildNode(moonLight)
        
        // Front fill light - subtle glow to see character in night
        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .directional
        fillLight.light?.intensity = 150  // Dimmer fill for night
        fillLight.light?.color = UIColor(red: 0.6, green: 0.7, blue: 0.9, alpha: 1.0)  // Cool blue
        fillLight.eulerAngles = SCNVector3(x: Float.pi / 6, y: 0, z: 0) // From front
        scene.rootNode.addChildNode(fillLight)
    }
    
    func setupPlayer() {
        // Create player capsule
        playerNode = SCNNode()
        playerNode.name = "Player"
        
        // Bigger capsule for visibility (height 3, radius 0.8)
        let capsule = SCNCapsule(capRadius: 0.8, height: 3.0)
        
        // Better material for 3D look
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.systemBlue
        material.specular.contents = UIColor.white
        material.shininess = 0.7
        material.reflective.contents = UIColor(white: 0.3, alpha: 1.0)
        capsule.materials = [material]
        
        let capsuleNode = SCNNode(geometry: capsule)
        capsuleNode.position.y = 4.0 // Raise so bottom is at y=0
        capsuleNode.castsShadow = true
        playerNode.addChildNode(capsuleNode)
        
        // Position player at center lane, at start
        playerNode.position = SCNVector3(x: 0, y: 0, z: 0)
        
        scene.rootNode.addChildNode(playerNode)
    }
    
    func setupRoadManager() {
        roadManager = RoadManager(scene: scene)
        roadManager.delegate = self  // Set delegate for obstacle spawning
        
        // Set road width BEFORE loading templates (controls width of ALL roads!)
        roadManager.roadWidth = 20.0  // Change this to make roads wider or narrower
        
        // Now load the road templates with the correct width
        roadManager.loadRoadTemplates()
        
        // Set vertical positions for each road type (customize these!)
        roadManager.roadSimpleYPosition = 0.0     // Simple roads at ground level
        roadManager.roadTunnelYPosition = -0.5    // Tunnel roads at ground level
        roadManager.roadPlatformYPosition = -1.48   // Platform roads raised 2 units
        
        // Set curve settings (Subway Surfers style!)
        roadManager.curveEnabled = curveEnabled
        roadManager.curveStrength = curveStrength
        roadManager.curveHorizontalStrength = curveHorizontalStrength
        roadManager.curveRotationStrength = curveRotationStrength
        roadManager.curveStartDistance = curveStartDistance
        
        // Preload all road types to prevent lag when first encountering them
        roadManager.preloadAllRoadTypes()
        
        roadManager.generateInitialRoads()
    }
    
    func setupPlanet() {
        // Try multiple paths to find the planet asset
        let possiblePaths = [
            "Assets/Stylized_planet",
            "Stylized_planet",
            "0/Stylized_planet",
            "ExtractedAssets/0/Stylized_planet"
        ]
        
        var loadedURL: URL? = nil
        for path in possiblePaths {
            if let url = Bundle.main.url(forResource: path, withExtension: "usdz") {
                loadedURL = url
                print("✅ Found planet at path: \(path)")
                break
            } else {
                print("❌ Not found at: \(path).usdz")
            }
        }
        
        // If not found, create a placeholder sphere so we can see SOMETHING
        guard let url = loadedURL else {
            print("⚠️ Could not find Stylized_planet.usdz - Creating placeholder sphere!")
            createPlaceholderPlanet()
            return
        }
        
        do {
            let planetScene = try SCNScene(url: url, options: [
                .checkConsistency: false,
                .convertToYUp: true
            ])
            
            // Create a container node for the planet
            planetNode = SCNNode()
            planetNode?.name = "StylizedPlanet"
            
            // Add all geometry from the loaded scene
            var childCount = 0
            for child in planetScene.rootNode.childNodes {
                planetNode?.addChildNode(child.clone())
                childCount += 1
            }
            
            print("📦 Planet has \(childCount) child nodes")
            
            // Check if we actually got any geometry
            if childCount == 0 {
                print("⚠️ Planet loaded but has no children - Creating placeholder!")
                createPlaceholderPlanet()
                return
            }
            
            // Apply position and scale
            planetNode?.position = SCNVector3(x: planetXAxisPos, y: planetYAxisPos, z: planetZAxisPos)
            planetNode?.scale = SCNVector3(planetSize, planetSize, planetSize)
            
            // Add to scene
            scene.rootNode.addChildNode(planetNode!)
            
            // Play all animations in loop
            playPlanetAnimations()
            
            print("✅ Loaded stylized planet at (\(planetXAxisPos), \(planetYAxisPos), \(planetZAxisPos)) with size \(planetSize)")
        } catch {
            print("❌ Error loading planet: \(error.localizedDescription)")
            createPlaceholderPlanet()
        }
    }
    
    func createPlaceholderPlanet() {
        // Create a visible placeholder sphere
        planetNode = SCNNode()
        planetNode?.name = "PlaceholderPlanet"
        
        // Create a sphere geometry
        let sphere = SCNSphere(radius: 1.0)
        
        // Make it bright orange so it's visible
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.orange
        material.emission.contents = UIColor.orange.withAlphaComponent(0.3) // Slight glow
        material.specular.contents = UIColor.white
        sphere.materials = [material]
        
        let sphereNode = SCNNode(geometry: sphere)
        planetNode?.addChildNode(sphereNode)
        
        // Apply position and scale
        planetNode?.position = SCNVector3(x: planetXAxisPos, y: planetYAxisPos, z: planetZAxisPos)
        planetNode?.scale = SCNVector3(planetSize, planetSize, planetSize)
        
        // Add rotation animation
        let rotationDuration = 5.0 / Double(planetAnimationSpeed)  // Adjust speed
        let rotation = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: rotationDuration)
        let repeatRotation = SCNAction.repeatForever(rotation)
        planetNode?.runAction(repeatRotation, forKey: "planetRotation")
        
        // Add to scene
        scene.rootNode.addChildNode(planetNode!)
        
        print("🟠 Created PLACEHOLDER planet (orange sphere) at (\(planetXAxisPos), \(planetYAxisPos), \(planetZAxisPos)) with size \(planetSize)")
    }
    
    func playPlanetAnimations() {
        guard let planetNode = planetNode else { return }
        
        // Get all animation keys from the planet node and its children
        func getAllAnimations(from node: SCNNode) -> [(key: String, animation: CAAnimation)] {
            var animations: [(key: String, animation: CAAnimation)] = []
            
            // Get animations from current node
            for key in node.animationKeys {
                if let animation = node.animation(forKey: key) {
                    animations.append((key: key, animation: animation))
                }
            }
            
            // Recursively get animations from children
            for child in node.childNodes {
                animations.append(contentsOf: getAllAnimations(from: child))
            }
            
            return animations
        }
        
        // Play all animations in loop
        let allAnimations = getAllAnimations(from: planetNode)
        
        if allAnimations.isEmpty {
            // If no embedded animations, try loading from the scene's animation player
            if let url = Bundle.main.url(forResource: "Assets/Stylized_planet", withExtension: "usdz") {
                do {
                    let planetScene = try SCNScene(url: url, options: nil)
                    
                    // Apply all animations from the scene
                    for child in planetScene.rootNode.childNodes {
                        for animKey in child.animationKeys {
                            if let animation = child.animation(forKey: animKey)?.copy() as? CAAnimation {
                                animation.repeatCount = .infinity // Loop forever
                                animation.speed = planetAnimationSpeed  // Control animation speed
                                
                                // Find matching child in our planet node and apply animation
                                if let targetChild = planetNode.childNode(withName: child.name ?? "", recursively: true) {
                                    targetChild.addAnimation(animation, forKey: animKey)
                                    print("🎬 Playing animation '\(animKey)' on loop at \(planetAnimationSpeed)x speed")
                                }
                            }
                        }
                    }
                } catch {
                    print("⚠️ Could not load animations: \(error.localizedDescription)")
                }
            }
        } else {
            // Play existing animations
            for (key, animation) in allAnimations {
                let loopingAnimation = animation.copy() as! CAAnimation
                loopingAnimation.repeatCount = .infinity
                loopingAnimation.speed = planetAnimationSpeed  // Control animation speed
                planetNode.addAnimation(loopingAnimation, forKey: key + "_loop")
                print("🎬 Playing animation '\(key)' on loop at \(planetAnimationSpeed)x speed")
            }
        }
        
        // Also add a gentle rotation as fallback if no animations found
        if allAnimations.isEmpty {
            let rotationDuration = 20.0 / Double(planetAnimationSpeed)  // Adjust speed
            let rotation = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: rotationDuration)
            let repeatRotation = SCNAction.repeatForever(rotation)
            planetNode.runAction(repeatRotation, forKey: "planetRotation")
            print("🎬 Added fallback rotation animation at \(planetAnimationSpeed)x speed")
        }
    }
    
    // MARK: - Drone System
    func setupDroneSystem() {
        // Preload the drone template
        loadDroneTemplate()
        print("🤖 Drone system initialized")
    }
    
    func loadDroneTemplate() {
        let possiblePaths = [
            "Assets/Drone_remastered",
            "Drone_remastered",
            "Drone_Remastered",
            "Assets/Buster_Drone",
            "Buster_Drone"
        ]
        
        for path in possiblePaths {
            print("🔍 Trying to load drone from: \(path)")
            if let url = Bundle.main.url(forResource: path, withExtension: "usdz") {
                do {
                    let droneScene = try SCNScene(url: url, options: [
                        .checkConsistency: false,
                        .convertToYUp: true
                    ])
                    
                    droneTemplate = SCNNode()
                    droneTemplate?.name = "DroneTemplate"
                    
                    var childCount = 0
                    for child in droneScene.rootNode.childNodes {
                        droneTemplate?.addChildNode(child.clone())
                        childCount += 1
                    }
                    
                    // Measure the drone size
                    let (minBound, maxBound) = droneTemplate!.boundingBox
                    let width = maxBound.x - minBound.x
                    let height = maxBound.y - minBound.y
                    let length = maxBound.z - minBound.z
                    print("📦 Drone has \(childCount) children, size: \(width) x \(height) x \(length)")
                    
                    print("✅ Loaded drone template from: \(path)")
                    return
                } catch {
                    print("❌ Error loading drone: \(error.localizedDescription)")
                }
            }
        }
        
        // If not found, create placeholder
        print("⚠️ Drone asset not found - Creating placeholder")
        createPlaceholderDrone()
    }
    
    func createPlaceholderDrone() {
        droneTemplate = SCNNode()
        droneTemplate?.name = "PlaceholderDrone"
        
        // Create a simple drone shape (box with propellers)
        let body = SCNBox(width: 2, height: 0.5, length: 2, chamferRadius: 0.1)
        let bodyMaterial = SCNMaterial()
        bodyMaterial.diffuse.contents = UIColor.darkGray
        bodyMaterial.emission.contents = UIColor.red.withAlphaComponent(0.3)
        body.materials = [bodyMaterial]
        
        let bodyNode = SCNNode(geometry: body)
        droneTemplate?.addChildNode(bodyNode)
        
        // Add 4 "propeller" spheres at corners
        let propPositions: [(Float, Float)] = [(-0.8, -0.8), (0.8, -0.8), (-0.8, 0.8), (0.8, 0.8)]
        for (x, z) in propPositions {
            let prop = SCNSphere(radius: 0.3)
            let propMaterial = SCNMaterial()
            propMaterial.diffuse.contents = UIColor.cyan
            propMaterial.emission.contents = UIColor.cyan.withAlphaComponent(0.5)
            prop.materials = [propMaterial]
            
            let propNode = SCNNode(geometry: prop)
            propNode.position = SCNVector3(x, 0.3, z)
            droneTemplate?.addChildNode(propNode)
        }
        
        print("🤖 Created placeholder drone")
    }
    
    // MARK: - Obstacle System Methods
    
    func setupObstacleSystem() {
        loadObstaclesTemplate()
        print("🚧 Obstacle system initialized")
    }
    
    func loadObstaclesTemplate() {
        guard let obstaclesURL = Bundle.main.url(forResource: "Obstacles", withExtension: "usdz") else {
            print("❌ Obstacles.usdz not found!")
            return
        }
        
        do {
            let obstaclesScene = try SCNScene(url: obstaclesURL, options: nil)
            obstaclesTemplate = obstaclesScene.rootNode
            print("✅ Obstacles template loaded successfully")
        } catch {
            print("❌ Failed to load Obstacles.usdz: \\(error)")
        }
    }
    
    func shouldSpawnObstacle(for roadSegment: SCNNode) -> Bool {
        // Only spawn on road_simple segments
        guard roadSegment.name?.contains("road_simple") == true else { return false }
        
        // Increment segment counter
        obstacleSegmentCounter += 1
        
        // Check if we should spawn based on frequency
        if obstacleSegmentCounter >= obstacleSpawnEveryXSegments {
            obstacleSegmentCounter = 0
            return true
        }
        
        return false
    }
    
    func spawnObstacleOnRoad(_ roadSegment: SCNNode) {
        guard let obstaclesTemplate = obstaclesTemplate else { return }
        
        // Get road's world position
        let roadZ = roadSegment.position.z
        
        // Check minimum distance
        if abs(roadZ - lastObstacleZ) < obstacleMinDistanceBetween {
            return
        }
        
        // Select a random pattern and spawn all its pieces
        let pieces = selectObstaclePattern()
        for piece in pieces {
            spawnSingleObstacle(piece: piece, roadSegment: roadSegment)
        }
        
        lastObstacleZ = roadZ
    }
    
    // Structure describing a single obstacle piece within a pattern
    struct ObstaclePiece {
        let type: String   // "cube", "cuboid", "hover"
        let xOffset: Float // Exact X position (from pattern variable)
    }
    
    /// Builds the list of enabled patterns, picks one at random.
    /// Each pattern returns an array of ObstaclePiece with exact X offsets
    /// pulled from the p1_, p2_, … control variables.
    func selectObstaclePattern() -> [ObstaclePiece] {
        
        var allPatterns: [[ObstaclePiece]] = []
        
        // ── Pattern 1: All 3 lanes cubes → MUST jump ──
        if p1_enabled {
            allPatterns.append([
                ObstaclePiece(type: "cube",  xOffset: p1_cubeLeftX),
                ObstaclePiece(type: "cube",  xOffset: p1_cubeCenterX),
                ObstaclePiece(type: "cube",  xOffset: p1_cubeRightX),
            ])
        }
        
        // ── Pattern 2: 2 cuboids left+center → dodge RIGHT ──
        if p2_enabled {
            allPatterns.append([
                ObstaclePiece(type: "cuboid", xOffset: p2_cuboidLeftX),
                ObstaclePiece(type: "cuboid", xOffset: p2_cuboidCenterX),
            ])
        }
        
        // ── Pattern 3: 2 cuboids center+right → dodge LEFT ──
        if p3_enabled {
            allPatterns.append([
                ObstaclePiece(type: "cuboid", xOffset: p3_cuboidCenterX),
                ObstaclePiece(type: "cuboid", xOffset: p3_cuboidRightX),
            ])
        }
        
        // ── Pattern 4: 2 cuboids left+right → stay CENTER ──
        if p4_enabled {
            allPatterns.append([
                ObstaclePiece(type: "cuboid", xOffset: p4_cuboidLeftX),
                ObstaclePiece(type: "cuboid", xOffset: p4_cuboidRightX),
            ])
        }
        
        // ── Pattern 5: 2 cuboids left+center + cube right → dodge right AND jump ──
        if p5_enabled {
            allPatterns.append([
                ObstaclePiece(type: "cuboid", xOffset: p5_cuboidLeftX),
                ObstaclePiece(type: "cuboid", xOffset: p5_cuboidCenterX),
                ObstaclePiece(type: "cube",   xOffset: p5_cubeRightX),
            ])
        }
        
        // ── Pattern 6: cube left + 2 cuboids center+right → dodge left AND jump ──
        if p6_enabled {
            allPatterns.append([
                ObstaclePiece(type: "cube",   xOffset: p6_cubeLeftX),
                ObstaclePiece(type: "cuboid", xOffset: p6_cuboidCenterX),
                ObstaclePiece(type: "cuboid", xOffset: p6_cuboidRightX),
            ])
        }
        
        // ── Pattern 7: cuboid left + cube center + cuboid right → stay center AND jump ──
        if p7_enabled {
            allPatterns.append([
                ObstaclePiece(type: "cuboid", xOffset: p7_cuboidLeftX),
                ObstaclePiece(type: "cube",   xOffset: p7_cubeCenterX),
                ObstaclePiece(type: "cuboid", xOffset: p7_cuboidRightX),
            ])
        }
        
        // ── Pattern 8: Hover platform all lanes → MUST dive ──
        if p8_enabled {
            allPatterns.append([
                ObstaclePiece(type: "hover", xOffset: p8_hoverX),
            ])
        }
        
        // ── Pattern 9: Single cube center (breather) ──
        if p9_enabled {
            allPatterns.append([
                ObstaclePiece(type: "cube", xOffset: p9_cubeCenterX),
            ])
        }
        
        // ── Pattern 10: cuboid left + cube center + cube right ──
        if p10_enabled {
            allPatterns.append([
                ObstaclePiece(type: "cuboid", xOffset: p10_cuboidLeftX),
                ObstaclePiece(type: "cube",   xOffset: p10_cubeCenterX),
                ObstaclePiece(type: "cube",   xOffset: p10_cubeRightX),
            ])
        }
        
        // ── Pattern 11: cube left + cube right → stay center or jump ──
        if p11_enabled {
            allPatterns.append([
                ObstaclePiece(type: "cube", xOffset: p11_cubeLeftX),
                ObstaclePiece(type: "cube", xOffset: p11_cubeRightX),
            ])
        }
        
        // ── Pattern 12: hover all lanes + cube center → dive or dodge ──
        if p12_enabled {
            allPatterns.append([
                ObstaclePiece(type: "hover", xOffset: p12_hoverX),
                ObstaclePiece(type: "cube",  xOffset: p12_cubeCenterX),
            ])
        }
        
        // Pick a random enabled pattern (fallback to single center cube)
        return allPatterns.randomElement() ?? [ObstaclePiece(type: "cube", xOffset: 0.0)]
    }
    
    /// Spawn one obstacle piece at the exact X offset specified by the pattern
    func spawnSingleObstacle(piece: ObstaclePiece, roadSegment: SCNNode) {
        guard let obstaclesTemplate = obstaclesTemplate else { return }
        
        // Determine template name, Y offset, scale, and rotation from type
        var obstacleTemplateName: String
        var yOffset: Float
        var scale: SCNVector3
        var rotation: SCNVector3
        
        switch piece.type {
        case "cube":
            obstacleTemplateName = "cube_obstacle"
            yOffset = cubeYOffset
            scale = SCNVector3(cubeSizeX, cubeSizeY, cubeSizeZ)
            rotation = SCNVector3(
                cubeRotationX * .pi / 180,
                cubeRotationY * .pi / 180,
                cubeRotationZ * .pi / 180
            )
        case "cuboid":
            obstacleTemplateName = "cuboid_obstacle"
            yOffset = cuboidYOffset
            scale = SCNVector3(cuboidSizeX, cuboidSizeY, cuboidSizeZ)
            rotation = SCNVector3(
                cuboidRotationX * .pi / 180,
                cuboidRotationY * .pi / 180,
                cuboidRotationZ * .pi / 180
            )
        case "hover":
            obstacleTemplateName = "dive_obstacle"
            yOffset = hoverPlatformYOffset
            scale = SCNVector3(hoverPlatformSizeX, hoverPlatformSizeY, hoverPlatformSizeZ)
            rotation = SCNVector3(
                hoverPlatformRotationX * .pi / 180,
                hoverPlatformRotationY * .pi / 180,
                hoverPlatformRotationZ * .pi / 180
            )
        default:
            return
        }
        
        guard let templateNode = obstaclesTemplate.childNode(withName: obstacleTemplateName, recursively: true) else {
            print("❌ Obstacle template \(obstacleTemplateName) not found")
            return
        }
        
        // X position comes directly from the pattern variable
        let xPos = piece.xOffset
        
        // Clone the obstacle
        let obstacleClone = templateNode.clone()
        
        // Use a WRAPPER node so rotation and scale don't interfere
        let obstacleNode = SCNNode()
        obstacleClone.scale = scale
        obstacleNode.addChildNode(obstacleClone)
        obstacleNode.eulerAngles = rotation
        
        // Position relative to road segment
        let roadY = roadSegment.position.y
        obstacleNode.position = SCNVector3(
            x: xPos,
            y: roadY + yOffset,
            z: roadSegment.position.z
        )
        
        // Store metadata for collision detection
        obstacleNode.name = "obstacle_\(piece.type)_\(UUID().uuidString)"
        
        // Store obstacle data for curve updates
        let obstacleData = ObstacleData(
            baseX: xPos,
            baseY: roadY + yOffset,
            baseZ: roadSegment.position.z,
            roadBaseY: roadY
        )
        obstacleDataMap[obstacleNode] = obstacleData
        
        // Add to scene
        scene.rootNode.addChildNode(obstacleNode)
        activeObstacles.append(obstacleNode)
        
        print("🚧 Spawned \(piece.type) obstacle at X=\(xPos), Z=\(roadSegment.position.z)")
    }
    
    func updateObstacleCurves(playerZ: Float) {
        guard curveEnabled else { return }
        
        for obstacle in activeObstacles {
            guard let data = obstacleDataMap[obstacle] else { continue }
            
            // Calculate distance from player to obstacle
            let distanceFromPlayer = playerZ - data.baseZ  // Positive = obstacle is ahead
            
            // Only apply curve to obstacles ahead of the player
            if distanceFromPlayer > curveStartDistance {
                let curveDistance = distanceFromPlayer - curveStartDistance
                
                // Same curve formula as roads
                let curveY = curveStrength * curveDistance * curveDistance
                let curveX = curveHorizontalStrength * curveDistance * curveDistance
                
                // Rotation to match road tilt
                let tiltX = curveRotationStrength * curveDistance
                
                // Apply curved position (base position + curve offset)
                obstacle.position = SCNVector3(
                    x: data.baseX + curveX,
                    y: data.baseY + curveY,
                    z: data.baseZ
                )
                
                // Apply rotation to match road tilt
                obstacle.eulerAngles = SCNVector3(
                    x: tiltX,
                    y: obstacle.eulerAngles.y,
                    z: obstacle.eulerAngles.z
                )
            } else {
                // Obstacle is near/behind player - keep flat at original position
                obstacle.position = SCNVector3(
                    x: data.baseX,
                    y: data.baseY,
                    z: data.baseZ
                )
                obstacle.eulerAngles = SCNVector3(
                    x: 0,
                    y: obstacle.eulerAngles.y,
                    z: obstacle.eulerAngles.z
                )
            }
        }
    }
    
    func cleanupOldObstacles() {
        // Remove obstacles that are far behind the player
        let cleanupDistance: Float = 50.0
        
        activeObstacles.removeAll { obstacle in
            // Use the stored baseZ from obstacleDataMap for accurate distance
            let baseZ = obstacleDataMap[obstacle]?.baseZ ?? obstacle.position.z
            let distance = baseZ - playerZPosition
            if distance > cleanupDistance {
                obstacle.removeFromParentNode()
                obstacleDataMap.removeValue(forKey: obstacle)  // Clean up data map
                clearedObstacles.remove(ObjectIdentifier(obstacle))  // Clean up cleared set
                return true
            }
            return false
        }
    }
    
    // MARK: - RoadManagerDelegate
    
    func roadManager(_ manager: RoadManager, didSpawnRoad roadSegment: RoadSegment) {
        // Check if we should spawn an obstacle on this road
        if shouldSpawnObstacle(for: roadSegment.node) {
            spawnObstacleOnRoad(roadSegment.node)
        }
    }
    
    // MARK: - Drone Animation Segment Functions
    
    /// Play a specific animation segment on the drone
    /// - Parameters:
    ///   - startFrame: Starting frame of the segment
    ///   - endFrame: Ending frame of the segment (0 = play to end)
    ///   - loop: Whether to loop the animation
    ///   - speed: Playback speed multiplier (1.0 = normal)
    func playDroneAnimationSegment(startFrame: Int, endFrame: Int, loop: Bool = false, speed: Float = 1.0) {
        guard let droneNode = droneNode else { return }
        
        // Calculate time offset and duration based on frames
        let startTime = Float(startFrame) / droneAnimationFPS
        let endTime = endFrame > 0 ? Float(endFrame) / droneAnimationFPS : 999.0
        let duration = endTime - startTime
        
        // Find and play animations on all child nodes
        droneNode.enumerateChildNodes { (node, _) in
            for key in node.animationKeys {
                if let animationPlayer = node.animationPlayer(forKey: key) {
                    // Stop current animation
                    animationPlayer.stop()
                    
                    // Configure animation
                    animationPlayer.animation.repeatCount = loop ? .greatestFiniteMagnitude : 1
                    animationPlayer.speed = CGFloat(speed)
                    
                    // Set time offset to start frame
                    animationPlayer.animation.timeOffset = CFTimeInterval(startTime)
                    
                    // Play from the start frame
                    animationPlayer.play()
                    
                    // If not looping and we have a valid end frame, schedule stop
                    if !loop && endFrame > 0 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(duration / speed)) {
                            animationPlayer.stop()
                        }
                    }
                }
            }
        }
        
        print("🎬 Playing drone animation: frames \(startFrame) to \(endFrame > 0 ? "\(endFrame)" : "end"), loop: \(loop)")
    }
    
    /// Play takeoff animation
    func playDroneTakeOff(completion: (() -> Void)? = nil) {
        currentDroneAnimationPhase = "takeoff"
        playDroneAnimationSegment(startFrame: takeOffStart, endFrame: takeOffEnd, loop: false)
        
        let duration = Float(takeOffEnd - takeOffStart) / droneAnimationFPS
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(duration)) {
            completion?()
        }
    }
    
    /// Play box dropping animation
    func playDroneBoxDropping(completion: (() -> Void)? = nil) {
        currentDroneAnimationPhase = "boxDropping"
        playDroneAnimationSegment(startFrame: boxDroppingStart, endFrame: boxDroppingEnd, loop: false)
        
        let duration = Float(boxDroppingEnd - boxDroppingStart) / droneAnimationFPS
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(duration)) {
            completion?()
        }
    }
    
    /// Play rotating animation
    func playDroneRotating(completion: (() -> Void)? = nil) {
        currentDroneAnimationPhase = "rotating"
        playDroneAnimationSegment(startFrame: rotatingStart, endFrame: rotatingEnd, loop: false)
        
        let duration = Float(rotatingEnd - rotatingStart) / droneAnimationFPS
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(duration)) {
            completion?()
        }
    }
    
    /// Play flying animation at half speed (for traveling phases)
    func playDroneFlyingHalfSpeed() {
        currentDroneAnimationPhase = "flying_half"
        playDroneAnimationSegment(startFrame: flyingStart, endFrame: flyingEnd, loop: true, speed: 1.0)
    }
    
    /// Play flying animation (loops by default)
    func playDroneFlying() {
        currentDroneAnimationPhase = "flying"
        playDroneAnimationSegment(startFrame: flyingStart, endFrame: flyingEnd, loop: true)
    }
    
    /// Stop all drone animations
    func stopDroneAnimations() {
        guard let droneNode = droneNode else { return }
        currentDroneAnimationPhase = "none"
        
        droneNode.enumerateChildNodes { (node, _) in
            for key in node.animationKeys {
                if let animationPlayer = node.animationPlayer(forKey: key) {
                    animationPlayer.stop()
                }
            }
        }
    }
    
    /// Play the hover sequence: boxDropping -> rotating
    func playDroneHoverSequence() {
        playDroneBoxDropping { [weak self] in
            self?.playDroneRotating(completion: nil)
        }
    }
    
    /// Play the full animation sequence: takeoff -> boxDropping -> rotating -> flying
    func playFullDroneSequence() {
        playDroneTakeOff { [weak self] in
            self?.playDroneBoxDropping { [weak self] in
                self?.playDroneRotating { [weak self] in
                    self?.playDroneFlying()
                }
            }
        }
    }
    
    func spawnDrone() {
        guard !isDroneActive else { return }
        guard let template = droneTemplate else { return }
        
        // Check if player is on simple road
        if let currentRoadType = roadManager.getCurrentRoadType(atZ: playerZPosition) {
            guard currentRoadType == .simple else {
                return // Only spawn on simple roads
            }
        }
        
        isDroneActive = true
        dronePathPhase = 0
        dronePathProgress = 0.0
        dronePathStartTime = gameTime
        
        // Randomly choose direction: true = start from right (point 1), false = start from left (point 3)
        droneStartedFromRight = Bool.random()
        
        // Create drone instance
        droneNode = template.clone()
        droneNode?.name = "ActiveDrone"
        droneNode?.scale = SCNVector3(droneSize, droneSize, droneSize)
        
        // Create cargo cube
        droneCargoNode = createCargoCube()
        
        // Position drone at start (will be updated immediately in updateDronePosition)
        updateDronePosition()
        
        // Add to scene
        scene.rootNode.addChildNode(droneNode!)
        scene.rootNode.addChildNode(droneCargoNode!)
        
        // Start flying animation at half speed for phase 0 (coming from start to point 2)
        playDroneFlyingHalfSpeed()
        
        print("🤖 Drone spawned from \(droneStartedFromRight ? "right" : "left") side")
    }
    
    func createCargoCube() -> SCNNode {
        let cargoNode = SCNNode()
        cargoNode.name = "DroneCargo"
        
        // Create a cube
        let cube = SCNBox(width: CGFloat(cargoSize), height: CGFloat(cargoSize), length: CGFloat(cargoSize), chamferRadius: 0.1)
        
        // Make it look like a crate/obstacle
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.orange
        material.emission.contents = UIColor.orange.withAlphaComponent(0.2)
        material.specular.contents = UIColor.white
        cube.materials = [material]
        
        let cubeNode = SCNNode(geometry: cube)
        cargoNode.addChildNode(cubeNode)
        
        return cargoNode
    }
    
    func updateCargoPosition() {
        guard let droneNode = droneNode, let cargoNode = droneCargoNode else { return }
        
        // Position cargo relative to drone
        cargoNode.position = SCNVector3(
            droneNode.position.x + cargoOffsetX,
            droneNode.position.y + cargoOffsetY,
            droneNode.position.z + cargoOffsetZ
        )
    }
    
    func updateDronePosition() {
        guard let droneNode = droneNode, isDroneActive else { return }
        
        // Get the X and Y positions for current path progress
        let startX: Float
        let midX: Float = dronePoint2X
        let endX: Float
        
        let startY: Float
        let midY: Float = dronePoint2Y
        let endY: Float
        
        if droneStartedFromRight {
            startX = dronePoint1X
            startY = dronePoint1Y
            endX = dronePoint3X
            endY = dronePoint3Y
        } else {
            startX = dronePoint3X
            startY = dronePoint3Y
            endX = dronePoint1X
            endY = dronePoint1Y
        }
        
        // Calculate position based on current phase
        var currentX: Float = midX
        var currentY: Float = midY
        let arcHeight: Float = 5.0  // Extra height for curved path
        
        let elapsedInPhase = gameTime - dronePathStartTime
        
        switch dronePathPhase {
        case 0: // Moving from start to mid - Flying animation at half speed
            let progress = Float(min(elapsedInPhase / droneTimeToPoint2, 1.0))
            
            // Quadratic bezier for arc: start -> control -> mid
            let controlX = (startX + midX) / 2
            let controlY = max(startY, midY) + arcHeight
            
            let t = progress
            let oneMinusT = 1 - t
            currentX = oneMinusT * oneMinusT * startX + 2 * oneMinusT * t * controlX + t * t * midX
            currentY = oneMinusT * oneMinusT * startY + 2 * oneMinusT * t * controlY + t * t * midY
            
            // Move to next phase when done
            if progress >= 1.0 {
                dronePathPhase = 1
                dronePathStartTime = gameTime
                droneHoverAnimationStarted = false  // Reset for hover phase
                
                // Start hover sequence: boxDropping -> rotating
                playDroneHoverSequence()
                print("🎬 Phase 1: Playing boxDropping -> rotating")
            }
            
        case 1: // Hovering at mid - BoxDropping then Rotating animations
            let progress = Float(min(elapsedInPhase / droneHoverTime, 1.0))
            
            // Add slight bobbing motion
            let bobOffset = sin(Float(elapsedInPhase) * 4.0) * 0.5
            currentX = midX
            currentY = midY + bobOffset
            
            // Move to next phase when done
            if progress >= 1.0 {
                dronePathPhase = 2
                dronePathStartTime = gameTime
                
                // Start flying animation at half speed for exit
                playDroneFlyingHalfSpeed()
                print("🎬 Phase 2: Playing flying at half speed (exiting)")
            }
            
        case 2: // Moving from mid to end - Flying animation at half speed
            let progress = Float(min(elapsedInPhase / droneTimeFromPoint2, 1.0))
            
            // Quadratic bezier for arc: mid -> control -> end
            let controlX = (midX + endX) / 2
            let controlY = max(midY, endY) + arcHeight
            
            let t = progress
            let oneMinusT = 1 - t
            currentX = oneMinusT * oneMinusT * midX + 2 * oneMinusT * t * controlX + t * t * endX
            currentY = oneMinusT * oneMinusT * midY + 2 * oneMinusT * t * controlY + t * t * endY
            
            // Remove drone when done
            if progress >= 1.0 {
                removeDrone()
                return
            }
            
        default:
            break
        }
        
        // Z position always follows player
        let currentZ = playerZPosition + dronePoint2Z
        
        // Update drone position
        droneNode.position = SCNVector3(currentX, currentY, currentZ)
        
        // Update cargo position
        updateCargoPosition()
    }
    
    func removeDrone() {
        stopDroneAnimations()
        droneNode?.removeFromParentNode()
        droneCargoNode?.removeFromParentNode()
        droneNode = nil
        droneCargoNode = nil
        isDroneActive = false
        dronePathPhase = 0
        droneHoverAnimationStarted = false
        print("🤖 Drone removed")
    }
    
    func updateDroneSystem(currentTime: TimeInterval) {
        // Check if we should spawn a new drone
        if !isDroneActive {
            if lastDroneSpawnTime == 0 {
                lastDroneSpawnTime = currentTime
            }
            
            if currentTime - lastDroneSpawnTime >= TimeInterval(droneSpawnInterval) {
                spawnDrone()
                lastDroneSpawnTime = currentTime
            }
        }
        
        // Update drone position every frame (follows player Z)
        updateDronePosition()
    }
    
    func setupControls() {
        // Swipe gestures for touch controls
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeLeft.direction = .left
        sceneView.addGestureRecognizer(swipeLeft)
        
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeRight.direction = .right
        sceneView.addGestureRecognizer(swipeRight)
        
        let swipeUp = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeUp.direction = .up
        sceneView.addGestureRecognizer(swipeUp)
        
        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeDown.direction = .down
        sceneView.addGestureRecognizer(swipeDown)
    }
    
    @objc func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        switch gesture.direction {
        case .left:
            movePlayerLeft()
        case .right:
            movePlayerRight()
        case .up:
            playerJump()
        case .down:
            playerDive()
        default:
            break
        }
    }
    
    // MARK: - Keyboard Controls (Arrow Keys for Simulator)
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            guard let key = press.key else { continue }
            
            switch key.keyCode {
            case .keyboardLeftArrow:
                movePlayerLeft()
            case .keyboardRightArrow:
                movePlayerRight()
            case .keyboardUpArrow:
                startMoveForward()
            case .keyboardDownArrow:
                startMoveBackward()
            case .keyboardSpacebar:
                playerJump()
            case .keyboardX:
                playerDive()
            default:
                super.pressesBegan(presses, with: event)
            }
        }
    }
    
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            guard let key = press.key else { continue }
            
            switch key.keyCode {
            case .keyboardUpArrow:
                stopMoveForward()
            case .keyboardDownArrow:
                stopMoveBackward()
            default:
                super.pressesEnded(presses, with: event)
            }
        }
    }
    
    // MARK: - Player Movement
    func startMoveForward() {
        isMovingForward = true
        isMovingBackward = false // Cancel backward if moving forward
        print("⬆️ Moving forward!")
    }
    
    func stopMoveForward() {
        isMovingForward = false
    }
    
    func startMoveBackward() {
        isMovingBackward = true
        isMovingForward = false // Cancel forward if moving backward
        print("⬇️ Moving backward!")
    }
    
    func stopMoveBackward() {
        isMovingBackward = false
    }
    
    func movePlayerLeft() {
        guard currentLane > 0 else { return }
        currentLane -= 1
        animatePlayerToLane()
        print("⬅️ Moved to lane \(currentLane)")
    }
    
    func movePlayerRight() {
        guard currentLane < 2 else { return }
        currentLane += 1
        animatePlayerToLane()
        print("➡️ Moved to lane \(currentLane)")
    }
    
    func animatePlayerToLane() {
        let targetX = Float(currentLane - 1) * laneWidth // Lane 0=-4, Lane 1=0, Lane 2=4
        
        // Smooth animation to new lane
        let currentPos = playerNode.position
        let targetPos = SCNVector3(x: targetX, y: currentPos.y, z: currentPos.z)
        let moveAction = SCNAction.move(to: targetPos, duration: 0.15)
        moveAction.timingMode = .easeOut
        playerNode.runAction(moveAction)
    }
    
    func playerJump() {
        // Don't jump if already jumping
        guard !isJumping else { return }
        isJumping = true
        
        // Store the original Y position before jumping
        let originalY = playerNode.position.y
        
        print("⬆️ Jump! Height: \(jumpHeight), Duration: \(jumpUpDuration + jumpDownDuration)s")
        
        // Jump animation using control variables
        let jumpUp = SCNAction.moveBy(
            x: 0,
            y: CGFloat(jumpHeight),
            z: CGFloat(-jumpForwardBoost),  // Negative Z = forward
            duration: TimeInterval(jumpUpDuration)
        )
        jumpUp.timingMode = .easeOut
        
        let jumpDown = SCNAction.moveBy(
            x: 0,
            y: CGFloat(-jumpHeight),
            z: 0,  // No additional Z movement on descent
            duration: TimeInterval(jumpDownDuration)
        )
        jumpDown.timingMode = .linear  // Linear for clean landing, no bounce
        
        // Ensure player is exactly at ground level after landing
        let snapToGround = SCNAction.run { [weak self] _ in
            guard let self = self else { return }
            var pos = self.playerNode.position
            pos.y = originalY
            self.playerNode.position = pos
        }
        
        let jumpSequence = SCNAction.sequence([jumpUp, jumpDown, snapToGround])
        
        playerNode.runAction(jumpSequence) { [weak self] in
            self?.isJumping = false
        }
    }
    
    func playerDive() {
        // Don't dive if already diving
        guard !isDiving else { return }
        isDiving = true
        
        print("⬇️ Dive! Squash: \(diveSquashScale), Hold: \(diveHoldDuration)s")
        
        // Dive/slide animation using control variables
        let squash = SCNAction.scale(
            to: CGFloat(diveSquashScale),
            duration: TimeInterval(diveSquashDuration)
        )
        let hold = SCNAction.wait(duration: TimeInterval(diveHoldDuration))
        let restore = SCNAction.scale(
            to: CGFloat(1.0),
            duration: TimeInterval(diveRestoreDuration)
        )
        let diveSequence = SCNAction.sequence([squash, hold, restore])
        
        playerNode.runAction(diveSequence) { [weak self] in
            self?.isDiving = false
        }
    }
    
    // MARK: - Speed Bar
    func setupSpeedBar() {
        let screenWidth = view.bounds.width
        let barWidth = screenWidth - speedBarSideMargin * 2
        let divisionWidth = barWidth / 3.0
        
        // Container
        let container = UIView(frame: CGRect(
            x: speedBarSideMargin,
            y: view.bounds.height - speedBarBottomMargin - speedBarHeight,
            width: barWidth,
            height: speedBarHeight
        ))
        container.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        container.layer.cornerRadius = speedBarCornerRadius
        container.clipsToBounds = true
        container.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        view.addSubview(container)
        speedBarContainerView = container
        
        // Division backgrounds + fills
        let tierColors: [(bg: UIColor, fill: UIColor, label: String)] = [
            (UIColor(red: 0.1, green: 0.2, blue: 0.1, alpha: 1.0),
             UIColor(red: 0.2, green: 0.85, blue: 0.3, alpha: 1.0), "SLOW"),
            (UIColor(red: 0.25, green: 0.2, blue: 0.05, alpha: 1.0),
             UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0), "MED"),
            (UIColor(red: 0.25, green: 0.08, blue: 0.08, alpha: 1.0),
             UIColor(red: 1.0, green: 0.25, blue: 0.2, alpha: 1.0), "MAX"),
        ]
        
        var tierBGs: [UIView] = []
        var tierFills: [UIView] = []
        
        for i in 0..<3 {
            let x = CGFloat(i) * divisionWidth
            
            // Background
            let bg = UIView(frame: CGRect(x: x, y: 0, width: divisionWidth, height: speedBarHeight))
            bg.backgroundColor = tierColors[i].bg
            container.addSubview(bg)
            tierBGs.append(bg)
            
            // Fill bar (starts at width 0)
            let fill = UIView(frame: CGRect(x: x, y: 0, width: 0, height: speedBarHeight))
            fill.backgroundColor = tierColors[i].fill
            container.addSubview(fill)
            tierFills.append(fill)
            
            // Division label
            let label = UILabel(frame: CGRect(x: x, y: 0, width: divisionWidth, height: speedBarHeight))
            label.text = tierColors[i].label
            label.textAlignment = .center
            label.textColor = UIColor.white.withAlphaComponent(0.5)
            label.font = UIFont.systemFont(ofSize: 10, weight: .bold)
            container.addSubview(label)
        }
        
        speedBarTier1View = tierBGs[0]
        speedBarTier2View = tierBGs[1]
        speedBarTier3View = tierBGs[2]
        speedBarTier1Fill = tierFills[0]
        speedBarTier2Fill = tierFills[1]
        speedBarTier3Fill = tierFills[2]
        
        // Divider lines
        for i in 1..<3 {
            let divider = UIView(frame: CGRect(
                x: CGFloat(i) * divisionWidth - 1,
                y: 0,
                width: 2,
                height: speedBarHeight
            ))
            divider.backgroundColor = UIColor.white.withAlphaComponent(0.3)
            container.addSubview(divider)
        }
        
        // Speed label above bar
        let sLabel = UILabel(frame: CGRect(
            x: speedBarSideMargin,
            y: view.bounds.height - speedBarBottomMargin - speedBarHeight - 20,
            width: barWidth,
            height: 18
        ))
        sLabel.text = "SPEED: 0"
        sLabel.textAlignment = .center
        sLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        sLabel.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .bold)
        sLabel.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        view.addSubview(sLabel)
        speedBarLabel = sLabel
        
        print("📊 Speed bar UI created")
    }
    
    /// Updates speedBarFill based on whether forward is held. Called every frame.
    func updateSpeedBar(dt: Float) {
        if isMovingForward {
            // ── FILLING ──
            // Determine which tier we're filling and use that tier's fill rate
            if speedBarFill < 1.0 {
                // Filling tier 1
                let rate = 1.0 / tier1FillTime  // fraction per second
                speedBarFill = min(1.0, speedBarFill + rate * dt)
            } else if speedBarFill < 2.0 {
                // Filling tier 2
                let rate = 1.0 / tier2FillTime
                speedBarFill = min(2.0, speedBarFill + rate * dt)
            } else if speedBarFill < 3.0 {
                // Filling tier 3
                let rate = 1.0 / tier3FillTime
                speedBarFill = min(3.0, speedBarFill + rate * dt)
            }
        } else {
            // ── DRAINING ──
            // Determine which tier we're draining and use that tier's drain rate
            if speedBarFill > 2.0 {
                // Draining tier 3
                let rate = 1.0 / tier3DrainTime
                speedBarFill = max(2.0, speedBarFill - rate * dt)
            } else if speedBarFill > 1.0 {
                // Draining tier 2
                let rate = 1.0 / tier2DrainTime
                speedBarFill = max(1.0, speedBarFill - rate * dt)
            } else if speedBarFill > 0.0 {
                // Draining tier 1
                let rate = 1.0 / tier1DrainTime
                speedBarFill = max(0.0, speedBarFill - rate * dt)
            }
        }
        
        // Update visuals
        updateSpeedBarUI()
    }
    
    /// Returns the current speed based on which tier the bar is in.
    func speedFromBar() -> Float {
        if speedBarFill <= 0.0 {
            return 0.0             // Stopped
        } else if speedBarFill <= 1.0 {
            return speedTier1      // Slow
        } else if speedBarFill <= 2.0 {
            return speedTier2      // Medium
        } else {
            return speedTier3      // Max
        }
    }
    
    /// Updates the speed bar fill visuals to match speedBarFill.
    func updateSpeedBarUI() {
        guard let container = speedBarContainerView else { return }
        
        let barWidth = container.bounds.width
        let divisionWidth = barWidth / 3.0
        
        // Tier 1 fill (0.0 - 1.0)
        let t1 = max(0, min(1, speedBarFill))
        speedBarTier1Fill?.frame = CGRect(
            x: 0,
            y: 0,
            width: divisionWidth * CGFloat(t1),
            height: speedBarHeight
        )
        
        // Tier 2 fill (1.0 - 2.0)
        let t2 = max(0, min(1, speedBarFill - 1.0))
        speedBarTier2Fill?.frame = CGRect(
            x: divisionWidth,
            y: 0,
            width: divisionWidth * CGFloat(t2),
            height: speedBarHeight
        )
        
        // Tier 3 fill (2.0 - 3.0)
        let t3 = max(0, min(1, speedBarFill - 2.0))
        speedBarTier3Fill?.frame = CGRect(
            x: divisionWidth * 2,
            y: 0,
            width: divisionWidth * CGFloat(t3),
            height: speedBarHeight
        )
        
        // Update speed label
        let currentSpeed = speedFromBar()
        let tierName: String
        if currentSpeed <= 0 {
            tierName = "STOPPED"
        } else if speedBarFill <= 1.0 {
            tierName = "SLOW"
        } else if speedBarFill <= 2.0 {
            tierName = "MEDIUM"
        } else {
            tierName = "MAX"
        }
        speedBarLabel?.text = "SPEED: \(Int(currentSpeed)) — \(tierName)"
    }
    
    // MARK: - Collision Detection
    
    /// Check if player collides with any obstacles
    func checkObstacleCollisions(currentTime: Float) {
        // Check cooldown - don't hit again if recently hit
        if currentTime - lastHitTime < hitCooldownTime {
            return
        }
        
        // Player bounding box (centered on player position)
        // Account for scale (when diving, player is squashed)
        let playerPos = playerNode.presentation.position
        let playerScale = playerNode.presentation.scale
        let scaledBBoxWidth = playerBBoxWidth * playerScale.x
        let scaledBBoxHeight = playerBBoxHeight * playerScale.y
        let scaledBBoxDepth = playerBBoxDepth * playerScale.z
        let scaledOffsetY = playerBBoxOffsetY * playerScale.y
        
        let playerMin = SCNVector3(
            playerPos.x - scaledBBoxWidth / 2,
            playerPos.y + scaledOffsetY - scaledBBoxHeight / 2,
            playerPos.z - scaledBBoxDepth / 2
        )
        let playerMax = SCNVector3(
            playerPos.x + scaledBBoxWidth / 2,
            playerPos.y + scaledOffsetY + scaledBBoxHeight / 2,
            playerPos.z + scaledBBoxDepth / 2
        )
        
        // Check each obstacle
        for obstacle in activeObstacles {
            guard let obstacleData = obstacleDataMap[obstacle] else { continue }
            
            // Get bounding box size and offset based on obstacle type
            var bboxSize: SCNVector3
            var bboxOffset: SCNVector3
            
            if obstacle.name?.contains("cube_") == true {
                bboxSize = SCNVector3(cubeBBoxWidth, cubeBBoxHeight, cubeBBoxDepth)
                bboxOffset = SCNVector3(cubeBBoxOffsetX, cubeBBoxOffsetY, cubeBBoxOffsetZ)
            } else if obstacle.name?.contains("cuboid_") == true {
                bboxSize = SCNVector3(cuboidBBoxWidth, cuboidBBoxHeight, cuboidBBoxDepth)
                bboxOffset = SCNVector3(cuboidBBoxOffsetX, cuboidBBoxOffsetY, cuboidBBoxOffsetZ)
            } else if obstacle.name?.contains("hover_") == true {
                bboxSize = SCNVector3(hoverBBoxWidth, hoverBBoxHeight, hoverBBoxDepth)
                bboxOffset = SCNVector3(hoverBBoxOffsetX, hoverBBoxOffsetY, hoverBBoxOffsetZ)
            } else {
                continue // Unknown obstacle type
            }
            
            // Obstacle bounding box (use presentation position for accurate collision during movement)
            let obstaclePos = obstacle.presentation.position
            let obstacleMin = SCNVector3(
                obstaclePos.x + bboxOffset.x - bboxSize.x / 2,
                obstaclePos.y + bboxOffset.y - bboxSize.y / 2,
                obstaclePos.z + bboxOffset.z - bboxSize.z / 2
            )
            let obstacleMax = SCNVector3(
                obstaclePos.x + bboxOffset.x + bboxSize.x / 2,
                obstaclePos.y + bboxOffset.y + bboxSize.y / 2,
                obstaclePos.z + bboxOffset.z + bboxSize.z / 2
            )
            
            // AABB collision test (Axis-Aligned Bounding Box)
            let collisionX = playerMax.x >= obstacleMin.x && playerMin.x <= obstacleMax.x
            let collisionY = playerMax.y >= obstacleMin.y && playerMin.y <= obstacleMax.y
            let collisionZ = playerMax.z >= obstacleMin.z && playerMin.z <= obstacleMax.z
            
            if collisionX && collisionY && collisionZ {
                // COLLISION DETECTED!
                print("💥 COLLISION: isJumping=\(isJumping), playerY=\(playerPos.y), obstacleY=\(obstaclePos.y)")
                
                // Check if this obstacle was already cleared (jumped over successfully)
                let obstacleID = ObjectIdentifier(obstacle)
                if clearedObstacles.contains(obstacleID) {
                    print("✅ Already cleared this obstacle - still invincible")
                    continue // Skip this obstacle, already cleared
                }
                
                // Check if player can safely jump over this obstacle type
                let canJumpOver = isJumpingOverObstacle(obstacle: obstacle)
                
                if canJumpOver {
                    // Safe! Player is jumping over this obstacle - no damage
                    // Mark this obstacle as cleared so we stay invincible
                    clearedObstacles.insert(obstacleID)
                    print("✅ Jumped over obstacle safely! INVINCIBLE - no damage applied")
                    // DO NOT apply damage - player is invincible
                } else {
                    // Hit! Apply damage
                    print("❌ Not protected - applying damage")
                    onObstacleHit(obstacle: obstacle, currentTime: currentTime)
                }
                break // Only process one collision per frame
            }
        }
    }
    
    /// Check if player is currently jumping over an obstacle (no damage)
    func isJumpingOverObstacle(obstacle: SCNNode) -> Bool {
        // Not jumping? Can't jump over anything
        guard isJumping else {
            print("❌ Jump check failed: Not jumping")
            return false
        }
        
        // Calculate horizontal distance between player and obstacle
        // Use presentation positions for accurate collision during movement
        let playerPos = playerNode.presentation.position
        let obstaclePos = obstacle.presentation.position
        let dx = playerPos.x - obstaclePos.x
        let dz = playerPos.z - obstaclePos.z
        let distance = sqrtf(dx * dx + dz * dz)
        
        print("🔍 Jump check: distance=\(distance), safeIn=\(safeDistanceIn), safeOut=\(safeDistanceOut), isJumping=\(isJumping)")
        
        // Check if player is within the safe jump window
        // Too far (outside outer boundary) or too close (inside inner boundary) = no protection
        guard distance <= safeDistanceOut && distance >= safeDistanceIn else {
            print("❌ Jump check failed: distance \(distance) not in range [\(safeDistanceIn), \(safeDistanceOut)]")
            return false
        }
        
        // Check obstacle type and corresponding setting
        if obstacle.name?.contains("cube_") == true {
            print("✅ Jump check: cube obstacle, enabled=\(jumpOverCubesEnabled)")
            return jumpOverCubesEnabled
        } else if obstacle.name?.contains("cuboid_") == true {
            print("✅ Jump check: cuboid obstacle, enabled=\(jumpOverCuboidsEnabled)")
            return jumpOverCuboidsEnabled
        } else if obstacle.name?.contains("hover_") == true {
            print("✅ Jump check: hover obstacle, enabled=\(jumpOverHoverEnabled)")
            return jumpOverHoverEnabled
        }
        
        print("❌ Jump check failed: Unknown obstacle type")
        return false // Unknown obstacle type - take damage
    }
    
    /// Called when player hits an obstacle
    func onObstacleHit(obstacle: SCNNode, currentTime: Float) {
        lastHitTime = currentTime
        
        // Drain speed bar
        speedBarFill = max(0.0, speedBarFill - hitSpeedPenalty)
        updateSpeedBarUI()
        
        // Visual feedback - red flash
        triggerHitFlash()
        
        // Optional: Camera shake
        if hitShakeAmount > 0 {
            triggerCameraShake()
        }
        
        print("💥 HIT! Speed reduced by \(hitSpeedPenalty). Current fill: \(speedBarFill)")
    }
    
    // MARK: - Bounding Box Visualization (Debug)
    
    /// Creates/updates debug wireframe boxes showing collision areas
    func updateBoundingBoxVisualization() {
        // Clear old boxes
        for node in boundingBoxNodes {
            node.removeFromParentNode()
        }
        boundingBoxNodes.removeAll()
        
        // Clear old safe distance circles
        for node in safeJumpDistanceNodes {
            node.removeFromParentNode()
        }
        safeJumpDistanceNodes.removeAll()
        
        // Player bounding box
        // Account for scale (when diving, player is squashed)
        let playerScale = playerNode.presentation.scale
        let scaledBBoxHeight = playerBBoxHeight * playerScale.y
        let scaledBBoxWidth = playerBBoxWidth * playerScale.x
        let scaledBBoxDepth = playerBBoxDepth * playerScale.z
        
        let playerBox = createWireframeBox(
            size: SCNVector3(scaledBBoxWidth, scaledBBoxHeight, scaledBBoxDepth),
            color: UIColor.cyan
        )
        let playerPos = playerNode.presentation.position
        // Adjust Y offset based on scale (when squashed, center moves down)
        let scaledOffsetY = playerBBoxOffsetY * playerScale.y
        playerBox.position = SCNVector3(
            playerPos.x,
            playerPos.y + scaledOffsetY,
            playerPos.z
        )
        scene.rootNode.addChildNode(playerBox)
        boundingBoxNodes.append(playerBox)
        
        // Obstacle bounding boxes
        for obstacle in activeObstacles {
            var bboxSize: SCNVector3
            var bboxOffset: SCNVector3
            var color: UIColor
            
            if obstacle.name?.contains("cube_") == true {
                bboxSize = SCNVector3(cubeBBoxWidth, cubeBBoxHeight, cubeBBoxDepth)
                bboxOffset = SCNVector3(cubeBBoxOffsetX, cubeBBoxOffsetY, cubeBBoxOffsetZ)
                color = UIColor.green
            } else if obstacle.name?.contains("cuboid_") == true {
                bboxSize = SCNVector3(cuboidBBoxWidth, cuboidBBoxHeight, cuboidBBoxDepth)
                bboxOffset = SCNVector3(cuboidBBoxOffsetX, cuboidBBoxOffsetY, cuboidBBoxOffsetZ)
                color = UIColor.yellow
            } else if obstacle.name?.contains("hover_") == true {
                bboxSize = SCNVector3(hoverBBoxWidth, hoverBBoxHeight, hoverBBoxDepth)
                bboxOffset = SCNVector3(hoverBBoxOffsetX, hoverBBoxOffsetY, hoverBBoxOffsetZ)
                color = UIColor.magenta
            } else {
                continue
            }
            
            let obstacleBox = createWireframeBox(size: bboxSize, color: color)
            let obstaclePos = obstacle.presentation.position
            obstacleBox.position = SCNVector3(
                obstaclePos.x + bboxOffset.x,
                obstaclePos.y + bboxOffset.y,
                obstaclePos.z + bboxOffset.z
            )
            scene.rootNode.addChildNode(obstacleBox)
            boundingBoxNodes.append(obstacleBox)
            
            // Add safe jump distance circle if enabled
            if showSafeJumpDistance {
                let canJumpOver = (obstacle.name?.contains("cube_") == true && jumpOverCubesEnabled) ||
                                  (obstacle.name?.contains("cuboid_") == true && jumpOverCuboidsEnabled) ||
                                  (obstacle.name?.contains("hover_") == true && jumpOverHoverEnabled)
                
                if canJumpOver {
                    let distanceCircle = createSafeJumpDistanceCircle()
                    distanceCircle.position = SCNVector3(
                        obstaclePos.x,
                        obstaclePos.y + 0.1,  // Slightly above ground
                        obstaclePos.z
                    )
                    scene.rootNode.addChildNode(distanceCircle)
                    safeJumpDistanceNodes.append(distanceCircle)
                }
            }
        }
    }
    
    /// Creates a ring showing the safe jump distance window (between inner and outer radius)
    func createSafeJumpDistanceCircle() -> SCNNode {
        let containerNode = SCNNode()
        
        // Outer circle (green - safe zone starts here)
        let outerCircle = SCNTorus(
            ringRadius: CGFloat(safeDistanceOut),
            pipeRadius: 0.2
        )
        let outerMaterial = SCNMaterial()
        outerMaterial.diffuse.contents = UIColor.green.withAlphaComponent(0.5)
        outerMaterial.emission.contents = UIColor.green
        outerMaterial.isDoubleSided = true
        outerCircle.materials = [outerMaterial]
        let outerNode = SCNNode(geometry: outerCircle)
        containerNode.addChildNode(outerNode)
        
        // Inner circle (red - danger zone inside this)
        let innerCircle = SCNTorus(
            ringRadius: CGFloat(safeDistanceIn),
            pipeRadius: 0.2
        )
        let innerMaterial = SCNMaterial()
        innerMaterial.diffuse.contents = UIColor.red.withAlphaComponent(0.5)
        innerMaterial.emission.contents = UIColor.red
        innerMaterial.isDoubleSided = true
        innerCircle.materials = [innerMaterial]
        let innerNode = SCNNode(geometry: innerCircle)
        containerNode.addChildNode(innerNode)
        
        // Optional: Fill the safe zone with a transparent orange ring
        let safeZoneFill = SCNTube(
            innerRadius: CGFloat(safeDistanceIn),
            outerRadius: CGFloat(safeDistanceOut),
            height: 0.05
        )
        let fillMaterial = SCNMaterial()
        fillMaterial.diffuse.contents = UIColor.orange.withAlphaComponent(0.15)
        fillMaterial.emission.contents = UIColor.orange.withAlphaComponent(0.1)
        fillMaterial.isDoubleSided = true
        safeZoneFill.materials = [fillMaterial]
        let fillNode = SCNNode(geometry: safeZoneFill)
        containerNode.addChildNode(fillNode)
        
        return containerNode
    }
    
    /// Creates a wireframe box for visualization
    func createWireframeBox(size: SCNVector3, color: UIColor) -> SCNNode {
        let box = SCNBox(
            width: CGFloat(size.x),
            height: CGFloat(size.y),
            length: CGFloat(size.z),
            chamferRadius: 0
        )
        
        // Wireframe material
        let material = SCNMaterial()
        material.diffuse.contents = color.withAlphaComponent(0.3)
        material.emission.contents = color
        material.fillMode = .lines
        material.isDoubleSided = true
        box.materials = [material]
        
        let node = SCNNode(geometry: box)
        return node
    }
    
    // MARK: - Hit Visual Feedback
    
    func setupHitFlashOverlay() {
        // Create a red overlay view for hit flash
        let flashView = UIView(frame: view.bounds)
        flashView.backgroundColor = UIColor.red.withAlphaComponent(0.0)
        flashView.isUserInteractionEnabled = false
        flashView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(flashView)
        hitFlashView = flashView
        
        print("💥 Hit flash overlay created")
    }
    
    func triggerHitFlash() {
        guard let flashView = hitFlashView else { return }
        
        // Remove any existing animation
        flashView.layer.removeAllAnimations()
        
        // Flash red
        flashView.backgroundColor = UIColor.red.withAlphaComponent(0.4)
        UIView.animate(withDuration: TimeInterval(hitFlashDuration)) {
            flashView.backgroundColor = UIColor.red.withAlphaComponent(0.0)
        }
    }
    
    func triggerCameraShake() {
        let originalPos = cameraNode.position
        
        // Random shake offset
        let shakeX = Float.random(in: -hitShakeAmount...hitShakeAmount)
        let shakeY = Float.random(in: -hitShakeAmount...hitShakeAmount)
        
        let shake = SCNAction.moveBy(
            x: CGFloat(shakeX),
            y: CGFloat(shakeY),
            z: 0,
            duration: 0.05
        )
        let restore = SCNAction.move(to: originalPos, duration: 0.05)
        let sequence = SCNAction.sequence([shake, restore])
        
        cameraNode.runAction(sequence)
    }
    
    // MARK: - Game Loop
    func startGame() {
        isGameRunning = true
        
        // Become first responder to receive keyboard events
        becomeFirstResponder()
        
        // Set up game loop
        sceneView.delegate = self
        sceneView.isPlaying = true
    }
    
    // Store current time for collision system and drone system
    private var gameTime: TimeInterval = 0
    
    func updateGame(deltaTime: TimeInterval, currentTime: TimeInterval) {
        guard isGameRunning else { return }
        
        let time = Float(currentTime)
        
        // ── Speed Bar Update ──
        let dt = Float(deltaTime)
        updateSpeedBar(dt: dt)
        
        // Calculate current speed from speed bar fill level
        let currentSpeed = speedFromBar()
        
        // Move forward if bar has charge, backward overrides
        var movement: Float = 0
        if isMovingBackward {
            movement = speedTier1 * dt  // Backward always uses slow speed
        } else if currentSpeed > 0 && speedBarFill > 0 {
            movement = -currentSpeed * dt
        }
        
        playerZPosition += movement
        
        // Get the Y position of the current road and apply player offset
        if let roadY = roadManager.getCurrentRoadYPosition(atZ: playerZPosition) {
            // Get the appropriate offset based on current road type
            var yOffset: Float = 0.0
            if let roadType = roadManager.getCurrentRoadType(atZ: playerZPosition) {
                switch roadType {
                case .simple:
                    yOffset = playerYOffsetOnSimple
                case .tunnel:
                    yOffset = playerYOffsetOnTunnel
                case .platform:
                    yOffset = playerYOffsetOnPlatform
                }
            }
            
            // Smoothly transition player to road's Y position + offset
            let targetY = roadY + yOffset
            let currentY = playerNode.position.y
            let smoothFactor: Float = 0.1 // Adjust for smoother/faster transition
            let newY = currentY + (targetY - currentY) * smoothFactor
            playerNode.position.y = newY
        }
        
        // Update player position
        playerNode.position.z = playerZPosition
        
        // Determine camera settings based on current road type
        let currentRoadType = roadManager.getCurrentRoadType(atZ: playerZPosition)
        let isInTunnel = currentRoadType == .tunnel
        
        // Target camera settings (tunnel or normal)
        let targetCameraOffsetY = isInTunnel ? cameraOffsetYInTunnel : cameraOffsetY
        let targetCameraOffsetZ = isInTunnel ? cameraOffsetZInTunnel : cameraOffsetZ
        let targetCameraTiltXDegrees = isInTunnel ? cameraTiltXDegreesinTunnel : cameraTiltXDegrees
        
        // Smooth camera transition (lerp between current and target)
        let cameraTransitionSpeed: Float = 0.05 // Lower = smoother, higher = faster transition
        
        // Smoothly interpolate camera values
        currentCameraOffsetY += (targetCameraOffsetY - currentCameraOffsetY) * cameraTransitionSpeed
        currentCameraOffsetZ += (targetCameraOffsetZ - currentCameraOffsetZ) * cameraTransitionSpeed
        currentCameraTiltXDegrees += (targetCameraTiltXDegrees - currentCameraTiltXDegrees) * cameraTransitionSpeed
        
        // Update camera to follow player using interpolated values
        cameraNode.position = SCNVector3(
            x: cameraOffsetX + (playerNode.position.x * cameraFollowPlayerX),
            y: currentCameraOffsetY,
            z: playerZPosition + currentCameraOffsetZ
        )
        
        // Update camera rotation with smoothly interpolated tilt
        let interpolatedTiltX = currentCameraTiltXDegrees * .pi / 180
        cameraNode.eulerAngles = SCNVector3(x: interpolatedTiltX, y: cameraTiltY, z: cameraTiltZ)
        
        // Update field of view if changed
        cameraNode.camera?.fieldOfView = cameraFieldOfView
        
        // Update planet position and scale if variables changed
        updatePlanetTransform()
        
        // Update road manager
        roadManager.update(playerZ: playerZPosition)
        
        // Update obstacle curves to match road curves
        updateObstacleCurves(playerZ: playerZPosition)
        
        // Check for collisions with obstacles
        if collisionEnabled {
            checkObstacleCollisions(currentTime: Float(time))
        }
        
        // Update bounding box visualization if enabled
        if showBoundingBoxes {
            updateBoundingBoxVisualization()
        }
        
        // Cleanup old obstacles
        cleanupOldObstacles()
    }
    
    // MARK: - Planet Update
    private var lastPlanetAnimationSpeed: Float = 1.0  // Track speed changes
    
    func updatePlanetTransform() {
        guard let planetNode = planetNode else { return }
        
        // Update position - planet follows player in Z direction (stays at constant distance)
        // X and Y are absolute, Z is relative to player position
        planetNode.position = SCNVector3(
            x: planetXAxisPos,
            y: planetYAxisPos,
            z: playerZPosition + planetZAxisPos  // Moves with player in Z
        )
        planetNode.scale = SCNVector3(planetSize, planetSize, planetSize)
        
        // Update animation speed if it changed
        if planetAnimationSpeed != lastPlanetAnimationSpeed {
            updatePlanetAnimationSpeed()
            lastPlanetAnimationSpeed = planetAnimationSpeed
        }
    }
    
    func updatePlanetAnimationSpeed() {
        guard let planetNode = planetNode else { return }
        
        // Remove existing rotation action and recreate with new speed
        planetNode.removeAction(forKey: "planetRotation")
        
        let rotationDuration = 5.0 / Double(planetAnimationSpeed)
        let rotation = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: rotationDuration)
        let repeatRotation = SCNAction.repeatForever(rotation)
        planetNode.runAction(repeatRotation, forKey: "planetRotation")
        
        // Also update CAAnimation speed for all children
        updateAnimationSpeedRecursively(for: planetNode)
        
        print("🎬 Updated planet animation speed to \(planetAnimationSpeed)x")
    }
    
    func updateAnimationSpeedRecursively(for node: SCNNode) {
        // Update speed for all animations on this node
        for key in node.animationKeys {
            if let animationPlayer = node.animationPlayer(forKey: key) {
                animationPlayer.speed = CGFloat(planetAnimationSpeed)
            }
        }
        
        // Recursively update children
        for child in node.childNodes {
            updateAnimationSpeedRecursively(for: child)
        }
    }
}

// MARK: - SCNSceneRendererDelegate
extension GameViewController: SCNSceneRendererDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        // Calculate delta time
        struct Holder {
            static var lastTime: TimeInterval = 0
        }
        
        let deltaTime = Holder.lastTime == 0 ? 0 : time - Holder.lastTime
        Holder.lastTime = time
        
        // Cap delta time to prevent huge jumps
        let cappedDelta = min(deltaTime, 1.0 / 30.0)
        
        DispatchQueue.main.async { [weak self] in
            self?.gameTime = time  // Store current time for drone system
            self?.updateGame(deltaTime: cappedDelta, currentTime: time)
            // self?.updateDroneSystem(currentTime: time)  // Drone disabled
        }
    }
}
