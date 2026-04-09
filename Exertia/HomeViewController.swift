import UIKit
import AVFoundation

class HomeViewController: UIViewController {
    private struct CachedHomeSnapshot: Codable {
        let todayCalories: Int
        let todayDistance: Double
        let liveStreak: Int
    }

    @IBOutlet weak var characterImageView: UIImageView!
    @IBOutlet weak var stageHighlightView: UIImageView!
    @IBOutlet weak var currencyLabel: UILabel!
    @IBOutlet weak var streakLabel: UILabel!
    @IBOutlet weak var profileButton: UIButton!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var caloriesLabel: UILabel!

    private let tabBarContainer = UIView()
    private let tabBarStackView = UIStackView()
    private let indicatorView = UIView()
    private var tabIcons: [UIImageView] = []
    private var tabLabels: [UILabel] = []
    private var tabWrappers: [UIView] = []
    private let currentTabIndex = 0

    // Preloaded video player — ready before user taps Start
    private var preloadedPlayer: AVPlayer?
    private var preloadedPlayerLayer: AVPlayerLayer?
    private var isPlayerReady = false
    private static let homeCacheKeyPrefix = "home.cache."
    private static let celebrationKeyPrefix = "home.celebration."
    private var todayStatsWidthConstraint: NSLayoutConstraint?
    private weak var todayStatsTitleLabel: UILabel?
    private weak var todayStatsRowView: UIStackView?
    private weak var startButtonImageView: UIImageView?
    private weak var startButtonTitleLabel: UILabel?

