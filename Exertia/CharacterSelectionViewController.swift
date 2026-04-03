import UIKit
import SceneKit

class CharacterSelectionViewController: UIViewController {

    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var mainCharacterImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var profileButton: UIButton!
    @IBOutlet weak var headerTitleLabel: UILabel!

    private let nextButton = UIButton()
    private let tabBarContainer = UIView()
    private let tabBarStackView = UIStackView()
    private let indicatorView = UIView()
    private var tabIcons: [UIImageView] = []
    private var tabLabels: [UILabel] = []
    private var tabWrappers: [UIView] = []

    // 3D character scene
    private var characterSceneView: SCNView?
    private var characterNode: SCNNode?
    private var lastPanX: CGFloat = 0
    private var sceneSetupDone = false

    /// Adjust to scale the 3D character up or down
    private let characterScale: Float = 0.085
    /// Shift the character left (–) or right (+) in scene units
    private let characterOffsetX: Float = 0.0
    /// Shift the character down (–) or up (+) in scene units
    private let characterOffsetY: Float = 0.0
    /// Move the character closer (+) or further away (–) from the camera
    private let characterOffsetZ: Float = 0.0

    var gameData = GameData.shared
    var currentViewingIndex: Int = 0

    private var headerHeight: CGFloat {
        if Responsive.isIPad { return 72 }
        if Responsive.isSmallPhone { return 56 }
        return 60
    }

    private var headerTopInset: CGFloat {
        if Responsive.isIPad { return 14 }
        if Responsive.isSmallPhone { return 10 }
        return 8
    }

    private var headerButtonSize: CGFloat {
        if Responsive.isIPad { return 50 }
        if Responsive.isSmallPhone { return 42 }
        return 44
    }

    private var profileButtonSize: CGFloat {
        if Responsive.isIPad { return 42 }
        if Responsive.isSmallPhone { return 34 }
        return 36
    }

    private var characterDisplayWidth: CGFloat {
        let screenWidth = max(view.bounds.width, Responsive.screenWidth)
        if Responsive.isIPad { return min(screenWidth * 0.44, 360) }
        if Responsive.isSmallPhone { return min(screenWidth * 0.54, 238) }
        if Responsive.isLargePhone { return min(screenWidth * 0.66, 324) }
        return min(screenWidth * 0.60, 290)
    }

    private var characterTopSpacing: CGFloat {
        if Responsive.isIPad { return 8 }
        if Responsive.isSmallPhone { return 6 }
        return 6
    }

    private var characterToNameSpacing: CGFloat {
        if Responsive.isIPad { return 10 }
        if Responsive.isSmallPhone { return 14 }
        return 14
    }

    private var nameToDescriptionSpacing: CGFloat {
        if Responsive.isIPad { return 8 }
        if Responsive.isSmallPhone { return 8 }
        return 10
    }

    private var descriptionToCollectionSpacing: CGFloat {
        if Responsive.isIPad { return 8 }
        if Responsive.isSmallPhone { return 8 }
        return 10
    }

    private var collectionToTabBarSpacing: CGFloat {
        if Responsive.isIPad { return 10 }
        if Responsive.isSmallPhone { return 18 }
        return 20
    }

    private var descriptionHorizontalInset: CGFloat {
        if Responsive.isIPad { return 120 }
        if Responsive.isSmallPhone { return 24 }
        return 40
    }

    private var collectionHorizontalInset: CGFloat {
        Responsive.isIPad ? 40 : 16
    }

    private var sectionVerticalInset: CGFloat {
        Responsive.isIPad ? 10 : 8
    }

    private var collectionTopInset: CGFloat {
        Responsive.isSmallPhone ? 16 : sectionVerticalInset
    }

    private var collectionBottomInset: CGFloat {
        sectionVerticalInset
    }

    private var cellHeight: CGFloat {
        if Responsive.isIPad { return 92 }
        if Responsive.isSmallPhone { return 66 }
        return 72
    }

