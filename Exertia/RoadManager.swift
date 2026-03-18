//
//  RoadManager.swift
//  VisionExample
//
//  Adapted from Exeria_Game_Final_1
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
    let baseYPosition: Float
    var originalRotation: SCNVector3
    
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
    
    private var activeRoads: [RoadSegment] = []
    private var roadTemplates: [RoadType: SCNNode] = [:]
    private var pattern = RoadPattern()
    
    var roadLength: Float = 20.0
    var roadWidth: Float = 12.0
    var laneWidth: Float { return roadWidth / 3.0 }
    
    var roadSimpleYPosition: Float = 0.0
    var roadTunnelYPosition: Float = 0.0
    var roadPlatformYPosition: Float = 0.0
    
    // Curve Settings
    var curveEnabled: Bool = true
    var curveStrength: Float = 0.0000
    var curveHorizontalStrength: Float = 0.01
    var curveRotationStrength: Float = 0.008
    var curveStartDistance: Float = 20.0
    
    let segmentsAhead: Int = 11
    let segmentsBehind: Int = 2
    
    private var nextRoadZ: Float = 0
    
    var lanePositions: [Float] {
        return [-laneWidth, 0, laneWidth]
    }
    
    // MARK: - Initialization
    init(scene: SCNScene) {
        self.scene = scene
    }
    
    // MARK: - Load Road Templates
    func loadRoadTemplates() {
        guard roadTemplates.isEmpty else { return }
        
        for roadType in RoadType.allCases {
            if let roadNode = loadRoadAsset(for: roadType) {
                roadTemplates[roadType] = roadNode
                
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
        
        let possibleNames = [
            assetName,
            "GameAssets/\(assetName)",
            "Assets/\(assetName)"
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
                    
                    let (minBound, maxBound) = containerNode.boundingBox
                    let originalWidth = maxBound.x - minBound.x
                    
                    if originalWidth > 0 {
                        let scaleFactor = roadWidth / originalWidth
                        containerNode.scale = SCNVector3(scaleFactor, scaleFactor, scaleFactor)
                    }
                    
                    if roadType == .simple || roadType == .platform {
                        containerNode.eulerAngles.y = Float.pi / 2
                    }
                    
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
        let scale = node.scale.x
        let width = (max.x - min.x) * scale
        let length = (max.z - min.z) * scale
        
        if length > 0 { roadLength = length }
        if width > 0 { roadWidth = width }
    }
    
    private func createPlaceholderRoad(for type: RoadType) -> SCNNode {
        let node = SCNNode()
        
        let roadGeometry = SCNBox(width: CGFloat(roadWidth), 
                                  height: 1.0, 
                                  length: CGFloat(roadLength), 
                                  chamferRadius: 0)
        
        let roadMaterial = SCNMaterial()
        roadMaterial.diffuse.contents = UIColor.darkGray
        roadGeometry.materials = [roadMaterial]
        
        let roadNode = SCNNode(geometry: roadGeometry)
        roadNode.position.y = -0.5
        node.addChildNode(roadNode)
        
        return node
    }
    
    // MARK: - Road Generation
    func preloadAllRoadTypes() {
        var preloadNodes: [SCNNode] = []
        let preloadZ: Float = -1000
        
        for roadType in RoadType.allCases {
            guard let template = roadTemplates[roadType] else { continue }
            
            let preloadNode = template.clone()
            preloadNode.position = SCNVector3(x: 0, y: -100, z: preloadZ)
            scene?.rootNode.addChildNode(preloadNode)
            preloadNodes.append(preloadNode)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for node in preloadNodes {
                node.removeFromParentNode()
            }
        }
    }
    
    func generateInitialRoads() {
        pattern.reset()
        
        for road in activeRoads {
            road.node.removeFromParentNode()
        }
        activeRoads.removeAll()
        
        nextRoadZ = 0
        
        let totalInitialSegments = segmentsAhead + segmentsBehind + 1
        for _ in 0..<totalInitialSegments {
            spawnNextRoad()
        }
    }
    
    private func spawnNextRoad() {
        let roadType = pattern.getNextRoadType()
        
        guard let template = roadTemplates[roadType] else { return }
        
        let roadNode = template.clone()
        
        let (minBound, maxBound) = roadNode.boundingBox
        let scale = roadNode.scale.z
        let actualLength = (maxBound.z - minBound.z) * scale
        let centerOffsetZ = ((minBound.z + maxBound.z) / 2.0) * scale
        
        let yPosition: Float
        switch roadType {
        case .simple: yPosition = roadSimpleYPosition
        case .tunnel: yPosition = roadTunnelYPosition
        case .platform: yPosition = roadPlatformYPosition
        }
        
        roadNode.position = SCNVector3(
            x: 0,
            y: yPosition,
            z: nextRoadZ - actualLength / 2.0 - centerOffsetZ
        )
        
        scene?.rootNode.addChildNode(roadNode)
        
        let lengthToUse = actualLength > 0 ? actualLength : roadLength
        let segment = RoadSegment(node: roadNode, type: roadType, zPosition: nextRoadZ, length: lengthToUse, baseYPosition: yPosition)
        activeRoads.append(segment)
        
        delegate?.roadManager(self, didSpawnRoad: segment)
        
        nextRoadZ -= lengthToUse
    }
    
    // MARK: - Update
    func update(playerZ: Float) {
        let lookAheadDistance = roadLength * Float(segmentsAhead)
        let targetAheadZ = playerZ - lookAheadDistance
        
        while nextRoadZ > targetAheadZ {
            spawnNextRoad()
        }
        
        updateRoadCurves(playerZ: playerZ)
        
        let removeDistance = roadLength * Float(segmentsBehind)
        
        activeRoads.removeAll { segment in
            let roadEndZ = segment.zPosition - segment.length
            if roadEndZ > playerZ + removeDistance {
                segment.node.removeFromParentNode()
                return true
            }
            return false
        }
    }
    
    // MARK: - Curve Effect
    func updateRoadCurves(playerZ: Float) {
        guard curveEnabled else { return }
        
        for segment in activeRoads {
            let roadCenterZ = segment.zPosition - segment.length / 2
            let distanceFromPlayer = playerZ - roadCenterZ
            
            if distanceFromPlayer > curveStartDistance {
                let curveDistance = distanceFromPlayer - curveStartDistance
                
                let curveY = curveStrength * curveDistance * curveDistance
                let curveX = curveHorizontalStrength * curveDistance * curveDistance
                let tiltX = curveRotationStrength * curveDistance
                
                let baseZ = segment.zPosition - segment.length / 2
                segment.node.position = SCNVector3(
                    x: curveX,
                    y: segment.baseYPosition + curveY,
                    z: baseZ
                )
                
                segment.node.eulerAngles = SCNVector3(
                    x: segment.originalRotation.x + tiltX,
                    y: segment.originalRotation.y,
                    z: segment.originalRotation.z
                )
            } else {
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
        case .simple: return roadSimpleYPosition
        case .tunnel: return roadTunnelYPosition
        case .platform: return roadPlatformYPosition
        }
    }
}