    let gameData = GameData.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        setupGlassTabBarDesign()
        setupCustomTabs()
        setupProfileDesign()
        updateCharacterUI()
        scaleTopNavBar()
        configureTodayStatsCapsule()
        configureTodayStatsSpacing()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNavigateToHome),
            name: .navigateToHome,
            object: nil
        )
    }

    /// Adjusts all storyboard constraints for the current screen size
    private func scaleTopNavBar() {
        guard let navStack = profileButton.superview as? UIStackView else { return }

        // --- Nav bar sizing ---
        let navHeight: CGFloat = Responsive.isIPad ? 48 : (Responsive.isSmallPhone ? 30 : Responsive.size(36))
        for constraint in navStack.constraints where constraint.firstAttribute == .height {
            constraint.constant = navHeight
        }

        let profileSize: CGFloat = Responsive.isIPad ? 48 : (Responsive.isSmallPhone ? 30 : Responsive.size(36))
        for constraint in profileButton.constraints {
            if constraint.firstAttribute == .width || constraint.firstAttribute == .height {
                constraint.constant = profileSize
            }
        }

        // --- Adjust all view-level storyboard constraints ---
        for constraint in view.constraints {
            // Nav stack top position: push up on small phones, slightly up on larger
            if let first = constraint.firstItem as? UIView, first === navStack,
               constraint.firstAttribute == .top {
                constraint.constant = Responsive.isSmallPhone ? 50 : Responsive.verticalSize(60)
            }

            // Stage centerY: less offset on small phones, more on iPad
            if let first = constraint.firstItem as? UIView, first === stageHighlightView,
               constraint.firstAttribute == .centerY {
                if Responsive.isSmallPhone {
                    constraint.constant = 30     // much higher on SE
                } else if Responsive.isIPad {
                    constraint.constant = 140    // push down on iPad
                } else {
                    constraint.constant = Responsive.verticalSize(80)
                }
            }

            // Highlight bottom to safeArea: reduce on small phones
            if constraint.firstAttribute == .bottom,
               let second = constraint.secondItem as? UIView,
               second.constraints.contains(where: { $0.firstAttribute == .width && $0.secondAttribute == .height && $0.multiplier == 1.0 }),
               constraint.constant == 130 {
                if Responsive.isSmallPhone {
                    constraint.constant = 60
                }
            }

            // Character bottom offset from Highlight
            if let first = constraint.firstItem as? UIView, first === characterImageView,
               constraint.firstAttribute == .bottom, constraint.constant == -150 {
                if Responsive.isSmallPhone {
                    constraint.constant = -80
                } else if Responsive.isIPad {
                    constraint.constant = -180
                }
            }

            // "Today's stats" label top from stage (storyboard: 140)
            // Push daily stats + start button lower on iPad
            if constraint.firstAttribute == .top,
               constraint.constant == 140,
               let second = constraint.secondItem as? UIView, second === stageHighlightView {
                if Responsive.isIPad {
                    constraint.constant = 190
                } else if Responsive.isSmallPhone {
                    constraint.constant = 110
                }
            }
        }

        // Scale Start button on iPad
        if Responsive.isIPad {
            for sub in view.subviews {
                if let imgView = sub as? UIImageView {
                    for c in imgView.constraints where c.firstAttribute == .height && c.constant == 75 {
                        c.constant = 100
                    }
                }
            }
        }
        // Shrink Start button on SE
        if Responsive.isSmallPhone {
            for sub in view.subviews {
                if let imgView = sub as? UIImageView {
                    for c in imgView.constraints where c.firstAttribute == .height && c.constant == 75 {
                        c.constant = 55
                    }
                }
            }
        }
    }

    @objc private func handleNavigateToHome() {
        // Fallback: dismiss whatever is still presented over HomeVC.
        DispatchQueue.main.async {
            self.presentedViewController?.dismiss(animated: true)
        }
    }

    private func configureTodayStatsCapsule() {
        guard let statsRow = distanceLabel.superview?.superview?.superview else { return }

        if let existingConstraint = todayStatsWidthConstraint {
            existingConstraint.isActive = false
        }

        if let proportionalWidthConstraint = view.constraints.first(where: {
            ($0.firstItem as? UIStackView) === statsRow && $0.firstAttribute == .width
        }) {
            proportionalWidthConstraint.isActive = false
        }

        let targetWidth: CGFloat
        if Responsive.isIPad {
            targetWidth = 260
        } else if Responsive.isSmallPhone {
            targetWidth = 215
        } else {
            targetWidth = min(view.bounds.width * 0.5, 230)
        }

        let widthConstraint = statsRow.widthAnchor.constraint(equalToConstant: targetWidth)
        widthConstraint.isActive = true
        todayStatsWidthConstraint = widthConstraint
    }

    private func configureTodayStatsSpacing() {
        let todayLabel = todayStatsTitleLabel ?? findTodayStatsLabel()
        todayStatsTitleLabel = todayLabel

        let statsRow = todayStatsRowView ?? (distanceLabel.superview?.superview?.superview as? UIStackView)
        todayStatsRowView = statsRow

        let startButton = startButtonImageView ?? findStartButtonImageView()
        startButtonImageView = startButton

        guard let todayLabel,
              let statsRow,
              let startButton else { return }

        if let labelTopConstraint = view.constraints.first(where: {
            ($0.firstItem as? UILabel) === todayLabel &&
            ($0.secondItem as? UIView) === stageHighlightView &&
            $0.firstAttribute == .top &&
            $0.secondAttribute == .top
        }) {
            if Responsive.isIPad {
                labelTopConstraint.constant = 210
            } else if Responsive.isSmallPhone {
                labelTopConstraint.constant = 175
            } else {
                labelTopConstraint.constant = 140
            }
        }

        if let rowTopConstraint = view.constraints.first(where: {
            ($0.firstItem as? UIStackView) === statsRow &&
            ($0.secondItem as? UILabel) === todayLabel &&
            $0.firstAttribute == .top &&
            $0.secondAttribute == .bottom
        }) {
            rowTopConstraint.constant = Responsive.isSmallPhone ? 16 : 10
        }

        if let startTopConstraint = view.constraints.first(where: {
            ($0.firstItem as? UIImageView) === startButton &&
            ($0.secondItem as? UIStackView) === statsRow &&
            $0.firstAttribute == .top &&
            $0.secondAttribute == .top
        }) {
            if Responsive.isIPad {
                startTopConstraint.constant = 58
            } else if Responsive.isSmallPhone {
                startTopConstraint.constant = 72
            } else {
                startTopConstraint.constant = 48
            }
        }
    }

    private func findTodayStatsLabel() -> UILabel? {
        view.subviews.compactMap { $0 as? UILabel }.first(where: { $0.text == "Today's stats" })
    }

    private func findStartButtonImageView() -> UIImageView? {
        view.subviews.compactMap { $0 as? UIImageView }.first(where: { imageView in
            imageView !== stageHighlightView &&
            imageView !== characterImageView &&
            imageView.constraints.contains(where: { $0.firstAttribute == .height && abs($0.constant - 75) < 0.5 })
        })
    }

    private func findStartButtonTitleLabel() -> UILabel? {
        view.subviews.compactMap { $0 as? UILabel }.first(where: { $0.text == "START" })
    }

    private func positionLowerHomeStackForCurrentDevice() {
        guard let todayLabel = todayStatsTitleLabel ?? findTodayStatsLabel(),
              let statsRow = todayStatsRowView ?? (distanceLabel.superview?.superview?.superview as? UIStackView),
              let startImage = startButtonImageView ?? findStartButtonImageView() else { return }

        todayStatsTitleLabel = todayLabel
        todayStatsRowView = statsRow
        startButtonImageView = startImage
        startButtonTitleLabel = startButtonTitleLabel ?? findStartButtonTitleLabel()

        todayLabel.transform = .identity
        statsRow.transform = .identity
        startImage.transform = .identity
        startButtonTitleLabel?.transform = .identity

        guard Responsive.isSmallPhone else { return }

        let labelOffset: CGFloat = 34
        let rowOffset: CGFloat = 42
        let startOffset: CGFloat = 52

        todayLabel.transform = CGAffineTransform(translationX: 0, y: labelOffset)
        statsRow.transform = CGAffineTransform(translationX: 0, y: rowOffset)
        startImage.transform = CGAffineTransform(translationX: 0, y: startOffset)
        startButtonTitleLabel?.transform = CGAffineTransform(translationX: 0, y: startOffset)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tabBarContainer.layoutIfNeeded()
        if tabWrappers.indices.contains(currentTabIndex) {
            moveIndicator(to: tabWrappers[currentTabIndex], animated: false)
        }
        
        // Dynamically scale the character proportionally to screen size
        let charScale: CGFloat
        if Responsive.isSmallPhone {
            charScale = 0.96
        } else if Responsive.isIPad {
            charScale = 0.86
        } else {
            charScale = 1.0 + (view.bounds.height - 667) / 1200
        }

        // Nudge stage position per device
        let stageNudge: CGFloat
        if Responsive.isSmallPhone {
            stageNudge = 15      // push stage down closer to daily stats
        } else if Responsive.isIPad {
            stageNudge = 20
        } else {
            stageNudge = 10
        }
        stageHighlightView.transform = CGAffineTransform(translationX: 0, y: stageNudge)

        // Keep the character centered on the stage across all device classes.
        let stageCenterX = stageHighlightView.center.x
        let stageCenterY = stageHighlightView.center.y + stageNudge
        let charNaturalCenter = characterImageView.center
        let scaledFeetOffsetFromCenter = characterImageView.bounds.height * 0.35 * charScale
        let charXOffset = stageCenterX - charNaturalCenter.x
        let charYOffset = stageCenterY - (charNaturalCenter.y + scaledFeetOffsetFromCenter)
        characterImageView.transform = CGAffineTransform(translationX: charXOffset, y: charYOffset)
            .scaledBy(x: charScale, y: charScale)

        positionLowerHomeStackForCurrentDevice()

        // Re-round profile button after layout
        profileButton.layoutIfNeeded()
        profileButton.layer.cornerRadius = profileButton.frame.height / 2
        
        setupRocketAnimation()
        setupStarField()
    }
    
    private func setupRocketAnimation() {
        if let newLogo = UIImage(named: "LOGO4"),
           let logoView = view.subviews.first(where: { ($0 as? UIImageView)?.image == newLogo }) {
            
            let rocketSize: CGFloat = min(logoView.bounds.height * 0.50, 65)
            let startX: CGFloat = -rocketSize * 2
            let endX: CGFloat = view.bounds.width + rocketSize * 2
            
            let rocketView: UIView // We now use a clear UIView container to safely host the pre-rotated image
            if let existingContainer = view.viewWithTag(999) {
                rocketView = existingContainer
                rocketView.layer.removeAllAnimations() // Flush old animations to cleanly re-run the loop
            } else {
                rocketView = UIView()
                rocketView.tag = 999
                
                let innerImage = UIImageView(image: UIImage(named: "Rocket2") ?? UIImage(named: "rocket_image"))
                innerImage.contentMode = .scaleAspectFit
                
                // The uploaded "Rocket2" asset is natively drawn pointing diagonally Up-Right (approx 45 degrees).
                // We physically pre-rotate the image exactly 45 degrees clockwise inside the container so it lays completely flat, pointing perfectly RIGHT (+X).
                // This absolute horizontal alignment guarantees `.rotateAuto` steers the nose strictly along the path!
                innerImage.transform = CGAffineTransform(rotationAngle: CGFloat.pi / 4) // 45° clockwise
                // UIKit rendering crash prevention: DO NOT use autoresizing masks on a pre-transformed view!
                
                rocketView.addSubview(innerImage)
                view.insertSubview(rocketView, aboveSubview: logoView)
            }
            
            // CRITICAL SIZING FIX: Explicitly constrain the mathematical container bounds
            rocketView.bounds = CGRect(x: 0, y: 0, width: rocketSize, height: rocketSize)
            // UIKit Rendering Bug Fix: Modifying the `.frame` property of a mathematically transformed view physically crushes its bounds geometry into a zero-dimensional scale making it instantly invisible!
            // We correctly restrict mapping utilizing only its static `.bounds` and geometric `.center`!
            rocketView.subviews.first?.bounds = CGRect(x: 0, y: 0, width: rocketSize, height: rocketSize)
            rocketView.subviews.first?.center = CGPoint(x: rocketSize / 2, y: rocketSize / 2)
            
            rocketView.layer.zPosition = 999
            
            // Mathematically plot a beautiful 2D path: fly straight, loop-de-loop around the middle, fly out
            let rocketPath = UIBezierPath()
            let centerY = logoView.center.y
            let midX = view.bounds.width / 2
            let loopRadius: CGFloat = 45 // The size of the circular loop
            
            // 1. Enter from the left gently dipping into a playful little wave before returning to perfectly flat horizontally entering the loop
            let enterStartX = startX + rocketSize / 2
            rocketPath.move(to: CGPoint(x: enterStartX, y: centerY))
            
            let dipMidX = enterStartX + (midX - enterStartX) * 0.5
            let dipDepth: CGFloat = 35 // A small, playful dipping amplitude
            let bottomY = centerY + dipDepth // iOS Y goes DOWN, so adding depth pulls it downwards
            
            // Curve 1: Slide in perfectly horizontally, then gracefully dip downwards
            let cp1A = CGPoint(x: enterStartX + 50, y: centerY) // Forces perfectly horizontal entry
            let cp1B = CGPoint(x: dipMidX - 40, y: bottomY) // Forces perfectly horizontal sweeping bottom
            rocketPath.addCurve(to: CGPoint(x: dipMidX, y: bottomY), controlPoint1: cp1A, controlPoint2: cp1B)
            
            // Curve 2: Perfectly transition from the dip's bottom back up to the perfectly flat entering line of the loop
            let cp2A = CGPoint(x: dipMidX + 40, y: bottomY) // Purely horizontal continuous tangent
            let cp2B = CGPoint(x: midX - 50, y: centerY) // Forces perfectly horizontal recovery into the circle!
            rocketPath.addCurve(to: CGPoint(x: midX, y: centerY), controlPoint1: cp2A, controlPoint2: cp2B)
            
            // 2. Perform a perfect circular loop-the-loop upwards over the logo
            // Counter-clockwise from the bottom guarantees a smooth upward swoop
            rocketPath.addArc(withCenter: CGPoint(x: midX, y: centerY - loopRadius),
                              radius: loopRadius,
                              startAngle: CGFloat.pi / 2,
                              endAngle: CGFloat.pi / 2 - (CGFloat.pi * 2),
                              clockwise: false)
            
            // 3. Exit the loop with a magnificent, mathematically natural swoop!
            // Reverting mathematically to the smooth parabolic J-Curve while safely preserving the upward nose-pitching exit tangent.
            let exitY = centerY - 150 
            let cp1 = CGPoint(x: midX + 120, y: centerY) // Flawlessly carries horizontal momentum securely out of the loop
            let cp2 = CGPoint(x: endX - 100, y: exitY + 100) // Pulls the nose upward gracefully and naturally without mathematically snapping
            
            rocketPath.addCurve(to: CGPoint(x: endX + rocketSize / 2, y: exitY),
                                controlPoint1: cp1,
                                controlPoint2: cp2)
            
            // Park the rocket safely off-screen left. This brilliantly guarantees it stays physically invisible gracefully during its 2-second repeating rest interval!
            rocketView.center = CGPoint(x: enterStartX, y: centerY)
            
            // Execute the path natively using CoreAnimation
            let flightAnim = CAKeyframeAnimation(keyPath: "position")
            flightAnim.path = rocketPath.cgPath
            flightAnim.duration = 3.5 // Smooth enough for a big loop
            flightAnim.calculationMode = .paced // Maintains absolutely consistent velocity
            flightAnim.rotationMode = .rotateAuto // CRITICAL: This magically auto-steers the rocket's nose natively along the curvy path!
            
            // Group the animation into a nested layout to flawlessly inject a pure 2-second loop delay!
            let groupAnim = CAAnimationGroup()
            groupAnim.animations = [flightAnim]
            groupAnim.duration = 3.5 + 1 // Exactly 3.5s of visible flight time + a pure 2.0s invisible math delay
            groupAnim.repeatCount = .infinity
            
            rocketView.layer.add(groupAnim, forKey: "loopDeLoopFlight")
        }
    }
    
    private func setupStarField() {
        let starView: UIView
        // Prevent stacking natively duplicate emitter layers explicitly across layout passes!
        if let existing = view.viewWithTag(777) {
            starView = existing
            starView.frame = view.bounds
            // Natively structurally resize the dynamic emitter constraints if the screen violently rotates
            if let layers = starView.layer.sublayers {
                for layer in layers {
                    guard let emitter = layer as? CAEmitterLayer else { continue }
                    if emitter.emitterShape == .line { // Shooting stars
                        emitter.emitterPosition = CGPoint(x: view.bounds.width + 50, y: view.bounds.height / 4)
                        emitter.emitterSize = CGSize(width: view.bounds.height, height: 10)
                    } else { // Twinkling stars
                        emitter.emitterPosition = CGPoint(x: view.bounds.width / 2, y: view.bounds.height / 2)
                        emitter.emitterSize = view.bounds.size
                    }
                }
            }
            return
        }
        
        starView = UIView(frame: view.bounds)
        starView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        starView.isUserInteractionEnabled = false // Rigorously ensures it's purely natively visual and never mathematically intercepts touches!
        starView.tag = 777
        
        // 1. Static Twinkling Stars Native Field
        let twinkleEmitter = CAEmitterLayer()
        twinkleEmitter.emitterPosition = CGPoint(x: view.bounds.width / 2, y: view.bounds.height / 2)
        twinkleEmitter.emitterSize = view.bounds.size
        twinkleEmitter.emitterShape = .rectangle
        
        let starCell = CAEmitterCell()
        starCell.contents = createStarImage()?.cgImage
        starCell.birthRate = 25 // Populating natively 25 tiny stars dynamically every second
        starCell.lifetime = 3.0 // Lasting ~3s natively on average explicitly before dying
        starCell.lifetimeRange = 2.0
        // Crank base native brightness and structural variability extremely high so some distinct stars spawn fully opaque and massive, while others spawn natively microscopically dim!
        starCell.color = UIColor(white: 1.0, alpha: 0.95).cgColor
        starCell.alphaRange = 0.7 
        starCell.alphaSpeed = -0.25 // Fade out natively gradually mathematically over time creating an aggressive dynamic twinkle!
        starCell.scale = 0.18 // Boost base mathematical size significantly so the most brilliant stars physically visually pop!
        starCell.scaleRange = 0.12 // Induce massive mathematical variation natively so some are microscopic and some are uniquely visibly enormous!
        starCell.velocity = 0 // Stand explicitly completely still physically to just twinkle
        
        twinkleEmitter.emitterCells = [starCell]
        starView.layer.addSublayer(twinkleEmitter)
        
        // 2. High-Velocity Massive Shooting Stars Field
        let shootingStarEmitter = CAEmitterLayer()
        // Anchor them explicitly natively off-screen completely to the absolute right, and vertically high up natively!
        shootingStarEmitter.emitterPosition = CGPoint(x: view.bounds.width + 50, y: view.bounds.height / 4)
        shootingStarEmitter.emitterSize = CGSize(width: view.bounds.height, height: 10)
        shootingStarEmitter.emitterShape = .line
        
        let shootingCell = CAEmitterCell()
        shootingCell.contents = createStarImage()?.cgImage
        shootingCell.birthRate = 0.4 // Extraordinarily rare! ~1 huge shooting star natively every 2.5 seconds
        shootingCell.lifetime = 1.5
        shootingCell.color = UIColor.white.cgColor // Max brightness explicitly!
        shootingCell.velocity = 600 // Screaming fast mathematically!
        shootingCell.velocityRange = 200
        // .pi is mathematically exactly Left! .pi * 0.85 sweeps them organically falling Left and explicitly mathematically downwards!
        shootingCell.emissionLongitude = .pi * 0.85 
        // Force the physical cell to physically visually point perfectly left and slightly mathematically down natively!
        shootingCell.spin = 0
        shootingCell.emissionRange = .pi * 0.05 // Tiny mathematical bit of random rotation geometric variation natively per star
        shootingCell.scale = 0.25 // Make shooting stars structurally much, much larger than standard twinkles
        shootingCell.scaleRange = 0.1
        shootingCell.scaleSpeed = -0.08 // Subtly mathematically shrink physically as they rapidly fly geometrically out
        shootingCell.alphaSpeed = -0.5 // Mathematically rigidly burn out very quickly realistically simulating atmospheric planetary entry!
        
        shootingStarEmitter.emitterCells = [shootingCell]
        starView.layer.addSublayer(shootingStarEmitter)
        
        // Push explicitly strictly fundamentally beneath the massive character models but structurally strictly natively ABOVE the background image view layer!
        view.insertSubview(starView, at: 1)
    }
    
    // Dynamic structural native zero-dependency asset generator: geometrically directly paints a perfect mathematical radial glow pixel gradient via pure CoreGraphics!
    private func createStarImage() -> UIImage? {
        let size = CGSize(width: 8, height: 8)
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [UIColor.white.cgColor, UIColor(white: 1.0, alpha: 0.0).cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) else { return nil }
        
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: size.width / 2, options: .drawsBeforeStartLocation)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AudioManager.shared.playAppMusic()
        updateCharacterUI()
        setupRocketAnimation()
        preloadTrackVideo()
        if !applyCachedHomeSnapshot() {
            showLoadingState()
        }
        fetchHomeData()
        if tabWrappers.indices.contains(currentTabIndex) {
            tabBarContainer.layoutIfNeeded()
            moveIndicator(to: tabWrappers[currentTabIndex], animated: false)
        }
    }
    
    // IST timezone — all "today" comparisons must use this
    private static let istCalendar: Calendar = {
        var c = Calendar.current
        c.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        return c
    }()

    private static let istDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = istCalendar
        formatter.timeZone = istCalendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    // Use ISODateParser.date(from:) for flexible ISO8601 parsing

    private var homeCacheKey: String? {
        guard let userId = UserDefaults.standard.string(forKey: "supabaseUserID") else { return nil }
        return Self.homeCacheKeyPrefix + userId
    }

    private var celebrationKey: String? {
        guard let userId = UserDefaults.standard.string(forKey: "supabaseUserID") else { return nil }
        return Self.celebrationKeyPrefix + userId
    }

    private var todayISTKey: String {
        Self.istDateFormatter.string(from: Date())
    }

    private func persistHomeSnapshot(todayCalories: Int, todayDistance: Double, liveStreak: Int) {
        guard let key = homeCacheKey else { return }
        let snapshot = CachedHomeSnapshot(todayCalories: todayCalories, todayDistance: todayDistance, liveStreak: liveStreak)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    @discardableResult
    private func applyCachedHomeSnapshot() -> Bool {
        guard let key = homeCacheKey,
              let data = UserDefaults.standard.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(CachedHomeSnapshot.self, from: data) else { return false }

        removeShimmers()
        streakLabel.text = "\(snapshot.liveStreak)"
        currencyLabel.text = "\(snapshot.todayCalories)"
        distanceLabel.text = String(format: "%.1f km", snapshot.todayDistance)
        caloriesLabel.text = "\(snapshot.todayCalories) cal"

        if snapshot.liveStreak > 0 {
            startStreakPulse()
        } else {
            streakLabel.superview?.layer.removeAnimation(forKey: "streakPulse")
        }
        return true
    }

    private func hasShownCelebrationToday() -> Bool {
        guard let key = celebrationKey else { return false }
        return UserDefaults.standard.string(forKey: key) == todayISTKey
    }

    private func markCelebrationShownToday() {
        guard let key = celebrationKey else { return }
        UserDefaults.standard.set(todayISTKey, forKey: key)
    }

    func fetchHomeData() {
        guard let userId = UserDefaults.standard.string(forKey: "supabaseUserID") else { return }

        Task {
            do {
                async let statsFetch  = SupabaseManager.shared.getUserStats(userId: userId)
                async let userFetch   = SupabaseManager.shared.getUser(userId: userId)
                async let sessFetch   = SupabaseManager.shared.getUserSessions(userId: userId)
                async let streakFetch = SupabaseManager.shared.calculateLiveStreak(userId: userId)

                let (stats, user, sessions, liveStreak) = try await (statsFetch, userFetch, sessFetch, streakFetch)

                // Count both completed and abandoned sessions toward today's totals
                // as long as Supabase recorded real distance/calories on them.
                let todaySessions = sessions.filter { s in
                    guard s.countsTowardDailyProgress,
                          let raw = s.created_at,
                          let ts  = ISODateParser.date(from: raw) else { return false }
                    return Self.istCalendar.isDateInToday(ts)
                }

                let todayDistance = todaySessions.compactMap { $0.distance_covered }.reduce(0, +)
                let todayCalories = todaySessions.compactMap { $0.calories_burned  }.reduce(0, +)

                // Update local GameData cache
                self.gameData.stats.calories       = stats.total_calories
                self.gameData.stats.runTimeMinutes = stats.total_minutes
                self.gameData.stats.currentStreak  = liveStreak
                self.gameData.stats.personalBestCalories = stats.personal_best_calories > 0 ? stats.personal_best_calories : 0
                self.gameData.stats.personalBestDistance = stats.personal_best_distance > 0 ? stats.personal_best_distance : 0.0

                // Check if daily target is met (both calories AND distance)
                let dailyCalTarget = user.daily_target_calories ?? 500
                let dailyDistTarget = user.daily_target_distance ?? 5.0
                let targetMetNow = todayCalories >= dailyCalTarget && todayDistance >= dailyDistTarget

                DispatchQueue.main.async {
                    self.removeShimmers()
                    // Animate counters from current value to new value
                    self.animateCounter(label: self.streakLabel, to: liveStreak, suffix: "")
                    self.animateCounter(label: self.currencyLabel, to: todayCalories, suffix: "")

                    // "Today's stats" row — IST-filtered, resets at IST midnight
                    if todaySessions.isEmpty {
                        self.distanceLabel.text = "0 km"
                        self.caloriesLabel.text  = "0 cal"
                    } else {
                        self.animateDecimalCounter(label: self.distanceLabel, to: todayDistance, suffix: " km")
                        self.animateCounter(label: self.caloriesLabel, to: todayCalories, suffix: " cal")
                    }

                    // Pulse streak icon if streak is active
                    if liveStreak > 0 {
                        self.startStreakPulse()
                    }

                    // Show celebration if target was just met
                    if targetMetNow && !self.hasShownCelebrationToday() {
                        self.markCelebrationShownToday()
                        // Check for streak milestones first
                        let milestones = [7, 14, 30, 50, 100]
                        if milestones.contains(liveStreak) {
                            CelebrationView.showMilestone(on: self, streak: liveStreak)
                        } else {
                            CelebrationView.show(on: self, streak: liveStreak)
                        }
                    }

                    self.persistHomeSnapshot(
                        todayCalories: todayCalories,
                        todayDistance: todayDistance,
                        liveStreak: liveStreak
                    )

                    print("✅ Home UI: today (IST) — \(String(format: "%.1f", todayDistance)) km, \(todayCalories) cal (\(todaySessions.count) sessions)")
                }
            } catch {
                print("❌ Failed to fetch home data: \(error)")
            }
        }
    }

    func setupGlassTabBarDesign() {
        view.addSubview(tabBarContainer)
        tabBarContainer.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            tabBarContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -5),
            tabBarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Responsive.contentInset),
            tabBarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Responsive.contentInset),
            tabBarContainer.heightAnchor.constraint(equalToConstant: Responsive.tabBarHeight)
        ])
        
        tabBarContainer.backgroundColor = .clear
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
        indicatorView.layer.cornerRadius = Responsive.cornerRadius(30)
        indicatorView.layer.cornerCurve = .continuous
        indicatorView.layer.shadowColor = UIColor.white.cgColor
        indicatorView.layer.shadowRadius = 8
        indicatorView.layer.shadowOpacity = 0.4
        indicatorView.layer.shadowOffset = .zero
        tabBarContainer.insertSubview(indicatorView, at: 1)
        
        view.bringSubviewToFront(tabBarContainer)
        
        // Gesture Recognizers for Swipe Navigation
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleTabSwipe(_:)))
        swipeLeft.direction = .left
        tabBarContainer.addGestureRecognizer(swipeLeft)
        
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleTabSwipe(_:)))
        swipeRight.direction = .right
        tabBarContainer.addGestureRecognizer(swipeRight)
    }

    @objc private func handleTabSwipe(_ gesture: UISwipeGestureRecognizer) {
        if gesture.direction == .left { // Swipe left goes to next tab (Customize)
            AudioManager.shared.playEffect(.buttonTapped)
            let sb = UIStoryboard(name: "Main", bundle: nil)
            if let vc = sb.instantiateViewController(withIdentifier: "CharacterSelectionViewController") as? CharacterSelectionViewController {
                vc.modalPresentationStyle = .fullScreen
                let transition = CATransition()
                transition.duration = 0.3
                transition.type = .push
                transition.subtype = .fromRight
                transition.timingFunction = CAMediaTimingFunction(name: .easeOut)
                view.window?.layer.add(transition, forKey: kCATransition)
                self.present(vc, animated: false)
            }
        }
    }
    
    func setupCustomTabs() {
        tabBarStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        tabIcons.removeAll(); tabLabels.removeAll(); tabWrappers.removeAll()
        tabBarStackView.distribution = .fillEqually
        tabBarStackView.translatesAutoresizingMaskIntoConstraints = false
        tabBarContainer.addSubview(tabBarStackView)
        
        NSLayoutConstraint.activate([
            tabBarStackView.topAnchor.constraint(equalTo: tabBarContainer.topAnchor),
            tabBarStackView.bottomAnchor.constraint(equalTo: tabBarContainer.bottomAnchor),
            tabBarStackView.leadingAnchor.constraint(equalTo: tabBarContainer.leadingAnchor, constant: 10),
            tabBarStackView.trailingAnchor.constraint(equalTo: tabBarContainer.trailingAnchor, constant: -10)
        ])
        
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
        updateTabState(selectedIndex: currentTabIndex)
    }

    @objc func tabTapped(_ sender: UIButton) {
        AudioManager.shared.playEffect(.buttonTapped)
        let index = sender.tag
        moveIndicator(to: tabWrappers[index], animated: true)
        
        switch index {
        case 0: break  // Already on Home
        case 1:
            // Customize
            let sb = UIStoryboard(name: "Main", bundle: nil)
            if let vc = sb.instantiateViewController(withIdentifier: "CharacterSelectionViewController") as? CharacterSelectionViewController {
                vc.modalPresentationStyle = .fullScreen
                vc.modalTransitionStyle = .crossDissolve
                self.present(vc, animated: true)
            }
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
    
    func updateTabState(selectedIndex: Int) {
        if tabWrappers.indices.contains(selectedIndex) {
            moveIndicator(to: tabWrappers[selectedIndex], animated: false)
        }
    }
    
    @IBAction func profileButtonTapped(_ sender: UIButton) {
        AudioManager.shared.playEffect(.buttonTapped)
        let sb = UIStoryboard(name: "Main", bundle: nil)
        if let vc = sb.instantiateViewController(withIdentifier: "ProfileViewController") as? ProfileViewController {
            vc.modalPresentationStyle = .fullScreen
            vc.modalTransitionStyle = .crossDissolve
            self.present(vc, animated: true)
        }
    }

    func setupProfileDesign() {
        profileButton.layoutIfNeeded()
        profileButton.layer.cornerRadius = profileButton.frame.height / 2
        profileButton.layer.masksToBounds = true
        profileButton.layer.borderWidth = 1
        profileButton.layer.borderColor = UIColor.white.withAlphaComponent(0.8).cgColor
        profileButton.imageView?.contentMode = .scaleAspectFit
    }

    private func updateCharacterUI() {
        characterImageView.image = UIImage(named: "HomePageMain")
        characterImageView.contentMode = .scaleAspectFit
        characterImageView.isHidden = false
        stageHighlightView?.isHidden = false
        
        // Remove the 'Highlight' asset specifically by size signature
        if let highlightSize = UIImage(named: "Highlight")?.size {
            for subview in view.subviews {
                if let imgView = subview as? UIImageView, 
                   imgView != stageHighlightView, 
                   imgView != characterImageView,
                   imgView.image?.size == highlightSize {
                    imgView.isHidden = true
                }
            }
        }
        
        // Dynamically replace the old 'ExertiaHomePageTitle' logo with 'LOGO4' and center it
        if let newLogo = UIImage(named: "LOGO4"), let oldLogoSize = UIImage(named: "ExertiaHomePageTitle")?.size {
            for subview in view.subviews {
                if let imgView = subview as? UIImageView,
                   imgView.image?.size == oldLogoSize || imgView.image == newLogo {
                    if imgView.image != newLogo {
                        imgView.image = newLogo
                        imgView.contentMode = .scaleAspectFit
                        imgView.transform = .identity
                        // Remove fixedFrame autoresizing and add proper center constraints
                        imgView.translatesAutoresizingMaskIntoConstraints = false
                        let logoTop: CGFloat = Responsive.isSmallPhone ? 55 : Responsive.verticalSize(75)
                        let logoWidth: CGFloat = Responsive.isSmallPhone ? 260 : Responsive.size(333)
                        let logoHeight: CGFloat = Responsive.isSmallPhone ? 130 : Responsive.size(180)
                        NSLayoutConstraint.activate([
                            imgView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                            imgView.topAnchor.constraint(equalTo: view.topAnchor, constant: logoTop),
                            imgView.widthAnchor.constraint(equalToConstant: logoWidth),
                            imgView.heightAnchor.constraint(equalToConstant: logoHeight)
                        ])
                    }
                    break
                }
            }
        }
    }

    private func showLoadingState() {
        currencyLabel.text = "--"
        streakLabel.text = "--"
        distanceLabel.text = "--"
        caloriesLabel.text = "-- cal"
        [currencyLabel, streakLabel, distanceLabel, caloriesLabel].forEach { addShimmer(to: $0) }
    }

    private func addShimmer(to view: UIView?) {
        guard let view = view else { return }
        view.layer.removeAnimation(forKey: "shimmer")
        let shimmer = CABasicAnimation(keyPath: "opacity")
        shimmer.fromValue = 1.0
        shimmer.toValue = 0.3
        shimmer.duration = 0.8
        shimmer.autoreverses = true
        shimmer.repeatCount = .infinity
        shimmer.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        view.layer.add(shimmer, forKey: "shimmer")
    }

    private func removeShimmers() {
        [currencyLabel, streakLabel, distanceLabel, caloriesLabel].forEach {
            $0?.layer.removeAnimation(forKey: "shimmer")
        }
    }
    
    private func preloadTrackVideo() {
        guard !isPlayerReady,
              let path = Bundle.main.path(forResource: "Nova-Station", ofType: "mp4") else { return }
        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        asset.loadValuesAsynchronously(forKeys: ["playable"]) { [weak self] in
            guard let self else { return }
            var error: NSError?
            guard asset.statusOfValue(forKey: "playable", error: &error) == .loaded else { return }
            let item = AVPlayerItem(asset: asset)
            item.preferredForwardBufferDuration = 3.0
            let player = AVPlayer(playerItem: item)
            player.automaticallyWaitsToMinimizeStalling = false
            AudioManager.shared.applyMutedState(to: player)
            DispatchQueue.main.async {
                self.preloadedPlayer = player
                self.isPlayerReady = true
            }
        }
    }

    @IBAction func playButtonTapped(_ sender: UIButton) {
        AudioManager.shared.playEffect(.buttonTapped)
        bounceButton(sender) {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let trackVC = storyboard.instantiateViewController(withIdentifier: "TrackSelectionViewController") as? TrackSelectionViewController {
                trackVC.modalPresentationStyle = .fullScreen
                trackVC.modalTransitionStyle = .crossDissolve
                // Pass preloaded player if ready — avoids cold-start delay
                if self.isPlayerReady {
                    trackVC.preloadedPlayer = self.preloadedPlayer
                    self.preloadedPlayer = nil
                    self.isPlayerReady = false
                }
                self.present(trackVC, animated: true, completion: nil)
            }
        }
    }



    // MARK: - Animations

    /// Animates an integer counter from 0 to target value
    private func animateCounter(label: UILabel, to target: Int, suffix: String, duration: Double = 0.8) {
        guard target > 0 else { label.text = "0\(suffix)"; return }
        let steps = min(target, 30)
        let interval = duration / Double(steps)
        for i in 0...steps {
            let value = Int(Double(target) * Double(i) / Double(steps))
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) {
                label.text = "\(value)\(suffix)"
            }
        }
    }

    /// Animates a decimal counter (e.g. distance)
    private func animateDecimalCounter(label: UILabel, to target: Double, suffix: String, duration: Double = 0.8) {
        guard target > 0 else { label.text = "0.0\(suffix)"; return }
        let steps = 30
        let interval = duration / Double(steps)
        for i in 0...steps {
            let value = target * Double(i) / Double(steps)
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) {
                label.text = String(format: "%.1f\(suffix)", value)
            }
        }
    }

    /// Pulse animation on the streak icon when streak > 0
    private func startStreakPulse() {
        guard let streakPill = streakLabel.superview else { return }
        // Remove existing pulse if any
        streakPill.layer.removeAnimation(forKey: "streakPulse")
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue = 1.08
        pulse.duration = 0.8
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        streakPill.layer.add(pulse, forKey: "streakPulse")
    }

    /// Bounce effect for buttons
    private func bounceButton(_ button: UIView, completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.1, animations: {
            button.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.5,
                           initialSpringVelocity: 0.5, options: [], animations: {
                button.transform = .identity
            }) { _ in
                completion()
            }
        }
    }
}