    private var collectionHeight: CGFloat {
        let rows = ceil(CGFloat(gameData.players.count) / cellsPerRow)
        let spacing = max(rows - 1, 0) * spacingBetweenCells
        let extraBottomPadding: CGFloat = Responsive.isIPad ? 6 : 24
        return rows * cellHeight + spacing + collectionTopInset + collectionBottomInset + extraBottomPadding
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        backgroundImageView.addBlurEffect(style: .dark, alpha: 0.3)
        configureResponsiveLayout()
        setupGlassStyling()
        setupNextButton()
        setupFinalLayout()
        setupGlassTabBarDesign()
        setupCustomTabs()
        setupCollectionView()
        currentViewingIndex = gameData.getSelectedIndex()
        updateMainDisplay(index: currentViewingIndex)
        profileButton.addTarget(self, action: #selector(profileTapped), for: .touchUpInside)
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backButton.layer.cornerRadius = backButton.frame.height / 2
        profileButton.layer.cornerRadius = profileButton.frame.height / 2
        nextButton.layer.cornerRadius = nextButton.frame.height / 2
        if let blur = nextButton.subviews.first(where: { $0 is UIVisualEffectView }) {
            blur.frame = nextButton.bounds
        }
        tabBarContainer.layoutIfNeeded()
        if tabWrappers.indices.contains(1) {
            moveIndicator(to: tabWrappers[1], animated: false)
        }
        setupCharacterSceneView()
        characterSceneView?.frame = mainCharacterImageView.frame
    }
    // MARK: - 3D Character Scene

    private func setupCharacterSceneView() {
        guard !sceneSetupDone, mainCharacterImageView.frame.width > 0 else { return }
        sceneSetupDone = true

        mainCharacterImageView.isHidden = true

        let scnView = SCNView(frame: mainCharacterImageView.frame)
        scnView.backgroundColor = .clear
        scnView.allowsCameraControl = false
        scnView.autoenablesDefaultLighting = false
        scnView.antialiasingMode = .multisampling4X

        if let superview = mainCharacterImageView.superview,
           let idx = superview.subviews.firstIndex(of: mainCharacterImageView) {
            superview.insertSubview(scnView, at: idx + 1)
        } else {
            view.addSubview(scnView)
        }
        characterSceneView = scnView

        // LOAD THE PHYSICAL GEOMETRY MESH ASYNCHRONOUSLY TO PREVENT MAIN THREAD BLOCKING!
        scnView.alpha = 0
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            guard let importedScene = SCNScene(named: "Character.scnassets/MascotFinal.usdz") else {
                print("⚠️ Could not load Character.scnassets/charMain.usdz")
                return
            }

            // Build a mathematically clean master view scene container!
            let masterScene = SCNScene()
            
            // Safely extract the completely intact payload geometry shell from the freshly parsed .dae without breaking its internal bone/animation target paths!
            let characterShell = importedScene.rootNode.clone()
            
            // Wrap the character in a master container to cleanly handle global spinning without messing up its local Z-up orientation correction!
            let wrapperNode = SCNNode()
            wrapperNode.addChildNode(characterShell)
            masterScene.rootNode.addChildNode(wrapperNode)
            
            // Force the USDZ to stand up if it was exported laying down (Z-up)
            characterShell.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
            
            // Note: MascotFinal.usdz has baked textures, so we DO NOT inject procedural materials here!
            

            
            // Compute bounds AFTER rotation/injection
            let (minB, maxB) = characterShell.boundingBox
            
            // Use the largest dimension as the "height" since bounding box might be weirdly rotated
            let modelSpanX = maxB.x - minB.x
            let modelSpanY = maxB.y - minB.y
            let modelSpanZ = maxB.z - minB.z
            let maxDim = max(modelSpanX, modelSpanY, modelSpanZ)
            
            let autoScale: Float = maxDim > 0 ? (1.8 / maxDim) : 1.0
            
            characterShell.scale = SCNVector3(1, 1, 1)

            let midX = (minB.x + maxB.x) / 2
            let midY = (minB.y + maxB.y) / 2
            
            // Mathematically inversely cleanly scale the standard UI mathematical layout parameter
            let virtualShiftX = self.characterOffsetX / autoScale
            let virtualShiftY = self.characterOffsetY / autoScale
            
            characterShell.position = SCNVector3(-midX + virtualShiftX, -midY + virtualShiftY, 0)

            // VERY IMPORTANT: Since we restored native PBR materials, they need an environment to reflect,
            // otherwise they turn pitch black when you spin the character.
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

            let cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            cameraNode.camera?.fieldOfView = 50
            
            // Re-tuned to 2.1 to pull the camera back slightly and prevent the model from clipping out of the view bounds!
            let visualCameraZ = 2.5 / autoScale
            let visualOffsetZ = self.characterOffsetZ / autoScale
      
            cameraNode.camera?.zNear = Double(visualCameraZ) * 0.05
            cameraNode.camera?.zFar = Double(visualCameraZ) * 5.0
            cameraNode.position = SCNVector3(0, 0, visualCameraZ - visualOffsetZ)
            
            masterScene.rootNode.addChildNode(cameraNode)

            // START SLOW AUTO-ROTATION
            let spin = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 15.0)
            let repeatSpin = SCNAction.repeatForever(spin)
            wrapperNode.runAction(repeatSpin)

            // Safely deploy fully built complex mathematical memory hierarchy onto main UIKit rendering thread smoothly
            DispatchQueue.main.async {
                self.characterNode = wrapperNode
                scnView.scene = masterScene
                scnView.pointOfView = cameraNode
                scnView.isPlaying = true 

                let pan = UIPanGestureRecognizer(target: self, action: #selector(self.handleCharacterPan(_:)))
                scnView.addGestureRecognizer(pan)
                
                UIView.animate(withDuration: 0.4) {
                    scnView.alpha = 1.0
                }
            }
        }
    }



