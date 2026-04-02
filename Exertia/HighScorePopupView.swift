import SwiftUI
import SceneKit

// MARK: - Confetti Emitter (UIKit CAEmitterLayer wrapped for SwiftUI)
struct ConfettiView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let host = UIView(frame: .zero)
        host.backgroundColor = .clear
        host.isUserInteractionEnabled = false

        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: UIScreen.main.bounds.midX, y: -20)
        emitter.emitterSize     = CGSize(width: UIScreen.main.bounds.width * 1.2, height: 1)
        emitter.emitterShape    = .line
        emitter.renderMode      = .additive

        let colors: [UIColor] = [
            UIColor(red: 1.0, green: 0.75, blue: 0.0, alpha: 1),  // amber
            UIColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 1),  // cyan
            UIColor(red: 1.0, green: 0.3,  blue: 0.4, alpha: 1),  // coral
            UIColor(red: 0.6, green: 0.4,  blue: 1.0, alpha: 1),  // purple
            UIColor(red: 0.2, green: 1.0,  blue: 0.5, alpha: 1),  // green
            UIColor.white
        ]

        emitter.emitterCells = colors.map { color in
            let cell = CAEmitterCell()
            cell.birthRate        = 12
            cell.lifetime         = 6.0
            cell.velocity         = 120
            cell.velocityRange    = 60
            cell.emissionLongitude = .pi
            cell.emissionRange    = .pi / 4
            cell.spin             = 3.0
            cell.spinRange        = 6.0
            cell.scale            = 0.06
            cell.scaleRange       = 0.04
            cell.color            = color.cgColor
            cell.alphaSpeed       = -0.15
            cell.yAcceleration    = 80

            // Tiny rectangle as confetti piece
            let size = CGSize(width: 12, height: 8)
            UIGraphicsBeginImageContextWithOptions(size, false, 0)
            color.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 1.5).fill()
            cell.contents = UIGraphicsGetImageFromCurrentImageContext()?.cgImage
            UIGraphicsEndImageContext()

            return cell
        }

        host.layer.addSublayer(emitter)

        // Stop emission after a burst
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            emitter.birthRate = 0
        }

        return host
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - 3D Dancing Character (SceneKit wrapped for SwiftUI)
struct DancingCharacterView: UIViewRepresentable {

    func makeUIView(context: Context) -> UIView {
        // Container that SwiftUI will size — SCNView goes inside it
        let container = UIView()
        container.backgroundColor = .clear
        container.clipsToBounds = true

        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.allowsCameraControl = false
        scnView.autoenablesDefaultLighting = false
        scnView.antialiasingMode = .multisampling4X
        scnView.clipsToBounds = true
        scnView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scnView)

        // Pin SCNView to fill the container exactly
        NSLayoutConstraint.activate([
            scnView.topAnchor.constraint(equalTo: container.topAnchor),
            scnView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            scnView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scnView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])

        // Load mesh from Idle.dae (contains full skeleton + skin)
        guard let importedScene = SCNScene(named: "Character.scnassets/Idle.dae") else {
            return container
        }

        let masterScene = SCNScene()
        let characterShell = importedScene.rootNode.clone()
        masterScene.rootNode.addChildNode(characterShell)

