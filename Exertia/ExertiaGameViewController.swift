//
//  ExertiaGameViewController.swift
//  VisionExample
//
//  SceneKit-based endless runner game - complete replica of GameViewControllerReference
//  Designed to be controlled by ML pose detection
//

import UIKit
import SceneKit
import SwiftUI

class ExertiaGameViewController: UIViewController, RoadManagerDelegate {
    
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
    let baseSpeed: Float = 30.0
    var gameSpeed: Float = 30.0
    
    // Player settings
    var currentLane: Int = 1 // 0 = left, 1 = center, 2 = right
    let laneWidth: Float = 3.5
    var isJumping: Bool = false
    var isDiving: Bool = false
    var isMovingForward: Bool = false
    var isMovingBackward: Bool = false
    
    // Jump control settings
    var jumpHeight: Float = 8.0
    var jumpUpDuration: Float = 0.6
    var jumpDownDuration: Float = 0.6
    var jumpForwardBoost: Float = 10.0
    var jumpForwardBoostDuration: Float = 0.40  // Time to apply forward boost smoothly (seconds)
    
    // Dive/Slide control settings
    var diveSquashScale: Float = 0.3
    var diveSquashDuration: Float = 0.1
    var diveHoldDuration: Float = 0.9
    var diveRestoreDuration: Float = 0.1
    
    // MARK: - Speed Bar System
    var baseMovementSpeed: Float = 2.5  // Minimum speed even when not running
    var speedTier1: Float = 15.0
    var speedTier2: Float = 21.0
    var speedTier3: Float = 27.0
    
    var tier1FillTime: Float = 3.0
    var tier2FillTime: Float = 5.0
    var tier3FillTime: Float = 8.0
    
    var tier1DrainTime: Float = 10.0
    var tier2DrainTime: Float = 8.0
    var tier3DrainTime: Float = 6.0
    
    var speedBarFill: Float = 0.0

    // MARK: - Session Tracking
    weak var gameDelegate: ExertiaGameDelegate?
    private var sessionStartTime: Date = Date()
    private var totalJumps: Int = 0
    private var totalCrouches: Int = 0
    private var totalLeftLeans: Int = 0
    private var totalRightLeans: Int = 0
    private var totalDistanceCovered: Float = 0.0
    private let sceneKitUnitsToMeters: Float = 0.1
    private var endGameButton: UIButton?

    // MARK: - Pause State
    var isPaused: Bool = false
    private var pauseMenuHostingController: UIViewController?
    private var summaryHostingController: UIViewController?

    // Smooth movement interpolation
    private var currentSpeed: Float = 0.0  // Actual interpolated speed
    private var targetSpeed: Float = 0.0   // Target speed from speed bar
    var speedAcceleration: Float = 25.0    // How fast we accelerate
    var speedDeceleration: Float = 35.0    // How fast we decelerate (slightly faster for responsive stop)
    
    // Smooth lane change
    private var targetLaneX: Float = 0.0
    private var currentLaneX: Float = 0.0
    var laneChangeSmoothness: Float = 12.0  // Higher = faster lane change
    
    // Speed bar UI
    var speedBarContainerView: UIView?
    var speedBarTier1View: UIView?
    var speedBarTier2View: UIView?
    var speedBarTier3View: UIView?
    var speedBarTier1Fill: UIView?
    var speedBarTier2Fill: UIView?
    var speedBarTier3Fill: UIView?
    var speedBarLabel: UILabel?
    
    var speedBarHeight: CGFloat = 22.0
    var speedBarBottomMargin: CGFloat = 40.0
    var speedBarSideMargin: CGFloat = 40.0
    var speedBarCornerRadius: CGFloat = 6.0
    
    // MARK: - Collision Detection System
    var collisionEnabled: Bool = true
    var hitSpeedPenalty: Float = 0.8
    var hitCooldownTime: Float = 1.5
    var lastHitTime: Float = -999.0
    
    var jumpOverCubesEnabled: Bool = true
    var jumpOverCuboidsEnabled: Bool = false
    var jumpOverHoverEnabled: Bool = false
    var safeDistanceOut: Float = 12.0
    var safeDistanceIn: Float = 3.0
    
    // Player bounding box
    var playerBBoxWidth: Float = 1.4
    var playerBBoxHeight: Float = 2.8
    var playerBBoxDepth: Float = 1.4
    var playerBBoxOffsetY: Float = 4.0
    
    // Obstacle bounding boxes
    var cubeBBoxWidth: Float = 3.2
    var cubeBBoxHeight: Float = 6.2
    var cubeBBoxDepth: Float = 6.5
    var cubeBBoxOffsetX: Float = 0.0
    var cubeBBoxOffsetY: Float = 0.0
    var cubeBBoxOffsetZ: Float = 0.0
    
    var cuboidBBoxWidth: Float = 4.8
    var cuboidBBoxHeight: Float = 8.8
    var cuboidBBoxDepth: Float = 7.8
    var cuboidBBoxOffsetX: Float = 0.0
    var cuboidBBoxOffsetY: Float = -1.0
    var cuboidBBoxOffsetZ: Float = 0.0
    
    var hoverBBoxWidth: Float = 19.0
    var hoverBBoxHeight: Float = 2.9
    var hoverBBoxDepth: Float = 14.5
    var hoverBBoxOffsetX: Float = 0.0
    var hoverBBoxOffsetY: Float = 0.0
    var hoverBBoxOffsetZ: Float = 0.0
    
    var hitFlashDuration: Float = 0.2
    var hitFlashView: UIView?
    var hitShakeAmount: Float = 0.1
    
    // MARK: - Loading Screen
    private var loadingOverlay: UIView?
    private var loadingProgressBar: UIView?
    private var loadingProgressFill: UIView?
    private var loadingStatusLabel: UILabel?
    private var loadingTitleLabel: UILabel?
    private var loadingProgress: Float = 0.0
    
    // Player Y position offsets for each road type
    var playerYOffsetOnSimple: Float = -0.8
    var playerYOffsetOnTunnel: Float = 0.2
    var playerYOffsetOnPlatform: Float = 1.35
    
    // Camera control settings
    var cameraOffsetX: Float = 0.0
    var cameraOffsetY: Float = 12.0
    var cameraOffsetZ: Float = 15.0
    var cameraFollowPlayerX: Float = 0.5
    var cameraTiltXDegrees: Float = -23.7
    var cameraTiltYDegrees: Float = 0.0
    var cameraTiltZDegrees: Float = 0.0
    var cameraFieldOfView: CGFloat = 65.0
    var cameraTiltXDegreesinTunnel: Float = -18.7
    var cameraOffsetYInTunnel: Float = 7.0
    var cameraOffsetZInTunnel: Float = 12.0
    
    var cameraTiltX: Float { cameraTiltXDegrees * .pi / 180 }
    var cameraTiltY: Float { cameraTiltYDegrees * .pi / 180 }
    var cameraTiltZ: Float { cameraTiltZDegrees * .pi / 180 }
    
    private var currentCameraOffsetY: Float = 12.0
    private var currentCameraOffsetZ: Float = 15.0
    private var currentCameraTiltXDegrees: Float = -23.7
    
    // MARK: - Curve Settings
    var curveEnabled: Bool = true
    var curveStrength: Float = -0.0018
    var curveHorizontalStrength: Float = 0.001
    var curveRotationStrength: Float = 0.001
    var curveStartDistance: Float = 65.0
    
    // MARK: - Planet Settings
    var planetNode: SCNNode?
    var planetXAxisPos: Float = -100.0
    var planetYAxisPos: Float = 200.0
    var planetZAxisPos: Float = -800.0
    var planetSize: Float = 4.0
    var planetAnimationSpeed: Float = 0.03
    
    // MARK: - Night Sky Settings
    var starParticleNode: SCNNode?
    var starCount: CGFloat = 500
    var starSize: CGFloat = 1.0
    var starTwinkleSpeed: CGFloat = 1.0
    var starBrightness: CGFloat = 1.0
    var skyTopColor: UIColor = UIColor(red: 0.0, green: 0.0, blue: 0.05, alpha: 1.0)
    var skyBottomColor: UIColor = UIColor(red: 0.02, green: 0.02, blue: 0.15, alpha: 1.0)
    
    // MARK: - Obstacle System
    var obstaclesTemplate: SCNNode?
    var activeObstacles: [SCNNode] = []
    var obstacleDataMap: [SCNNode: ObstacleData] = [:]
    var clearedObstacles: Set<ObjectIdentifier> = []
    
    struct ObstacleData {
        let baseX: Float
        let baseY: Float
        let baseZ: Float
        let roadBaseY: Float
        let obstacleType: String
    }
    
    var obstacleSpawnEveryXSegments: Int = 6
    var obstacleMinDistanceBetween: Float = 20.0
    var lastObstacleZ: Float = -40.0
    var obstacleSegmentCounter: Int = 0
    
    var cubeYOffset: Float = 3.8
    var cuboidYOffset: Float = 6.0
    var hoverPlatformYOffset: Float = 6.0
    
