//
//  RoadManager.swift
//  Exeria_Game_Final_1
//
//  Created by admin62 on 05/02/26.
//

import SceneKit

// MARK: - Road Type Enum
enum RoadType: String, CaseIterable {
    case simple = "road_simple"
    case tunnel = "road_tunnel"
    case platform = "road_with_platform"
    
    var fileName: String {
        return rawValue + ".usdz"
    }
}

// MARK: - Road Segment Class
class RoadSegment {
    let node: SCNNode
    let type: RoadType
    let zPosition: Float
    let length: Float
    let baseYPosition: Float      // Original Y position (before curve)
    var originalRotation: SCNVector3  // Original rotation
    
    init(node: SCNNode, type: RoadType, zPosition: Float, length: Float, baseYPosition: Float) {
        self.node = node
        self.type = type
        self.zPosition = zPosition
        self.length = length
        self.baseYPosition = baseYPosition
        self.originalRotation = node.eulerAngles
    }
}

// MARK: - Road Pattern
struct RoadPattern {
    // Pattern: 10 simple -> 1 platform -> 10 tunnel -> 1 platform -> 10 simple -> 1 platform
    // Then loops
    
    static let pattern: [(RoadType, Int)] = [
        (.simple, 25),
        (.platform, 1),
        (.tunnel, 15),
        (.platform, 1),
        (.simple, 25),
        (.platform, 1)
    ]
    
    private var currentPatternIndex: Int = 0
    private var currentCountInPattern: Int = 0
    
    mutating func getNextRoadType() -> RoadType {
        let (roadType, count) = RoadPattern.pattern[currentPatternIndex]
        
        currentCountInPattern += 1
        
        if currentCountInPattern >= count {
            currentCountInPattern = 0
            currentPatternIndex = (currentPatternIndex + 1) % RoadPattern.pattern.count
        }
        
        return roadType
    }
    
    mutating func reset() {
        currentPatternIndex = 0
        currentCountInPattern = 0
    }
}

// MARK: - Road Delegate Protocol
protocol RoadManagerDelegate: AnyObject {
    func roadManager(_ manager: RoadManager, didSpawnRoad roadSegment: RoadSegment)
}

// MARK: - Road Manager Class
class RoadManager {
    
    // MARK: - Properties
    weak var scene: SCNScene?
    weak var delegate: RoadManagerDelegate?
    
    // Road segments currently in the scene
    private var activeRoads: [RoadSegment] = []
    
    // Loaded road templates (cached)
    private var roadTemplates: [RoadType: SCNNode] = [:]
    
    // Road generation pattern
    private var pattern = RoadPattern()
    
    // Road dimensions (will be set after loading assets)
    // Default values - will be updated once assets are measured
    var roadLength: Float = 20.0 // Length of each road segment in Z direction
    var roadWidth: Float = 12.0  // Width for 3 lanes
    var laneWidth: Float { return roadWidth / 3.0 }
    
    // Vertical positions for each road type (customize these!)
    var roadSimpleYPosition: Float = 0.0
    var roadTunnelYPosition: Float = 0.0
    var roadPlatformYPosition: Float = 0.0
    
    // MARK: - Curve Settings (Subway Surfers style!)
    var curveEnabled: Bool = true              // Enable/disable curve effect
    var curveStrength: Float = 0.0000          // How much roads curve upward (higher = more curve)
    var curveHorizontalStrength: Float = 0.01  // Horizontal curve (0 = straight, positive = curve right)
    var curveRotationStrength: Float = 0.008  // How much roads rotate/tilt with distance
    var curveStartDistance: Float = 20.0       // Distance from player where curve starts
    
    // Generation settings
    let segmentsAhead: Int = 11      // How many segments visible ahead (increased for curve visibility)
    let segmentsBehind: Int = 2     // How many segments to keep behind before deleting
    
    // Current road position
    private var nextRoadZ: Float = 0
    
    // Lane positions (X coordinates)
    var lanePositions: [Float] {
        return [-laneWidth, 0, laneWidth]
    }
    
    // MARK: - Initialization
    init(scene: SCNScene) {
        self.scene = scene
        // Don't load templates here - wait until roadWidth is configured
    }
    