        // Apply material styling (matching CharacterSelectionViewController)
        let chestNodes: Set<String> = ["chest_armor_detail", "chest_armor_detail-001", "chest_armor_main"]
        let darkSuit = UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1)
        let exactPink = UIColor(red: 194/255.0, green: 149/255.0, blue: 144/255.0, alpha: 1.0)

        characterShell.enumerateChildNodes { node, _ in
            if let name = node.name?.lowercased(),
               let geometry = node.geometry {
                for material in geometry.materials {
                    material.isDoubleSided = false
                    material.lightingModel = .phong

                    if name == "____helm" {
                        material.diffuse.contents = UIColor(red: 0.90, green: 0.90, blue: 0.92, alpha: 1)
                        material.specular.contents = UIColor(white: 0.15, alpha: 1.0)
                    } else if name == "cube-001" {
                        material.diffuse.contents = UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1)
                        material.specular.contents = UIColor.white
                        material.shininess = 1.0
                    } else if name == "stomach_plate" {
                        material.diffuse.contents = UIColor(red: 0.78, green: 0.78, blue: 0.80, alpha: 1)
                        material.specular.contents = UIColor(white: 0.15, alpha: 1.0)
                    } else if chestNodes.contains(name) {
                        material.diffuse.contents = UIColor.white
                        material.specular.contents = UIColor(white: 0.15, alpha: 1.0)
                    } else if material.name == "undersuit" {
                        material.diffuse.contents = darkSuit
                        material.specular.contents = UIColor(white: 0.1, alpha: 1.0)
                    } else if material.name == "metallic_pink" {
                        material.diffuse.contents = exactPink
                        material.specular.contents = UIColor(white: 0.7, alpha: 1.0)
                        material.shininess = 0.5
                    } else if material.name == "white_suit" {
                        material.diffuse.contents = UIColor.white
                        material.specular.contents = UIColor(white: 0.2, alpha: 1.0)
                    } else if material.name == "neon_glow" {
                        material.diffuse.contents = UIColor.black
                        material.emission.contents = UIColor.black
                    } else {
                        material.diffuse.contents = darkSuit
                    }
                }
            }
        }

        // Use CharacterSelectionVC's approach: native scale, camera pushed back
        characterShell.scale = SCNVector3(1, 1, 1)

        let (minB, maxB) = characterShell.boundingBox
        let modelHeight = maxB.y - minB.y
        let midX = (minB.x + maxB.x) / 2
        let midY = (minB.y + maxB.y) / 2
        characterShell.position = SCNVector3(-midX, -midY, 0)

        // Lighting
        masterScene.lightingEnvironment.contents = UIColor(white: 0.2, alpha: 1.0)

        let ambientNode = SCNNode()
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = UIColor.white
        ambient.intensity = 600
        ambientNode.light = ambient
        masterScene.rootNode.addChildNode(ambientNode)

        let dirNode = SCNNode()
        let dir = SCNLight()
        dir.type = .directional
        dir.color = UIColor.white
        dir.intensity = 900
        dirNode.light = dir
        dirNode.eulerAngles = SCNVector3(-Float.pi / 4, -Float.pi / 6, 0)
        masterScene.rootNode.addChildNode(dirNode)

        // Camera — same inverse-proportional approach as CharacterSelectionVC
        let autoScale: Float = modelHeight > 0 ? (1.8 / modelHeight) : 0.01
        let cameraZ = 3.5 / autoScale

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 50
        cameraNode.camera?.zNear = Double(cameraZ) * 0.05
        cameraNode.camera?.zFar = Double(cameraZ) * 5.0
        cameraNode.position = SCNVector3(0, 0, cameraZ)
        masterScene.rootNode.addChildNode(cameraNode)

        scnView.scene = masterScene
        scnView.pointOfView = cameraNode
        scnView.isPlaying = true

        // Graft Wave Hip Hop Dance animation onto the skeleton
        injectDanceAnimation(into: characterShell)

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}


    private func injectDanceAnimation(into targetArmature: SCNNode) {
        guard let animScene = SCNScene(named: "Character.scnassets/Wave Hip Hop Dance.dae") else {
            print("⚠️ Could not load Wave Hip Hop Dance.dae")
            return
        }

        func spliceAnimationKeys(from sourceBone: SCNNode, to targetBone: SCNNode) {
            for key in sourceBone.animationKeys {
                if let player = sourceBone.animationPlayer(forKey: key) {
                    player.animation.repeatCount = .infinity
                    if let boneName = sourceBone.name,
                       let matchingBone = targetBone.childNode(withName: boneName, recursively: true) {
                        matchingBone.addAnimationPlayer(player, forKey: key)
                    } else {
                        targetBone.addAnimationPlayer(player, forKey: key)
                    }
                }
            }
            sourceBone.childNodes.forEach { spliceAnimationKeys(from: $0, to: targetBone) }
        }

        spliceAnimationKeys(from: animScene.rootNode, to: targetArmature)
    }
}

// MARK: - High Score Popup View
struct HighScorePopupView: View {
    let metricName: String
    let newValue: String
    let oldValue: String
    let unit: String
    var onContinue: () -> Void

    @State private var animateEntrance = false
    @State private var animateGlow = false

    // Core Colors
    let neonCyan = Color(red: 0.0, green: 0.95, blue: 1.0)
    let neonAmber = Color(red: 1.0, green: 0.75, blue: 0.0)
    let bgDark = Color(red: 0.02, green: 0.02, blue: 0.06)

