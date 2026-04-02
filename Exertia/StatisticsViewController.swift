import UIKit

extension UIColor {
    static let neonPink = UIColor(red: 255/255, green: 92/255, blue: 255/255, alpha: 1.0)
    static let neonYellow = UIColor(red: 255/255, green: 239/255, blue: 190/255, alpha: 1.0)
}

class StatisticsViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private struct CachedStatsSnapshot: Codable {
        let userName: String?
        let dailyTargetCalories: Int
        let dailyTargetDistance: Double
        let currentWeight: Double?
        let targetWeight: Double?
        let currentStreak: Int
        let longestStreak: Int
        let totalCalories: Int
        let totalDistance: Double
        let totalMinutes: Int
        let completedSessions: Int
        let todayCalories: Int
        let todayDistance: Double
        let lastSessionDuration: Int?
        let lastSessionCalories: Int?
        let lastSessionDistance: Double?
        let lastSessionStatus: String?
        let bestSessionDuration: Int?
        let bestSessionCalories: Int?
        let bestSessionDistance: Double?
        let activeDateStrings: [String]
        let allCompletedSessions: [AppSession]
    }

    private enum WeightValidation {
        static let minAllowedKg = 30.0
        static let maxAllowedKg = 300.0
        static let maxRelativeTargetChange = 0.25
    }
    private static let statsCacheKeyPrefix = "statistics.cache."

    private let gradientView = UIView()
    private let navBar = UIView()
    private let backBtn = UIButton()
    private let titleLabel = UILabel()
    private let profileImg = UIImageView()
    
    private let mainScroll = UIScrollView()
    private let stackContainer = UIStackView()
    
    private let helloLabel = UILabel()
    private let nameLabel = UILabel()
    
    private let tabContainer = UIView()
    private let tabStack = UIStackView()
    private let tabIndicator = UIView()
    private var tabIcons: [UIImageView] = []
    private var tabLabels: [UILabel] = []
    private var tabWrappers: [UIView] = []
    
    private let bigStatLabel = UILabel()
    private let subStatLabel = UILabel()
    private let outerRing = CAShapeLayer()
    private let innerRing = CAShapeLayer()
    private let planetIcon = UIImageView()
    
    private var runCard: UIView?
    private var bestCard: UIView?
    
    private let lastTimeLabel = UILabel()
    private let lastCalLabel = UILabel()
    private let lastRunStatusLabel = UILabel()
    private let bestTimeLabel = UILabel()
    private let bestCalLabel = UILabel()
    
    private let weightBar = UIProgressView(progressViewStyle: .bar)
    private let bubbleView = UIView()
    private let bubbleLabel = UILabel()
    private let weightMsg = UILabel()
    private var bubbleConstraint: NSLayoutConstraint?
    
    private var streakCollection: UICollectionView!
    private var dates: [Date] = []
    private let todayOffset = 180
    
    private var showCalories = true
    private var calBtn: UIButton!
    private var timeBtn: UIButton!

    // Target label below the big stat
    private let targetLabel = UILabel()

    // Dynamic weight labels
    private let weightStartLabel = UILabel()
    private let weightEndLabel = UILabel()

    // Streak label references
    private var streakCountLabel: UILabel?
    private var streakSubtitleLabel: UILabel?
    private var bestStreakLabel: UILabel?

    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 13/255, green: 5/255, blue: 26/255, alpha: 1.0)
        
        loadDates()
        addGradient()
        configureNavBar()
        configureScroll()
        addHeader()
        addMainCard()
        addGridCards()
        addWeightView()
        addStreakView()
        styleTabBar()
        initTabs()
        loadingIndicator.color = .white
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        loadCachedStatsSnapshot()
        fetchRealUserName()
        fetchStatsData()
        fetchStreakCalendar()
        animateCardsEntrance()
    }

    /// Staggered slide-up entrance for stats cards
    private func animateCardsEntrance() {
        let cards = stackContainer.arrangedSubviews
        for (i, card) in cards.enumerated() {
            card.alpha = 0
            card.transform = CGAffineTransform(translationX: 0, y: 40)
            UIView.animate(withDuration: 0.5, delay: Double(i) * 0.08,
                           usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3,
                           options: .curveEaseOut, animations: {
                card.alpha = 1
                card.transform = .identity
            })
        }
    }
    
    // MARK: - Cached API data for display
    private var apiTotalCalories: Int = 0
    private var apiTotalDistance: Double = 0
    private var apiTotalMinutes: Int = 0
    private var apiCompletedSessions: Int = 0
    // TODAY (IST) — used for the ring progress + big stat number
    private var apiTodayCalories: Int = 0
    private var apiTodayDistance: Double = 0

    private static let istCalendar: Calendar = {
        var c = Calendar.current
        c.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        return c
    }()
    // Use ISODateParser.date(from:) for flexible ISO8601 parsing
    private var apiLastSessionDuration: Int? = nil
    private var apiLastSessionCalories: Int? = nil
    private var apiLastSessionDistance: Double? = nil
    private var apiLastSessionStatus: String? = nil
    private var apiBestSessionDuration: Int? = nil
    private var apiBestSessionCalories: Int? = nil
    private var apiBestSessionDistance: Double? = nil
    private var apiDailyTargetCalories: Int = 500
    private var apiDailyTargetDistance: Double = 5.0
    private var apiCurrentWeight: Double? = nil
    private var apiTargetWeight: Double? = nil

    private func validateWeightInputs(current: Double, target: Double) -> String? {
        guard current.isFinite, target.isFinite else {
            return "Please enter valid weight values."
        }

        guard current >= WeightValidation.minAllowedKg,
              current <= WeightValidation.maxAllowedKg else {
            return String(
                format: "Current weight must be between %.0f kg and %.0f kg.",
                WeightValidation.minAllowedKg,
                WeightValidation.maxAllowedKg
            )
        }

        guard target >= WeightValidation.minAllowedKg,
              target <= WeightValidation.maxAllowedKg else {
            return String(
                format: "Target weight must be between %.0f kg and %.0f kg.",
                WeightValidation.minAllowedKg,
                WeightValidation.maxAllowedKg
            )
        }

        let minTarget = max(
            WeightValidation.minAllowedKg,
            current * (1.0 - WeightValidation.maxRelativeTargetChange)
        )
        let maxTarget = min(
            WeightValidation.maxAllowedKg,
            current * (1.0 + WeightValidation.maxRelativeTargetChange)
        )

        guard target >= minTarget, target <= maxTarget else {
            return String(
                format: "For a current weight of %.1f kg, your next target should stay between %.1f kg and %.1f kg.",
                current,
                minTarget,
                maxTarget
            )
        }

        return nil
    }

    private var statsCacheKey: String? {
        guard let userId = UserDefaults.standard.string(forKey: "supabaseUserID") else { return nil }
        return Self.statsCacheKeyPrefix + userId
    }

    private func loadCachedStatsSnapshot() {
        guard let key = statsCacheKey,
              let data = UserDefaults.standard.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(CachedStatsSnapshot.self, from: data) else { return }

        nameLabel.text = snapshot.userName ?? "Player"
        apiDailyTargetCalories = snapshot.dailyTargetCalories
        apiDailyTargetDistance = snapshot.dailyTargetDistance
        apiCurrentWeight = snapshot.currentWeight
        apiTargetWeight = snapshot.targetWeight
        apiCurrentStreak = snapshot.currentStreak
        apiLongestStreak = snapshot.longestStreak
        apiTotalCalories = snapshot.totalCalories
        apiTotalDistance = snapshot.totalDistance
        apiTotalMinutes = snapshot.totalMinutes
        apiCompletedSessions = snapshot.completedSessions
        apiTodayCalories = snapshot.todayCalories
        apiTodayDistance = snapshot.todayDistance
        apiLastSessionDuration = snapshot.lastSessionDuration
        apiLastSessionCalories = snapshot.lastSessionCalories
        apiLastSessionDistance = snapshot.lastSessionDistance
        apiLastSessionStatus = snapshot.lastSessionStatus
        apiBestSessionDuration = snapshot.bestSessionDuration
        apiBestSessionCalories = snapshot.bestSessionCalories
        apiBestSessionDistance = snapshot.bestSessionDistance
        activeDateStrings = Set(snapshot.activeDateStrings)
        allCompletedSessions = snapshot.allCompletedSessions

        refreshUI()
        streakCollection?.reloadData()
    }

    private func persistStatsSnapshot() {
        guard let key = statsCacheKey else { return }

        let snapshot = CachedStatsSnapshot(
            userName: nameLabel.text,
            dailyTargetCalories: apiDailyTargetCalories,
            dailyTargetDistance: apiDailyTargetDistance,
            currentWeight: apiCurrentWeight,
            targetWeight: apiTargetWeight,
            currentStreak: apiCurrentStreak,
            longestStreak: apiLongestStreak,
            totalCalories: apiTotalCalories,
            totalDistance: apiTotalDistance,
            totalMinutes: apiTotalMinutes,
            completedSessions: apiCompletedSessions,
            todayCalories: apiTodayCalories,
            todayDistance: apiTodayDistance,
            lastSessionDuration: apiLastSessionDuration,
            lastSessionCalories: apiLastSessionCalories,
            lastSessionDistance: apiLastSessionDistance,
            lastSessionStatus: apiLastSessionStatus,
            bestSessionDuration: apiBestSessionDuration,
            bestSessionCalories: apiBestSessionCalories,
            bestSessionDistance: apiBestSessionDistance,
            activeDateStrings: Array(activeDateStrings),
            allCompletedSessions: allCompletedSessions
        )

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
    private var apiCurrentStreak: Int = 0
    private var apiLongestStreak: Int = 0
    // Dates from streak-calendar API where the daily target was met
    private var activeDateStrings: Set<String> = []
    // All completed sessions — used to build day-by-day stats for the calendar
    private var allCompletedSessions: [AppSession] = []
    
    func fetchRealUserName() {
            guard let userId = UserDefaults.standard.string(forKey: "supabaseUserID") else { return }

            Task {
                do {
                    async let userFetch = SupabaseManager.shared.getUser(userId: userId)
                    async let streakFetch = SupabaseManager.shared.calculateLiveStreak(userId: userId)
                    let (user, liveStreak) = try await (userFetch, streakFetch)
                    DispatchQueue.main.async {
                        self.nameLabel.text = user.display_name ?? user.username ?? "Player"
                        self.apiDailyTargetCalories = user.daily_target_calories ?? 500
                        self.apiDailyTargetDistance = user.daily_target_distance ?? 5.0
                        self.apiCurrentWeight = user.current_weight
                        self.apiTargetWeight = user.target_weight
                        self.apiLongestStreak = user.longest_streak ?? 0
                        self.apiCurrentStreak = liveStreak
                        self.refreshUI()
                        self.persistStatsSnapshot()
                    }
                } catch {
                    print("❌ Failed to fetch user name for stats page: \(error)")
                }
            }
        }
    
    func fetchStatsData() {
        guard let userId = UserDefaults.standard.string(forKey: "supabaseUserID") else { return }

        DispatchQueue.main.async { self.loadingIndicator.startAnimating() }
        Task {
            do {
                // Fetch aggregated stats
                let stats = try await SupabaseManager.shared.getUserStats(userId: userId)
                self.apiTotalCalories = stats.total_calories
                self.apiTotalDistance = stats.total_distance
                self.apiTotalMinutes = stats.total_minutes
                self.apiCompletedSessions = stats.completed_sessions

                // Use stats endpoint for personal bests
                self.apiBestSessionDistance = stats.personal_best_distance > 0 ? stats.personal_best_distance : nil
                self.apiBestSessionCalories = stats.personal_best_calories > 0 ? stats.personal_best_calories : nil

                // Fetch all sessions to find last run
                let sessions = try await SupabaseManager.shared.getUserSessions(userId: userId)
                let completed = sessions.filter { $0.completion_status == "completed" }
                let calendarSessions = sessions.filter {
                    let status = $0.completion_status?.lowercased() ?? ""
                    return status == "completed" || status == "abandoned"
                }
                self.allCompletedSessions = calendarSessions   // stored for calendar day-stats

                // If no sessions exist at all, clear streak calendar cache immediately
                if sessions.isEmpty {
                    self.activeDateStrings = []
                }

                // Compute TODAY (IST) totals for the ring / big stat label
                let todaySessions = sessions.filter { s in
                    guard s.countsTowardDailyProgress,
                          let raw = s.created_at,
                          let ts  = ISODateParser.date(from: raw) else { return false }
                    return Self.istCalendar.isDateInToday(ts)
                }
                self.apiTodayCalories = todaySessions.compactMap { $0.calories_burned  }.reduce(0, +)
                self.apiTodayDistance = todaySessions.compactMap { $0.distance_covered }.reduce(0, +)
                print("📊 Stats today (IST): \(self.apiTodayCalories) cal, \(String(format: "%.2f", self.apiTodayDistance)) km (\(todaySessions.count) sessions)")

                let recentDisplayableSessions = sessions.filter {
                    let status = $0.completion_status?.lowercased() ?? ""
                    return status == "completed" || status == "abandoned"
                }.sorted { ($0.created_at ?? "") > ($1.created_at ?? "") }

                if let lastSession = recentDisplayableSessions.first {
                    self.apiLastSessionDuration = lastSession.duration_minutes
                    self.apiLastSessionCalories = lastSession.calories_burned
                    self.apiLastSessionDistance = lastSession.distance_covered
                    self.apiLastSessionStatus = lastSession.completion_status
                } else {
                    self.apiLastSessionDuration = nil
                    self.apiLastSessionCalories = nil
                    self.apiLastSessionDistance = nil
                    self.apiLastSessionStatus = nil
                }

                // If stats endpoint doesn't have best duration, compute from sessions
                if let bestSession = completed.max(by: { ($0.calories_burned ?? 0) < ($1.calories_burned ?? 0) }) {
                    self.apiBestSessionDuration = bestSession.duration_minutes
                } else {
                    self.apiBestSessionDuration = nil
                }

                DispatchQueue.main.async {
                    self.loadingIndicator.stopAnimating()
                    self.refreshUI()
                    self.persistStatsSnapshot()
                    print("✅ Statistics UI hydrated with real API data!")
                }
            } catch {
                print("❌ Failed to fetch stats data: \(error). Using defaults.")
                DispatchQueue.main.async {
                    self.loadingIndicator.stopAnimating()
                    self.refreshUI()
                }
            }
        }
    }
    
    func fetchStreakCalendar() {
        guard let userId = UserDefaults.standard.string(forKey: "supabaseUserID") else { return }
        Task {
            do {
                let records = try await SupabaseManager.shared.getStreakCalendar(userId: userId, days: 90)
                // daily_progress.date is already stored as an IST date string — use directly
                let active = Set(records.filter { $0.target_met }.map { $0.date })
                DispatchQueue.main.async {
                    self.activeDateStrings = active
                    self.streakCollection.reloadData()
                    self.persistStatsSnapshot()
                    print("✅ Streak calendar: \(active.count) target-met days")
                }
            } catch {
                print("❌ Failed to fetch streak calendar: \(error)")
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backBtn.layer.cornerRadius = backBtn.frame.height / 2
        profileImg.layer.cornerRadius = profileImg.frame.height / 2
        moveBubble()

        tabContainer.layoutIfNeeded()
        if tabWrappers.indices.contains(2) {
            moveIndicator(to: tabWrappers[2], animated: false)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AudioManager.shared.playAppMusic()
        refreshUI()
    }
    
    func loadDates() {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        let today = Date()
        dates = (-180...180).compactMap { i in
            calendar.date(byAdding: .day, value: i, to: today)
        }
    }

    func addGradient() {
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(gradientView)
        view.sendSubviewToBack(gradientView)
        NSLayoutConstraint.activate([
            gradientView.topAnchor.constraint(equalTo: view.topAnchor),
            gradientView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gradientView.heightAnchor.constraint(equalToConstant: Responsive.gradientHeight)
        ])
        let layer = CAGradientLayer()
        layer.colors = [UIColor.neonPink.withAlphaComponent(0.3).cgColor, UIColor.clear.cgColor]
        layer.locations = [0.0, 1.0]
        layer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: Responsive.gradientHeight)
        gradientView.layer.addSublayer(layer)
    }
    
    func configureNavBar() {
        navBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navBar)
        
        backBtn.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        backBtn.layer.borderWidth = 1
        backBtn.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        let config = UIImage.SymbolConfiguration(weight: .bold)
        backBtn.setImage(UIImage(systemName: "chevron.left", withConfiguration: config), for: .normal)
        backBtn.tintColor = .white
        backBtn.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        
        titleLabel.text = "Statistics"
        titleLabel.font = .systemFont(ofSize: Responsive.font(20), weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        
        profileImg.image = UIImage(named: "profile")
        profileImg.contentMode = .scaleAspectFill
        profileImg.clipsToBounds = true
        profileImg.layer.borderWidth = 1
        profileImg.layer.borderColor = UIColor.white.withAlphaComponent(0.8).cgColor
        
        profileImg.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(openProfile))
        profileImg.addGestureRecognizer(tap)
        
        navBar.addSubview(backBtn)
        navBar.addSubview(titleLabel)
        navBar.addSubview(profileImg)
        
        backBtn.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        profileImg.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navBar.heightAnchor.constraint(equalToConstant: Responsive.navBarHeight),

            backBtn.leadingAnchor.constraint(equalTo: navBar.leadingAnchor, constant: Responsive.contentInset),
            backBtn.centerYAnchor.constraint(equalTo: navBar.centerYAnchor),
            backBtn.widthAnchor.constraint(equalToConstant: Responsive.size(40)),
            backBtn.heightAnchor.constraint(equalToConstant: Responsive.size(40)),

            titleLabel.centerXAnchor.constraint(equalTo: navBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: navBar.centerYAnchor),

            profileImg.trailingAnchor.constraint(equalTo: navBar.trailingAnchor, constant: -Responsive.contentInset),
            profileImg.centerYAnchor.constraint(equalTo: navBar.centerYAnchor),
            profileImg.widthAnchor.constraint(equalToConstant: Responsive.size(36)),
            profileImg.heightAnchor.constraint(equalToConstant: Responsive.size(36))
        ])
    }

    func configureScroll() {
        view.addSubview(mainScroll)
        view.addSubview(tabContainer)
        mainScroll.translatesAutoresizingMaskIntoConstraints = false
        tabContainer.translatesAutoresizingMaskIntoConstraints = false

        // Pull-to-refresh
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = .neonPink
        refreshControl.addTarget(self, action: #selector(handlePullToRefresh), for: .valueChanged)
        mainScroll.refreshControl = refreshControl

        mainScroll.addSubview(stackContainer)
        stackContainer.translatesAutoresizingMaskIntoConstraints = false
        stackContainer.axis = .vertical
        stackContainer.spacing = 20
        stackContainer.alignment = .fill
        
        NSLayoutConstraint.activate([
            mainScroll.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 10),
            mainScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainScroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            tabContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -5),
            tabContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Responsive.contentInset),
            tabContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Responsive.contentInset),
            tabContainer.heightAnchor.constraint(equalToConstant: Responsive.tabBarHeight),

            stackContainer.topAnchor.constraint(equalTo: mainScroll.topAnchor),
            stackContainer.leadingAnchor.constraint(equalTo: mainScroll.leadingAnchor, constant: Responsive.contentInset),
            stackContainer.trailingAnchor.constraint(equalTo: mainScroll.trailingAnchor, constant: -Responsive.contentInset),
            stackContainer.bottomAnchor.constraint(equalTo: mainScroll.bottomAnchor, constant: -Responsive.verticalSize(100)),
            stackContainer.widthAnchor.constraint(equalTo: mainScroll.widthAnchor, constant: -(Responsive.contentInset * 2))
        ])
    }
    
    func addHeader() {
        let container = UIView()
        helloLabel.text = "Welcome Back,"
        helloLabel.font = .systemFont(ofSize: Responsive.font(16), weight: .medium)
        helloLabel.textColor = .lightGray
        nameLabel.text = "Player"
        nameLabel.font = .systemFont(ofSize: Responsive.font(28), weight: .bold)
        nameLabel.textColor = .white
        let stack = UIStackView(arrangedSubviews: [helloLabel, nameLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        stackContainer.addArrangedSubview(container)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 5),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -5),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: Responsive.verticalSize(70))
        ])
    }
    
    func addMainCard() {
        let card = glassCard(h: 200)
        let toggleBox = UIView()
        toggleBox.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        toggleBox.layer.cornerRadius = 16
        toggleBox.translatesAutoresizingMaskIntoConstraints = false
        
        calBtn = makeToggleBtn(text: "CAL BURN", color: .neonPink, on: true)
        timeBtn = makeToggleBtn(text: "DISTANCE", color: .neonYellow, on: false)
        
        calBtn.addTarget(self, action: #selector(clickedCal), for: .touchUpInside)
        timeBtn.addTarget(self, action: #selector(clickedTime), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [calBtn, timeBtn])
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        toggleBox.addSubview(stack)
        
        bigStatLabel.font = .systemFont(ofSize: Responsive.font(48), weight: .bold)
        bigStatLabel.textColor = .white
        bigStatLabel.textAlignment = .center

        subStatLabel.font = .systemFont(ofSize: Responsive.font(14), weight: .medium)
        subStatLabel.textAlignment = .center

        targetLabel.font = .systemFont(ofSize: Responsive.font(11), weight: .semibold)
        targetLabel.textColor = .white.withAlphaComponent(0.45)
        targetLabel.textAlignment = .center

        let textStack = UIStackView(arrangedSubviews: [bigStatLabel, subStatLabel, targetLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false
        
        let ringBox = UIView()
        ringBox.translatesAutoresizingMaskIntoConstraints = false
        drawRings(in: ringBox)
        
        let editTargetsBtn = UIButton(type: .system)
        let btnConfig = UIImage.SymbolConfiguration(pointSize: Responsive.font(16), weight: .medium)
        editTargetsBtn.setImage(UIImage(systemName: "slider.horizontal.3", withConfiguration: btnConfig), for: .normal)
        editTargetsBtn.tintColor = .white.withAlphaComponent(0.6)
        editTargetsBtn.addTarget(self, action: #selector(editTargetsTapped), for: .touchUpInside)
        editTargetsBtn.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(toggleBox)
        card.addSubview(textStack)
        card.addSubview(ringBox)
        card.addSubview(editTargetsBtn)  // added last so it's on top for touch

        NSLayoutConstraint.activate([
            toggleBox.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            toggleBox.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            toggleBox.widthAnchor.constraint(equalToConstant: 180),
            toggleBox.heightAnchor.constraint(equalToConstant: 32),
            editTargetsBtn.centerYAnchor.constraint(equalTo: toggleBox.centerYAnchor),
            editTargetsBtn.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Responsive.padding(20)),
            editTargetsBtn.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            editTargetsBtn.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            stack.topAnchor.constraint(equalTo: toggleBox.topAnchor),
            stack.bottomAnchor.constraint(equalTo: toggleBox.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: toggleBox.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: toggleBox.trailingAnchor),
            textStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 30),
            textStack.centerYAnchor.constraint(equalTo: card.centerYAnchor, constant: 20),
            ringBox.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            ringBox.centerYAnchor.constraint(equalTo: card.centerYAnchor, constant: 10),
            ringBox.widthAnchor.constraint(equalToConstant: Responsive.size(120)),
            ringBox.heightAnchor.constraint(equalToConstant: Responsive.size(120))
        ])
        stackContainer.addArrangedSubview(card)
    }
    
    func addGridCards() {
        let stack = UIStackView()
        stack.spacing = 15
        stack.distribution = .fillEqually
        
        runCard = glassCard(h: Responsive.verticalSize(130))
        fillSmallCard(view: runCard!, title: "Last Run", tLabel: lastTimeLabel, cLabel: lastCalLabel, statusLabel: lastRunStatusLabel)

        bestCard = glassCard(h: Responsive.verticalSize(130))
        fillSmallCard(view: bestCard!, title: "Personal Best", tLabel: bestTimeLabel, cLabel: bestCalLabel)
        
        let t1 = UITapGestureRecognizer(target: self, action: #selector(openHistoryNormal))
        runCard?.addGestureRecognizer(t1)
        runCard?.isUserInteractionEnabled = true

        let t2 = UITapGestureRecognizer(target: self, action: #selector(openHistoryBest))
        bestCard?.addGestureRecognizer(t2)
        bestCard?.isUserInteractionEnabled = true
        
        stack.addArrangedSubview(runCard!)
        stack.addArrangedSubview(bestCard!)
        stackContainer.addArrangedSubview(stack)
    }
    
    func addWeightView() {
        let card = glassCard(h: Responsive.verticalSize(110))
        let title = UILabel()
        title.text = "Weight Goal Progress"
        title.font = .systemFont(ofSize: Responsive.font(14), weight: .bold)
        title.textColor = .white
        title.translatesAutoresizingMaskIntoConstraints = false

        let editBtn = UIButton(type: .system)
        editBtn.setImage(UIImage(systemName: "pencil.circle.fill"), for: .normal)
        editBtn.tintColor = .neonPink
        editBtn.addTarget(self, action: #selector(editWeightTapped), for: .touchUpInside)
        editBtn.translatesAutoresizingMaskIntoConstraints = false

        weightBar.trackTintColor = UIColor.white.withAlphaComponent(0.1)
        weightBar.progressTintColor = .neonPink
        weightBar.layer.cornerRadius = 6
        weightBar.clipsToBounds = true
        weightBar.translatesAutoresizingMaskIntoConstraints = false

        bubbleView.backgroundColor = .neonYellow
        bubbleView.layer.cornerRadius = 8
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        bubbleLabel.font = .systemFont(ofSize: 10, weight: .bold)
        bubbleLabel.textColor = .black
        bubbleLabel.textAlignment = .center
        bubbleLabel.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(bubbleLabel)

        weightStartLabel.text = "-- kg"
        weightStartLabel.textColor = .white
        weightStartLabel.font = .systemFont(ofSize: 12, weight: .bold)
        weightEndLabel.text = "-- kg"
        weightEndLabel.textColor = .white
        weightEndLabel.font = .systemFont(ofSize: 12, weight: .bold)
        weightMsg.text = "Set your weight goal to track progress"
        weightMsg.textColor = .gray
        weightMsg.font = .systemFont(ofSize: 10)
        weightMsg.textAlignment = .center
        let bottom = UIStackView(arrangedSubviews: [weightStartLabel, weightMsg, weightEndLabel])
        bottom.distribution = .equalCentering
        bottom.alignment = .center
        bottom.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(title)
        card.addSubview(editBtn)
        card.addSubview(weightBar)
        card.addSubview(bubbleView)
        card.addSubview(bottom)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            title.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            editBtn.centerYAnchor.constraint(equalTo: title.centerYAnchor),
            editBtn.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            editBtn.widthAnchor.constraint(equalToConstant: 28),
            editBtn.heightAnchor.constraint(equalToConstant: 28),
            weightBar.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 28),
            weightBar.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            weightBar.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            weightBar.heightAnchor.constraint(equalToConstant: 12),
            bubbleLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 2),
            bubbleLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -2),
            bubbleLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 6),
            bubbleLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -6),
            bubbleView.bottomAnchor.constraint(equalTo: weightBar.topAnchor, constant: -4),
            bottom.topAnchor.constraint(equalTo: weightBar.bottomAnchor, constant: 6),
            bottom.leadingAnchor.constraint(equalTo: weightBar.leadingAnchor),
            bottom.trailingAnchor.constraint(equalTo: weightBar.trailingAnchor)
        ])
        bubbleConstraint = bubbleView.leadingAnchor.constraint(equalTo: weightBar.leadingAnchor, constant: 0)
        bubbleConstraint?.isActive = true
        stackContainer.addArrangedSubview(card)
        stackContainer.setCustomSpacing(50, after: card)
    }
    
    func addStreakView() {
        let card = glassCard(h: 155)
        card.clipsToBounds = false

        let fireImg = UIImageView(image: UIImage(named: "Streaks"))
        fireImg.contentMode = .scaleAspectFit
        fireImg.translatesAutoresizingMaskIntoConstraints = false

        let t1 = UILabel()
        t1.text = "0 Day Streak!"
        t1.font = .systemFont(ofSize: 22, weight: .bold)
        t1.textColor = .white
        streakCountLabel = t1

        let t2 = UILabel()
        t2.text = "Keep going, you are almost there"
        t2.font = .systemFont(ofSize: 12)
        t2.textColor = .gray
        streakSubtitleLabel = t2

        let bestLbl = UILabel()
        bestLbl.text = "Best: 0 days"
        bestLbl.font = .systemFont(ofSize: 11, weight: .medium)
        bestLbl.textColor = UIColor(red: 1, green: 0.86, blue: 0.24, alpha: 0.8)
        bestStreakLabel = bestLbl

        let txtStack = UIStackView(arrangedSubviews: [t1, t2, bestLbl])
        txtStack.axis = .vertical
        txtStack.spacing = 2
        txtStack.alignment = .center
        txtStack.translatesAutoresizingMaskIntoConstraints = false
        
        let calBtn = UIButton()
        calBtn.setImage(UIImage(systemName: "calendar"), for: .normal)
        calBtn.tintColor = .white.withAlphaComponent(0.6)
        calBtn.addTarget(self, action: #selector(openCalendar), for: .touchUpInside)
        calBtn.translatesAutoresizingMaskIntoConstraints = false
        
        let backBtn = UIButton()
        backBtn.setImage(UIImage(systemName: "arrow.uturn.backward.circle.fill"), for: .normal)
        backBtn.tintColor = .neonPink
        backBtn.addTarget(self, action: #selector(goToToday), for: .touchUpInside)
        backBtn.translatesAutoresizingMaskIntoConstraints = false
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 50, height: 50)
        layout.minimumLineSpacing = 10
        
        streakCollection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        streakCollection.backgroundColor = .clear
        streakCollection.showsHorizontalScrollIndicator = false
        streakCollection.dataSource = self
        streakCollection.delegate = self
        streakCollection.register(CalendarDayCell.self, forCellWithReuseIdentifier: "Cell")
        streakCollection.translatesAutoresizingMaskIntoConstraints = false
        
        // Pulse animation on streak badge
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue = 1.1
        pulse.duration = 1.0
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        fireImg.layer.add(pulse, forKey: "streakPulse")

        card.addSubview(fireImg)
        card.addSubview(txtStack)
        card.addSubview(calBtn)
        card.addSubview(backBtn)
        card.addSubview(streakCollection)
        
        NSLayoutConstraint.activate([
            fireImg.centerYAnchor.constraint(equalTo: card.topAnchor),
            fireImg.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            fireImg.widthAnchor.constraint(equalToConstant: 75),
            fireImg.heightAnchor.constraint(equalToConstant: 75),

            calBtn.topAnchor.constraint(equalTo: card.topAnchor, constant: 15),
            calBtn.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -15),
            
            backBtn.topAnchor.constraint(equalTo: card.topAnchor, constant: 15),
            backBtn.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 15),

            txtStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 42),
            txtStack.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            streakCollection.topAnchor.constraint(equalTo: txtStack.bottomAnchor, constant: 6),
            streakCollection.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 15),
            streakCollection.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -15),
            streakCollection.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -4)
        ])
        stackContainer.addArrangedSubview(card)
        DispatchQueue.main.async { self.goToToday() }
    }
    
    @objc func goBack() {
        AudioManager.shared.playEffect(.buttonTapped)
        self.dismiss(animated: true)
    }
    
    @objc func openProfile() {
            AudioManager.shared.playEffect(.buttonTapped)
            let sb = UIStoryboard(name: "Main", bundle: nil)
            if let vc = sb.instantiateViewController(withIdentifier: "ProfileViewController") as? ProfileViewController {
                vc.modalPresentationStyle = .fullScreen
                vc.modalTransitionStyle = .crossDissolve
                self.present(vc, animated: true)
            }
        }
    
    @objc func openHistoryNormal() {
        AudioManager.shared.playEffect(.buttonTapped)
        openHistory(scrollToBest: false)
    }
    @objc func openHistoryBest()   {
        AudioManager.shared.playEffect(.buttonTapped)
        openHistory(scrollToBest: true)
    }

    private func openHistory(scrollToBest: Bool) {
        let vc = RunHistoryViewController()
        vc.scrollToBest = scrollToBest
        vc.modalPresentationStyle = .fullScreen
        vc.modalTransitionStyle   = .crossDissolve
        present(vc, animated: true)
    }

    @objc func openCalendar() {
        AudioManager.shared.playEffect(.buttonTapped)
        let vc = FullCalendarViewController()
        vc.activeDateStrings = activeDateStrings
        vc.sessionsByDate    = buildSessionsByDate()
        vc.modalPresentationStyle = .fullScreen
        vc.modalTransitionStyle   = .crossDissolve
        present(vc, animated: true)
    }

    private func buildSessionsByDate() -> [String: [AppSession]] {
        let istFmt = DateFormatter()
        istFmt.dateFormat = "yyyy-MM-dd"
        istFmt.timeZone   = TimeZone(identifier: "Asia/Kolkata")!
        var dict: [String: [AppSession]] = [:]
        for s in allCompletedSessions {
            if let raw = s.created_at, let ts = ISODateParser.date(from: raw) {
                let key = istFmt.string(from: ts)
                dict[key, default: []].append(s)
            }
        }
        return dict
    }
    
    @objc func goToToday() {
        streakCollection.scrollToItem(at: IndexPath(item: todayOffset, section: 0), at: .centeredHorizontally, animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dates.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! CalendarDayCell
        let date = dates[indexPath.item]
        // Use IST calendar so "today" matches the backend's date storage
        var istCalendar = Calendar.current
        istCalendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        let isToday = istCalendar.isDateInToday(date)

        // Format date as "yyyy-MM-dd" in IST to match backend date strings
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "Asia/Kolkata")
        let dateKey = fmt.string(from: date)

        let targetMet = activeDateStrings.contains(dateKey)
        cell.configure(date: date, isToday: isToday, targetMet: targetMet)
        return cell
    }

    func glassCard(h: CGFloat) -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: h).isActive = true
        v.backgroundColor = .clear
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = 24
        blur.clipsToBounds = true
        blur.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        blur.layer.borderWidth = 1
        v.addSubview(blur)
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: v.topAnchor),
            blur.bottomAnchor.constraint(equalTo: v.bottomAnchor),
            blur.leadingAnchor.constraint(equalTo: v.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: v.trailingAnchor)
        ])
        return v
    }
    
    func drawRings(in v: UIView) {
        planetIcon.image = UIImage(named: "stats planet")
        planetIcon.contentMode = .scaleAspectFit
        planetIcon.frame = CGRect(x: 30, y: 30, width: 60, height: 60)
        
        let path1 = UIBezierPath(arcCenter: CGPoint(x: 60, y: 60), radius: 55, startAngle: -CGFloat.pi / 2, endAngle: 1.5 * CGFloat.pi, clockwise: true)
        configRing(l: outerRing, p: path1, c: .neonPink)
        
        let path2 = UIBezierPath(arcCenter: CGPoint(x: 60, y: 60), radius: 45, startAngle: -CGFloat.pi / 2, endAngle: 1.5 * CGFloat.pi, clockwise: true)
        configRing(l: innerRing, p: path2, c: .neonYellow)
        
        v.layer.addSublayer(outerRing)
        v.layer.addSublayer(innerRing)
        v.addSubview(planetIcon)
    }
    
    func configRing(l: CAShapeLayer, p: UIBezierPath, c: UIColor) {
        let t = CAShapeLayer()
        t.path = p.cgPath
        t.strokeColor = UIColor.white.withAlphaComponent(0.1).cgColor
        t.lineWidth = 6
        t.fillColor = UIColor.clear.cgColor
        t.lineCap = .round
        l.addSublayer(t)
        l.path = p.cgPath
        l.strokeColor = c.cgColor
        l.lineWidth = 6
        l.fillColor = UIColor.clear.cgColor
        l.lineCap = .round
        l.strokeEnd = 0
    }
    
    func makeToggleBtn(text: String, color: UIColor, on: Bool) -> UIButton {
        let b = UIButton()
        b.setTitle(text, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
        b.setTitleColor(on ? color : .gray, for: .normal)
        b.backgroundColor = on ? UIColor.white.withAlphaComponent(0.2) : .clear
        b.layer.cornerRadius = 14
        return b
    }
    
    func animateToggle(b: UIButton, on: Bool, c: UIColor) {
        UIView.animate(withDuration: 0.3) {
            b.backgroundColor = on ? UIColor.white.withAlphaComponent(0.2) : .clear
            b.setTitleColor(on ? c : .gray, for: .normal)
        }
    }
    
    func fillSmallCard(view: UIView, title: String, tLabel: UILabel, cLabel: UILabel, statusLabel: UILabel? = nil) {
        let l = UILabel()
        l.text = title
        l.font = .systemFont(ofSize: Responsive.font(13), weight: .bold)
        l.textColor = .white
        l.setContentHuggingPriority(.required, for: .horizontal)
        l.setContentCompressionResistancePriority(.required, for: .horizontal)

        if let statusLabel {
            statusLabel.font = .systemFont(ofSize: Responsive.font(8), weight: .bold)
            statusLabel.textColor = .systemOrange
            statusLabel.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.12)
            statusLabel.layer.borderWidth = 1
            statusLabel.layer.borderColor = UIColor.systemOrange.withAlphaComponent(0.45).cgColor
            statusLabel.layer.cornerRadius = 7
            statusLabel.clipsToBounds = true
            statusLabel.textAlignment = .center
            statusLabel.isHidden = true
            statusLabel.translatesAutoresizingMaskIntoConstraints = false
            statusLabel.heightAnchor.constraint(equalToConstant: Responsive.size(14)).isActive = true
            statusLabel.widthAnchor.constraint(equalToConstant: Responsive.size(55)).isActive = true
        }

        let img = UIImageView(image: UIImage(systemName: "chevron.right"))
        img.tintColor = .white
        img.setContentHuggingPriority(.required, for: .horizontal)

        var topViews: [UIView] = [l]
        if let statusLabel { topViews.append(statusLabel) }
        let spacer = UIView()
        topViews.append(spacer)
        topViews.append(img)
        let top = UIStackView(arrangedSubviews: topViews)
        top.distribution = .fill
        top.alignment = .center
        top.spacing = 6

        let r1 = makeRow(icon: "Running", label: "Distance", c: .neonYellow, l: tLabel)
        let r2 = makeRow(icon: "fire", label: "Calories", c: .neonPink, l: cLabel)

        let box = UIStackView(arrangedSubviews: [top, r1, r2])
        box.axis = .vertical
        box.spacing = 8
        box.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(box)
        NSLayoutConstraint.activate([
            box.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            box.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            box.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    func makeRow(icon: String, label: String, c: UIColor, l: UILabel) -> UIStackView {
        let i = UIImageView(image: UIImage(named: icon))
        i.tintColor = c
        i.contentMode = .scaleAspectFit
        i.widthAnchor.constraint(equalToConstant: 16).isActive = true
        i.heightAnchor.constraint(equalToConstant: 16).isActive = true

        let t = UILabel()
        t.text = label
        t.font = .systemFont(ofSize: 12)
        t.textColor = .lightGray
        l.font = .systemFont(ofSize: 14, weight: .bold)
        l.textColor = c
        let v = UIStackView(arrangedSubviews: [t, l])
        v.axis = .vertical
        let h = UIStackView(arrangedSubviews: [i, v])
        h.spacing = 10
        h.alignment = .top
        return h
    }
    
    func moveBubble() {
        let w = weightBar.bounds.width
        if w > 0 {
            let p = CGFloat(weightBar.progress)
            bubbleConstraint?.constant = (w * p) - (bubbleView.frame.width / 2)
        }
    }
    
    func refreshUI() {
        // Ring + big label show TODAY's (IST) progress vs daily target
        let cal  = apiTodayCalories
        let dist = apiTodayDistance

        UIView.transition(with: bigStatLabel, duration: 0.3, options: .transitionCrossDissolve) {
            self.bigStatLabel.text = self.showCalories ? "\(cal)" : String(format: "%.1f", dist)
            self.subStatLabel.text = self.showCalories ? "Calories Burned" : "Distance (km)"
            self.subStatLabel.textColor = self.showCalories ? .neonPink : .neonYellow
            self.targetLabel.text = self.showCalories
                ? "Target: \(self.apiDailyTargetCalories) cal"
                : String(format: "Target: %.1f km", self.apiDailyTargetDistance)
        }

        // Ring progress — today's value vs daily target
        let calProgress  = apiDailyTargetCalories > 0  ? min(CGFloat(cal)  / CGFloat(apiDailyTargetCalories),  1.0) : 0.0
        let distProgress = apiDailyTargetDistance > 0  ? min(CGFloat(dist) / CGFloat(apiDailyTargetDistance), 1.0) : 0.0
        outerRing.strokeEnd = calProgress
        innerRing.strokeEnd = distProgress
        outerRing.opacity = showCalories ? 1.0 : 0.2
        innerRing.opacity = showCalories ? 0.2 : 1.0

        // Last Run card
        if let lastDist = apiLastSessionDistance, let lastCal = apiLastSessionCalories {
            lastTimeLabel.text = formatDistanceKm(lastDist)
            lastCalLabel.text = "\(lastCal) cal"
        } else {
            lastTimeLabel.text = "-- m"
            lastCalLabel.text = "-- cal"
        }
        let lastStatus = apiLastSessionStatus?.lowercased() ?? ""
        lastRunStatusLabel.text = lastStatus == "abandoned" ? "Abandoned" : nil
        lastRunStatusLabel.isHidden = lastStatus != "abandoned"

        // Personal Best card
        if let bestDist = apiBestSessionDistance, let bestCal = apiBestSessionCalories {
            bestTimeLabel.text = formatDistanceKm(bestDist)
            bestCalLabel.text = "\(bestCal) cal"
        } else {
            bestTimeLabel.text = "-- m"
            bestCalLabel.text = "-- cal"
        }

        // Weight goal from user profile
        if let current = apiCurrentWeight, let target = apiTargetWeight, target > 0 {
            // Determine range: start = max(current, target), end = min(current, target)
            let startWeight = max(current, target)  // heavier end (left)
            let endWeight = min(current, target)    // lighter end (right/goal)
            weightStartLabel.text = String(format: "%.0f kg", startWeight)
            weightEndLabel.text = String(format: "%.0f kg", endWeight)

            let totalRange = startWeight - endWeight
            let diff = current - target
            if abs(diff) < 0.1 {
                weightMsg.text = "Goal reached! 🎉"
            } else if diff > 0 {
                weightMsg.text = String(format: "%.1f kg to go!", diff)
            } else {
                weightMsg.text = String(format: "%.1f kg below target!", abs(diff))
            }

            // Progress: how far along the range from start to target
            let progress: Float
            if totalRange > 0 {
                progress = Float((startWeight - current) / totalRange)
            } else {
                progress = 1.0
            }
            weightBar.progress = max(min(progress, 1.0), 0.05)
            bubbleLabel.text = String(format: "%.1f", current)
        } else {
            weightStartLabel.text = "-- kg"
            weightEndLabel.text = "-- kg"
            weightMsg.text = "Tap edit to set your weight goal"
            weightBar.progress = 0
            bubbleLabel.text = "--"
        }
        moveBubble()

        // Update streak labels with live values
        streakCountLabel?.text = "\(apiCurrentStreak) Day Streak!"
        bestStreakLabel?.text = "Best: \(apiLongestStreak) days"
        if apiCurrentStreak == 0 {
            streakSubtitleLabel?.text = "Start a new streak today!"
        } else if apiCurrentStreak >= apiLongestStreak {
            streakSubtitleLabel?.text = "You're on your best streak! 🔥"
        } else {
            streakSubtitleLabel?.text = "Keep going, you are almost there"
        }
    }
    
    @objc private func handlePullToRefresh() {
        fetchStatsData()
        fetchStreakCalendar()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.mainScroll.refreshControl?.endRefreshing()
        }
    }

    @objc func clickedCal() {
        AudioManager.shared.playEffect(.buttonTapped)
        showCalories = true
        animateToggle(b: calBtn, on: true, c: .neonPink)
        animateToggle(b: timeBtn, on: false, c: .gray)
        refreshUI()
    }
    @objc func clickedTime() {
        AudioManager.shared.playEffect(.buttonTapped)
        showCalories = false
        animateToggle(b: calBtn, on: false, c: .gray)
        animateToggle(b: timeBtn, on: true, c: .neonYellow)
        refreshUI()
    }

    // MARK: - Edit Weight
    @objc func editWeightTapped() {
        AudioManager.shared.playEffect(.buttonTapped)
        let modal = GlassEditModalController(
            title: "Update Weight",
            subtitle: "Track your weight journey with realistic goals",
            icon: "scalemass.fill",
            accentColor: .neonPink,
            fields: [
                GlassEditModalController.FieldConfig(
                    placeholder: "e.g. 70.0",
                    icon: "figure.stand",
                    keyboard: .decimalPad,
                    value: apiCurrentWeight.map { String(format: "%.1f", $0) } ?? "",
                    label: "Current Weight",
                    unit: "kg"
                ),
                GlassEditModalController.FieldConfig(
                    placeholder: "e.g. 65.0",
                    icon: "target",
                    keyboard: .decimalPad,
                    value: apiTargetWeight.map { String(format: "%.1f", $0) } ?? "",
                    label: "Target Weight",
                    unit: "kg"
                )
            ],
            validator: { [weak self] values in
                guard let self = self else { return "Something went wrong. Please try again." }
                guard let current = Double(values[0]), current > 0,
                      let target = Double(values[1]), target > 0 else {
                    return "Please enter valid weight values greater than 0."
                }

                return self.validateWeightInputs(current: current, target: target)
            },
            onSave: { [weak self] values in
                guard let self = self,
                      let current = Double(values[0]), current > 0,
                      let target = Double(values[1]), target > 0,
                      let userId = UserDefaults.standard.string(forKey: "supabaseUserID") else { return }
                Task {
                    do {
                        let data: [String: AnyEncodable] = ["current_weight": AnyEncodable(current), "target_weight": AnyEncodable(target)]
                        let _ = try await SupabaseManager.shared.updateUser(userId: userId, data: data)
                        DispatchQueue.main.async {
                            self.apiCurrentWeight = current
                            self.apiTargetWeight = target
                            self.refreshUI()
                            self.persistStatsSnapshot()
                        }
                    } catch {
                        print("❌ Failed to update weight: \(error)")
                    }
                }
            },
            onValidationError: nil
        )
        modal.modalPresentationStyle = .overCurrentContext
        modal.modalTransitionStyle = .crossDissolve
        present(modal, animated: true)
    }

    // MARK: - Edit Targets
    @objc func editTargetsTapped() {
        AudioManager.shared.playEffect(.buttonTapped)
        let modal = GlassEditModalController(
            title: "Daily Targets",
            subtitle: "Set your daily fitness goals",
            icon: "flame.fill",
            accentColor: .neonYellow,
            fields: [
                GlassEditModalController.FieldConfig(
                    placeholder: "e.g. 300",
                    icon: "flame",
                    keyboard: .numberPad,
                    value: "\(apiDailyTargetCalories)",
                    label: "Calorie Target",
                    unit: "kcal"
                ),
                GlassEditModalController.FieldConfig(
                    placeholder: "e.g. 3.0",
                    icon: "figure.run",
                    keyboard: .decimalPad,
                    value: String(format: "%.1f", apiDailyTargetDistance),
                    label: "Distance Target",
                    unit: "km"
                )
            ],
            onSave: { [weak self] values in
                guard let self = self,
                      let cal = Int(values[0]), cal > 0,
                      let dist = Double(values[1]), dist > 0,
                      let userId = UserDefaults.standard.string(forKey: "supabaseUserID") else { return }
                Task {
                    do {
                        let data: [String: AnyEncodable] = [
                            "daily_target_calories": AnyEncodable(cal),
                            "daily_target_distance": AnyEncodable(dist)
                        ]
                        let _ = try await SupabaseManager.shared.updateUser(userId: userId, data: data)
                        DispatchQueue.main.async {
                            self.apiDailyTargetCalories = cal
                            self.apiDailyTargetDistance = dist
                            self.refreshUI()
                            self.persistStatsSnapshot()
                        }
                    } catch {
                        print("❌ Failed to update targets: \(error)")
                    }
                }
            }
        )
        modal.modalPresentationStyle = .overCurrentContext
        modal.modalTransitionStyle = .crossDissolve
        present(modal, animated: true)
    }

    func styleTabBar() {
        tabContainer.backgroundColor = .clear
        tabContainer.subviews.filter { $0 is UIVisualEffectView }.forEach { $0.removeFromSuperview() }
        
        // Liquid glass ultra-thin material
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.isUserInteractionEnabled = false
        blur.layer.cornerRadius = Responsive.tabBarCornerRadius
        blur.clipsToBounds = true
        blur.translatesAutoresizingMaskIntoConstraints = false

        tabContainer.insertSubview(blur, at: 0)

        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: tabContainer.topAnchor),
            blur.bottomAnchor.constraint(equalTo: tabContainer.bottomAnchor),
            blur.leadingAnchor.constraint(equalTo: tabContainer.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: tabContainer.trailingAnchor)
        ])

        tabContainer.layer.cornerRadius = Responsive.tabBarCornerRadius
        tabContainer.layer.borderWidth = 1.5
        tabContainer.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor

        // Fluid glowing ambient shadow
        tabContainer.layer.shadowColor = UIColor.white.cgColor
        tabContainer.layer.shadowRadius = 15
        tabContainer.layer.shadowOpacity = 0.2
        tabContainer.layer.shadowOffset = .zero

        tabIndicator.backgroundColor = UIColor.white.withAlphaComponent(0.25)
        tabIndicator.layer.cornerRadius = Responsive.cornerRadius(30)
        tabIndicator.layer.cornerCurve = .continuous
        tabIndicator.layer.shadowColor = UIColor.white.cgColor
        tabIndicator.layer.shadowRadius = 8
        tabIndicator.layer.shadowOpacity = 0.4
        tabIndicator.layer.shadowOffset = .zero
        tabContainer.insertSubview(tabIndicator, at: 1)
        
        // Gesture Recognizer for Swipe Navigation
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleTabSwipe(_:)))
        swipeRight.direction = .right
        tabContainer.addGestureRecognizer(swipeRight)
    }

    @objc private func handleTabSwipe(_ gesture: UISwipeGestureRecognizer) {
        if gesture.direction == .right { // Swipe right goes backwards to Customize (index 1)
            AudioManager.shared.playEffect(.buttonTapped)
            let transition = CATransition()
            transition.duration = 0.3
            transition.type = .push
            transition.subtype = .fromLeft
            transition.timingFunction = CAMediaTimingFunction(name: .easeOut)
            view.window?.layer.add(transition, forKey: kCATransition)
            self.dismiss(animated: false, completion: nil)
        }
    }
    
    func initTabs() {
        tabStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        tabIcons.removeAll(); tabLabels.removeAll(); tabWrappers.removeAll()
        tabStack.distribution = .fillEqually
        tabStack.translatesAutoresizingMaskIntoConstraints = false
        tabContainer.addSubview(tabStack)
        NSLayoutConstraint.activate([
            tabStack.topAnchor.constraint(equalTo: tabContainer.topAnchor),
            tabStack.bottomAnchor.constraint(equalTo: tabContainer.bottomAnchor),
            tabStack.leadingAnchor.constraint(equalTo: tabContainer.leadingAnchor, constant: 10),
            tabStack.trailingAnchor.constraint(equalTo: tabContainer.trailingAnchor, constant: -10)
        ])
        let list = [("home2", "Home"), ("customize2", "Customize"), ("statistics2", "Statistics")]
        for (i, (icon, txt)) in list.enumerated() {
            let stack = UIStackView()
            stack.axis = .vertical
            stack.alignment = .center
            stack.spacing = 2
            stack.isUserInteractionEnabled = false
            let img = UIImageView(image: UIImage(named: icon))
            img.contentMode = .scaleAspectFit
            img.translatesAutoresizingMaskIntoConstraints = false
            img.widthAnchor.constraint(equalToConstant: Responsive.size(44)).isActive = true
            img.heightAnchor.constraint(equalToConstant: Responsive.size(34)).isActive = true
            let l = UILabel()
            l.text = txt
            l.font = UIFont.systemFont(ofSize: Responsive.font(10), weight: .semibold)
            l.textColor = .lightGray
            l.textAlignment = .center
            tabIcons.append(img)
            tabLabels.append(l)
            stack.addArrangedSubview(img)
            stack.addArrangedSubview(l)
            let b = UIButton()
            b.tag = i
            b.addTarget(self, action: #selector(tapTab(_:)), for: .touchUpInside)
            b.translatesAutoresizingMaskIntoConstraints = false
            let wrap = UIView()
            wrap.translatesAutoresizingMaskIntoConstraints = false
            wrap.addSubview(stack)
            wrap.addSubview(b)
            tabWrappers.append(wrap)
            stack.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                stack.centerXAnchor.constraint(equalTo: wrap.centerXAnchor),
                stack.centerYAnchor.constraint(equalTo: wrap.centerYAnchor),
                b.topAnchor.constraint(equalTo: wrap.topAnchor),
                b.bottomAnchor.constraint(equalTo: wrap.bottomAnchor),
                b.leadingAnchor.constraint(equalTo: wrap.leadingAnchor),
                b.trailingAnchor.constraint(equalTo: wrap.trailingAnchor)
            ])
            tabStack.addArrangedSubview(wrap)
        }
    }
    
    @objc func tapTab(_ sender: UIButton) {
        AudioManager.shared.playEffect(.buttonTapped)
        let i = sender.tag
        moveIndicator(to: tabWrappers[i], animated: true)
        
        switch i {
        case 0:
            // Go back to Home
            var check = self.presentingViewController
            while check != nil {
                if check is HomeViewController {
                    check?.dismiss(animated: true, completion: nil)
                    return
                }
                check = check?.presentingViewController
            }
            self.dismiss(animated: true, completion: nil)
        case 1:
            // Customize
            let sb = UIStoryboard(name: "Main", bundle: nil)
            if let vc = sb.instantiateViewController(withIdentifier: "CharacterSelectionViewController") as? CharacterSelectionViewController {
                vc.modalPresentationStyle = .fullScreen
                vc.modalTransitionStyle = .crossDissolve
                self.present(vc, animated: true)
            }
        case 2: break  // Already on Statistics
        default: break
        }
    }
    
    func moveIndicator(to v: UIView, animated: Bool) {
        let frame = v.convert(v.bounds, to: tabContainer)
        let newFrame = frame.insetBy(dx: 4, dy: 4)
        // Fluid spring (liquid glass feel) for indicator movement
        UIView.animate(withDuration: animated ? 0.5 : 0.0, delay: 0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.8, options: .curveEaseOut, animations: {
            self.tabIndicator.frame = newFrame
        }, completion: nil)
        for (idx, icon) in tabIcons.enumerated() {
            let selected = (tabWrappers[idx] == v)
            UIView.animate(withDuration: 0.3) {
                icon.alpha = selected ? 1.0 : 0.5
                self.tabLabels[idx].textColor = selected ? .white : .lightGray
                self.tabLabels[idx].alpha = selected ? 1.0 : 0.5
            }
        }
    }
}

