import UIKit

class HomeViewController: UIViewController {

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

    let gameData = GameData.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        setupGlassTabBarDesign()
        setupCustomTabs()
        setupProfileDesign()
        updateUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tabBarContainer.layoutIfNeeded()
        if tabWrappers.indices.contains(currentTabIndex) {
            moveIndicator(to: tabWrappers[currentTabIndex], animated: false)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateUI()
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
    private static let isoParser: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    func fetchHomeData() {
        guard let userId = UserDefaults.standard.string(forKey: "djangoUserID") else { return }

        Task {
            do {
                async let statsFetch = APIManager.shared.getUserStats(userId: userId)
                async let userFetch  = APIManager.shared.getUser(userId: userId)
                async let sessFetch  = APIManager.shared.getUserSessions(userId: userId)

                let (stats, user, sessions) = try await (statsFetch, userFetch, sessFetch)

                // Filter completed sessions whose createdAt falls on TODAY in IST
                let todaySessions = sessions.filter { s in
                    guard s.completionStatus == "completed",
                          let raw = s.createdAt,
                          let ts  = Self.isoParser.date(from: raw) else { return false }
                    return Self.istCalendar.isDateInToday(ts)
                }

                let todayDistance = todaySessions.compactMap { $0.distanceCovered }.reduce(0, +)
                let todayCalories = todaySessions.compactMap { $0.caloriesBurned  }.reduce(0, +)

                // Update local GameData cache
                self.gameData.stats.calories       = stats.totalCalories
                self.gameData.stats.runTimeMinutes = stats.totalMinutes
                self.gameData.stats.currentStreak  = user.currentStreak ?? 0

                DispatchQueue.main.async {
                    // Top-left streak + TODAY's cal badges (resets at IST midnight)
                    self.streakLabel.text   = "\(user.currentStreak ?? 0)"
                    self.currencyLabel.text = "\(todayCalories)"

                    // "Today's stats" row — IST-filtered, resets at IST midnight
                    if todaySessions.isEmpty {
                        self.distanceLabel.text = "0 km"
                        self.caloriesLabel.text  = "0 cal"
                    } else {
                        self.distanceLabel.text = String(format: "%.1f km", todayDistance)
                        self.caloriesLabel.text  = "\(todayCalories) cal"
                    }
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

    func updateUI() {
        let selectedPlayer = gameData.getSelectedPlayer()
        characterImageView.image = UIImage(named: selectedPlayer.fullBodyImageName)
        currencyLabel.text = "--"
        streakLabel.text = "--"
        distanceLabel.text = "--"
        caloriesLabel.text = "-- cal"
    }
    
    @IBAction func playButtonTapped(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let trackVC = storyboard.instantiateViewController(withIdentifier: "TrackSelectionViewController") as? TrackSelectionViewController {
            
            trackVC.modalPresentationStyle = .fullScreen
            trackVC.modalTransitionStyle = .crossDissolve
            self.present(trackVC, animated: true, completion: nil)
        }
    }
}