    var body: some View {
        ZStack {
            // Dark Background
            Color.black.opacity(0.88).ignoresSafeArea()

            // Pulsing Glow Orbs
            GeometryReader { geo in
                Circle()
                    .fill(neonAmber.opacity(0.15))
                    .frame(width: 350, height: 350)
                    .blur(radius: 80)
                    .offset(x: geo.size.width * 0.5 - 175, y: geo.size.height * 0.15)
                    .scaleEffect(animateGlow ? 1.2 : 0.8)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animateGlow)

                Circle()
                    .fill(neonCyan.opacity(0.1))
                    .frame(width: 300, height: 300)
                    .blur(radius: 70)
                    .offset(x: geo.size.width * 0.5 - 150, y: geo.size.height * 0.65)
                    .scaleEffect(animateGlow ? 1.1 : 0.9)
                    .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(0.5), value: animateGlow)
            }
            .ignoresSafeArea()

            // Confetti Burst
            ConfettiView()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 16) {
                // Header Icon
                Image(systemName: "crown.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(colors: [neonAmber, neonAmber.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: neonAmber.opacity(0.6), radius: animateGlow ? 25 : 10)
                    .scaleEffect(animateEntrance ? 1.0 : 0.4)
                    .opacity(animateEntrance ? 1.0 : 0.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.5, blendDuration: 0), value: animateEntrance)

                // Title
                VStack(spacing: 6) {
                    Text("NEW RECORD!")
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundStyle(
                            LinearGradient(colors: [neonAmber, Color.white], startPoint: .leading, endPoint: .trailing)
                        )
                        .shadow(color: neonAmber.opacity(0.5), radius: 10)
                        .tracking(4)

                    Text("\(metricName) BEST BEATEN")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(neonCyan)
                        .tracking(3)
                }
                .scaleEffect(animateEntrance ? 1.0 : 0.8)
                .opacity(animateEntrance ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.5).delay(0.2), value: animateEntrance)

                // 3D Dancing Character
                DancingCharacterView()
                    .frame(height: 220)
                    .clipped()
                    .scaleEffect(animateEntrance ? 1.0 : 0.6)
                    .opacity(animateEntrance ? 1.0 : 0.0)
                    .animation(.spring(response: 0.7, dampingFraction: 0.6, blendDuration: 0).delay(0.3), value: animateEntrance)

                // Score Cards
                HStack(spacing: 20) {
                    // Old Score
                    VStack(spacing: 6) {
                        Text("PREVIOUS")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(1)
                        Text(oldValue)
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                        Text(unit)
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .frame(width: 100, height: 90)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))

                    // Arrow
                    Image(systemName: "arrow.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(neonAmber.opacity(0.7))

                    // New Score
                    VStack(spacing: 6) {
                        Text("NEW BEST")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(neonAmber)
                            .tracking(1)
                        Text(newValue)
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                            .shadow(color: neonAmber.opacity(0.4), radius: 8)
                        Text(unit)
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(neonAmber.opacity(0.6))
                    }
                    .frame(width: 120, height: 105)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 14).fill(neonAmber.opacity(0.15))
                            RoundedRectangle(cornerRadius: 14).stroke(neonAmber.opacity(0.6), lineWidth: 1.5)
                        }
                    )
                    .shadow(color: neonAmber.opacity(0.2), radius: 15)
                }
                .offset(y: animateEntrance ? 0 : 30)
                .opacity(animateEntrance ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.5).delay(0.5), value: animateEntrance)

                Spacer().frame(height: 16)

                // Continue Button
                Button(action: onContinue) {
                    HStack(spacing: 8) {
                        Text("CONTINUE")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .tracking(2)
                        Image(systemName: "chevron.right.2")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(bgDark)
                    .frame(width: 240, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(LinearGradient(colors: [neonAmber, Color(red: 1.0, green: 0.85, blue: 0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .shadow(color: neonAmber.opacity(0.4), radius: 12, y: 5)
                }
                .opacity(animateEntrance ? 1.0 : 0.0)
                .animation(.easeIn(duration: 0.3).delay(0.9), value: animateEntrance)
            }
            .padding(.top, 30)
        }
        .onAppear {
            animateEntrance = true
            animateGlow = true
        }
    }
}