    @objc private func handleCharacterPan(_ gesture: UIPanGestureRecognizer) {
        guard let node = characterNode else { return }
        
        // Temporarily pause auto-rotation while user is aggressively swiping
        switch gesture.state {
        case .began:
            lastPanX = gesture.translation(in: gesture.view).x
            node.isPaused = true
        case .changed:
            let translation = gesture.translation(in: gesture.view).x
            let delta = translation - lastPanX
            lastPanX = translation
            node.eulerAngles.y += Float(delta) * 0.01
        default:
            node.isPaused = false
            break
        }
    }

        func setupNextButton() {
            view.addSubview(nextButton)
            nextButton.translatesAutoresizingMaskIntoConstraints = false
            let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)
            let icon = UIImage(systemName: "chevron.right", withConfiguration: config)
            nextButton.setImage(icon, for: .normal)
            nextButton.tintColor = .white
            nextButton.backgroundColor = .clear
            let blurEffect = UIBlurEffect(style: .regular)
            let blurView = UIVisualEffectView(effect: blurEffect)
            blurView.isUserInteractionEnabled = false
            blurView.layer.cornerRadius = Responsive.cornerRadius(22)
            blurView.clipsToBounds = true
            blurView.translatesAutoresizingMaskIntoConstraints = false
            nextButton.insertSubview(blurView, at: 0)
            nextButton.imageView?.layer.zPosition = 1
            if let imageView = nextButton.imageView {
                nextButton.bringSubviewToFront(imageView)
            }
            
            NSLayoutConstraint.activate([
                blurView.topAnchor.constraint(equalTo: nextButton.topAnchor),
                blurView.bottomAnchor.constraint(equalTo: nextButton.bottomAnchor),
                blurView.leadingAnchor.constraint(equalTo: nextButton.leadingAnchor),
                blurView.trailingAnchor.constraint(equalTo: nextButton.trailingAnchor)
            ])
            nextButton.layer.cornerRadius = Responsive.cornerRadius(22)
            nextButton.layer.borderWidth = 1.5
            nextButton.layer.borderColor = UIColor.white.withAlphaComponent(0.6).cgColor
            nextButton.addTarget(self, action: #selector(confirmAndGoHome), for: .touchUpInside)
        }
    
    func setupGlassStyling() {
        applyGlassEffect(to: backButton, iconName: "chevron.left")
        profileButton.backgroundColor = .clear
        profileButton.layer.cornerRadius = 18
        profileButton.layer.borderWidth = 1
        profileButton.layer.borderColor = UIColor.white.withAlphaComponent(0.8).cgColor
        profileButton.clipsToBounds = true
    }