    // MARK: - Pattern X Offset Controls
    var p1_cubeLeftX: Float = -2.65
    var p1_cubeCenterX: Float = 1
    var p1_cubeRightX: Float = 4.2
    
    var p2_cuboidLeftX: Float = -3.5
    var p2_cuboidCenterX: Float = 0.0
    
    var p3_cuboidCenterX: Float = 0.0
    var p3_cuboidRightX: Float = 3.8
    
    var p4_cuboidLeftX: Float = -3.5
    var p4_cuboidRightX: Float = 3.8
    
    var p5_cuboidLeftX: Float = -3.5
    var p5_cuboidCenterX: Float = 0.2
    var p5_cubeRightX: Float = 4.2
    
    var p6_cubeLeftX: Float = -2.65
    var p6_cuboidCenterX: Float = 0.2
    var p6_cuboidRightX: Float = 3.8
    
    var p7_cuboidLeftX: Float = -3.5
    var p7_cubeCenterX: Float = 1
    var p7_cuboidRightX: Float = 3.8
    
    var p8_hoverX: Float = 0.0
    
    var p9_cubeCenterX: Float = 1
    
    var p10_cuboidLeftX: Float = -3.5
    var p10_cubeCenterX: Float = 1
    var p10_cubeRightX: Float = 4.2
    
    var p11_cubeLeftX: Float = -2.65
    var p11_cubeRightX: Float = 4.2
    
    var p12_hoverX: Float = 0.0
    var p12_cubeCenterX: Float = 1
    
    // Pattern enable/disable
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
    var cubeSizeX: Float = 3.5
    var cubeSizeY: Float = 3.5
    var cubeSizeZ: Float = 6.8
    var cuboidSizeX: Float = 7.0
    var cuboidSizeY: Float = 7.0
    var cuboidSizeZ: Float = 8.0
    var hoverPlatformSizeX: Float = 20.0
    var hoverPlatformSizeY: Float = 5
    var hoverPlatformSizeZ: Float = 15.0
    
    // Obstacle Rotation Control
    var cubeRotationX: Float = 0
    var cubeRotationY: Float = 0.0
    var cubeRotationZ: Float = 0.0
    var cuboidRotationX: Float = 0.0
    var cuboidRotationY: Float = 0.0
    var cuboidRotationZ: Float = 0.0
    var hoverPlatformRotationX: Float = 0.0
    var hoverPlatformRotationY: Float = 0
    var hoverPlatformRotationZ: Float = 0
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        currentCameraOffsetY = cameraOffsetY
        currentCameraOffsetZ = cameraOffsetZ
        currentCameraTiltXDegrees = cameraTiltXDegrees
        
        // Step 1: Set up the scene view and loading screen immediately
        setupScene()
        setupLoadingScreen()
        
        // Step 2: Load all assets in background, then start game
        loadAllAssetsAsync()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    // MARK: - Setup Methods
    func setupScene() {
        sceneView = SCNView(frame: view.bounds)
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(sceneView)
        
        scene = SCNScene()
        scene.background.contents = createGradientImage()
        sceneView.scene = scene
        
        sceneView.allowsCameraControl = false
        sceneView.showsStatistics = false
        sceneView.backgroundColor = UIColor.black
        sceneView.antialiasingMode = .multisampling2X
        sceneView.preferredFramesPerSecond = 60
    }
    
    // MARK: - Loading Screen
    
    private func setupLoadingScreen() {
        let overlay = UIView(frame: view.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = UIColor(red: 0.02, green: 0.02, blue: 0.06, alpha: 1.0)
        view.addSubview(overlay)
        loadingOverlay = overlay
        
        // Grid pattern (subtle)
        let gridLayer = CAShapeLayer()
        let gridPath = UIBezierPath()
        let spacing: CGFloat = 40
        var x: CGFloat = 0
        while x < view.bounds.width {
            gridPath.move(to: CGPoint(x: x, y: 0))
            gridPath.addLine(to: CGPoint(x: x, y: view.bounds.height))
            x += spacing
        }
        var y: CGFloat = 0
        while y < view.bounds.height {
            gridPath.move(to: CGPoint(x: 0, y: y))
            gridPath.addLine(to: CGPoint(x: view.bounds.width, y: y))
            y += spacing
        }
        gridLayer.path = gridPath.cgPath
        gridLayer.strokeColor = UIColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 0.04).cgColor
        gridLayer.lineWidth = 0.5
        overlay.layer.addSublayer(gridLayer)
        
        // Title
        let title = UILabel()
        title.text = "LOADING SYSTEMS"
        title.font = UIFont.monospacedSystemFont(ofSize: 22, weight: .bold)
        title.textColor = UIColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 1.0)
        title.textAlignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(title)
        loadingTitleLabel = title
        
        // Status label
        let status = UILabel()
        status.text = "Initializing..."
        status.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        status.textColor = UIColor.white.withAlphaComponent(0.5)
        status.textAlignment = .center
        status.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(status)
        loadingStatusLabel = status
        
        // Progress bar container
        let barWidth: CGFloat = view.bounds.width - 80
        let barHeight: CGFloat = 4
        
        let progressContainer = UIView()
        progressContainer.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        progressContainer.layer.cornerRadius = barHeight / 2
        progressContainer.clipsToBounds = true
        progressContainer.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(progressContainer)
        loadingProgressBar = progressContainer
        