    // MARK: - Load Road Templates
    func loadRoadTemplates() {
        // Only load once
        guard roadTemplates.isEmpty else { return }
        
        for roadType in RoadType.allCases {
            if let roadNode = loadRoadAsset(for: roadType) {
                roadTemplates[roadType] = roadNode
                
                // Measure the road dimensions from the first loaded road
                if roadType == .simple {
                    measureRoadDimensions(from: roadNode)
                }
                
                print("✅ Loaded road template: \(roadType.rawValue)")
            } else {
                print("⚠️ Using placeholder for: \(roadType.rawValue)")
                roadTemplates[roadType] = createPlaceholderRoad(for: roadType)
            }
        }
    }
    
    private func loadRoadAsset(for roadType: RoadType) -> SCNNode? {
        let assetName = roadType.rawValue
        
        // Try loading from bundle with various paths
        let possibleNames = [
            assetName,
            "Assets/\(assetName)",
            "0/\(assetName)",
            "ExtractedAssets/0/\(assetName)"
        ]
        
        for name in possibleNames {
            if let url = Bundle.main.url(forResource: name, withExtension: "usdz") {
                do {
                    let loadedScene = try SCNScene(url: url, options: [
                        .checkConsistency: false,
                        .convertToYUp: true
                    ])
                    
                    let containerNode = SCNNode()
                    containerNode.name = assetName
                    
                    for child in loadedScene.rootNode.childNodes {
                        containerNode.addChildNode(child.clone())
                    }
                    
                    // Measure original size
                    let (minBound, maxBound) = containerNode.boundingBox
                    let originalWidth = maxBound.x - minBound.x
                    let originalLength = maxBound.z - minBound.z
                    
                    print("📏 Original \(assetName) size - Width: \(originalWidth), Length: \(originalLength)")
                    
                    // Scale the road to match our configured width
                    if originalWidth > 0 {
                        let scaleFactor = roadWidth / originalWidth
                        containerNode.scale = SCNVector3(scaleFactor, scaleFactor, scaleFactor)
                        print("📐 Scaled \(assetName) by factor: \(scaleFactor)")
                    }
                    
                    // Rotate specific road types that are sideways
                    if roadType == .simple || roadType == .platform {
                        containerNode.eulerAngles.y = Float.pi / 2 // Rotate 90 degrees around Y axis
                        print("🔄 Rotated \(assetName) by 90°")
                    }
                    
                    print("✅ Loaded \(assetName) from: \(name)")
                    return containerNode
                } catch {
                    print("Error loading \(name): \(error.localizedDescription)")
                }
            }
        }
        
        return nil
    }
    
    private func measureRoadDimensions(from node: SCNNode) {
        let (min, max) = node.boundingBox
        
        // Account for scale
        let scale = node.scale.x
        let width = (max.x - min.x) * scale
        let length = (max.z - min.z) * scale
        let height = (max.y - min.y) * scale
        
        print("📏 Scaled Road dimensions - Width: \(width), Length: \(length), Height: \(height)")
        
        // Update road dimensions if we got valid measurements
        if length > 0 {
            roadLength = length
        }
        if width > 0 {
            roadWidth = width
        }
    }
    
    private func createPlaceholderRoad(for type: RoadType) -> SCNNode {
        let node = SCNNode()
        
        // Create a 3D road surface
        let roadGeometry = SCNBox(width: CGFloat(roadWidth), 
                                  height: 1.0, 
                                  length: CGFloat(roadLength), 
                                  chamferRadius: 0)
        
        // Different materials for different road types
        let roadMaterial = SCNMaterial()
        roadMaterial.diffuse.contents = UIColor.darkGray
        roadMaterial.specular.contents = UIColor.gray
        roadMaterial.shininess = 0.3
        
        let sideMaterial = SCNMaterial()
        sideMaterial.diffuse.contents = UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)
        
        roadGeometry.materials = [sideMaterial, sideMaterial, roadMaterial, sideMaterial, sideMaterial, sideMaterial]
        
        let roadNode = SCNNode(geometry: roadGeometry)
        roadNode.position.y = -0.5 // Half height down so top is at y=0
        roadNode.castsShadow = true
        node.addChildNode(roadNode)
        
        // Add side walls/curbs for depth
        let curbHeight: CGFloat = 0.5
        let curbWidth: CGFloat = 0.5
        