    private func configureResponsiveLayout() {
        if let topConstraint = view.constraints.first(where: {
            (($0.firstItem as? UILayoutGuide) === view.safeAreaLayoutGuide && ($0.secondItem as? UIView) === headerView && $0.firstAttribute == .top && $0.secondAttribute == .top) ||
            (($0.firstItem as? UIView) === headerView && ($0.secondItem as? UILayoutGuide) === view.safeAreaLayoutGuide && $0.firstAttribute == .top && $0.secondAttribute == .top)
        }) {
            topConstraint.constant = headerTopInset
        }

        if let headerHeightConstraint = headerView.constraints.first(where: {
            ($0.firstItem as? UIView) == headerView && $0.firstAttribute == .height
        }) {
            headerHeightConstraint.constant = headerHeight
        }

        if let widthConstraint = mainCharacterImageView.constraints.first(where: {
            ($0.firstItem as? UIImageView) == mainCharacterImageView && $0.firstAttribute == .width
        }) {
            widthConstraint.constant = characterDisplayWidth
        }

        if let backButtonWidthConstraint = backButton.constraints.first(where: { $0.firstAttribute == .width }) {
            backButtonWidthConstraint.constant = headerButtonSize
        }

        if let profileButtonWidthConstraint = profileButton.constraints.first(where: { $0.firstAttribute == .width }) {
            profileButtonWidthConstraint.constant = profileButtonSize
        }

        headerTitleLabel.font = UIFont.systemFont(
            ofSize: Responsive.isIPad ? 25 : (Responsive.isSmallPhone ? 19 : 21),
            weight: .bold
        )
        nameLabel.font = UIFont(
            name: "Audiowide-Regular",
            size: Responsive.isIPad ? 46 : (Responsive.isSmallPhone ? 30 : 38)
        )
        descriptionLabel.font = UIFont(
            name: "Audiowide-Regular",
            size: Responsive.isIPad ? 18 : (Responsive.isSmallPhone ? 15 : 18)
        )
    }
    
    func applyGlassEffect(to button: UIButton, iconName: String?) {
        button.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        
        if let iconName = iconName {
            let config = UIImage.SymbolConfiguration(weight: .bold)
            button.setImage(UIImage(systemName: iconName, withConfiguration: config), for: .normal)
            button.tintColor = .white
        }
    }
    
    @objc func confirmAndGoHome() {
        AudioManager.shared.playEffect(.characterSelected)
        let success = gameData.selectPlayer(at: currentViewingIndex)
        if success {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            var candidate = self.presentingViewController
            while candidate != nil {
                if candidate is HomeViewController {
                    candidate?.dismiss(animated: true, completion: nil)
                    return
                }
                candidate = candidate?.presentingViewController
            }
            let sb = UIStoryboard(name: "Main", bundle: nil)
            if let homeVC = sb.instantiateViewController(withIdentifier: "HomeViewController") as? HomeViewController {
                homeVC.modalPresentationStyle = .fullScreen
                homeVC.modalTransitionStyle = .crossDissolve
                self.present(homeVC, animated: true)
            }
        }
    }
    