// MARK: - Glass Edit Modal Controller
class GlassEditModalController: UIViewController {

    struct FieldConfig {
        let placeholder: String
        let icon: String
        let keyboard: UIKeyboardType
        let value: String
        var label: String = ""
        var unit: String = ""
    }

    struct AsyncFieldValidation {
        let fieldIndex: Int
        let currentValue: String
        let minLength: Int
        let check: (String) async throws -> Bool
    }

    private let modalTitle: String
    private let subtitle: String
    private let iconName: String
    private let accentColor: UIColor
    private let fields: [FieldConfig]
    private let validator: (([String]) -> String?)?
    private let onSave: ([String]) -> Void
    private let onValidationError: ((String) -> Void)?

    private let dimView = UIView()
    private let cardView = UIView()
    private let errorLabel = UILabel()
    private var textFields: [UITextField] = []
    private var cardBottomConstraint: NSLayoutConstraint!

    // Async username validation
    private let asyncStatusLabel  = UILabel()
    private let asyncCheckSpinner = UIActivityIndicatorView(style: .medium)
    private var asyncDebounceTimer: Timer?
    private var asyncValidated    = false
    private var asyncConfig: AsyncFieldValidation?
    private weak var saveButton: UIButton?

    init(
        title: String,
        subtitle: String,
        icon: String,
        accentColor: UIColor,
        fields: [FieldConfig],
        asyncValidation: AsyncFieldValidation? = nil,
        validator: (([String]) -> String?)? = nil,
        onSave: @escaping ([String]) -> Void,
        onValidationError: ((String) -> Void)? = nil
    ) {
        self.asyncConfig = asyncValidation
        self.modalTitle = title
        self.subtitle = subtitle
        self.iconName = icon
        self.accentColor = accentColor
        self.fields = fields
        self.validator = validator
        self.onSave = onSave
        self.onValidationError = onValidationError
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupDim()
        setupCard()
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateIn()
    }

