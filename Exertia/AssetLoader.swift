//
//  AssetLoader.swift
//  Exeria_Game_Final_1
//
//  Created by admin62 on 05/02/26.
//

import SceneKit

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
    
    // MARK: - Clear Cache
    func clearCache() {
        sceneCache.removeAll()
    }
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