        // Progress fill
        let progressFill = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: barHeight))
        progressFill.backgroundColor = UIColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 0.9)
        progressFill.layer.cornerRadius = barHeight / 2
        progressContainer.addSubview(progressFill)
        loadingProgressFill = progressFill
        
        // Glow effect on fill
        progressFill.layer.shadowColor = UIColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 1.0).cgColor
        progressFill.layer.shadowRadius = 6
        progressFill.layer.shadowOpacity = 0.8
        progressFill.layer.shadowOffset = .zero
        progressFill.clipsToBounds = false
        
        // Layout
        NSLayoutConstraint.activate([
            title.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            title.centerYAnchor.constraint(equalTo: overlay.centerYAnchor, constant: -40),
            
            progressContainer.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            progressContainer.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 24),
            progressContainer.widthAnchor.constraint(equalToConstant: barWidth),
            progressContainer.heightAnchor.constraint(equalToConstant: barHeight),
            
            status.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            status.topAnchor.constraint(equalTo: progressContainer.bottomAnchor, constant: 16),
        ])
    }
    
    private func updateLoadingProgress(_ progress: Float, status: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let bar = self.loadingProgressBar, let fill = self.loadingProgressFill else { return }
            self.loadingProgress = progress
            self.loadingStatusLabel?.text = status
            
            let barWidth = bar.bounds.width
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
                fill.frame = CGRect(x: 0, y: 0, width: barWidth * CGFloat(progress), height: bar.bounds.height)
            }
        }
    }
    
    private func dismissLoadingScreen() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let overlay = self.loadingOverlay else { return }
            
            // Final progress
            self.updateLoadingProgress(1.0, status: "READY")
            
            // Fade out after a short beat
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseIn, animations: {
                    overlay.alpha = 0
                }) { _ in
                    overlay.removeFromSuperview()
                    self.loadingOverlay = nil
                }
            }
        }
    }
    
    // MARK: - Async Asset Loading
    
    private func loadAllAssetsAsync() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Step 1: Camera & Lighting (fast, but must be on main thread for scene graph)
            self.updateLoadingProgress(0.05, status: "Initializing renderer...")
            DispatchQueue.main.sync {
                self.setupCamera()
                self.setupLighting()
            }
            
            // Step 2: Night sky (moderate - creates many star nodes)
            self.updateLoadingProgress(0.15, status: "Generating star field...")
            DispatchQueue.main.sync {
                self.setupNightSky()
            }
            
            // Step 3: Player
            self.updateLoadingProgress(0.25, status: "Loading player...")
            DispatchQueue.main.sync {
                self.setupPlayer()
            }
            
            // Step 4: Planet (USDZ load)
            self.updateLoadingProgress(0.35, status: "Loading planet assets...")
            DispatchQueue.main.sync {
                self.setupPlanet()
            }
            
            // Step 5: Obstacle system (USDZ load)
            self.updateLoadingProgress(0.45, status: "Loading obstacle assets...")
            DispatchQueue.main.sync {
                self.setupObstacleSystem()
            }
            
            // Step 6: Road manager (USDZ loads + template caching)
            self.updateLoadingProgress(0.55, status: "Loading road segments...")
            DispatchQueue.main.sync {
                self.setupRoadManager()
            }
            
            // Step 7: GPU warm-up — preload obstacle clones into the scene
            self.updateLoadingProgress(0.70, status: "Uploading textures to GPU...")
            DispatchQueue.main.sync {
                self.preloadAllObstacleTypes()
            }
            
            // Step 8: Use SCNScene.prepare() to force GPU compilation of all shaders/textures
            self.updateLoadingProgress(0.80, status: "Compiling shaders...")
            let nodesToPrepare = self.collectAllPreparableNodes()
            self.sceneView.prepare(nodesToPrepare, completionHandler: { success in
                // Step 9: Final UI setup (must be on main)
                self.updateLoadingProgress(0.92, status: "Setting up HUD...")
                DispatchQueue.main.async {
                    self.setupSpeedBar()
                    self.setupHitFlashOverlay()
                    self.setupEndGameButton()

                    // Step 10: Start game & dismiss loading
                    self.startGame()
                    self.dismissLoadingScreen()
                }
            })
        }
    }
    
    /// Clone each obstacle type and briefly add to scene to force GPU upload
    private func preloadAllObstacleTypes() {
        guard let template = obstaclesTemplate else { return }
        
        let obstacleNames = ["cube_obstacle", "cuboid_obstacle", "dive_obstacle"]
        var warmupNodes: [SCNNode] = []
        
        for name in obstacleNames {
            guard let obstacleTemplate = template.childNode(withName: name, recursively: true) else { continue }
            
            // Clone with all geometry/materials
            let clone = obstacleTemplate.clone()
            clone.position = SCNVector3(0, -200, -2000) // Far offscreen
            scene.rootNode.addChildNode(clone)
            warmupNodes.append(clone)
        }
        
        // Also warm up the planet if loaded
        if let planet = planetNode?.clone() {
            planet.position = SCNVector3(0, -200, -2000)
            scene.rootNode.addChildNode(planet)
            warmupNodes.append(planet)
        }
        
        // Remove after a brief moment to let SceneKit upload to GPU
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            for node in warmupNodes {
                node.removeFromParentNode()
            }
        }
    }
    
    /// Collect all significant nodes for SCNScene.prepare() to compile shaders ahead of time
    private func collectAllPreparableNodes() -> [SCNNode] {
        var nodes: [SCNNode] = []
        
        // Player
        if let player = playerNode {
            nodes.append(player)
        }
        
        // Planet
        if let planet = planetNode {
            nodes.append(planet)
        }
        
        // Obstacle templates
        if let template = obstaclesTemplate {
            let obstacleNames = ["cube_obstacle", "cuboid_obstacle", "dive_obstacle"]
            for name in obstacleNames {
                if let node = template.childNode(withName: name, recursively: true) {
                    nodes.append(node)
                }
            }
        }
        
        // All road nodes currently in scene (from generateInitialRoads + preloadAllRoadTypes)
        for child in scene.rootNode.childNodes {
            if let name = child.name, (name.contains("road_simple") || name.contains("road_tunnel") || name.contains("road_with_platform")) {
                nodes.append(child)
            }
        }
        
        // Stars
        if let stars = starParticleNode {
            nodes.append(stars)
        }
        
        return nodes
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
        starParticleNode = SCNNode()
        starParticleNode?.name = "StarField"
        
        let numberOfStars = min(Int(starCount), 200)
        
        for i in 0..<numberOfStars {
            let radius: Float = 250.0 + Float.random(in: 0...100)
            let theta = Float.random(in: 0...(2 * Float.pi))
            let phi = Float.random(in: 0...Float.pi)
            let adjustedPhi = phi * 0.6
            
            let x = radius * sin(adjustedPhi) * cos(theta)
            let y = abs(radius * cos(adjustedPhi)) + 50
            let z = radius * sin(adjustedPhi) * sin(theta)
            
            let starGeometry = SCNPlane(width: CGFloat(starSize), height: CGFloat(starSize))
            let starMaterial = SCNMaterial()
            starMaterial.diffuse.contents = UIColor.white
            starMaterial.emission.contents = UIColor.white
            starMaterial.isDoubleSided = true
            starMaterial.blendMode = .add
            starGeometry.materials = [starMaterial]
            
            let starNode = SCNNode(geometry: starGeometry)
            starNode.position = SCNVector3(x, y, z)
            starNode.constraints = [SCNBillboardConstraint()]
            starNode.name = "star_\(i)"
            
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
        
        addFeatureStars()
    }
    
    func addFeatureStars() {
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
            starNode.constraints = [SCNBillboardConstraint()]
            
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
    }
    
    func setupCamera() {
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = cameraFieldOfView
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 1000
        cameraNode.camera?.wantsDepthOfField = false
        
        cameraNode.position = SCNVector3(x: cameraOffsetX, y: cameraOffsetY, z: cameraOffsetZ)
        cameraNode.eulerAngles = SCNVector3(x: cameraTiltX, y: cameraTiltY, z: cameraTiltZ)
        
        scene.rootNode.addChildNode(cameraNode)
    }
    
    func setupLighting() {
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 150
        ambientLight.light?.color = UIColor(red: 0.3, green: 0.3, blue: 0.5, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLight)
        
        let moonLight = SCNNode()
        moonLight.light = SCNLight()
        moonLight.light?.type = .directional
        moonLight.light?.intensity = 600
        moonLight.light?.color = UIColor(red: 0.7, green: 0.8, blue: 1.0, alpha: 1.0)
        moonLight.light?.castsShadow = true
        moonLight.light?.shadowMode = .deferred
        moonLight.light?.shadowColor = UIColor.black.withAlphaComponent(0.6)
        moonLight.light?.shadowRadius = 3.0
        moonLight.light?.shadowMapSize = CGSize(width: 2048, height: 2048)
        moonLight.light?.automaticallyAdjustsShadowProjection = true
        moonLight.eulerAngles = SCNVector3(x: -Float.pi / 3, y: Float.pi / 6, z: 0)
        scene.rootNode.addChildNode(moonLight)
        
        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .directional
        fillLight.light?.intensity = 150
        fillLight.light?.color = UIColor(red: 0.6, green: 0.7, blue: 0.9, alpha: 1.0)
        fillLight.eulerAngles = SCNVector3(x: Float.pi / 6, y: 0, z: 0)
        scene.rootNode.addChildNode(fillLight)
    }
    
    func setupPlayer() {
        playerNode = SCNNode()
        playerNode.name = "Player"
        
        // Load the character model directly from the SceneKit catalog
        // SceneKit can load .dae files perfectly! But sometimes Xcode compiles them into .scn files
        var characterScene = SCNScene(named: "Character.scnassets/Idle.dae")
        if characterScene == nil {
            print("❌ GameViewController: Failed to find Idle.dae, trying Idle.scn instead...")
            characterScene = SCNScene(named: "Character.scnassets/Idle.scn")
        }
        
        if let characterScene = characterScene {
            print("✅ GameViewController: Successfully loaded the 3D Character!")
            
            let characterContainerNode = SCNNode()
            characterContainerNode.name = "CharacterContainer"
            
            // Add all nodes from the parsed DAE file to a container node WITHOUT cloning!
            // Cloning a skinned mesh in SceneKit breaks the skeleton and leaves the skin behind at the start line.
            for child in characterScene.rootNode.childNodes {
                characterContainerNode.addChildNode(child)
            }
            
            // We removed the custom character light because the global moonLight & fillLight in setupLighting() are enough.
            
            // Adjust character positioning and scale
            // If the head is barely poking out, the model's origin is likely at its center of mass, not its feet.
            characterContainerNode.position.y = 2.8 // Lifted out of the track!
            
            // Mixamo & Blender exports use centimeters, SceneKit uses meters. We must shrink it 100x!
            characterContainerNode.scale = SCNVector3(x: 0.01, y: 0.01, z: 0.01)
            
            // In SceneKit, imported characters often face the screen. Rotate them 180 degrees to face forward!
            characterContainerNode.eulerAngles = SCNVector3(x: 0, y: Float.pi, z: 0)
            
            // Critical Fix: Strip ALL default animations (like the Idle loop) from the DAE
            // If we don't do this, SceneKit will mathematically blend your Idle and Running animations
            // together at the same time, causing the character's limbs to twist and move weirdly!
            characterContainerNode.removeAllAnimations()
            
            // Critical Fix: Force-stop any embedded animations recursively. Mixamo adds T-Pose and Idle tracks everywhere.
            characterContainerNode.enumerateChildNodes { (node, _) in
                node.castsShadow = true
                for key in node.animationKeys {
                    node.removeAnimation(forKey: key, blendOutDuration: 0.0)
                }
                node.removeAllAnimations()
                
                // DAE exports from Blender lose their PBR/Metallic nodes. Let's restore them!
                if let materials = node.geometry?.materials {
                    for material in materials {
                        material.lightingModel = .physicallyBased
                        material.metalness.contents = 0.8 // High metal finish
                        material.roughness.contents = 0.2 // Smooth reflection
                        material.isDoubleSided = true
                    }
                }
            }
                   // Map missing bone animations perfectly
            applyBoneAnimations(fromFile: "Character.scnassets/Running-2.dae", toNode: characterContainerNode, animKey: "run", repeats: true)
            applyBoneAnimations(fromFile: "Character.scnassets/Jumping-2.dae", toNode: characterContainerNode, animKey: "jump", repeats: false)
            applyBoneAnimations(fromFile: "Character.scnassets/Stand To Roll.dae", toNode: characterContainerNode, animKey: "roll", repeats: false)
            
            // Start running immediately!
            playBoneAnimation(key: "run", onNode: characterContainerNode)
            
            playerNode.addChildNode(characterContainerNode)
        } else {
            print("⚠️ GameViewController: CRITICAL WARNING - Could not find the 3D Character in Character.scnassets. Falling back to the blue capsule.")
            // Fallback capsule if the DAE file is missing/fails to load
            let capsule = SCNCapsule(capRadius: 0.8, height: 3.0)
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.systemBlue
            material.specular.contents = UIColor.white
            material.shininess = 0.7
            material.reflective.contents = UIColor(white: 0.3, alpha: 1.0)
            capsule.materials = [material]
            
            let capsuleNode = SCNNode(geometry: capsule)
            capsuleNode.position.y = 4.0
            capsuleNode.castsShadow = true
            playerNode.addChildNode(capsuleNode)
        }
        
        playerNode.position = SCNVector3(x: 0, y: 0, z: 0)
        scene.rootNode.addChildNode(playerNode)
    }
    
    // MARK: - Animation System
    func applyBoneAnimations(fromFile fileName: String, toNode rootNode: SCNNode, animKey: String, repeats: Bool) {
        let scnName = fileName.replacingOccurrences(of: ".dae", with: ".scn")
        guard let animScene = SCNScene(named: fileName) ?? SCNScene(named: scnName) else { 
            print("❌ Failed to load animation scene: \(fileName)")
            return 
        }
        
        animScene.rootNode.enumerateChildNodes { srcNode, _ in
            if let boneName = srcNode.name, !srcNode.animationKeys.isEmpty {
                if let targetBone = rootNode.childNode(withName: boneName, recursively: true) {
                    for key in srcNode.animationKeys {
                        if let player = srcNode.animationPlayer(forKey: key) {
                            // Adjust blending and speed for maximum snappiness
                            if animKey == "roll" {
                                player.animation.blendInDuration = 0.05 // extremely fast transition
                                player.animation.blendOutDuration = 0.2
                                player.speed = 1.35 // 35% faster animation playback
                            } else if animKey == "jump" {
                                player.animation.blendInDuration = 0.1
                                player.animation.blendOutDuration = 0.2
                                player.speed = 1.1 
                            } else {
                                player.animation.blendInDuration = 0.2
                                player.animation.blendOutDuration = 0.2
                                player.speed = 1.0
                            }
                            
                            if repeats {
                                player.animation.repeatCount = .greatestFiniteMagnitude
                            } else {
                                player.animation.repeatCount = 1
                                player.animation.isRemovedOnCompletion = false
                            }
                            targetBone.addAnimationPlayer(player, forKey: animKey)
                            player.stop() // loaded but halted
                        }
                    }
                }
            }
        }
    }
    
    func playBoneAnimation(key: String, onNode rootNode: SCNNode) {
        let allKeys = ["run", "jump", "roll"]
        rootNode.enumerateChildNodes { node, _ in
            for k in allKeys {
                if let player = node.animationPlayer(forKey: k) {
                    if k == key {
                        player.play()
                    } else {
                        player.stop(withBlendOutDuration: 0.2)
                    }
                }
            }
        }
    }
    
    func setupRoadManager() {
        roadManager = RoadManager(scene: scene)
        roadManager.delegate = self
        roadManager.roadWidth = 20.0
        roadManager.loadRoadTemplates()
        
        roadManager.roadSimpleYPosition = 0.0
        roadManager.roadTunnelYPosition = -0.5
        roadManager.roadPlatformYPosition = -1.48
        
        roadManager.curveEnabled = curveEnabled
        roadManager.curveStrength = curveStrength
        roadManager.curveHorizontalStrength = curveHorizontalStrength
        roadManager.curveRotationStrength = curveRotationStrength
        roadManager.curveStartDistance = curveStartDistance
        
        roadManager.preloadAllRoadTypes()
        roadManager.generateInitialRoads()
    }
    
    func setupPlanet() {
        let possiblePaths = [
            "GameAssets/Stylized_planet",
            "Stylized_planet",
        ]
        
        for path in possiblePaths {
            if let url = Bundle.main.url(forResource: path, withExtension: "usdz") {
                do {
                    let planetScene = try SCNScene(url: url, options: [.convertToYUp: true])
                    
                    planetNode = SCNNode()
                    planetNode?.name = "StylizedPlanet"
                    
                    for child in planetScene.rootNode.childNodes {
                        planetNode?.addChildNode(child.clone())
                    }
                    
                    planetNode?.position = SCNVector3(x: planetXAxisPos, y: planetYAxisPos, z: planetZAxisPos)
                    planetNode?.scale = SCNVector3(planetSize, planetSize, planetSize)
                    
                    scene.rootNode.addChildNode(planetNode!)
                    playPlanetAnimations()
                    
                    print("✅ Loaded stylized planet")
                    return
                } catch {
                    print("❌ Error loading planet: \(error)")
                }
            }
        }
        
        createPlaceholderPlanet()
    }
    
    func createPlaceholderPlanet() {
        planetNode = SCNNode()
        planetNode?.name = "PlaceholderPlanet"
        
        let sphere = SCNSphere(radius: 1.0)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.orange
        material.emission.contents = UIColor.orange.withAlphaComponent(0.3)
        material.specular.contents = UIColor.white
        sphere.materials = [material]
        
        let sphereNode = SCNNode(geometry: sphere)
        planetNode?.addChildNode(sphereNode)
        
        planetNode?.position = SCNVector3(x: planetXAxisPos, y: planetYAxisPos, z: planetZAxisPos)
        planetNode?.scale = SCNVector3(planetSize, planetSize, planetSize)
        
        let rotationDuration = 5.0 / Double(planetAnimationSpeed)
        let rotation = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: rotationDuration)
        planetNode?.runAction(SCNAction.repeatForever(rotation), forKey: "planetRotation")
        
        scene.rootNode.addChildNode(planetNode!)
    }
    
    func playPlanetAnimations() {
        guard let planetNode = planetNode else { return }
        
        let rotationDuration = 20.0 / Double(planetAnimationSpeed)
        let rotation = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: rotationDuration)
        planetNode.runAction(SCNAction.repeatForever(rotation), forKey: "planetRotation")
    }
    
    // MARK: - Obstacle System
    func setupObstacleSystem() {
        loadObstaclesTemplate()
        print("🚧 Obstacle system initialized")
    }
    
    func loadObstaclesTemplate() {
        let possiblePaths = ["GameAssets/Obstacles", "Obstacles"]
        
        for path in possiblePaths {
            if let url = Bundle.main.url(forResource: path, withExtension: "usdz") {
                do {
                    let obstaclesScene = try SCNScene(url: url, options: [.convertToYUp: true])
                    obstaclesTemplate = obstaclesScene.rootNode
                    
                    print("✅ Obstacles template loaded")
                    printNodeHierarchy(obstaclesTemplate!, indent: "  ")
                    return
                } catch {
                    print("❌ Failed to load Obstacles.usdz: \(error)")
                }
            }
        }
        print("⚠️ Obstacles template not found")
    }
    
    private func printNodeHierarchy(_ node: SCNNode, indent: String) {
        let name = node.name ?? "(unnamed)"
        print("\(indent)- \(name)")
        for child in node.childNodes {
            printNodeHierarchy(child, indent: indent + "  ")
        }
    }
    
    // MARK: - RoadManagerDelegate
    func roadManager(_ manager: RoadManager, didSpawnRoad roadSegment: RoadSegment) {
        guard roadSegment.node.name?.contains("road_simple") == true else { return }
        
        obstacleSegmentCounter += 1
        
        if obstacleSegmentCounter >= obstacleSpawnEveryXSegments {
            obstacleSegmentCounter = 0
            spawnObstacleOnRoad(roadSegment)
        }
    }
    
    func spawnObstacleOnRoad(_ roadSegment: RoadSegment) {
        guard obstaclesTemplate != nil else { return }
        
        let roadZ = roadSegment.zPosition - roadSegment.length / 2
        
        if abs(roadZ - lastObstacleZ) < obstacleMinDistanceBetween {
            return
        }
        
        let pieces = selectObstaclePattern()
        for piece in pieces {
            spawnSingleObstacle(piece: piece, roadSegment: roadSegment)
        }
        
        lastObstacleZ = roadZ
    }
    
    struct ObstaclePiece {
        let type: String
        let xOffset: Float
    }
    
    func selectObstaclePattern() -> [ObstaclePiece] {
        var allPatterns: [[ObstaclePiece]] = []
        
        // Pattern 1: Three cubes across
        if p1_enabled {
            allPatterns.append([
                ObstaclePiece(type: "cube", xOffset: p1_cubeLeftX),
                ObstaclePiece(type: "cube", xOffset: p1_cubeCenterX),
                ObstaclePiece(type: "cube", xOffset: p1_cubeRightX),
            ])
        }
        
        // Pattern 2: Two cuboids left and center
        if p2_enabled {
            allPatterns.append([
                ObstaclePiece(type: "cuboid", xOffset: p2_cuboidLeftX),
                ObstaclePiece(type: "cuboid", xOffset: p2_cuboidCenterX),
            ])
        }
        
        // Pattern 3: Two cuboids center and right
        if p3_enabled {
            allPatterns.append([
                ObstaclePiece(type: "cuboid", xOffset: p3_cuboidCenterX),
                ObstaclePiece(type: "cuboid", xOffset: p3_cuboidRightX),
            ])
        }
        
        // Pattern 4: Two cuboids left and right
        if p4_enabled {
            allPatterns.append([
                ObstaclePiece(type: "cuboid", xOffset: p4_cuboidLeftX),
                ObstaclePiece(type: "cuboid", xOffset: p4_cuboidRightX),
            ])
        }
        
        // Pattern 5: Two cuboids left/center + cube right
        if p5_enabled {
            allPatterns.append([
                ObstaclePiece(type: "cuboid", xOffset: p5_cuboidLeftX),
                ObstaclePiece(type: "cuboid", xOffset: p5_cuboidCenterX),
                ObstaclePiece(type: "cube", xOffset: p5_cubeRightX),
            ])
        }
        
        // Pattern 6: Cube left + two cuboids center/right
        if p6_enabled {
            allPatterns.append([
                ObstaclePiece(type: "cube", xOffset: p6_cubeLeftX),
                ObstaclePiece(type: "cuboid", xOffset: p6_cuboidCenterX),
                ObstaclePiece(type: "cuboid", xOffset: p6_cuboidRightX),
            ])
        }
        
        // Pattern 7: Cuboid left + cube center + cuboid right
        if p7_enabled {
            allPatterns.append([
                ObstaclePiece(type: "cuboid", xOffset: p7_cuboidLeftX),
                ObstaclePiece(type: "cube", xOffset: p7_cubeCenterX),
                ObstaclePiece(type: "cuboid", xOffset: p7_cuboidRightX),
            ])
        }
        
        // Pattern 8: Single hover platform (dive under)
        if p8_enabled {
            allPatterns.append([
                ObstaclePiece(type: "hover", xOffset: p8_hoverX),
            ])
        }
        
        // Pattern 9: Single cube center
        if p9_enabled {
            allPatterns.append([
                ObstaclePiece(type: "cube", xOffset: p9_cubeCenterX),
            ])
        }
        
        // Pattern 10: Cuboid left + cube center + cube right
        if p10_enabled {
            allPatterns.append([
                ObstaclePiece(type: "cuboid", xOffset: p10_cuboidLeftX),
                ObstaclePiece(type: "cube", xOffset: p10_cubeCenterX),
                ObstaclePiece(type: "cube", xOffset: p10_cubeRightX),
            ])
        }
        
        // Pattern 11: Two cubes left and right
        if p11_enabled {
            allPatterns.append([
                ObstaclePiece(type: "cube", xOffset: p11_cubeLeftX),
                ObstaclePiece(type: "cube", xOffset: p11_cubeRightX),
            ])
        }
        
        // Pattern 12: Hover platform + cube center
        if p12_enabled {
            allPatterns.append([
                ObstaclePiece(type: "hover", xOffset: p12_hoverX),
                ObstaclePiece(type: "cube", xOffset: p12_cubeCenterX),
            ])
        }
        
        return allPatterns.randomElement() ?? [ObstaclePiece(type: "cube", xOffset: 0.0)]
    }
    
    func spawnSingleObstacle(piece: ObstaclePiece, roadSegment: RoadSegment) {
        guard let obstaclesTemplate = obstaclesTemplate else { return }
        
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
        
        let xPos = piece.xOffset
        let obstacleClone = templateNode.clone()
        
        let obstacleNode = SCNNode()
        obstacleClone.scale = scale
        obstacleNode.addChildNode(obstacleClone)
        obstacleNode.eulerAngles = rotation
        
        let roadY = roadSegment.baseYPosition
        let obstacleZ = roadSegment.zPosition - roadSegment.length / 2
        
        obstacleNode.position = SCNVector3(
            x: xPos,
            y: roadY + yOffset,
            z: obstacleZ
        )
        
        obstacleNode.name = "obstacle_\(piece.type)_\(UUID().uuidString)"
        
        let obstacleData = ObstacleData(
            baseX: xPos,
            baseY: roadY + yOffset,
            baseZ: obstacleZ,
            roadBaseY: roadY,
            obstacleType: piece.type
        )
        obstacleDataMap[obstacleNode] = obstacleData
        
        scene.rootNode.addChildNode(obstacleNode)
        activeObstacles.append(obstacleNode)
    }
    
    func updateObstacleCurves(playerZ: Float) {
        guard curveEnabled else { return }
        
        for obstacle in activeObstacles {
            guard let data = obstacleDataMap[obstacle] else { continue }
            
            let distanceFromPlayer = playerZ - data.baseZ
            
            if distanceFromPlayer > curveStartDistance {
                let curveDistance = distanceFromPlayer - curveStartDistance
                
                let curveY = curveStrength * curveDistance * curveDistance
                let curveX = curveHorizontalStrength * curveDistance * curveDistance
                let tiltX = curveRotationStrength * curveDistance
                
                obstacle.position = SCNVector3(
                    x: data.baseX + curveX,
                    y: data.baseY + curveY,
                    z: data.baseZ
                )
                
                obstacle.eulerAngles = SCNVector3(
                    x: tiltX,
                    y: obstacle.eulerAngles.y,
                    z: obstacle.eulerAngles.z
                )
            } else {
                obstacle.position = SCNVector3(x: data.baseX, y: data.baseY, z: data.baseZ)
                obstacle.eulerAngles = SCNVector3(x: 0, y: obstacle.eulerAngles.y, z: obstacle.eulerAngles.z)
            }
        }
    }
    
    func cleanupOldObstacles() {
        let cleanupDistance: Float = 50.0
        
        activeObstacles.removeAll { obstacle in
            let baseZ = obstacleDataMap[obstacle]?.baseZ ?? obstacle.position.z
            let distance = baseZ - playerZPosition
            if distance > cleanupDistance {
                obstacle.removeFromParentNode()
                obstacleDataMap.removeValue(forKey: obstacle)
                clearedObstacles.remove(ObjectIdentifier(obstacle))
                return true
            }
            return false
        }
    }
    
    // MARK: - Public Control Methods (called from ML detectors)
    
    func startMoveForward() {
        isMovingForward = true
        isMovingBackward = false
    }
    
    func stopMoveForward() {
        isMovingForward = false
    }
    
    func movePlayerLeft() {
        guard currentLane > 0 else { return }
        totalLeftLeans += 1
        currentLane -= 1
        animatePlayerToLane()
    }

    func movePlayerRight() {
        guard currentLane < 2 else { return }
        totalRightLeans += 1
        currentLane += 1
        animatePlayerToLane()
    }
    
    func animatePlayerToLane() {
        // Just update target - smooth interpolation happens in updateGame
        targetLaneX = Float(currentLane - 1) * laneWidth
    }
    
    /// Smoothly interpolate lane position
    func updateLanePosition(dt: Float) {
        let diff = targetLaneX - currentLaneX
        
        // If very close, snap to target
        if abs(diff) < 0.01 {
            currentLaneX = targetLaneX
        } else {
            // Smooth exponential interpolation
            currentLaneX += diff * min(1.0, laneChangeSmoothness * dt)
        }
        
        playerNode.position.x = currentLaneX
    }
    
    /// Smoothly interpolate speed for acceleration/deceleration
    func updateSpeedInterpolation(dt: Float) {
        targetSpeed = speedFromBar()
        
        let diff = targetSpeed - currentSpeed
        
        if abs(diff) < 0.1 {
            // Close enough, snap
            currentSpeed = targetSpeed
        } else if diff > 0 {
            // Accelerating
            currentSpeed += speedAcceleration * dt
            currentSpeed = min(currentSpeed, targetSpeed)
        } else {
            // Decelerating
            currentSpeed -= speedDeceleration * dt
            currentSpeed = max(currentSpeed, targetSpeed)
        }
    }
    
    // Jump state tracking
    private var jumpStartY: Float = 0
    private var jumpVelocityY: Float = 0
    private var isJumpingUp: Bool = false
    private var isLanding: Bool = false
    private var jumpForwardBoostRemaining: Float = 0  // Remaining forward boost to apply
    
    func playerJump() {
        guard isGameRunning, !isJumping else { return }
        isJumping = true
        isJumpingUp = true
        isLanding = false
        
        // Play jump animation and blend out the running loop
        if let characterNode = playerNode.childNode(withName: "CharacterContainer", recursively: true) {
            playBoneAnimation(key: "jump", onNode: characterNode)
        }
        
        // Record the ground level at jump start
        jumpStartY = getGroundY()
        
        // Calculate initial upward velocity for physics-based jump
        // Using kinematic equation: v = sqrt(2 * g * h) where we want to reach jumpHeight
        let gravity: Float = 80.0  // Gravity acceleration
        jumpVelocityY = sqrt(2.0 * gravity * jumpHeight)
        
        // Initialize forward boost to be applied smoothly over time
        jumpForwardBoostRemaining = jumpForwardBoost
    }
    
    /// Get current ground Y position based on road
    func getGroundY() -> Float {
        guard isGameRunning, roadManager != nil else { return 0.0 }
        
        if let roadY = roadManager.getCurrentRoadYPosition(atZ: playerZPosition) {
            var yOffset: Float = 0.0
            if let roadType = roadManager.getCurrentRoadType(atZ: playerZPosition) {
                switch roadType {
                case .simple: yOffset = playerYOffsetOnSimple
                case .tunnel: yOffset = playerYOffsetOnTunnel
                case .platform: yOffset = playerYOffsetOnPlatform
                }
            }
            return roadY + yOffset
        }
        return 0.0
    }
    
    /// Update jump physics - called every frame
    func updateJumpPhysics(dt: Float) {
        guard isJumping else { return }
        
        let gravity: Float = 80.0
        let currentGroundY = getGroundY()
        
        // Apply gravity to velocity
        jumpVelocityY -= gravity * dt
        
        // Update Y position
        var newY = playerNode.position.y + jumpVelocityY * dt
        
        // Apply forward boost smoothly over time
        if jumpForwardBoostRemaining > 0 && jumpForwardBoostDuration > 0 {
            let boostRate = jumpForwardBoost / jumpForwardBoostDuration
            let boostThisFrame = min(boostRate * dt, jumpForwardBoostRemaining)
            playerZPosition -= boostThisFrame
            jumpForwardBoostRemaining -= boostThisFrame
        }
        
        // Check if we've started falling
        if jumpVelocityY < 0 {
            isJumpingUp = false
        }
        
        // Check for landing
        if !isJumpingUp && newY <= currentGroundY {
            // Landed!
            newY = currentGroundY
            isJumping = false
            isLanding = false
            jumpVelocityY = 0
            jumpForwardBoostRemaining = 0  // Clear any remaining boost on landing
            
            // Resume running animation immediately
            if let characterNode = playerNode.childNode(withName: "CharacterContainer", recursively: true) {
                playBoneAnimation(key: "run", onNode: characterNode)
            }
        }
        
        playerNode.position.y = newY
    }
    
    // Dive state tracking
    private var diveStartTime: Float = 0
    private var originalScaleY: Float = 1.0
    
    func playerDive() {
        guard !isDiving && !isJumping else { return }
        totalCrouches += 1
        isDiving = true
        
        originalScaleY = playerNode.scale.y
        
        // Play roll animation
        if let characterNode = playerNode.childNode(withName: "CharacterContainer", recursively: true) {
            playBoneAnimation(key: "roll", onNode: characterNode)
        }
        
        // Smooth dive animation using SCNTransaction for better control
        SCNTransaction.begin()
        SCNTransaction.animationDuration = TimeInterval(diveSquashDuration)
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
        playerNode.scale = SCNVector3(1.0, diveSquashScale, 1.0)
        
        // Counter-scale the visual 3D model so it doesn't get flattened or sunk into the ground!
        if let characterNode = playerNode.childNode(withName: "CharacterContainer", recursively: true) {
            let invScale = 1.0 / diveSquashScale
            characterNode.scale = SCNVector3(0.01, 0.01 * invScale, 0.01)
            characterNode.position.y = 2.8 * invScale
        }
        
        SCNTransaction.commit()
        
        // Schedule restore after hold duration
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(diveSquashDuration + diveHoldDuration)) { [weak self] in
            guard let self = self, self.isDiving else { return }
            
            SCNTransaction.begin()
            SCNTransaction.animationDuration = TimeInterval(self.diveRestoreDuration)
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeIn)
            self.playerNode.scale = SCNVector3(1.0, 1.0, 1.0)
            
            // Restore visual 3D model scale
            if let characterNode = self.playerNode.childNode(withName: "CharacterContainer", recursively: true) {
                characterNode.scale = SCNVector3(0.01, 0.01, 0.01)
                characterNode.position.y = 2.8
            }
            SCNTransaction.completionBlock = {
                self.isDiving = false
                
                // Resume running animation immediately
                if let characterNode = self.playerNode.childNode(withName: "CharacterContainer", recursively: true) {
                    self.playBoneAnimation(key: "run", onNode: characterNode)
                }
            }
            SCNTransaction.commit()
        }
    }
    
    /// Called when a running rep is completed - adds 20% to current tier
    func onRunningRepCompleted() {
        let repBoost: Float = 0.2
        speedBarFill = min(3.0, speedBarFill + repBoost)
        
        DispatchQueue.main.async { [weak self] in
            self?.updateSpeedBarUI()
        }
    }
    
    // MARK: - Speed Bar
    func setupSpeedBar() {
        let screenWidth = view.bounds.width
        let barWidth = screenWidth - speedBarSideMargin * 2
        let divisionWidth = barWidth / 3.0
        
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
            
            let bg = UIView(frame: CGRect(x: x, y: 0, width: divisionWidth, height: speedBarHeight))
            bg.backgroundColor = tierColors[i].bg
            container.addSubview(bg)
            tierBGs.append(bg)
            
            let fill = UIView(frame: CGRect(x: x, y: 0, width: 0, height: speedBarHeight))
            fill.backgroundColor = tierColors[i].fill
            container.addSubview(fill)
            tierFills.append(fill)
            
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
        
        for i in 1..<3 {
            let divider = UIView(frame: CGRect(x: CGFloat(i) * divisionWidth - 1, y: 0, width: 2, height: speedBarHeight))
            divider.backgroundColor = UIColor.white.withAlphaComponent(0.3)
            container.addSubview(divider)
        }
        
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
    }
    
    func updateSpeedBar(dt: Float) {
        if isMovingForward {
            if speedBarFill < 1.0 {
                let rate = 1.0 / tier1FillTime
                speedBarFill = min(1.0, speedBarFill + rate * dt)
            } else if speedBarFill < 2.0 {
                let rate = 1.0 / tier2FillTime
                speedBarFill = min(2.0, speedBarFill + rate * dt)
            } else if speedBarFill < 3.0 {
                let rate = 1.0 / tier3FillTime
                speedBarFill = min(3.0, speedBarFill + rate * dt)
            }
        } else {
            // Drain continuously from current level to 0
            if speedBarFill > 0.0 {
                var drainRate: Float
                if speedBarFill > 2.0 {
                    drainRate = 1.0 / tier3DrainTime
                } else if speedBarFill > 1.0 {
                    drainRate = 1.0 / tier2DrainTime
                } else {
                    drainRate = 1.0 / tier1DrainTime
                }
                speedBarFill = max(0.0, speedBarFill - drainRate * dt)
            }
        }
        
        // Ensure UI update happens on main thread
        DispatchQueue.main.async { [weak self] in
            self?.updateSpeedBarUI()
        }
    }
    
    func speedFromBar() -> Float {
        if speedBarFill <= 0.0 {
            return baseMovementSpeed  // Always move at base speed minimum
        } else if speedBarFill <= 1.0 {
            return speedTier1
        } else if speedBarFill <= 2.0 {
            return speedTier2
        } else {
            return speedTier3
        }
    }
    
    func updateSpeedBarUI() {
        guard let container = speedBarContainerView else { return }
        
        let barWidth = container.bounds.width
        let divisionWidth = barWidth / 3.0
        
        // Tier 1: fills from 0.0 to 1.0
        let t1Fill = max(0, min(1, speedBarFill))
        speedBarTier1Fill?.frame = CGRect(x: 0, y: 0, width: divisionWidth * CGFloat(t1Fill), height: speedBarHeight)
        
        // Tier 2: fills from 1.0 to 2.0 (only show if speedBarFill > 1.0)
        let t2Fill: CGFloat
        if speedBarFill > 1.0 {
            t2Fill = CGFloat(min(1, speedBarFill - 1.0))
        } else {
            t2Fill = 0  // Completely empty when below 1.0
        }
        speedBarTier2Fill?.frame = CGRect(x: divisionWidth, y: 0, width: divisionWidth * t2Fill, height: speedBarHeight)
        
        // Tier 3: fills from 2.0 to 3.0 (only show if speedBarFill > 2.0)
        let t3Fill: CGFloat
        if speedBarFill > 2.0 {
            t3Fill = CGFloat(min(1, speedBarFill - 2.0))
        } else {
            t3Fill = 0  // Completely empty when below 2.0
        }
        speedBarTier3Fill?.frame = CGRect(x: divisionWidth * 2, y: 0, width: divisionWidth * t3Fill, height: speedBarHeight)
        
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
    func checkObstacleCollisions(currentTime: Float) {
        if currentTime - lastHitTime < hitCooldownTime {
            return
        }
        
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
        
        for obstacle in activeObstacles {
            guard let data = obstacleDataMap[obstacle] else { continue }
            
            var bboxSize: SCNVector3
            var bboxOffset: SCNVector3
            
            switch data.obstacleType {
            case "cube":
                bboxSize = SCNVector3(cubeBBoxWidth, cubeBBoxHeight, cubeBBoxDepth)
                bboxOffset = SCNVector3(cubeBBoxOffsetX, cubeBBoxOffsetY, cubeBBoxOffsetZ)
            case "cuboid":
                bboxSize = SCNVector3(cuboidBBoxWidth, cuboidBBoxHeight, cuboidBBoxDepth)
                bboxOffset = SCNVector3(cuboidBBoxOffsetX, cuboidBBoxOffsetY, cuboidBBoxOffsetZ)
            case "hover":
                bboxSize = SCNVector3(hoverBBoxWidth, hoverBBoxHeight, hoverBBoxDepth)
                bboxOffset = SCNVector3(hoverBBoxOffsetX, hoverBBoxOffsetY, hoverBBoxOffsetZ)
            default:
                continue
            }
            
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
            
            let collisionX = playerMax.x >= obstacleMin.x && playerMin.x <= obstacleMax.x
            let collisionY = playerMax.y >= obstacleMin.y && playerMin.y <= obstacleMax.y
            let collisionZ = playerMax.z >= obstacleMin.z && playerMin.z <= obstacleMax.z
            
            if collisionX && collisionY && collisionZ {
                let obstacleID = ObjectIdentifier(obstacle)
                if clearedObstacles.contains(obstacleID) {
                    continue
                }
                
                let canJumpOver = isJumpingOverObstacle(obstacle: obstacle, type: data.obstacleType)
                
                if canJumpOver {
                    clearedObstacles.insert(obstacleID)
                } else {
                    onObstacleHit(obstacle: obstacle, currentTime: currentTime)
                }
                break
            }
        }
    }
    
    func isJumpingOverObstacle(obstacle: SCNNode, type: String) -> Bool {
        guard isJumping else { return false }
        
        let playerPos = playerNode.presentation.position
        let obstaclePos = obstacle.presentation.position
        let dx = playerPos.x - obstaclePos.x
        let dz = playerPos.z - obstaclePos.z
        let distance = sqrtf(dx * dx + dz * dz)
        
        guard distance <= safeDistanceOut && distance >= safeDistanceIn else {
            return false
        }
        
        switch type {
        case "cube":
            return jumpOverCubesEnabled
        case "cuboid":
            return jumpOverCuboidsEnabled
        case "hover":
            return jumpOverHoverEnabled
        default:
            return false
        }
    }
    
    func onObstacleHit(obstacle: SCNNode, currentTime: Float) {
        lastHitTime = currentTime
        
        speedBarFill = max(0.0, speedBarFill - hitSpeedPenalty)
        updateSpeedBarUI()
        
        triggerHitFlash()
        
        if hitShakeAmount > 0 {
            triggerCameraShake()
        }
    }
    
    // MARK: - Hit Visual Feedback
    func setupHitFlashOverlay() {
        let flashView = UIView(frame: view.bounds)
        flashView.backgroundColor = UIColor.red.withAlphaComponent(0.0)
        flashView.isUserInteractionEnabled = false
        flashView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(flashView)
        hitFlashView = flashView
        
        // Add debug tap gesture to test hit effect (double tap anywhere)
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(debugTriggerHit))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)
    }
    
    /// Debug method - double tap screen to test hit effect
    @objc func debugTriggerHit() {
        print("🔴 DEBUG: Triggering hit effect manually")
        onObstacleHit(obstacle: SCNNode(), currentTime: Float(gameTime))
    }
    
    func triggerHitFlash() {
        guard let flashView = hitFlashView else { 
            print("⚠️ hitFlashView is nil!")
            return 
        }
        
        print("🔴 Hit flash triggered!")
        
        // Ensure we're on main thread for UI updates
        DispatchQueue.main.async {
            flashView.layer.removeAllAnimations()
            flashView.backgroundColor = UIColor.red.withAlphaComponent(0.5)
            flashView.alpha = 1.0
            
            UIView.animate(withDuration: TimeInterval(self.hitFlashDuration), delay: 0, options: [.curveEaseOut]) {
                flashView.backgroundColor = UIColor.red.withAlphaComponent(0.0)
            }
        }
    }
    
    func triggerCameraShake() {
        print("📸 Camera shake triggered!")
        
        let shakeAmount = max(hitShakeAmount, 0.3) // Minimum shake for visibility
        let shakeX = Float.random(in: -shakeAmount...shakeAmount)
        let shakeY = Float.random(in: -shakeAmount...shakeAmount)
        
        let shake1 = SCNAction.moveBy(x: CGFloat(shakeX), y: CGFloat(shakeY), z: 0, duration: 0.03)
        let shake2 = SCNAction.moveBy(x: CGFloat(-shakeX * 2), y: CGFloat(-shakeY * 2), z: 0, duration: 0.03)
        let shake3 = SCNAction.moveBy(x: CGFloat(shakeX), y: CGFloat(shakeY), z: 0, duration: 0.03)
        let sequence = SCNAction.sequence([shake1, shake2, shake3])
        
        cameraNode.runAction(sequence)
    }
    
    // MARK: - Game Loop
    // MARK: - End Game Button & Session Finalization

    private func setupEndGameButton() {
        let button = UIButton(type: .system)
        button.setTitle("  END  ", for: .normal)
        button.titleLabel?.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .bold)
        button.setTitleColor(UIColor(red: 1.0, green: 0.15, blue: 0.25, alpha: 1.0), for: .normal)
        button.backgroundColor = UIColor(red: 0.12, green: 0.02, blue: 0.04, alpha: 0.9)
        button.layer.cornerRadius = 10
        button.layer.borderWidth = 1.0
        button.layer.borderColor = UIColor(red: 1.0, green: 0.15, blue: 0.25, alpha: 0.5).cgColor
        button.layer.shadowColor = UIColor(red: 1.0, green: 0.15, blue: 0.25, alpha: 1.0).cgColor
        button.layer.shadowRadius = 6
        button.layer.shadowOpacity = 0.4
        button.layer.shadowOffset = .zero
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(endGameButtonTapped), for: .touchUpInside)
        view.addSubview(button)
        endGameButton = button

        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            button.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    @objc private func endGameButtonTapped() {
        guard isGameRunning else { return }
        finalizeAndSaveSession(completionStatus: "completed")
    }

    private func finalizeAndSaveSession(completionStatus: String) {
        isGameRunning = false
        sceneView.isPlaying = false

        let durationSeconds = Int(Date().timeIntervalSince(sessionStartTime))
        let durationMinutes = max(1, durationSeconds / 60)
        // Calorie formula: 80 kcal per 600 seconds (from TrackModel.TimeAndCalories)
        let caloriesBurned = Int(Double(durationSeconds) * (80.0 / 600.0))
        let distanceMeters = Double(totalDistanceCovered)
        let avgSpeed: Double? = durationMinutes > 0 ? distanceMeters / Double(durationMinutes) : nil

        let trackId = DifficultySettings.shared.selectedTrackId
        let trackDisplayName = DifficultySettings.shared.selectedTrackDisplayName
        let character = GameData.shared.getSelectedPlayer()

        GameData.shared.addSession(
            duration: durationMinutes,
            calories: caloriesBurned,
            track: trackDisplayName,
            trackId: trackId,
            characterId: character.id,
            jumps: totalJumps,
            crouches: totalCrouches,
            leftLeans: totalLeftLeans,
            rightLeans: totalRightLeans,
            distanceCovered: distanceMeters,
            averageSpeed: avgSpeed,
            completionStatus: completionStatus
        )

        gameDelegate?.gameDidEnd()

        DispatchQueue.main.async { [weak self] in
            self?.dismiss(animated: true)
        }
    }

    // MARK: - Pause / Resume

    func pauseGame() {
        guard isGameRunning, !isPaused else { return }
        isPaused = true
        isGameRunning = false
        sceneView.isPlaying = false
        showPauseMenu()
    }

    func resumeGame() {
        guard isPaused else { return }
        pauseMenuHostingController?.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.pauseMenuHostingController = nil
            self.isPaused = false
            self.isGameRunning = true
            self.sceneView.isPlaying = true
        }
    }

    private func showPauseMenu() {
        let elapsed      = Date().timeIntervalSince(sessionStartTime)
        let currentCal   = Int(elapsed * (80.0 / 600.0))
        let currentDistKm = Double(totalDistanceCovered) / 1000.0
        let targetDistKm = DifficultySettings.shared.selectedDistanceKm
        let targetCal    = Int((targetDistKm * 70).rounded())

        let menuView = PauseMenuView(
            currentCalories:   currentCal,
            targetCalories:    targetCal,
            currentDistanceKm: currentDistKm,
            targetDistanceKm:  targetDistKm,
            onResume:         { [weak self] in self?.resumeGame() },
            onExitConfirmed:  { [weak self] in self?.exitAndShowSummary() }
        )

        let hosting = UIHostingController(rootView: menuView)
        hosting.modalPresentationStyle = .overFullScreen
        hosting.modalTransitionStyle   = .crossDissolve
        hosting.view.backgroundColor   = .clear
        present(hosting, animated: true)
        pauseMenuHostingController = hosting
    }

    // MARK: - Exit → Summary

    func exitAndShowSummary() {
        // Stop the game
        isGameRunning = false
        isPaused      = false
        sceneView.isPlaying = false

        // Compute session stats
        let durationSeconds = Int(Date().timeIntervalSince(sessionStartTime))
        let durationMinutes = max(1, durationSeconds / 60)
        let caloriesBurned  = Int(Double(durationSeconds) * (80.0 / 600.0))
        let distanceMeters  = Double(totalDistanceCovered)
        let avgSpeed: Double? = durationMinutes > 0 ? distanceMeters / Double(durationMinutes) : nil
        let character  = GameData.shared.getSelectedPlayer()
        let trackName  = DifficultySettings.shared.selectedTrackDisplayName
        let trackId    = DifficultySettings.shared.selectedTrackId

        let summaryData = SessionSummaryData(
            trackName:        trackName,
            durationSeconds:  durationSeconds,
            caloriesBurned:   caloriesBurned,
            completionStatus: "abandoned",
            characterName:    character.name,
            avgSpeedMpMin:    avgSpeed,
            totalJumps:       totalJumps,
            totalCrouches:    totalCrouches,
            totalLeftLeans:   totalLeftLeans,
            totalRightLeans:  totalRightLeans,
            distanceMeters:   distanceMeters
        )

        // Capture values for the closure (avoid capturing self strongly in summary)
        let capturedDuration  = durationMinutes
        let capturedCal       = caloriesBurned
        let capturedDist      = distanceMeters
        let capturedSpeed     = avgSpeed
        let capturedJumps     = totalJumps
        let capturedCrouches  = totalCrouches
        let capturedLeftLeans = totalLeftLeans
        let capturedRightLeans = totalRightLeans
        let capturedCharacter = character
        let capturedTrack     = trackName
        let capturedTrackId   = trackId

        // Dismiss pause menu (no animation) then show summary
        pauseMenuHostingController?.dismiss(animated: false)
        pauseMenuHostingController = nil

        let summaryView = SessionSummaryView(summary: summaryData) {
            // Save to Supabase when user taps "Go Home"
            GameData.shared.addSession(
                duration:        capturedDuration,
                calories:        capturedCal,
                track:           capturedTrack,
                trackId:         capturedTrackId,
                characterId:     capturedCharacter.id,
                jumps:           capturedJumps,
                crouches:        capturedCrouches,
                leftLeans:       capturedLeftLeans,
                rightLeans:      capturedRightLeans,
                distanceCovered: capturedDist,
                averageSpeed:    capturedSpeed,
                completionStatus: "abandoned"
            )
            // Navigate all the way home via notification (HomeVC dismisses its stack)
            NotificationCenter.default.post(name: .navigateToHome, object: nil)
        }

        let hosting = UIHostingController(rootView: summaryView)
        hosting.modalPresentationStyle = .overFullScreen
        hosting.modalTransitionStyle   = .crossDissolve
        hosting.view.backgroundColor   = UIColor(red: 0.02, green: 0.02, blue: 0.06, alpha: 1.0)
        present(hosting, animated: true)
        summaryHostingController = hosting
    }

    func startGame() {
        isGameRunning = true
        sceneView.delegate = self
        sceneView.isPlaying = true

        // Session tracking initialization
        sessionStartTime = Date()
        totalJumps = 0
        totalCrouches = 0
        totalLeftLeans = 0
        totalRightLeans = 0
        totalDistanceCovered = 0.0
    }
    
    private var gameTime: TimeInterval = 0
    
    func updateGame(deltaTime: TimeInterval, currentTime: TimeInterval) {
        guard isGameRunning else { return }
        
        let time = Float(currentTime)
        let dt = Float(deltaTime)
        
        updateSpeedBar(dt: dt)
        updateSpeedInterpolation(dt: dt)
        updateLanePosition(dt: dt)
        
        // Use smoothly interpolated speed for movement
        // Skip normal movement while jump boost is active so boost doesn't stack with speed
        var movement: Float = 0
        if isMovingBackward {
            movement = speedTier1 * dt
        } else if currentSpeed > 0 && jumpForwardBoostRemaining <= 0 {
            movement = -currentSpeed * dt
        }
        
        playerZPosition += movement

        // Accumulate session distance (movement is negative when moving forward)
        if movement < 0 {
            totalDistanceCovered += abs(movement) * sceneKitUnitsToMeters
        }

        // Handle Y position - either jumping or following ground
        if isJumping {
            // Physics-based jump update
            updateJumpPhysics(dt: dt)
        } else {
            // Follow ground smoothly when not jumping
            let targetY = getGroundY()
            let currentY = playerNode.position.y
            
            // Use faster smoothing for better responsiveness
            // Faster when below ground (prevent clipping), slower when above
            let smoothFactor: Float = currentY < targetY ? 0.4 : 0.25
            let newY = currentY + (targetY - currentY) * smoothFactor
            
            // Clamp to never go below ground
            playerNode.position.y = max(newY, targetY - 0.5)
        }
        
        playerNode.position.z = playerZPosition
        
        let currentRoadType = roadManager.getCurrentRoadType(atZ: playerZPosition)
        let isInTunnel = currentRoadType == .tunnel
        
        let targetCameraOffsetY = isInTunnel ? cameraOffsetYInTunnel : cameraOffsetY
        let targetCameraOffsetZ = isInTunnel ? cameraOffsetZInTunnel : cameraOffsetZ
        let targetCameraTiltXDegrees = isInTunnel ? cameraTiltXDegreesinTunnel : cameraTiltXDegrees
        
        let cameraTransitionSpeed: Float = 0.05
        
        currentCameraOffsetY += (targetCameraOffsetY - currentCameraOffsetY) * cameraTransitionSpeed
        currentCameraOffsetZ += (targetCameraOffsetZ - currentCameraOffsetZ) * cameraTransitionSpeed
        currentCameraTiltXDegrees += (targetCameraTiltXDegrees - currentCameraTiltXDegrees) * cameraTransitionSpeed
        
        // Smooth camera X follow (don't jerk with lane changes)
        let targetCameraX = cameraOffsetX + (currentLaneX * cameraFollowPlayerX)
        let currentCameraX = cameraNode.position.x
        let smoothCameraX = currentCameraX + (targetCameraX - currentCameraX) * 0.1
        
        cameraNode.position = SCNVector3(
            x: smoothCameraX,
            y: currentCameraOffsetY,
            z: playerZPosition + currentCameraOffsetZ
        )
        
        let interpolatedTiltX = currentCameraTiltXDegrees * .pi / 180
        cameraNode.eulerAngles = SCNVector3(x: interpolatedTiltX, y: cameraTiltY, z: cameraTiltZ)
        cameraNode.camera?.fieldOfView = cameraFieldOfView
        
        updatePlanetTransform()
        
        roadManager.update(playerZ: playerZPosition)
        updateObstacleCurves(playerZ: playerZPosition)
        
        if collisionEnabled {
            checkObstacleCollisions(currentTime: time)
        }
        
        cleanupOldObstacles()
    }
    
    private var lastPlanetAnimationSpeed: Float = 1.0
    
    func updatePlanetTransform() {
        guard let planetNode = planetNode else { return }
        
        planetNode.position = SCNVector3(
            x: planetXAxisPos,
            y: planetYAxisPos,
            z: playerZPosition + planetZAxisPos
        )
        planetNode.scale = SCNVector3(planetSize, planetSize, planetSize)
        
        if planetAnimationSpeed != lastPlanetAnimationSpeed {
            updatePlanetAnimationSpeed()
            lastPlanetAnimationSpeed = planetAnimationSpeed
        }
    }
    
    func updatePlanetAnimationSpeed() {
        guard let planetNode = planetNode else { return }
        
        planetNode.removeAction(forKey: "planetRotation")
        
        let rotationDuration = 5.0 / Double(planetAnimationSpeed)
        let rotation = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: rotationDuration)
        planetNode.runAction(SCNAction.repeatForever(rotation), forKey: "planetRotation")
    }
}

// MARK: - SCNSceneRendererDelegate
extension ExertiaGameViewController: SCNSceneRendererDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        struct Holder {
            static var lastTime: TimeInterval = 0
        }
        
        let deltaTime = Holder.lastTime == 0 ? 0 : time - Holder.lastTime
        Holder.lastTime = time
        
        let cappedDelta = min(deltaTime, 1.0 / 30.0)
        
        gameTime = time
        updateGame(deltaTime: cappedDelta, currentTime: time)
    }
}
