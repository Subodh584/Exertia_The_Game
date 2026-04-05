//
//  AssetLoader.swift
//  Exeria_Game_Final_1
//
//  Created by admin62 on 05/02/26.
//

import SceneKit
import UIKit

class AssetLoader {
    
    // Singleton
    static let shared = AssetLoader()
    
    // Cache for loaded scenes
    private var sceneCache: [String: SCNScene] = [:]
    
    // Asset names mapping
    enum Asset: String {
        // Roads
        case roadSimple = "road_simple"
        case roadTunnel = "road_tunnel"
        case roadWithPlatform = "road_with_platform"
        
        // Character
        case sharkoRunning = "Running_SharkoKhan-2"
        case sharkoJumping = "Jumping_SharkoKhan-2"
        case sharkoDiving = "Diving_SharkoKhan-2"
        case sharkoFlipping = "Flipping_SharkoKhan-2"
        
        // Enemies
        case busterDrone = "Buster_Drone"
        case crabMech = "Gunslinger_Crab_Mech_v1"
        case glytchBug = "Small_Glytchbug"
        
        // Environment
        case planet = "Stylized_planet"
    }
    
    private init() {}
    
    // MARK: - Load Main Asset Bundle
    /// Call this at app startup to extract assets from the main USDZ
    func prepareAssets(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let success = self?.extractMainAssetBundle() ?? false
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
    
    private func extractMainAssetBundle() -> Bool {
        // The main asset bundle path
        guard let mainBundleURL = Bundle.main.url(forResource: "Exertia_Assets_Final_1", withExtension: "usdz") else {
            print("❌ Could not find Exertia_Assets_Final_1.usdz in bundle")
            return false
        }
        
        print("✅ Found main asset bundle at: \(mainBundleURL)")
        return true
    }
    
    // MARK: - Load Individual Assets
    func loadScene(for asset: Asset) -> SCNScene? {
        // Check cache first
        if let cached = sceneCache[asset.rawValue] {
            return cached
        }
        
        // Try to load from the main USDZ bundle
        // Assets are in "0/" subdirectory inside the USDZ
        let assetName = asset.rawValue
        
        // First try: Direct bundle resource
        if let url = Bundle.main.url(forResource: assetName, withExtension: "usdz") {
            if let scene = loadSceneFromURL(url) {
                sceneCache[asset.rawValue] = scene
                return scene
            }
        }
        
        // Second try: Look in the extracted assets if available
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let extractedPath = documentsPath.appendingPathComponent("ExtractedAssets/0/\(assetName).usdz")
        if FileManager.default.fileExists(atPath: extractedPath.path) {
            if let scene = loadSceneFromURL(extractedPath) {
                sceneCache[asset.rawValue] = scene
                return scene
            }
        }
        
        print("❌ Could not load asset: \(assetName)")
        return nil
    }
    
    func loadNode(for asset: Asset) -> SCNNode? {
        guard let scene = loadScene(for: asset) else {
            return nil
        }
        
        // Create a container node and clone all children
        let containerNode = SCNNode()
        containerNode.name = asset.rawValue
        
        for child in scene.rootNode.childNodes {
            containerNode.addChildNode(child.clone())
        }
        
        return containerNode
    }
    
    private func loadSceneFromURL(_ url: URL) -> SCNScene? {
        do {
            let scene = try SCNScene(url: url, options: [
                .checkConsistency: false,
                .convertToYUp: true
            ])
            print("✅ Loaded scene from: \(url.lastPathComponent)")
            return scene
        } catch {
            print("❌ Error loading scene from \(url): \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Get Bounding Box
    func getAssetDimensions(for asset: Asset) -> (width: Float, height: Float, length: Float)? {
        guard let node = loadNode(for: asset) else {
            return nil
        }
        
        let (min, max) = node.boundingBox
        return (
            width: max.x - min.x,
            height: max.y - min.y,
            length: max.z - min.z
        )
    }
    
    // MARK: - Character Preview Cache (for CharacterSelectionViewController)

    /// Pre-built SCNScene for the character selection 3D preview.
    /// Populated during SplashViewController so the model appears instantly.
    private(set) var characterPreviewScene: SCNScene?
    private(set) var characterPreviewCameraNode: SCNNode?
    private(set) var characterPreviewWrapperNode: SCNNode?

    /// Call from SplashViewController to preload the character preview on a background thread.
    func preloadCharacterPreview(
        offsetX: Float = 0, offsetY: Float = 0, offsetZ: Float = 0
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            guard let importedScene = SCNScene(named: "Character.scnassets/MascotFinal.usdz") else {
                print("⚠️ AssetLoader: Could not preload MascotFinal.usdz")
                return
            }

            let masterScene = SCNScene()
            let characterShell = importedScene.rootNode.clone()
            let wrapperNode = SCNNode()
            wrapperNode.addChildNode(characterShell)
            masterScene.rootNode.addChildNode(wrapperNode)

            // Force USDZ to stand up (Z-up → Y-up)
            characterShell.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)

            // Compute bounds
            let (minB, maxB) = characterShell.boundingBox
            let maxDim = max(maxB.x - minB.x, maxB.y - minB.y, maxB.z - minB.z)
            let autoScale: Float = maxDim > 0 ? (1.8 / maxDim) : 1.0
            characterShell.scale = SCNVector3(1, 1, 1)

            let midX = (minB.x + maxB.x) / 2
            let midY = (minB.y + maxB.y) / 2
            let virtualShiftX = offsetX / autoScale
            let virtualShiftY = offsetY / autoScale
            characterShell.position = SCNVector3(-midX + virtualShiftX, -midY + virtualShiftY, 0)

            // Lighting
            masterScene.lightingEnvironment.contents = UIColor(white: 0.2, alpha: 1.0)

            let ambientNode = SCNNode()
            let ambient = SCNLight()
            ambient.type = .ambient; ambient.color = UIColor.white; ambient.intensity = 600
            ambientNode.light = ambient
            masterScene.rootNode.addChildNode(ambientNode)

            let dirNode = SCNNode()
            let dir = SCNLight()
            dir.type = .directional; dir.color = UIColor.white; dir.intensity = 900
            dirNode.light = dir
            dirNode.eulerAngles = SCNVector3(-Float.pi / 4, -Float.pi / 6, 0)
            masterScene.rootNode.addChildNode(dirNode)

            // Camera
            let cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            cameraNode.camera?.fieldOfView = 50
            let visualCameraZ = 2.5 / autoScale
            let visualOffsetZ = offsetZ / autoScale
            cameraNode.camera?.zNear = Double(visualCameraZ) * 0.05
            cameraNode.camera?.zFar  = Double(visualCameraZ) * 5.0
            cameraNode.position = SCNVector3(0, 0, visualCameraZ - visualOffsetZ)
            masterScene.rootNode.addChildNode(cameraNode)

            // NOTE: Rotation is NOT started here — CharacterSelectionVC starts it
            // after setting the initial facing angle.

            self.characterPreviewScene      = masterScene
            self.characterPreviewCameraNode  = cameraNode
            self.characterPreviewWrapperNode = wrapperNode
            print("✅ AssetLoader: Character preview preloaded")

            // Notify any listener that the preload is ready
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .characterPreviewReady, object: nil)
            }
        }
    }

    // MARK: - Clear Cache
    func clearCache() {
        sceneCache.removeAll()
        characterPreviewScene = nil
        characterPreviewCameraNode = nil
        characterPreviewWrapperNode = nil
    }
}

// MARK: - Notification Name
extension Notification.Name {
    static let characterPreviewReady = Notification.Name("characterPreviewReady")
}

// MARK: - SCNNode Extension for Cloning with Animations
extension SCNNode {
    func cloneWithAnimations() -> SCNNode {
        let cloned = self.clone()
        
        // Copy animations
        for key in self.animationKeys {
            if let animation = self.animationPlayer(forKey: key) {
                cloned.addAnimationPlayer(animation, forKey: key)
            }
        }
        
        return cloned
    }
}
