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
    private let characterScale: Float = 0.072
    /// Shift the character left (–) or right (+) in scene units
    private let characterOffsetX: Float = 0.0
    /// Shift the character down (–) or up (+) in scene units
    private let characterOffsetY: Float = -1.2
    /// Move the character closer (+) or further away (–) from the camera
    private let characterOffsetZ: Float = 0.4

    var gameData = GameData.shared
    var currentViewingIndex: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        backgroundImageView.addBlurEffect(style: .dark, alpha: 0.3)
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

        guard let scene = SCNScene(named: "Character.scnassets/Idle.dae") else {
            print("⚠️ Could not load Character.scnassets/Idle.dae")
            return
        }

        let pivot = SCNNode()
        let children = scene.rootNode.childNodes
        children.forEach {
            $0.removeFromParentNode()
            pivot.addChildNode($0)
        }
        scene.rootNode.addChildNode(pivot)
        characterNode = pivot

        let (minB, maxB) = pivot.boundingBox
        let modelHeight = maxB.y - minB.y
        let autoScale: Float = modelHeight > 0 ? (1.8 / modelHeight) * characterScale : characterScale
        pivot.scale = SCNVector3(autoScale, autoScale, autoScale)

        let midX = (minB.x + maxB.x) / 2 * autoScale
        let midY = (minB.y + maxB.y) / 2 * autoScale
        pivot.position = SCNVector3(-midX + characterOffsetX, -midY + characterOffsetY, characterOffsetZ)

        let ambientNode = SCNNode()
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = UIColor.white
        ambient.intensity = 600
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let dirNode = SCNNode()
        let dir = SCNLight()
        dir.type = .directional
        dir.color = UIColor.white
        dir.intensity = 900
        dirNode.light = dir
        dirNode.eulerAngles = SCNVector3(-Float.pi / 4, -Float.pi / 6, 0)
        scene.rootNode.addChildNode(dirNode)

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 50
        cameraNode.position = SCNVector3(0, 0, 3.5)
        scene.rootNode.addChildNode(cameraNode)

        scnView.scene = scene
        scnView.pointOfView = cameraNode

        playIdleAnimation(on: pivot)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleCharacterPan(_:)))
        scnView.addGestureRecognizer(pan)
    }

    private func playIdleAnimation(on node: SCNNode) {
        node.enumerateChildNodes { child, _ in
            for key in child.animationKeys {
                if let player = child.animationPlayer(forKey: key) {
                    player.animation.repeatCount = .infinity
                    player.play()
                }
            }
        }
    }

    @objc private func handleCharacterPan(_ gesture: UIPanGestureRecognizer) {
        guard let node = characterNode else { return }
        let translation = gesture.translation(in: gesture.view)
        switch gesture.state {
        case .began:
            lastPanX = translation.x
        case .changed:
            let delta = translation.x - lastPanX
            lastPanX = translation.x
            node.eulerAngles.y += Float(delta) * 0.01
        default:
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
            blurView.layer.cornerRadius = 22
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
            nextButton.layer.cornerRadius = 22
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
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func profileTapped() {
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
        
        let gridHeight: CGFloat = 190
        
        NSLayoutConstraint.activate([
            tabBarContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -5),
            tabBarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            tabBarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            tabBarContainer.heightAnchor.constraint(equalToConstant: 70),
            
            tabBarStackView.topAnchor.constraint(equalTo: tabBarContainer.topAnchor),
            tabBarStackView.bottomAnchor.constraint(equalTo: tabBarContainer.bottomAnchor),
            tabBarStackView.leadingAnchor.constraint(equalTo: tabBarContainer.leadingAnchor, constant: 10),
            tabBarStackView.trailingAnchor.constraint(equalTo: tabBarContainer.trailingAnchor, constant: -10),
            

            collectionView.bottomAnchor.constraint(equalTo: tabBarContainer.topAnchor, constant: -10),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            collectionView.heightAnchor.constraint(equalToConstant: gridHeight),
            
            descriptionLabel.bottomAnchor.constraint(equalTo: collectionView.topAnchor, constant: -20),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            nameLabel.bottomAnchor.constraint(equalTo: descriptionLabel.topAnchor, constant: -10),
            nameLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            nextButton.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            nextButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            nextButton.widthAnchor.constraint(equalToConstant: 44),
            nextButton.heightAnchor.constraint(equalToConstant: 44),
            
            mainCharacterImageView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 5),
            mainCharacterImageView.bottomAnchor.constraint(equalTo: nameLabel.topAnchor, constant: -20),
            mainCharacterImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            mainCharacterImageView.widthAnchor.constraint(lessThanOrEqualToConstant: 280)
        ])
    }
    
    func setupGlassTabBarDesign() {
        tabBarContainer.backgroundColor = .clear
        tabBarContainer.subviews.filter { $0 is UIVisualEffectView }.forEach { $0.removeFromSuperview() }
        
        let blurEffect = UIBlurEffect(style: .systemThinMaterialDark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = 35
        blurView.clipsToBounds = true
        blurView.isUserInteractionEnabled = false
        tabBarContainer.insertSubview(blurView, at: 0)
        
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: tabBarContainer.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: tabBarContainer.bottomAnchor),
            blurView.leadingAnchor.constraint(equalTo: tabBarContainer.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: tabBarContainer.trailingAnchor)
        ])
        
        tabBarContainer.layer.cornerRadius = 35
        tabBarContainer.layer.borderWidth = 1.0
        tabBarContainer.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        
        indicatorView.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        indicatorView.layer.cornerRadius = 30
        indicatorView.layer.cornerCurve = .continuous
        tabBarContainer.insertSubview(indicatorView, at: 1)
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
            iconImageView.widthAnchor.constraint(equalToConstant: 44).isActive = true
            iconImageView.heightAnchor.constraint(equalToConstant: 34).isActive = true
            
            let label = UILabel()
            label.text = title
            label.font = UIFont.systemFont(ofSize: 10, weight: .semibold)
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
        UIView.animate(withDuration: animated ? 0.4 : 0.0, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
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
    private var spacingBetweenCells: CGFloat { return 15 }
    private var edgeInsetPadding: CGFloat { return 16 }
    private var cellsPerRow: CGFloat { return 3 }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return gameData.players.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CharacterCellID", for: indexPath) as? CharacterCell else { return UICollectionViewCell() }
        let player = gameData.players[indexPath.row]
        let isLocked = indexPath.row > 0          // only the first character is unlocked for now
        let isCurrentlyViewing = (indexPath.row == currentViewingIndex) && !isLocked
        cell.configure(player: player, isSelected: isCurrentlyViewing, isLocked: isLocked)
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
        let height: CGFloat = 70.0
        return CGSize(width: width, height: height)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 10, left: edgeInsetPadding, bottom: 10, right: edgeInsetPadding)
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