    @IBAction func backButtonTapped(_ sender: UIButton) {
        AudioManager.shared.playEffect(.buttonTapped)
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func profileTapped() {
        AudioManager.shared.playEffect(.buttonTapped)
        let sb = UIStoryboard(name: "Main", bundle: nil)
        if let vc = sb.instantiateViewController(withIdentifier: "ProfileViewController") as? ProfileViewController {
            vc.modalPresentationStyle = .fullScreen
            vc.modalTransitionStyle = .crossDissolve
            self.present(vc, animated: true)
        }
    }
    
    func setupFinalLayout() {
        view.addSubview(tabBarContainer)
        tabBarContainer.addSubview(tabBarStackView)
        view.bringSubviewToFront(nextButton)
        view.bringSubviewToFront(tabBarContainer)
        let programmaticViews: [UIView?] = [mainCharacterImageView, nameLabel, descriptionLabel,
                                            collectionView, tabBarContainer, tabBarStackView, nextButton]
        
        programmaticViews.forEach {
            $0?.translatesAutoresizingMaskIntoConstraints = false
        }
        
        mainCharacterImageView.contentMode = .scaleAspectFit
        descriptionLabel.numberOfLines = 0
        descriptionLabel.textAlignment = .center
        
        descriptionLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        nameLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        collectionView.setContentCompressionResistancePriority(.required, for: .vertical)
        mainCharacterImageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        
        NSLayoutConstraint.activate([
            tabBarContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -5),
            tabBarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Responsive.contentInset),
            tabBarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Responsive.contentInset),
            tabBarContainer.heightAnchor.constraint(equalToConstant: Responsive.tabBarHeight),
            
            tabBarStackView.topAnchor.constraint(equalTo: tabBarContainer.topAnchor),
            tabBarStackView.bottomAnchor.constraint(equalTo: tabBarContainer.bottomAnchor),
            tabBarStackView.leadingAnchor.constraint(equalTo: tabBarContainer.leadingAnchor, constant: 10),
            tabBarStackView.trailingAnchor.constraint(equalTo: tabBarContainer.trailingAnchor, constant: -10),
            

            collectionView.bottomAnchor.constraint(equalTo: tabBarContainer.topAnchor, constant: -collectionToTabBarSpacing),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: collectionHorizontalInset),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -collectionHorizontalInset),
            collectionView.heightAnchor.constraint(equalToConstant: collectionHeight),
            
            descriptionLabel.bottomAnchor.constraint(equalTo: collectionView.topAnchor, constant: -descriptionToCollectionSpacing),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: descriptionHorizontalInset),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -descriptionHorizontalInset),
            
            nameLabel.bottomAnchor.constraint(equalTo: descriptionLabel.topAnchor, constant: -nameToDescriptionSpacing),
            nameLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            nextButton.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            nextButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            nextButton.widthAnchor.constraint(equalToConstant: Responsive.size(44)),
            nextButton.heightAnchor.constraint(equalToConstant: Responsive.size(44)),
            
            mainCharacterImageView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: characterTopSpacing),
            mainCharacterImageView.bottomAnchor.constraint(equalTo: nameLabel.topAnchor, constant: -characterToNameSpacing),
            mainCharacterImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            mainCharacterImageView.widthAnchor.constraint(lessThanOrEqualToConstant: characterDisplayWidth)
        ])
    }
    
    func setupGlassTabBarDesign() {
        tabBarContainer.backgroundColor = .clear
        tabBarContainer.subviews.filter { $0 is UIVisualEffectView }.forEach { $0.removeFromSuperview() }
        
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialDark) // Liquid glass
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = Responsive.tabBarCornerRadius
        blurView.clipsToBounds = true
        blurView.isUserInteractionEnabled = false
        tabBarContainer.insertSubview(blurView, at: 0)

        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: tabBarContainer.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: tabBarContainer.bottomAnchor),
            blurView.leadingAnchor.constraint(equalTo: tabBarContainer.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: tabBarContainer.trailingAnchor)
        ])

        tabBarContainer.layer.cornerRadius = Responsive.tabBarCornerRadius
        tabBarContainer.layer.borderWidth = 1.5
        tabBarContainer.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        
        // Fluid glowing ambient shadow
        tabBarContainer.layer.shadowColor = UIColor.white.cgColor
        tabBarContainer.layer.shadowRadius = 15
        tabBarContainer.layer.shadowOpacity = 0.2
        tabBarContainer.layer.shadowOffset = .zero
        
        indicatorView.backgroundColor = UIColor.white.withAlphaComponent(0.25)
        indicatorView.layer.cornerRadius = 30
        indicatorView.layer.cornerCurve = .continuous
        indicatorView.layer.shadowColor = UIColor.white.cgColor
        indicatorView.layer.shadowRadius = 8
        indicatorView.layer.shadowOpacity = 0.4
        indicatorView.layer.shadowOffset = .zero
        tabBarContainer.insertSubview(indicatorView, at: 1)
        
        // Gesture Recognizers for Swipe Navigation
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleTabSwipe(_:)))
        swipeLeft.direction = .left
        tabBarContainer.addGestureRecognizer(swipeLeft)
        
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleTabSwipe(_:)))
        swipeRight.direction = .right
        tabBarContainer.addGestureRecognizer(swipeRight)
    }

    @objc private func handleTabSwipe(_ gesture: UISwipeGestureRecognizer) {
        if gesture.direction == .left { // Swipe left goes to next tab (Statistics)
            AudioManager.shared.playEffect(.buttonTapped)
            let sb = UIStoryboard(name: "Main", bundle: nil)
            if let vc = sb.instantiateViewController(withIdentifier: "StatisticsViewController") as? StatisticsViewController {
                vc.modalPresentationStyle = .fullScreen
                let transition = CATransition()
                transition.duration = 0.3
                transition.type = .push
                transition.subtype = .fromRight
                transition.timingFunction = CAMediaTimingFunction(name: .easeOut)
                view.window?.layer.add(transition, forKey: kCATransition)
                self.present(vc, animated: false)
            }
        } else if gesture.direction == .right { // Swipe right goes purely back to previous tab (Home)
            AudioManager.shared.playEffect(.buttonTapped)
            var candidate = self.presentingViewController
            while candidate != nil {
                if candidate is HomeViewController {
                    let transition = CATransition()
                    transition.duration = 0.3
                    transition.type = .push
                    transition.subtype = .fromLeft
                    transition.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    view.window?.layer.add(transition, forKey: kCATransition)
                    candidate?.dismiss(animated: false, completion: nil)
                    return
                }
                candidate = candidate?.presentingViewController
            }
            
            // Fallback backward push if HomeViewController isn't found
            let transition = CATransition()
            transition.duration = 0.3
            transition.type = .push
            transition.subtype = .fromLeft
            transition.timingFunction = CAMediaTimingFunction(name: .easeOut)
            view.window?.layer.add(transition, forKey: kCATransition)
            self.dismiss(animated: false, completion: nil)
        }
    }
    
    func setupCustomTabs() {
        tabBarStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        tabIcons.removeAll(); tabLabels.removeAll(); tabWrappers.removeAll()
        tabBarStackView.distribution = .fillEqually
        
        let items = [("home2", "Home"), ("customize2", "Customize"), ("statistics2", "Statistics")]
        
        for (index, (iconName, title)) in items.enumerated() {
            let containerStack = UIStackView()
            containerStack.axis = .vertical
            containerStack.alignment = .center
            containerStack.spacing = 2
            containerStack.isUserInteractionEnabled = false
            
            let iconImageView = UIImageView(image: UIImage(named: iconName))
            iconImageView.contentMode = .scaleAspectFit
            iconImageView.translatesAutoresizingMaskIntoConstraints = false
            iconImageView.widthAnchor.constraint(equalToConstant: Responsive.size(44)).isActive = true
            iconImageView.heightAnchor.constraint(equalToConstant: Responsive.size(34)).isActive = true

            let label = UILabel()
            label.text = title
            label.font = UIFont.systemFont(ofSize: Responsive.font(10), weight: .semibold)
            label.textColor = .lightGray
            label.textAlignment = .center
            
            tabIcons.append(iconImageView)
            tabLabels.append(label)
            containerStack.addArrangedSubview(iconImageView)
            containerStack.addArrangedSubview(label)
            
            let button = UIButton()
            button.tag = index
            button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            button.translatesAutoresizingMaskIntoConstraints = false
            
            let wrapperView = UIView()
            wrapperView.translatesAutoresizingMaskIntoConstraints = false
            wrapperView.addSubview(containerStack)
            wrapperView.addSubview(button)
            tabWrappers.append(wrapperView)
            
            containerStack.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                containerStack.centerXAnchor.constraint(equalTo: wrapperView.centerXAnchor),
                containerStack.centerYAnchor.constraint(equalTo: wrapperView.centerYAnchor),
                button.topAnchor.constraint(equalTo: wrapperView.topAnchor),
                button.bottomAnchor.constraint(equalTo: wrapperView.bottomAnchor),
                button.leadingAnchor.constraint(equalTo: wrapperView.leadingAnchor),
                button.trailingAnchor.constraint(equalTo: wrapperView.trailingAnchor)
            ])
            tabBarStackView.addArrangedSubview(wrapperView)
        }
    }
    
    @objc func tabTapped(_ sender: UIButton) {
        AudioManager.shared.playEffect(.buttonTapped)
        let index = sender.tag
        moveIndicator(to: tabWrappers[index], animated: true)
        
        switch index {
        case 0:
            // Go back to Home
            var candidate = self.presentingViewController
            while candidate != nil {
                if candidate is HomeViewController {
                    candidate?.dismiss(animated: true, completion: nil)
                    return
                }
                candidate = candidate?.presentingViewController
            }
            self.dismiss(animated: true, completion: nil)
        case 1: break  // Already on Customize
        case 2:
            // Statistics
            let sb = UIStoryboard(name: "Main", bundle: nil)
            if let vc = sb.instantiateViewController(withIdentifier: "StatisticsViewController") as? StatisticsViewController {
                vc.modalPresentationStyle = .fullScreen
                vc.modalTransitionStyle = .crossDissolve
                self.present(vc, animated: true)
            }
        default: break
        }
    }
    
    func moveIndicator(to targetView: UIView, animated: Bool) {
        let targetFrame = targetView.convert(targetView.bounds, to: tabBarContainer)
        let paddedFrame = targetFrame.insetBy(dx: 4, dy: 4)
        // Fluid spring (liquid glass feel) for indicator movement
        UIView.animate(withDuration: animated ? 0.5 : 0.0, delay: 0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.8, options: .curveEaseOut, animations: {
            self.indicatorView.frame = paddedFrame
        }, completion: nil)
        for (i, icon) in tabIcons.enumerated() {
            let isSelected = (tabWrappers[i] == targetView)
            UIView.animate(withDuration: 0.3) {
                icon.alpha = isSelected ? 1.0 : 0.5
                self.tabLabels[i].textColor = isSelected ? .white : .lightGray
                self.tabLabels[i].alpha = isSelected ? 1.0 : 0.5
            }
        }
    }
    
    func updateMainDisplay(index: Int) {
        let player = gameData.players[index]
        nameLabel.text = player.name.uppercased()
        descriptionLabel.text = player.description
        
        UIView.transition(with: mainCharacterImageView, duration: 0.3, options: .transitionCrossDissolve, animations: {
            self.mainCharacterImageView.image = UIImage(named: player.fullBodyImageName)
        }, completion: nil)
        
        UIView.transition(with: backgroundImageView, duration: 0.5, options: .transitionCrossDissolve, animations: {
            self.backgroundImageView.image = UIImage(named: player.backgroundImageName)
        }, completion: nil)
    }
    
    func setupCollectionView() {
        collectionView.delegate = self
        collectionView.dataSource = self
        let nib = UINib(nibName: "CharacterCell", bundle: nil)
        collectionView.register(nib, forCellWithReuseIdentifier: "CharacterCellID")
        collectionView.backgroundColor = .clear
    }
}