        let leftCurb = SCNBox(width: curbWidth, height: curbHeight, length: CGFloat(roadLength), chamferRadius: 0)
        leftCurb.firstMaterial?.diffuse.contents = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        let leftCurbNode = SCNNode(geometry: leftCurb)
        leftCurbNode.position = SCNVector3(x: -roadWidth/2 - Float(curbWidth)/2, y: Float(curbHeight)/2 - 0.5, z: 0)
        leftCurbNode.castsShadow = true
        node.addChildNode(leftCurbNode)
        
        let rightCurb = SCNBox(width: curbWidth, height: curbHeight, length: CGFloat(roadLength), chamferRadius: 0)
        rightCurb.firstMaterial?.diffuse.contents = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        let rightCurbNode = SCNNode(geometry: rightCurb)
        rightCurbNode.position = SCNVector3(x: roadWidth/2 + Float(curbWidth)/2, y: Float(curbHeight)/2 - 0.5, z: 0)
        rightCurbNode.castsShadow = true
        node.addChildNode(rightCurbNode)
        
        // Add lane markers (white dashed lines)
        let lineCount = Int(roadLength / 3.0) // One dash every 3 units
        for i in 0..<lineCount {
            // Left lane marker
            let leftLine = SCNBox(width: 0.15, height: 0.05, length: 1.5, chamferRadius: 0)
            leftLine.firstMaterial?.diffuse.contents = UIColor.white
            leftLine.firstMaterial?.emission.contents = UIColor(white: 0.3, alpha: 1.0)
            let leftLineNode = SCNNode(geometry: leftLine)
            leftLineNode.position = SCNVector3(x: -laneWidth, y: 0.01, z: -roadLength/2 + Float(i) * 3.0 + 1.5)
            node.addChildNode(leftLineNode)
            
            // Right lane marker
            let rightLine = SCNBox(width: 0.15, height: 0.05, length: 1.5, chamferRadius: 0)
            rightLine.firstMaterial?.diffuse.contents = UIColor.white
            rightLine.firstMaterial?.emission.contents = UIColor(white: 0.3, alpha: 1.0)
            let rightLineNode = SCNNode(geometry: rightLine)
            rightLineNode.position = SCNVector3(x: laneWidth, y: 0.01, z: -roadLength/2 + Float(i) * 3.0 + 1.5)
            node.addChildNode(rightLineNode)
        }
        
        // Add special elements based on road type
        switch type {
        case .simple:
            break // Just the road
            
        case .tunnel:
            // Add tunnel walls and ceiling
            let wallHeight: Float = 8.0
            let wallThickness: CGFloat = 1.0
            
            let wallMaterial = SCNMaterial()
            wallMaterial.diffuse.contents = UIColor(red: 0.4, green: 0.35, blue: 0.3, alpha: 1.0)
            
            // Left wall
            let leftWall = SCNBox(width: wallThickness, height: CGFloat(wallHeight), length: CGFloat(roadLength), chamferRadius: 0)
            leftWall.firstMaterial = wallMaterial
            let leftWallNode = SCNNode(geometry: leftWall)
            leftWallNode.position = SCNVector3(x: -roadWidth/2 - Float(wallThickness)/2 - 0.5, y: wallHeight/2, z: 0)
            leftWallNode.castsShadow = true
            node.addChildNode(leftWallNode)
            
            // Right wall
            let rightWall = SCNBox(width: wallThickness, height: CGFloat(wallHeight), length: CGFloat(roadLength), chamferRadius: 0)
            rightWall.firstMaterial = wallMaterial
            let rightWallNode = SCNNode(geometry: rightWall)
            rightWallNode.position = SCNVector3(x: roadWidth/2 + Float(wallThickness)/2 + 0.5, y: wallHeight/2, z: 0)
            rightWallNode.castsShadow = true
            node.addChildNode(rightWallNode)
            
            // Ceiling
            let ceiling = SCNBox(width: CGFloat(roadWidth + 3), height: 0.5, length: CGFloat(roadLength), chamferRadius: 0)
            ceiling.firstMaterial = wallMaterial
            let ceilingNode = SCNNode(geometry: ceiling)
            ceilingNode.position = SCNVector3(x: 0, y: wallHeight, z: 0)
            ceilingNode.castsShadow = true
            node.addChildNode(ceilingNode)
            
        case .platform:
            // Add platforms on the sides
            let platformHeight: Float = 2.0
            let platformWidth: CGFloat = 3.0
            
            let platformMaterial = SCNMaterial()
            platformMaterial.diffuse.contents = UIColor(red: 0.6, green: 0.5, blue: 0.4, alpha: 1.0)
            
            // Left platform
            let leftPlatform = SCNBox(width: platformWidth, height: CGFloat(platformHeight), length: CGFloat(roadLength * 0.6), chamferRadius: 0.1)
            leftPlatform.firstMaterial = platformMaterial
            let leftPlatformNode = SCNNode(geometry: leftPlatform)
            leftPlatformNode.position = SCNVector3(x: -roadWidth/2 - Float(platformWidth)/2 - 1, y: platformHeight/2, z: 0)
            leftPlatformNode.castsShadow = true
            node.addChildNode(leftPlatformNode)
            
            // Right platform
            let rightPlatform = SCNBox(width: platformWidth, height: CGFloat(platformHeight), length: CGFloat(roadLength * 0.6), chamferRadius: 0.1)
            rightPlatform.firstMaterial = platformMaterial
            let rightPlatformNode = SCNNode(geometry: rightPlatform)
            rightPlatformNode.position = SCNVector3(x: roadWidth/2 + Float(platformWidth)/2 + 1, y: platformHeight/2, z: 0)
            rightPlatformNode.castsShadow = true
            node.addChildNode(rightPlatformNode)
        }
        
