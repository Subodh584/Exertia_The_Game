import UIKit

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
    private static let homeCacheKeyPrefix = "home.cache."
    private static let celebrationKeyPrefix = "home.celebration."

    let gameData = GameData.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        setupGlassTabBarDesign()
        setupCustomTabs()
        setupProfileDesign()
        updateCharacterUI()
        if !applyCachedHomeSnapshot() {
            showLoadingState()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tabBarContainer.layoutIfNeeded()
        if tabWrappers.indices.contains(currentTabIndex) {
            moveIndicator(to: tabWrappers[currentTabIndex], animated: false)
        }
        
        // Dynamically scale the image to be much bigger and ground it cleanly onto the podium
        let screenHeight = view.bounds.height
        let scale: CGFloat = screenHeight > 800 ? 1.35 : 1.2 // Larger screens get a bigger pop
        let yOffset = characterImageView.bounds.height * 0.02 // A precise, microscopic shift down (2%) so it hovers just above the stage
        
        characterImageView.transform = CGAffineTransform(translationX: 0, y: yOffset).scaledBy(x: scale, y: scale)
        
        setupRocketAnimation()
    }
    
    private func setupRocketAnimation() {
        if let newLogo = UIImage(named: "LOGO4"),
           let logoView = view.subviews.first(where: { ($0 as? UIImageView)?.image == newLogo }) {
            
            // Set to exactly half the height of the logo as requested, capped gracefully at 60 points
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
            groupAnim.duration = 3.5 + 2.0 // Exactly 3.5s of visible flight time + a pure 2.0s invisible math delay
            groupAnim.repeatCount = .infinity
            
            rocketView.layer.add(groupAnim, forKey: "loopDeLoopFlight")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AudioManager.shared.playAppMusic()
        updateCharacterUI()
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

                // Filter completed sessions whose created_at falls on TODAY in IST
                let todaySessions = sessions.filter { s in
                    guard s.completion_status == "completed",
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
            tabBarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            tabBarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            tabBarContainer.heightAnchor.constraint(equalToConstant: 70)
        ])
        
        tabBarContainer.backgroundColor = .clear
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
        
        view.bringSubviewToFront(tabBarContainer)
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
        
        // Dynamically replace the old 'ExertiaHomePageTitle' logo with 'LOGO4'
        if let newLogo = UIImage(named: "LOGO4"), let oldLogoSize = UIImage(named: "ExertiaHomePageTitle")?.size {
            for subview in view.subviews {
                if let imgView = subview as? UIImageView, imgView.image?.size == oldLogoSize {
                    imgView.image = newLogo
                    imgView.contentMode = .scaleAspectFit
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
    
    @IBAction func playButtonTapped(_ sender: UIButton) {
        AudioManager.shared.playEffect(.buttonTapped)
        // Bounce animation on tap
        bounceButton(sender) {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let trackVC = storyboard.instantiateViewController(withIdentifier: "TrackSelectionViewController") as? TrackSelectionViewController {
                trackVC.modalPresentationStyle = .fullScreen
                trackVC.modalTransitionStyle = .crossDissolve
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