extension CharacterSelectionViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private var spacingBetweenCells: CGFloat {
        Responsive.isIPad ? 18 : 14
    }

    private var edgeInsetPadding: CGFloat {
        Responsive.isIPad ? 20 : 16
    }

    private var cellsPerRow: CGFloat { return 3 }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return gameData.players.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CharacterCellID", for: indexPath) as? CharacterCell else { return UICollectionViewCell() }
        let player = gameData.players[indexPath.row]
        let isLocked = indexPath.row > 0          // only the first character is unlocked for now
        let isCurrentlyViewing = (indexPath.row == currentViewingIndex) && !isLocked
        cell.configure(player: player, isSelected: isCurrentlyViewing, isLocked: isLocked, characterIndex: indexPath.row)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Locked characters are non-interactive — silently ignore taps on them
        guard indexPath.row == 0 else { return }
        currentViewingIndex = indexPath.row
        updateMainDisplay(index: currentViewingIndex)
        collectionView.reloadData()
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let totalPadding = (edgeInsetPadding * 2)
        let totalSpacing = (cellsPerRow - 1) * spacingBetweenCells
        let availableWidth = collectionView.bounds.width - totalPadding - totalSpacing
        let width = floor(availableWidth / cellsPerRow)
        return CGSize(width: width, height: cellHeight)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: collectionTopInset, left: edgeInsetPadding, bottom: collectionBottomInset, right: edgeInsetPadding)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return spacingBetweenCells
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return spacingBetweenCells
    }
}

extension UIImageView {
    func addBlurEffect(style: UIBlurEffect.Style = .regular, alpha: CGFloat = 1.0) {
        removeBlurEffect()
        let blurEffect = UIBlurEffect(style: style)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = self.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurEffectView.alpha = alpha
        self.addSubview(blurEffectView)
    }
    func removeBlurEffect() {
        for subview in self.subviews { if subview is UIVisualEffectView { subview.removeFromSuperview() } }
    }
}