        return node
    }
    
    // MARK: - Road Generation
    func preloadAllRoadTypes() {
        // Spawn one of each road type far away to warm up rendering
        print("🔄 Preloading all road types...")
        
        var preloadNodes: [SCNNode] = []
        let preloadZ: Float = -1000 // Far away from camera
        
        for roadType in RoadType.allCases {
            guard let template = roadTemplates[roadType] else { continue }
            
            let preloadNode = template.clone()
            preloadNode.position = SCNVector3(x: 0, y: -100, z: preloadZ) // Far below and away
            scene?.rootNode.addChildNode(preloadNode)
            preloadNodes.append(preloadNode)
            
            print("✅ Preloaded \(roadType.rawValue)")
        }
        
        // Remove preloaded nodes after a brief delay to let SceneKit prepare them
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for node in preloadNodes {
                node.removeFromParentNode()
            }
            print("🧹 Cleaned up preload nodes")
        }
    }
    
    func generateInitialRoads() {
        // Reset pattern
        pattern.reset()
        
        // Clear any existing roads
        for road in activeRoads {
            road.node.removeFromParentNode()
        }
        activeRoads.removeAll()
        
        // Reset position
        nextRoadZ = 0
        
        // Generate initial roads (segments ahead + segments behind + 1 for current)
        let totalInitialSegments = segmentsAhead + segmentsBehind + 1
        for _ in 0..<totalInitialSegments {
            spawnNextRoad()
        }
        
        print("🛤️ Generated \(totalInitialSegments) initial road segments")
    }
    
    private func spawnNextRoad() {
        let roadType = pattern.getNextRoadType()
        
        guard let template = roadTemplates[roadType] else {
            print("❌ No template for road type: \(roadType)")
            return
        }
        
        // Clone the template
        let roadNode = template.clone()
        
        // Get the bounding box and account for scale
        let (minBound, maxBound) = roadNode.boundingBox
        let scale = roadNode.scale.z
        let actualLength = (maxBound.z - minBound.z) * scale
        let centerOffsetZ = ((minBound.z + maxBound.z) / 2.0) * scale
        
        // Get Y position based on road type
        let yPosition: Float
        switch roadType {
        case .simple:
            yPosition = roadSimpleYPosition
        case .tunnel:
            yPosition = roadTunnelYPosition
        case .platform:
            yPosition = roadPlatformYPosition
        }
        
        // Position road so its START edge aligns with nextRoadZ
        // The road's center needs to be offset so the front edge is at nextRoadZ
        roadNode.position = SCNVector3(
            x: 0,
            y: yPosition,
            z: nextRoadZ - actualLength / 2.0 - centerOffsetZ
        )
        
        // Add to scene
        scene?.rootNode.addChildNode(roadNode)
        
        // Create segment and track it
        let lengthToUse = actualLength > 0 ? actualLength : roadLength
        let segment = RoadSegment(node: roadNode, type: roadType, zPosition: nextRoadZ, length: lengthToUse, baseYPosition: yPosition)
        activeRoads.append(segment)
        
        // Notify delegate about new road spawn
        delegate?.roadManager(self, didSpawnRoad: segment)
        
        // Update next road position (use actual measured length)
        nextRoadZ -= lengthToUse
        
        print("🛤️ Spawned \(roadType.rawValue) at Z: \(segment.zPosition), length: \(lengthToUse)")
    }
    
    // MARK: - Update
    func update(playerZ: Float) {
        // Check if we need to spawn new roads ahead
        // Use a fixed look-ahead distance based on average road length
        let lookAheadDistance = roadLength * Float(segmentsAhead)
        let targetAheadZ = playerZ - lookAheadDistance
        
        while nextRoadZ > targetAheadZ {
            spawnNextRoad()
        }
        
        // Update curve positions for all active roads
        updateRoadCurves(playerZ: playerZ)
        
        // Remove roads that are too far behind
        let removeDistance = roadLength * Float(segmentsBehind)
        
        activeRoads.removeAll { segment in
            // Road is behind player by more than the threshold
            let roadEndZ = segment.zPosition - segment.length
            if roadEndZ > playerZ + removeDistance {
                segment.node.removeFromParentNode()
                print("🗑️ Removed road at Z: \(segment.zPosition)")
                return true
            }
            return false
        }
    }
    
    // MARK: - Curve Effect
    func updateRoadCurves(playerZ: Float) {
        guard curveEnabled else { return }
        
        for segment in activeRoads {
            // Calculate distance from player to road center
            let roadCenterZ = segment.zPosition - segment.length / 2
            let distanceFromPlayer = playerZ - roadCenterZ  // Positive = road is ahead
            
            // Only apply curve to roads ahead of the player
            if distanceFromPlayer > curveStartDistance {
                let curveDistance = distanceFromPlayer - curveStartDistance
                
                // Quadratic curve for smooth, natural-looking bend
                // Y curves upward (like going over a hill)
                let curveY = curveStrength * curveDistance * curveDistance
                
                // Optional horizontal curve (left/right bend)
                let curveX = curveHorizontalStrength * curveDistance * curveDistance
                
                // Rotation to make road tilt as it curves away
                let tiltX = curveRotationStrength * curveDistance  // Tilt up/down
                
                // Apply curved position
                let baseZ = segment.zPosition - segment.length / 2
                segment.node.position = SCNVector3(
                    x: curveX,
                    y: segment.baseYPosition + curveY,
                    z: baseZ
                )
                
                // Apply rotation - preserve original Y rotation and add tilt
                segment.node.eulerAngles = SCNVector3(
                    x: segment.originalRotation.x + tiltX,
                    y: segment.originalRotation.y,
                    z: segment.originalRotation.z
                )
            } else {
                // Road is near/behind player - keep flat
                let baseZ = segment.zPosition - segment.length / 2
                segment.node.position = SCNVector3(
                    x: 0,
                    y: segment.baseYPosition,
                    z: baseZ
                )
                segment.node.eulerAngles = segment.originalRotation
            }
        }
    }
    
    // MARK: - Utility
    func getLaneXPosition(lane: Int) -> Float {
        // Lane 0 = left, 1 = center, 2 = right
        let clampedLane = max(0, min(2, lane))
        return lanePositions[clampedLane]
    }
    
    func getCurrentRoadType(atZ z: Float) -> RoadType? {
        for segment in activeRoads {
            let segmentStart = segment.zPosition
            let segmentEnd = segment.zPosition - segment.length
            
            if z <= segmentStart && z > segmentEnd {
                return segment.type
            }
        }
        return nil
    }
    
    func getCurrentRoadYPosition(atZ z: Float) -> Float? {
        guard let roadType = getCurrentRoadType(atZ: z) else {
            return nil
        }
        
        switch roadType {
        case .simple:
            return roadSimpleYPosition
        case .tunnel:
            return roadTunnelYPosition
        case .platform:
            return roadPlatformYPosition
        }
    }
}
