import UIKit
import SceneKit

// MARK: - HighScoreViewController
/// Fullscreen high-score celebration screen (pure UIKit).
/// All 3-D character controls are in the clearly-marked TUNE section below.

final class HighScoreViewController: UIViewController {

    // ═══════════════════════════════════════════════════════════════════
    // MARK: - ▼ TUNE THESE ▼
    // ───────────────────────────────────────────────────────────────────
    // These mirror the exact constants used in CharacterSelectionViewController
    // so the character appears at the same size and position as it does there.

    /// Height of the 3-D character window in points.
    let characterViewHeight: CGFloat = 390

    /// Gap between the subtitle and the top of the character window.
    let characterTopSpacing: CGFloat = 8

    /// Overall size of the character in the scene.
    /// Matches CharacterSelectionViewController's characterScale = 0.085.
    /// Smaller = character appears smaller/further; larger = bigger/closer.
    let characterScale: Float = 0.085

    /// Shifts the character UP (+) or DOWN (-) within the viewport.
    /// Applied to the model node — not the camera.
    /// Matches CharacterSelectionViewController's characterOffsetY = -1.2.
    let characterOffsetY: Float = -1.2

    /// Pulls the camera CLOSER (+) or FURTHER (-) from the character.
    /// Matches CharacterSelectionViewController's characterOffsetZ = 0.4.
    let characterOffsetZ: Float = 0.4

    /// Camera field-of-view in degrees. Lower = zoomed in; higher = wider.
    let cameraFOV: Double = 50

    // ═══════════════════════════════════════════════════════════════════

    // MARK: - Input
    var metricName: String = ""
    var newValue:   String = ""
    var oldValue:   String = ""
    var unit:       String = ""
    var onContinue: (() -> Void)?

    // MARK: - Colors
    private let neonAmber = UIColor(red: 1.00, green: 0.75, blue: 0.00, alpha: 1)
    private let neonCyan  = UIColor(red: 0.00, green: 0.95, blue: 1.00, alpha: 1)
    private let bgDark    = UIColor(red: 0.02, green: 0.02, blue: 0.06, alpha: 1)

    // MARK: - Subviews
    private let crownImageView     = UIImageView()
    private let titleLabel         = UILabel()
    private let subtitleLabel      = UILabel()
    private let characterContainer = UIView()
    private let prevCardView       = UIView()
    private let arrowImageView     = UIImageView()
    private let newCardView        = UIView()
    private let continueButton     = UIButton(type: .custom)

    // Card inner labels
    private let prevHeaderLabel = UILabel()
    private let prevValueLabel  = UILabel()
    private let prevUnitLabel   = UILabel()
    private let newHeaderLabel  = UILabel()
    private let newValueLabel   = UILabel()
    private let newUnitLabel    = UILabel()