    private func setupDim() {
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.0)
        dimView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dimView)
        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: view.topAnchor),
            dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        let tap = UITapGestureRecognizer(target: self, action: #selector(cancelTapped))
        dimView.addGestureRecognizer(tap)
    }

    private func setupCard() {
        // Card container
        cardView.backgroundColor = UIColor(red: 20/255, green: 12/255, blue: 40/255, alpha: 0.98)
        cardView.layer.cornerRadius = 28
        cardView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardView)

        cardBottomConstraint = cardView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 500)
        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cardBottomConstraint
        ])

        // Drag handle
        let handle = UIView()
        handle.backgroundColor = UIColor.white.withAlphaComponent(0.25)
        handle.layer.cornerRadius = 2.5
        handle.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(handle)

        // Icon circle
        let iconCircle = UIView()
        iconCircle.backgroundColor = accentColor.withAlphaComponent(0.15)
        iconCircle.layer.cornerRadius = 28
        iconCircle.layer.borderWidth = 1
        iconCircle.layer.borderColor = accentColor.withAlphaComponent(0.3).cgColor
        iconCircle.translatesAutoresizingMaskIntoConstraints = false

        let iconImg = UIImageView(image: UIImage(systemName: iconName))
        iconImg.tintColor = accentColor
        iconImg.contentMode = .scaleAspectFit
        iconImg.translatesAutoresizingMaskIntoConstraints = false
        iconCircle.addSubview(iconImg)
        cardView.addSubview(iconCircle)

        // Title
        let titleLbl = UILabel()
        titleLbl.text = modalTitle
        titleLbl.font = .systemFont(ofSize: 22, weight: .bold)
        titleLbl.textColor = .white
        titleLbl.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLbl)

        // Subtitle
        let subLbl = UILabel()
        subLbl.text = subtitle
        subLbl.font = .systemFont(ofSize: 13, weight: .medium)
        subLbl.textColor = UIColor.white.withAlphaComponent(0.45)
        subLbl.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(subLbl)

        // Fields stack
        let fieldsStack = UIStackView()
        fieldsStack.axis = .vertical
        fieldsStack.spacing = 14
        fieldsStack.translatesAutoresizingMaskIntoConstraints = false

        for config in fields {
            let (container, tf) = makeGlassField(config: config)
            textFields.append(tf)
            fieldsStack.addArrangedSubview(container)
        }
        cardView.addSubview(fieldsStack)

        errorLabel.font = .systemFont(ofSize: 12, weight: .medium)
        errorLabel.textColor = .systemRed
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.alpha = 0
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(errorLabel)

        // Buttons
        let cancelBtn = makeActionButton(title: "Cancel", filled: false)
        cancelBtn.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        let saveBtn = makeActionButton(title: "Save", filled: true)
        saveBtn.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        self.saveButton = saveBtn

        // Wire up async validation if configured
        if let config = asyncConfig {
            saveBtn.isEnabled = false
            saveBtn.alpha = 0.5

            asyncStatusLabel.font = .systemFont(ofSize: 11, weight: .semibold)
            asyncStatusLabel.textColor = .white
            asyncStatusLabel.layer.cornerRadius = 5
            asyncStatusLabel.clipsToBounds = true
            asyncStatusLabel.isHidden = true
            asyncStatusLabel.translatesAutoresizingMaskIntoConstraints = false

            asyncCheckSpinner.color = accentColor
            asyncCheckSpinner.hidesWhenStopped = true
            let spinContainer = UIView(frame: CGRect(x: 0, y: 0, width: 32, height: 44))
            asyncCheckSpinner.center = CGPoint(x: 16, y: 22)
            spinContainer.addSubview(asyncCheckSpinner)
            textFields[config.fieldIndex].rightView = spinContainer
            textFields[config.fieldIndex].rightViewMode = .always

            fieldsStack.insertArrangedSubview(asyncStatusLabel, at: config.fieldIndex + 1)

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(asyncFieldTextChanged(_:)),
                name: UITextField.textDidChangeNotification,
                object: textFields[config.fieldIndex]
            )
        }

        let btnStack = UIStackView(arrangedSubviews: [cancelBtn, saveBtn])
        btnStack.spacing = 12
        btnStack.distribution = .fillEqually
        btnStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(btnStack)

        NSLayoutConstraint.activate([
            handle.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            handle.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            handle.widthAnchor.constraint(equalToConstant: 40),
            handle.heightAnchor.constraint(equalToConstant: 5),

            iconCircle.topAnchor.constraint(equalTo: handle.bottomAnchor, constant: 24),
            iconCircle.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            iconCircle.widthAnchor.constraint(equalToConstant: 56),
            iconCircle.heightAnchor.constraint(equalToConstant: 56),
            iconImg.centerXAnchor.constraint(equalTo: iconCircle.centerXAnchor),
            iconImg.centerYAnchor.constraint(equalTo: iconCircle.centerYAnchor),
            iconImg.widthAnchor.constraint(equalToConstant: 24),
            iconImg.heightAnchor.constraint(equalToConstant: 24),

            titleLbl.topAnchor.constraint(equalTo: iconCircle.bottomAnchor, constant: 16),
            titleLbl.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),

            subLbl.topAnchor.constraint(equalTo: titleLbl.bottomAnchor, constant: 4),
            subLbl.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),

            fieldsStack.topAnchor.constraint(equalTo: subLbl.bottomAnchor, constant: 28),
            fieldsStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 28),
            fieldsStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -28),

            errorLabel.topAnchor.constraint(equalTo: fieldsStack.bottomAnchor, constant: 14),
            errorLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 28),
            errorLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -28),

            btnStack.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 18),
            btnStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 28),
            btnStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -28),
            btnStack.heightAnchor.constraint(equalToConstant: 50),
            btnStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -40)
        ])
    }

    private func makeGlassField(config: FieldConfig) -> (UIView, UITextField) {
        let hasLabel = !config.label.isEmpty
        let hasUnit  = !config.unit.isEmpty
        let containerH: CGFloat = hasLabel ? 72 : 54

        let container = UIView()
        container.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        container.layer.cornerRadius = 14
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: containerH).isActive = true

        let icon = UIImageView(image: UIImage(systemName: config.icon))
        icon.tintColor = accentColor.withAlphaComponent(0.7)
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let tf = UITextField()
        tf.text = config.value
        tf.attributedPlaceholder = NSAttributedString(
            string: config.placeholder,
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.3)]
        )
        tf.textColor = .white
        tf.font = .systemFont(ofSize: 16, weight: .medium)
        tf.keyboardType = config.keyboard
        tf.tintColor = accentColor
        tf.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(icon)
        container.addSubview(tf)

        if hasLabel {
            let subLbl = UILabel()
            subLbl.text = config.label
            subLbl.font = .systemFont(ofSize: 11, weight: .semibold)
            subLbl.textColor = UIColor.white.withAlphaComponent(0.4)
            subLbl.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(subLbl)

            NSLayoutConstraint.activate([
                subLbl.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
                subLbl.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

                icon.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
                icon.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -15),
                icon.widthAnchor.constraint(equalToConstant: 18),
                icon.heightAnchor.constraint(equalToConstant: 18),

                tf.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
                tf.centerYAnchor.constraint(equalTo: icon.centerYAnchor)
            ])
        } else {
            NSLayoutConstraint.activate([
                icon.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
                icon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 20),
                icon.heightAnchor.constraint(equalToConstant: 20),

                tf.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
                tf.centerYAnchor.constraint(equalTo: container.centerYAnchor)
            ])
        }

        if hasUnit {
            let unitLbl = UILabel()
            unitLbl.text = config.unit
            unitLbl.font = .systemFont(ofSize: 14, weight: .semibold)
            unitLbl.textColor = UIColor.white.withAlphaComponent(0.4)
            unitLbl.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(unitLbl)

            NSLayoutConstraint.activate([
                unitLbl.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
                unitLbl.centerYAnchor.constraint(equalTo: tf.centerYAnchor),
                tf.trailingAnchor.constraint(equalTo: unitLbl.leadingAnchor, constant: -8)
            ])
        } else {
            tf.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16).isActive = true
        }

        return (container, tf)
    }

    private func makeActionButton(title: String, filled: Bool) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        btn.layer.cornerRadius = 14

        if filled {
            btn.backgroundColor = accentColor
            btn.setTitleColor(UIColor(red: 13/255, green: 5/255, blue: 26/255, alpha: 1.0), for: .normal)
        } else {
            btn.backgroundColor = UIColor.white.withAlphaComponent(0.06)
            btn.setTitleColor(.white.withAlphaComponent(0.7), for: .normal)
            btn.layer.borderWidth = 1
            btn.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        }
        return btn
    }

    // MARK: - Animations
    private func animateIn() {
        view.layoutIfNeeded()
        cardBottomConstraint.constant = 0
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            self.dimView.backgroundColor = UIColor.black.withAlphaComponent(0.55)
            self.view.layoutIfNeeded()
        } completion: { _ in
            self.textFields.first?.becomeFirstResponder()
        }
    }

    private func animateOut(completion: (() -> Void)? = nil) {
        view.endEditing(true)
        cardBottomConstraint.constant = 500
        UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseIn) {
            self.dimView.backgroundColor = UIColor.black.withAlphaComponent(0.0)
            self.view.layoutIfNeeded()
        } completion: { _ in
            self.dismiss(animated: false, completion: completion)
        }
    }

    @objc private func cancelTapped() {
        AudioManager.shared.playEffect(.buttonTapped)
        animateOut()
    }

    // MARK: - Async Field Validation

    @objc private func asyncFieldTextChanged(_ notification: Notification) {
        guard let config = asyncConfig, let tf = notification.object as? UITextField else { return }

        // Auto-correct: lowercase, no spaces
        let raw = tf.text ?? ""
        let corrected = String(raw.lowercased().filter { !$0.isWhitespace })
        if raw != corrected { tf.text = corrected }

        asyncDebounceTimer?.invalidate()
        asyncValidated = false
        updateAsyncSaveButton()

        let text = corrected

        // Blank = keep existing, allow save
        if text.isEmpty {
            asyncValidated = true
            asyncStatusLabel.isHidden = true
            updateAsyncSaveButton()
            return
        }

        // Same as current value → skip re-check
        if text == config.currentValue.lowercased() {
            asyncValidated = true
            asyncStatusLabel.isHidden = true
            updateAsyncSaveButton()
            return
        }

        guard text.count >= config.minLength else {
            setAsyncStatus("  Minimum \(config.minLength) characters  ", color: .systemOrange)
            asyncCheckSpinner.stopAnimating()
            return
        }

        asyncStatusLabel.isHidden = true
        asyncDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
            self?.performAsyncCheck(text)
        }
    }

    private func performAsyncCheck(_ username: String) {
        asyncCheckSpinner.startAnimating()
        asyncStatusLabel.isHidden = true

        Task {
            do {
                let taken = try await asyncConfig?.check(username) ?? false
                DispatchQueue.main.async {
                    self.asyncCheckSpinner.stopAnimating()
                    if taken {
                        self.setAsyncStatus("  Username already taken  ", color: .systemRed)
                        self.asyncValidated = false
                    } else {
                        self.setAsyncStatus("  Available  ", color: .systemGreen)
                        self.asyncValidated = true
                    }
                    self.updateAsyncSaveButton()
                }
            } catch {
                DispatchQueue.main.async {
                    self.asyncCheckSpinner.stopAnimating()
                    self.setAsyncStatus("  Could not check — try again  ", color: .systemOrange)
                    self.asyncValidated = false
                    self.updateAsyncSaveButton()
                }
            }
        }
    }

    private func setAsyncStatus(_ text: String, color: UIColor) {
        asyncStatusLabel.isHidden = false
        asyncStatusLabel.text = text
        asyncStatusLabel.textColor = .white
        asyncStatusLabel.backgroundColor = color.withAlphaComponent(0.85)
    }

    private func updateAsyncSaveButton() {
        let enabled = asyncConfig == nil || asyncValidated
        saveButton?.isEnabled = enabled
        saveButton?.alpha     = enabled ? 1.0 : 0.5
    }

    @objc private func saveTapped() {
        AudioManager.shared.playEffect(.buttonTapped)
        let values = textFields.map { $0.text ?? "" }

        guard asyncConfig == nil || asyncValidated else {
            showValidationError("Please wait for username validation to complete.")
            shakeCard()
            return
        }

        // Validate all fields are non-empty
        guard values.allSatisfy({ !$0.isEmpty }) else {
            showValidationError("Please fill in all fields.")
            shakeCard()
            return
        }

        if let errorMessage = validator?(values) {
            showValidationError(errorMessage)
            shakeCard()
            onValidationError?(errorMessage)
            return
        }

        clearValidationError()
        animateOut { [weak self] in
            self?.onSave(values)
        }
    }

    private func showValidationError(_ message: String) {
        errorLabel.text = message
        UIView.animate(withDuration: 0.2) {
            self.errorLabel.alpha = 1
        }
    }

    private func clearValidationError() {
        errorLabel.text = nil
        errorLabel.alpha = 0
    }

    private func shakeCard() {
        let anim = CAKeyframeAnimation(keyPath: "transform.translation.x")
        anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        anim.duration = 0.4
        anim.values = [-12, 12, -8, 8, -4, 4, 0]
        cardView.layer.add(anim, forKey: "shake")

        // Flash border red
        let origColor = cardView.layer.borderColor
        cardView.layer.borderColor = UIColor.systemRed.withAlphaComponent(0.6).cgColor
        UIView.animate(withDuration: 0.4, delay: 0.3) {
            self.cardView.layer.borderColor = origColor
        }
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        cardBottomConstraint.constant = -keyboardFrame.height
        UIView.animate(withDuration: duration) { self.view.layoutIfNeeded() }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        cardBottomConstraint.constant = 0
        UIView.animate(withDuration: duration) { self.view.layoutIfNeeded() }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