    // Gradient layer for the continue button (resized in viewDidLayoutSubviews)
    private let buttonGradientLayer = CAGradientLayer()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.88)

        setupGlowOrbs()
        setupConfetti()
        setupCrown()
        setupTitleLabels()
        setupCharacterView()
        setupScoreCards()
        setupContinueButton()
        applyConstraints()
        setInitialState()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        runEntranceAnimation()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        buttonGradientLayer.frame = continueButton.bounds
    }

    // MARK: - Glow Orbs

    private func setupGlowOrbs() {
        addGlowOrb(
            color: neonAmber.withAlphaComponent(0.15),
            size: 350, blurRadius: 80,
            xAnchor: { $0.trailingAnchor }, xConstant: -30,
            yAnchor: { $0.topAnchor },      yConstant: view.bounds.height * 0.12,
            pulseFrom: 0.8, pulseTo: 1.2, duration: 2.0
        )
        addGlowOrb(
            color: neonCyan.withAlphaComponent(0.10),
            size: 300, blurRadius: 70,
            xAnchor: { $0.leadingAnchor }, xConstant: 30,
            yAnchor: { $0.bottomAnchor },  yConstant: -(view.bounds.height * 0.12),
            pulseFrom: 0.9, pulseTo: 1.1, duration: 2.5, delay: 0.5
        )
    }

    private func addGlowOrb(
        color: UIColor, size: CGFloat, blurRadius: CGFloat,
        xAnchor: (UIView) -> NSLayoutXAxisAnchor, xConstant: CGFloat,
        yAnchor: (UIView) -> NSLayoutYAxisAnchor, yConstant: CGFloat,
        pulseFrom: CGFloat, pulseTo: CGFloat,
        duration: TimeInterval, delay: TimeInterval = 0
    ) {
        let orb = UIView()
        orb.backgroundColor = color
        orb.layer.cornerRadius = size / 2
        orb.layer.shadowColor = color.cgColor
        orb.layer.shadowRadius = blurRadius
        orb.layer.shadowOpacity = 1.0
        orb.layer.shadowOffset = .zero
        orb.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(orb)
        NSLayoutConstraint.activate([
            orb.widthAnchor.constraint(equalToConstant: size),
            orb.heightAnchor.constraint(equalToConstant: size),
            xAnchor(orb).constraint(equalTo: xAnchor(view), constant: xConstant),
            yAnchor(orb).constraint(equalTo: yAnchor(view), constant: yConstant),
        ])
        UIView.animate(
            withDuration: duration, delay: delay,
            options: [.autoreverse, .repeat, .curveEaseInOut],
            animations: { orb.transform = CGAffineTransform(scaleX: pulseTo, y: pulseTo) }
        )
    }

    // MARK: - Confetti

    private func setupConfetti() {
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: UIScreen.main.bounds.midX, y: -20)
        emitter.emitterSize = CGSize(width: UIScreen.main.bounds.width * 1.2, height: 1)
        emitter.emitterShape = .line
        emitter.renderMode = .additive

        let colors: [UIColor] = [
            UIColor(red: 1.0, green: 0.75, blue: 0.0, alpha: 1),
            UIColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 1),
            UIColor(red: 1.0, green: 0.3,  blue: 0.4, alpha: 1),
            UIColor(red: 0.6, green: 0.4,  blue: 1.0, alpha: 1),
            UIColor(red: 0.2, green: 1.0,  blue: 0.5, alpha: 1),
            .white
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
            let sz = CGSize(width: 12, height: 8)
            UIGraphicsBeginImageContextWithOptions(sz, false, 0)
            color.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: sz), cornerRadius: 1.5).fill()
            cell.contents = UIGraphicsGetImageFromCurrentImageContext()?.cgImage
            UIGraphicsEndImageContext()
            return cell
        }

        view.layer.addSublayer(emitter)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { emitter.birthRate = 0 }
    }

    // MARK: - Crown

    private func setupCrown() {
        let config = UIImage.SymbolConfiguration(pointSize: 56, weight: .bold)
        crownImageView.image = UIImage(systemName: "crown.fill", withConfiguration: config)
        crownImageView.tintColor = neonAmber
        crownImageView.contentMode = .scaleAspectFit
        crownImageView.layer.shadowColor = neonAmber.cgColor
        crownImageView.layer.shadowRadius = 18
        crownImageView.layer.shadowOpacity = 0.8
        crownImageView.layer.shadowOffset = .zero
        view.addSubview(crownImageView)
    }

    // MARK: - Title Labels

    private func setupTitleLabels() {
        titleLabel.text = "NEW RECORD!"
        titleLabel.font = UIFont.monospacedSystemFont(ofSize: 34, weight: .black)
        titleLabel.textColor = neonAmber
        titleLabel.textAlignment = .center
        titleLabel.layer.shadowColor  = neonAmber.withAlphaComponent(0.5).cgColor
        titleLabel.layer.shadowRadius = 10
        titleLabel.layer.shadowOpacity = 1.0
        titleLabel.layer.shadowOffset = .zero
        view.addSubview(titleLabel)

        let subtitleText = "\(metricName) BEST BEATEN"
        let subtitleAttr = NSMutableAttributedString(string: subtitleText)
        subtitleAttr.addAttribute(.kern, value: CGFloat(3), range: NSRange(location: 0, length: subtitleText.count))
        subtitleLabel.attributedText = subtitleAttr
        subtitleLabel.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .bold)
        subtitleLabel.textColor = neonCyan
        subtitleLabel.textAlignment = .center
        view.addSubview(subtitleLabel)
    }

    // MARK: - 3-D Character

    private func setupCharacterView() {
        characterContainer.backgroundColor = .clear
        characterContainer.clipsToBounds = true
        view.addSubview(characterContainer)

        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.allowsCameraControl = false
        scnView.autoenablesDefaultLighting = false
        scnView.antialiasingMode = .multisampling4X
        scnView.clipsToBounds = true
        scnView.translatesAutoresizingMaskIntoConstraints = false
        characterContainer.addSubview(scnView)
        NSLayoutConstraint.activate([
            scnView.topAnchor.constraint(equalTo: characterContainer.topAnchor),
            scnView.bottomAnchor.constraint(equalTo: characterContainer.bottomAnchor),
            scnView.leadingAnchor.constraint(equalTo: characterContainer.leadingAnchor),
            scnView.trailingAnchor.constraint(equalTo: characterContainer.trailingAnchor),
        ])

        loadCharacter(into: scnView)
    }

    private func loadCharacter(into scnView: SCNView) {
        guard let importedScene = SCNScene(named: "Character.scnassets/Idle.dae") else { return }

        let masterScene = SCNScene()
        let shell = importedScene.rootNode.clone()
        masterScene.rootNode.addChildNode(shell)

        // ── Materials ─────────────────────────────────────────────────
        let chestNodes: Set<String> = ["chest_armor_detail", "chest_armor_detail-001", "chest_armor_main"]
        let darkSuit  = UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1)
        let exactPink = UIColor(red: 194/255, green: 149/255, blue: 144/255, alpha: 1)

        shell.enumerateChildNodes { node, _ in
            guard let name = node.name?.lowercased(), let geo = node.geometry else { return }
            for mat in geo.materials {
                mat.isDoubleSided = false
                mat.lightingModel = .phong
                switch name {
                case "____helm":
                    mat.diffuse.contents  = UIColor(red: 0.90, green: 0.90, blue: 0.92, alpha: 1)
                    mat.specular.contents = UIColor(white: 0.15, alpha: 1)
                case "cube-001":
                    mat.diffuse.contents  = UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1)
                    mat.specular.contents = UIColor.white
                    mat.shininess = 1.0
                case "stomach_plate":
                    mat.diffuse.contents  = UIColor(red: 0.78, green: 0.78, blue: 0.80, alpha: 1)
                    mat.specular.contents = UIColor(white: 0.15, alpha: 1)
                default:
                    if chestNodes.contains(name) {
                        mat.diffuse.contents  = UIColor.white
                        mat.specular.contents = UIColor(white: 0.15, alpha: 1)
                    } else {
                        switch mat.name {
                        case "undersuit":
                            mat.diffuse.contents  = darkSuit
                            mat.specular.contents = UIColor(white: 0.1, alpha: 1)
                        case "metallic_pink":
                            mat.diffuse.contents  = exactPink
                            mat.specular.contents = UIColor(white: 0.7, alpha: 1)
                            mat.shininess = 0.5
                        case "white_suit":
                            mat.diffuse.contents  = UIColor.white
                            mat.specular.contents = UIColor(white: 0.2, alpha: 1)
                        case "neon_glow":
                            mat.diffuse.contents  = UIColor.black
                            mat.emission.contents = UIColor.black
                        default:
                            mat.diffuse.contents  = darkSuit
                        }
                    }
                }
            }
        }

        // ── Scale / position — identical formula to CharacterSelectionViewController ──
        shell.scale = SCNVector3(1, 1, 1)
        let (minB, maxB) = shell.boundingBox
        let modelHeight  = maxB.y - minB.y

        // autoScale includes characterScale so the model appears the same size
        // as it does on the character-selection screen.
        let autoScale: Float = modelHeight > 0 ? (1.8 / modelHeight) * characterScale : characterScale

        // Offsets are divided by autoScale to stay proportional across models.
        let midX = (minB.x + maxB.x) / 2
        let midY = (minB.y + maxB.y) / 2
        let virtualShiftY = characterOffsetY / autoScale
        shell.position = SCNVector3(-midX, -midY + virtualShiftY, 0)

        // ── Lighting ──────────────────────────────────────────────────
        masterScene.lightingEnvironment.contents = UIColor(white: 0.2, alpha: 1)

        let ambientNode = SCNNode()
        let ambient = SCNLight(); ambient.type = .ambient; ambient.color = UIColor.white; ambient.intensity = 600
        ambientNode.light = ambient
        masterScene.rootNode.addChildNode(ambientNode)

        let dirNode = SCNNode()
        let dir = SCNLight(); dir.type = .directional; dir.color = UIColor.white; dir.intensity = 900
        dirNode.light = dir
        dirNode.eulerAngles = SCNVector3(-Float.pi / 4, -Float.pi / 6, 0)
        masterScene.rootNode.addChildNode(dirNode)

        // ── Camera — identical formula to CharacterSelectionViewController ─────
        let visualCameraZ  = 3.5 / autoScale
        let visualOffsetZ  = characterOffsetZ / autoScale

        let camNode = SCNNode()
        camNode.camera = SCNCamera()
        camNode.camera?.fieldOfView = cameraFOV
        camNode.camera?.zNear       = Double(visualCameraZ) * 0.05
        camNode.camera?.zFar        = Double(visualCameraZ) * 5.0
        camNode.position = SCNVector3(0, 0, visualCameraZ - visualOffsetZ)

        masterScene.rootNode.addChildNode(camNode)
        scnView.scene     = masterScene
        scnView.pointOfView = camNode
        scnView.isPlaying = true

        injectDanceAnimation(into: shell)
    }

    private func injectDanceAnimation(into target: SCNNode) {
        guard let animScene = SCNScene(named: "Character.scnassets/Wave Hip Hop Dance.dae") else { return }

        func splice(from src: SCNNode, to dst: SCNNode) {
            for key in src.animationKeys {
                if let player = src.animationPlayer(forKey: key) {
                    player.animation.repeatCount = .infinity
                    if let boneName = src.name,
                       let bone = dst.childNode(withName: boneName, recursively: true) {
                        bone.addAnimationPlayer(player, forKey: key)
                    } else {
                        dst.addAnimationPlayer(player, forKey: key)
                    }
                }
            }
            src.childNodes.forEach { splice(from: $0, to: dst) }
        }
        splice(from: animScene.rootNode, to: target)
    }

    // MARK: - Score Cards

    private func setupScoreCards() {
        // ── Previous (dim) ────────────────────────────────────────────
        styleCard(prevCardView, highlighted: false)
        prevHeaderLabel.text      = "PREVIOUS"
        prevHeaderLabel.font      = UIFont.monospacedSystemFont(ofSize: 11, weight: .bold)
        prevHeaderLabel.textColor = UIColor.white.withAlphaComponent(0.5)

        prevValueLabel.text      = oldValue
        prevValueLabel.font      = UIFont.monospacedSystemFont(ofSize: 22, weight: .bold)
        prevValueLabel.textColor = UIColor.white.withAlphaComponent(0.8)

        prevUnitLabel.text      = unit
        prevUnitLabel.font      = UIFont.monospacedSystemFont(ofSize: 9, weight: .semibold)
        prevUnitLabel.textColor = UIColor.white.withAlphaComponent(0.4)

        embedLabelsInCard(prevCardView, header: prevHeaderLabel, value: prevValueLabel, unit: prevUnitLabel)
        view.addSubview(prevCardView)

        // ── Arrow ─────────────────────────────────────────────────────
        let arrowConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        arrowImageView.image        = UIImage(systemName: "arrow.right", withConfiguration: arrowConfig)
        arrowImageView.tintColor    = neonAmber.withAlphaComponent(0.7)
        arrowImageView.contentMode  = .scaleAspectFit
        view.addSubview(arrowImageView)

        // ── New Best (glowing) ────────────────────────────────────────
        styleCard(newCardView, highlighted: true)
        newHeaderLabel.text      = "NEW BEST"
        newHeaderLabel.font      = UIFont.monospacedSystemFont(ofSize: 11, weight: .bold)
        newHeaderLabel.textColor = neonAmber

        newValueLabel.text      = newValue
        newValueLabel.font      = UIFont.monospacedSystemFont(ofSize: 28, weight: .black)
        newValueLabel.textColor = .white
        newValueLabel.layer.shadowColor   = neonAmber.withAlphaComponent(0.4).cgColor
        newValueLabel.layer.shadowRadius  = 8
        newValueLabel.layer.shadowOpacity = 1.0
        newValueLabel.layer.shadowOffset  = .zero

        newUnitLabel.text      = unit
        newUnitLabel.font      = UIFont.monospacedSystemFont(ofSize: 9, weight: .semibold)
        newUnitLabel.textColor = neonAmber.withAlphaComponent(0.6)

        embedLabelsInCard(newCardView, header: newHeaderLabel, value: newValueLabel, unit: newUnitLabel)
        view.addSubview(newCardView)
    }

    private func styleCard(_ card: UIView, highlighted: Bool) {
        card.layer.cornerRadius = 14
        if highlighted {
            card.backgroundColor       = neonAmber.withAlphaComponent(0.15)
            card.layer.borderColor     = neonAmber.withAlphaComponent(0.6).cgColor
            card.layer.borderWidth     = 1.5
            card.layer.shadowColor     = neonAmber.withAlphaComponent(0.2).cgColor
            card.layer.shadowRadius    = 15
            card.layer.shadowOpacity   = 1.0
            card.layer.shadowOffset    = .zero
        } else {
            card.backgroundColor       = UIColor.white.withAlphaComponent(0.05)
            card.layer.borderColor     = UIColor.white.withAlphaComponent(0.1).cgColor
            card.layer.borderWidth     = 1.0
        }
    }

    private func embedLabelsInCard(_ card: UIView, header: UILabel, value: UILabel, unit: UILabel) {
        [header, value, unit].forEach { $0.textAlignment = .center }
        let stack = UIStackView(arrangedSubviews: [header, value, unit])
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
        ])
    }

    // MARK: - Continue Button

    private func setupContinueButton() {
        buttonGradientLayer.colors      = [neonAmber.cgColor,
                                           UIColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1).cgColor]
        buttonGradientLayer.startPoint  = CGPoint(x: 0, y: 0)
        buttonGradientLayer.endPoint    = CGPoint(x: 1, y: 1)
        buttonGradientLayer.cornerRadius = 14
        continueButton.layer.insertSublayer(buttonGradientLayer, at: 0)
        continueButton.layer.cornerRadius = 14
        continueButton.clipsToBounds = false
        continueButton.layer.shadowColor   = neonAmber.withAlphaComponent(0.4).cgColor
        continueButton.layer.shadowRadius  = 12
        continueButton.layer.shadowOpacity = 1.0
        continueButton.layer.shadowOffset  = CGSize(width: 0, height: 5)

        var config = UIButton.Configuration.plain()
        var titleAttr = AttributedString("CONTINUE")
        titleAttr.font = UIFont.monospacedSystemFont(ofSize: 16, weight: .bold)
        titleAttr.kern = 2
        titleAttr.foregroundColor = bgDark
        config.attributedTitle = titleAttr
        config.image = UIImage(
            systemName: "chevron.right.2",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        )
        config.imagePlacement  = .trailing
        config.imagePadding    = 8
        config.baseForegroundColor = bgDark
        continueButton.configuration = config

        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        view.addSubview(continueButton)
    }

    // MARK: - Auto Layout

    private func applyConstraints() {
        let views: [UIView] = [crownImageView, titleLabel, subtitleLabel,
                               characterContainer, prevCardView, arrowImageView,
                               newCardView, continueButton]
        views.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            // Crown — anchored to safe area top
            crownImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            crownImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            crownImageView.widthAnchor.constraint(equalToConstant: 68),
            crownImageView.heightAnchor.constraint(equalToConstant: 68),

            // Title
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: crownImageView.bottomAnchor, constant: 10),

            // Subtitle
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),

            // Character window — full width, height driven by `characterViewHeight`
            characterContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            characterContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            characterContainer.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: characterTopSpacing),
            characterContainer.heightAnchor.constraint(equalToConstant: characterViewHeight),

            // Score cards row — centred, below character
            arrowImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            arrowImageView.topAnchor.constraint(equalTo: characterContainer.bottomAnchor, constant: 16),
            arrowImageView.widthAnchor.constraint(equalToConstant: 24),
            arrowImageView.heightAnchor.constraint(equalToConstant: 24),

            prevCardView.trailingAnchor.constraint(equalTo: arrowImageView.leadingAnchor, constant: -16),
            prevCardView.centerYAnchor.constraint(equalTo: arrowImageView.centerYAnchor),
            prevCardView.widthAnchor.constraint(equalToConstant: 100),
            prevCardView.heightAnchor.constraint(equalToConstant: 90),

            newCardView.leadingAnchor.constraint(equalTo: arrowImageView.trailingAnchor, constant: 16),
            newCardView.centerYAnchor.constraint(equalTo: arrowImageView.centerYAnchor),
            newCardView.widthAnchor.constraint(equalToConstant: 120),
            newCardView.heightAnchor.constraint(equalToConstant: 105),

            // Continue button — pinned to safe area bottom
            continueButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            continueButton.widthAnchor.constraint(equalToConstant: 240),
            continueButton.heightAnchor.constraint(equalToConstant: 52),
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
        ])
    }

    // MARK: - Entrance Animation

    private func setInitialState() {
        crownImageView.alpha     = 0
        crownImageView.transform = CGAffineTransform(scaleX: 0.4, y: 0.4)

        titleLabel.alpha     = 0
        subtitleLabel.alpha  = 0

        characterContainer.alpha     = 0
        characterContainer.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)

        let cardsAndArrow: [UIView] = [prevCardView, arrowImageView, newCardView]
        cardsAndArrow.forEach {
            $0.alpha = 0
            $0.transform = CGAffineTransform(translationX: 0, y: 30)
        }

        continueButton.alpha = 0
    }

    private func runEntranceAnimation() {
        // Crown springs in
        UIView.animate(withDuration: 0.6, delay: 0.0,
                       usingSpringWithDamping: 0.5, initialSpringVelocity: 0.8,
                       options: []) {
            self.crownImageView.alpha     = 1
            self.crownImageView.transform = .identity
        }

        // Title + subtitle fade in
        UIView.animate(withDuration: 0.5, delay: 0.2, options: .curveEaseOut) {
            self.titleLabel.alpha    = 1
            self.subtitleLabel.alpha = 1
        }

        // Character springs in
        UIView.animate(withDuration: 0.7, delay: 0.3,
                       usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5,
                       options: []) {
            self.characterContainer.alpha     = 1
            self.characterContainer.transform = .identity
        }

        // Score cards slide up
        UIView.animate(withDuration: 0.5, delay: 0.5, options: .curveEaseOut) {
            [self.prevCardView, self.arrowImageView, self.newCardView].forEach {
                $0.alpha     = 1
                $0.transform = .identity
            }
        }

        // Continue button fades in last
        UIView.animate(withDuration: 0.3, delay: 0.9, options: .curveEaseIn) {
            self.continueButton.alpha = 1
        }
    }

    // MARK: - Actions

    @objc private func continueTapped() {
        onContinue?()
    }
}
