import UIKit

struct Badge: Codable {
    let id: String
    let title: String
    let description: String
    let iconName: String
    let progress: Float
    let progressText: String
    let isLocked: Bool
    let completionToken: String?
}

class ProfileViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private struct CachedProfileSnapshot: Codable {
        let displayName: String
        let username: String
        let shortId: String
        let realUserId: String
        let inProgressBadges: [Badge]
        let completedBadges: [Badge]
    }

    private let backgroundImageView = UIImageView()
    private let headerView = UIView()
    private let backButton = UIButton()
    private let settingsButton = UIButton()
    private let titleLabel = UILabel()

    private let avatarImageView = UIImageView()
    private let editLabel  = UILabel()
    private let editButton = UIButton()          // transparent overlay on avatar + edit label
    private let nameLabel  = UILabel()
    private let emailLabel = UILabel()
    private let idPillView = UIView()
    private let idLabel = UILabel()

    private let tabContainer = UIView()
    private let inProgressButton = UIButton()
    private let completedButton = UIButton()
    private let tabIndicator = UIView()
    private let tableView = UITableView()
    private let emptyStateLabel = UILabel()

    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    private var isShowingCompleted = false
    private var inProgressBadges: [Badge] = []
    private var completedBadges: [Badge] = []
    private var activeBadges: [Badge] { return isShowingCompleted ? completedBadges : inProgressBadges }
    private var realUserId: String = ""

    private var headerTopInset: CGFloat {
        Responsive.isIPad ? 14 : 0
    }

    private var headerHeight: CGFloat {
        Responsive.isIPad ? 72 : Responsive.navBarHeight
    }

    private var headerSideInset: CGFloat {
        Responsive.isIPad ? 28 : Responsive.contentInset
    }

    private var profileCacheKey: String? {
        guard let userId = UserDefaults.standard.string(forKey: "supabaseUserID") else { return nil }
        return "profile.cache.\(userId)"
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupData()
        setupUI()
        setupActions()
        updateTabSelection()
        applyCachedProfileSnapshot()
        fetchRealProfileData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AudioManager.shared.playAppMusic()
    }
    
    func fetchRealProfileData() {
        guard let userId = UserDefaults.standard.string(forKey: "supabaseUserID") else { return }

        if !applyCachedProfileSnapshot() {
            loadingIndicator.startAnimating()
        }
        Task {
            var fetchedDisplayName: String?
            var fetchedUsername: String?
            var fetchedShortId: String?
            var fetchedRealUserId: String?

            // ── 1. Profile header (must always succeed) ──────────────────────
            do {
                let user = try await SupabaseManager.shared.getUser(userId: userId)
                fetchedDisplayName = user.display_name ?? user.username ?? "Player"
                fetchedUsername = "@\(user.username ?? "")"
                fetchedShortId = String(user.id.prefix(8)).uppercased()
                fetchedRealUserId = user.id
                DispatchQueue.main.async {
                    self.nameLabel.text  = fetchedDisplayName
                    self.emailLabel.text = fetchedUsername
                    self.idLabel.text = "ID: \(fetchedShortId ?? "...")"
                    self.realUserId   = user.id
                }
            } catch {
                print("❌ Failed to fetch user profile: \(error)")
            }

            // ── 2. Badges (isolated — a missing endpoint won't break the header) ──
            do {
                async let userBadgesFetch = SupabaseManager.shared.getUserBadges(userId: userId)
                async let allBadgesFetch  = SupabaseManager.shared.getAllBadges()
                async let sessionsFetch   = SupabaseManager.shared.getUserSessions(userId: userId)
                let (userBadges, allBadges, sessions) = try await (userBadgesFetch, allBadgesFetch, sessionsFetch)

                // Build a lookup: badge id → UserBadge progress record
                let progressMap = Dictionary(uniqueKeysWithValues: userBadges.compactMap { ub -> (String, AppUserBadge)? in
                    guard let bid = ub.badge?.id ?? ub.badge_id else { return nil }
                    return (bid, ub)
                })

                let qualifyingSessions = sessions.filter(\.countsTowardDailyProgress)
                let derivedDistanceProgress = qualifyingSessions.compactMap(\.distance_covered).reduce(0, +)
                let derivedCaloriesProgress = Double(qualifyingSessions.compactMap(\.calories_burned).reduce(0, +))

                var inProgress: [Badge] = []
                var completed:  [Badge] = []

                for badge in allBadges {
                    let userBadge    = progressMap[badge.id]
                    let storedCurrent = userBadge?.current_progress ?? 0
                    let derivedCurrent: Double
                    switch badge.badge_type {
                    case "distance":
                        derivedCurrent = derivedDistanceProgress
                    case "calories":
                        derivedCurrent = derivedCaloriesProgress
                    default:
                        derivedCurrent = storedCurrent
                    }
                    let current = max(storedCurrent, derivedCurrent)
                    let target       = badge.target_value
                    let isCompleted  = (userBadge?.is_completed ?? false) || current >= target
                    let progress     = target > 0 ? Float(current / target) : 0
                    let progressText = self.formatProgress(current, target: target, type: badge.badge_type)
                    let completionToken = self.completionToken(for: badge.id, userBadge: userBadge)

                    let badgeImageName = Self.badgeImageName(for: badge.name)
                    let localBadge = Badge(
                        id:           badge.id,
                        title:        badge.name,
                        description:  badge.description,
                        iconName:     badgeImageName,
                        progress:     min(progress, 1.0),
                        progressText: isCompleted ? "Done" : progressText,
                        isLocked:     !isCompleted,
                        completionToken: completionToken
                    )

                    if isCompleted { completed.append(localBadge) }
                    else           { inProgress.append(localBadge) }
                }

                DispatchQueue.main.async {
                    self.loadingIndicator.stopAnimating()
                    self.inProgressBadges = inProgress
                    self.completedBadges  = completed
                    self.tableView.reloadData()
                    self.updateEmptyState()

                    let shownCompletionTokens = self.shownBadgeCompletionTokens(for: userId)
                    let newlyCompletedBadges = completed.filter { badge in
                        guard let token = badge.completionToken else { return false }
                        return !shownCompletionTokens.contains(token)
                    }

                    if let firstNewBadge = newlyCompletedBadges.first {
                        CelebrationView.showBadge(on: self, badgeName: firstNewBadge.title, badgeImageName: firstNewBadge.iconName)
                    }

                    let currentCompletionTokens = Set(completed.compactMap(\.completionToken))
                    self.storeShownBadgeCompletionTokens(currentCompletionTokens, for: userId)
                    self.persistProfileSnapshot(
                        displayName: fetchedDisplayName ?? self.nameLabel.text ?? "Player",
                        username: fetchedUsername ?? self.emailLabel.text ?? "",
                        shortId: fetchedShortId ?? self.shortDisplayId(),
                        realUserId: fetchedRealUserId ?? self.realUserId,
                        inProgressBadges: inProgress,
                        completedBadges: completed
                    )

                    print("✅ Badges: \(inProgress.count) in progress, \(completed.count) completed (catalogue: \(allBadges.count))")
                }
            } catch {
                DispatchQueue.main.async {
                    self.loadingIndicator.stopAnimating()
                    self.updateEmptyState()
                }
                print("❌ Failed to fetch badges: \(error) — profile header still visible")
            }
        }
    }

    private func formatProgress(_ current: Double, target: Double, type: String) -> String {
        switch type {
        case "distance":
            return String(format: "%.1f/%.0f km", min(current, target), target)
        case "calories":
            return "\(Int(min(current, target)))/\(Int(target)) cal"
        case "sessions":
            return "\(Int(min(current, target)))/\(Int(target))"
        case "streak":
            return "\(Int(min(current, target)))/\(Int(target)) days"
        case "jumps":
            return "\(Int(min(current, target)))/\(Int(target)) jumps"
        case "crouches":
            return "\(Int(min(current, target)))/\(Int(target)) crouches"
        default:
            return String(format: "%.0f/%.0f", min(current, target), target)
        }
    }

    private static func badgeImageName(for name: String) -> String {
        switch name {
        case "First Run":        return "badge_first_run"
        case "Reactor Core":     return "badge_reactor_core"
        case "Nebula Walker":    return "badge_nebula_walker"
        case "Titanium Lungs":   return "badge_titanium_lungs"
        case "Calorie Crusher":  return "badge_calorie_crusher"
        case "Marathon Runner":  return "badge_marathon_runner"
        case "Streak Master":    return "badge_streak_master"
        default:                 return "badge_first_run"
        }
    }

    private func shownBadgeCompletionTokens(for userId: String) -> Set<String> {
        let key = shownBadgeCompletionTokensKey(for: userId)
        let stored = UserDefaults.standard.stringArray(forKey: key) ?? []
        return Set(stored)
    }

    private func storeShownBadgeCompletionTokens(_ tokens: Set<String>, for userId: String) {
        let key = shownBadgeCompletionTokensKey(for: userId)
        UserDefaults.standard.set(Array(tokens).sorted(), forKey: key)
    }

    private func shownBadgeCompletionTokensKey(for userId: String) -> String {
        "shown_badge_completion_tokens_\(userId)"
    }

    private func completionToken(for badgeId: String, userBadge: AppUserBadge?) -> String? {
        guard userBadge?.is_completed == true else { return nil }
        if let completedAt = userBadge?.completed_at, !completedAt.isEmpty {
            return "\(badgeId)|\(completedAt)"
        }
        return badgeId
    }

    @discardableResult
    private func applyCachedProfileSnapshot() -> Bool {
        guard let key = profileCacheKey,
              let data = UserDefaults.standard.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(CachedProfileSnapshot.self, from: data) else {
            return false
        }

        nameLabel.text = snapshot.displayName
        emailLabel.text = snapshot.username
        idLabel.text = "ID: \(snapshot.shortId)"
        realUserId = snapshot.realUserId
        inProgressBadges = snapshot.inProgressBadges
        completedBadges = snapshot.completedBadges
        tableView.reloadData()
        updateEmptyState()
        return true
    }

    private func persistProfileSnapshot(
        displayName: String,
        username: String,
        shortId: String,
        realUserId: String,
        inProgressBadges: [Badge],
        completedBadges: [Badge]
    ) {
        guard let key = profileCacheKey else { return }
        let snapshot = CachedProfileSnapshot(
            displayName: displayName,
            username: username,
            shortId: shortId,
            realUserId: realUserId,
            inProgressBadges: inProgressBadges,
            completedBadges: completedBadges
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func shortDisplayId() -> String {
        if let text = idLabel.text?.replacingOccurrences(of: "ID: ", with: ""), !text.isEmpty, text != "..." {
            return text
        }
        if let userId = UserDefaults.standard.string(forKey: "supabaseUserID") {
            return String(userId.prefix(8)).uppercased()
        }
        return "..."
    }

    private func updateEmptyState() {
        let totalBadgeCount = inProgressBadges.count + completedBadges.count
        let message: String?

        if isShowingCompleted {
            message = completedBadges.isEmpty ? "No badges earned yet" : nil
        } else {
            message = (totalBadgeCount > 0 && inProgressBadges.isEmpty) ? "All badges earned" : nil
        }

        emptyStateLabel.text = message
        emptyStateLabel.isHidden = (message == nil)
        tableView.backgroundView = message == nil ? nil : emptyStateLabel
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        avatarImageView.layer.cornerRadius = avatarImageView.frame.height / 2
        backButton.layer.cornerRadius = backButton.frame.height / 2
        settingsButton.layer.cornerRadius = settingsButton.frame.height / 2
        idPillView.layer.cornerRadius = idPillView.frame.height / 2
    }

    func setupData() {
        // Start empty — real data populated by fetchRealProfileData()
        inProgressBadges = []
        completedBadges = []
    }

    func setupUI() {
        view.backgroundColor = UIColor(red: 0.05, green: 0.02, blue: 0.1, alpha: 1.0)
        backgroundImageView.image = UIImage(named: "WhatsApp Image 2025-09-24 at 14.26.03")
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.alpha = 0.4
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundImageView)
        view.sendSubviewToBack(backgroundImageView)
        
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        setupHeader()
        setupProfileSection()
        setupTabs()
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(BadgeCell.self, forCellReuseIdentifier: "BadgeCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateLabel.font = .systemFont(ofSize: Responsive.font(15), weight: .semibold)
        emptyStateLabel.textColor = UIColor.white.withAlphaComponent(0.55)
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.numberOfLines = 0
        emptyStateLabel.isHidden = true
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: tabContainer.bottomAnchor, constant: 10),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        loadingIndicator.color = .white
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: tableView.centerYAnchor)
        ])
    }
    
    func setupHeader() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = Responsive.isIPad ? UIColor.black.withAlphaComponent(0.10) : .clear
        view.addSubview(headerView)
        
        setupGlassButton(backButton, icon: "chevron.left")
        setupGlassButton(settingsButton, icon: "gearshape")
        
        titleLabel.text = "Profile"
        titleLabel.font = .systemFont(ofSize: Responsive.font(20), weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        headerView.addSubview(backButton)
        headerView.addSubview(settingsButton)
        headerView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: headerTopInset),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: headerHeight),

            backButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: headerSideInset),
            backButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: Responsive.size(44)),
            backButton.heightAnchor.constraint(equalToConstant: Responsive.size(44)),

            settingsButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -headerSideInset),
            settingsButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: Responsive.size(44)),
            settingsButton.heightAnchor.constraint(equalToConstant: Responsive.size(44)),
            
            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
        ])
    }
    
    func setupProfileSection() {
        avatarImageView.image = UIImage(named: "profile")
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.layer.borderWidth = 2
        avatarImageView.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false

        editLabel.text = "Edit Profile"
        editLabel.font = .systemFont(ofSize: Responsive.font(12), weight: .medium)
        editLabel.textColor = UIColor(red: 0.6, green: 0.4, blue: 1.0, alpha: 1)
        editLabel.translatesAutoresizingMaskIntoConstraints = false

        editButton.backgroundColor = .clear
        editButton.translatesAutoresizingMaskIntoConstraints = false
        editButton.addTarget(self, action: #selector(editProfileTapped), for: .touchUpInside)
        nameLabel.text = ""
        nameLabel.font = .systemFont(ofSize: Responsive.font(22), weight: .bold)
        nameLabel.textColor = .white
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        emailLabel.text = ""
        emailLabel.font = .systemFont(ofSize: Responsive.font(12))
        emailLabel.textColor = .gray
        emailLabel.translatesAutoresizingMaskIntoConstraints = false
        idPillView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        idPillView.layer.borderWidth = 1
        idPillView.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        idPillView.translatesAutoresizingMaskIntoConstraints = false
        idLabel.text = "ID: ..."
        idLabel.font = .systemFont(ofSize: Responsive.font(12), weight: .bold)
        idLabel.textColor = .white
        idLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let copyIcon = UIImageView(image: UIImage(systemName: "doc.on.doc"))
        copyIcon.tintColor = .lightGray
        copyIcon.contentMode = .scaleAspectFit
        copyIcon.translatesAutoresizingMaskIntoConstraints = false

        // Transparent UIButton overlay — far more reliable than a tap gesture recogniser
        // in complex scroll/table view hierarchies.
        let copyButton = UIButton(type: .system)
        copyButton.backgroundColor = .clear
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        copyButton.addTarget(self, action: #selector(copyIDTapped), for: .touchUpInside)

        view.addSubview(avatarImageView)
        view.addSubview(editLabel)
        view.addSubview(editButton)
        view.addSubview(nameLabel)
        view.addSubview(emailLabel)
        view.addSubview(idPillView)
        idPillView.addSubview(idLabel)
        idPillView.addSubview(copyIcon)
        idPillView.addSubview(copyButton)   // on top — catches all taps on the pill

        NSLayoutConstraint.activate([
            avatarImageView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: Responsive.padding(10)),
            avatarImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: Responsive.size(100)),
            avatarImageView.heightAnchor.constraint(equalToConstant: Responsive.size(100)),

            editLabel.topAnchor.constraint(equalTo: avatarImageView.bottomAnchor, constant: Responsive.padding(8)),
            editLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Edit button covers the avatar + edit label so the whole area is tappable
            editButton.topAnchor.constraint(equalTo: avatarImageView.topAnchor),
            editButton.bottomAnchor.constraint(equalTo: editLabel.bottomAnchor),
            editButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            editButton.widthAnchor.constraint(equalToConstant: Responsive.size(120)),

            nameLabel.topAnchor.constraint(equalTo: editLabel.bottomAnchor, constant: Responsive.padding(8)),
            nameLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            emailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: Responsive.padding(4)),
            emailLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            idPillView.topAnchor.constraint(equalTo: emailLabel.bottomAnchor, constant: Responsive.padding(12)),
            idPillView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            idPillView.heightAnchor.constraint(equalToConstant: Responsive.size(32)),
            idPillView.widthAnchor.constraint(greaterThanOrEqualToConstant: Responsive.size(140)),

            idLabel.leadingAnchor.constraint(equalTo: idPillView.leadingAnchor, constant: Responsive.padding(16)),
            idLabel.centerYAnchor.constraint(equalTo: idPillView.centerYAnchor),
            
            copyIcon.leadingAnchor.constraint(equalTo: idLabel.trailingAnchor, constant: Responsive.padding(8)),
            copyIcon.trailingAnchor.constraint(equalTo: idPillView.trailingAnchor, constant: -Responsive.padding(12)),
            copyIcon.centerYAnchor.constraint(equalTo: idPillView.centerYAnchor),
            copyIcon.widthAnchor.constraint(equalToConstant: Responsive.size(14)),
            copyIcon.heightAnchor.constraint(equalToConstant: Responsive.size(14)),

            // Copy button fills the entire pill
            copyButton.topAnchor.constraint(equalTo: idPillView.topAnchor),
            copyButton.bottomAnchor.constraint(equalTo: idPillView.bottomAnchor),
            copyButton.leadingAnchor.constraint(equalTo: idPillView.leadingAnchor),
            copyButton.trailingAnchor.constraint(equalTo: idPillView.trailingAnchor)
        ])
    }
    
    func setupTabs() {
        tabContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabContainer)
        
        let header = UILabel()
        header.text = "Badges"
        header.font = .systemFont(ofSize: Responsive.font(20), weight: .bold)
        header.textColor = .white
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)
        
        configureTabButton(inProgressButton, title: "In Progress")
        configureTabButton(completedButton, title: "Completed")
        
        tabContainer.addSubview(inProgressButton)
        tabContainer.addSubview(completedButton)
        
        tabIndicator.backgroundColor = UIColor(red: 0.6, green: 0.4, blue: 1.0, alpha: 1.0)
        tabIndicator.translatesAutoresizingMaskIntoConstraints = false
        tabContainer.addSubview(tabIndicator)
        
        let divider = UIView()
        divider.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        divider.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(divider)
        
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: idPillView.bottomAnchor, constant: Responsive.padding(30)),
            header.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            tabContainer.topAnchor.constraint(equalTo: header.bottomAnchor, constant: Responsive.padding(15)),
            tabContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Responsive.contentInset),
            tabContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Responsive.contentInset),
            tabContainer.heightAnchor.constraint(equalToConstant: Responsive.size(40)),
            
            inProgressButton.leadingAnchor.constraint(equalTo: tabContainer.leadingAnchor),
            inProgressButton.topAnchor.constraint(equalTo: tabContainer.topAnchor),
            inProgressButton.bottomAnchor.constraint(equalTo: tabContainer.bottomAnchor),
            inProgressButton.widthAnchor.constraint(equalTo: tabContainer.widthAnchor, multiplier: 0.5),
            
            completedButton.trailingAnchor.constraint(equalTo: tabContainer.trailingAnchor),
            completedButton.topAnchor.constraint(equalTo: tabContainer.topAnchor),
            completedButton.bottomAnchor.constraint(equalTo: tabContainer.bottomAnchor),
            completedButton.widthAnchor.constraint(equalTo: tabContainer.widthAnchor, multiplier: 0.5),
            
            tabIndicator.heightAnchor.constraint(equalToConstant: 2),
            tabIndicator.bottomAnchor.constraint(equalTo: tabContainer.bottomAnchor),
            tabIndicator.widthAnchor.constraint(equalTo: tabContainer.widthAnchor, multiplier: 0.5),
            tabIndicator.centerXAnchor.constraint(equalTo: inProgressButton.centerXAnchor),
            
            divider.topAnchor.constraint(equalTo: tabContainer.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    func setupActions() {
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        
        // 🔥 ADDED THIS: Connect the settings button
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        
        inProgressButton.addTarget(self, action: #selector(tabChanged(_:)), for: .touchUpInside)
        completedButton.addTarget(self, action: #selector(tabChanged(_:)), for: .touchUpInside)

        // Swipe gestures for badge tabs
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(badgeSwipedLeft))
        swipeLeft.direction = .left
        tableView.addGestureRecognizer(swipeLeft)

        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(badgeSwipedRight))
        swipeRight.direction = .right
        tableView.addGestureRecognizer(swipeRight)
    }

    @objc private func badgeSwipedLeft() {
        if !isShowingCompleted {
            tabChanged(completedButton)
        }
    }

    @objc private func badgeSwipedRight() {
        if isShowingCompleted {
            tabChanged(inProgressButton)
        }
    }
    
    @objc func backTapped() {
        AudioManager.shared.playEffect(.buttonTapped)
        dismiss(animated: true, completion: nil)
    }
    
    // 🔥 ADDED THIS: Action to open Settings
    @objc func settingsTapped() {
        AudioManager.shared.playEffect(.buttonTapped)
        print("⚙️ Opening Settings...")
        let settingsVC = SettingsViewController()
        settingsVC.modalPresentationStyle = .fullScreen
        settingsVC.modalTransitionStyle = .crossDissolve
        present(settingsVC, animated: true)
    }
    
    @objc func editProfileTapped() {
        AudioManager.shared.playEffect(.buttonTapped)
        let currentName     = nameLabel.text ?? ""
        let rawUsername     = emailLabel.text ?? ""
        let currentUsername = rawUsername.hasPrefix("@") ? String(rawUsername.dropFirst()) : rawUsername
        let purple          = UIColor(red: 0.6, green: 0.4, blue: 1.0, alpha: 1)

        let modal = GlassEditModalController(
            title: "Edit Profile",
            subtitle: "Update your name and username",
            icon: "person.fill",
            accentColor: purple,
            fields: [
                GlassEditModalController.FieldConfig(
                    placeholder: "e.g. John Doe",
                    icon: "person.fill",
                    keyboard: .default,
                    value: currentName,
                    label: "Display Name"
                ),
                GlassEditModalController.FieldConfig(
                    placeholder: "e.g. johndoe",
                    icon: "at",
                    keyboard: .default,
                    value: currentUsername,
                    label: "Username"
                )
            ],
            asyncValidation: GlassEditModalController.AsyncFieldValidation(
                fieldIndex: 1,
                currentValue: currentUsername,
                minLength: 3,
                check: { username in
                    try await SupabaseManager.shared.checkUsernameExists(username)
                }
            )
        ) { [weak self] values in
            guard let self = self else { return }
            let newName     = values.count > 0 ? values[0].trimmingCharacters(in: .whitespaces) : ""
            let newUsername = values.count > 1 ? values[1].trimmingCharacters(in: .whitespaces) : ""

            if !newName.isEmpty     { self.nameLabel.text  = newName }
            if !newUsername.isEmpty { self.emailLabel.text = "@\(newUsername)" }

            guard let userId = UserDefaults.standard.string(forKey: "supabaseUserID") else { return }
            Task {
                do {
                    var data: [String: AnyEncodable] = [:]
                    if !newName.isEmpty     { data["display_name"] = AnyEncodable(newName) }
                    if !newUsername.isEmpty { data["username"]     = AnyEncodable(newUsername) }
                    guard !data.isEmpty else { return }
                    _ = try await SupabaseManager.shared.updateUser(userId: userId, data: data)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    print("✅ Profile updated — name: \(newName), username: \(newUsername)")
                } catch {
                    print("❌ Failed to update profile: \(error)")
                }
            }
        }
        modal.modalPresentationStyle = .overFullScreen
        modal.modalTransitionStyle   = .crossDissolve
        present(modal, animated: true)
    }

    @objc func copyIDTapped() {
        AudioManager.shared.playEffect(.buttonTapped)
        let idToCopy = realUserId.isEmpty ? (UserDefaults.standard.string(forKey: "supabaseUserID") ?? "123456") : realUserId
        UIPasteboard.general.string = idToCopy
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    @objc func tabChanged(_ sender: UIButton) {
        AudioManager.shared.playEffect(.buttonTapped)
        let isCompletedTab = (sender == completedButton)
        if isCompletedTab == isShowingCompleted { return }

        let swipeDirection: UIView.AnimationOptions = isCompletedTab ? .transitionFlipFromRight : .transitionFlipFromLeft
        let slideDirection: CGFloat = isCompletedTab ? 1 : -1

        isShowingCompleted = isCompletedTab
        updateTabSelection()
        updateEmptyState()

        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0.5, options: .curveEaseOut) {
            self.tabIndicator.center.x = sender.center.x
        }

        // Slide out + slide in animation
        let snapshot = tableView.snapshotView(afterScreenUpdates: false)
        if let snap = snapshot {
            snap.frame = tableView.frame
            tableView.superview?.addSubview(snap)

            tableView.transform = CGAffineTransform(translationX: slideDirection * tableView.bounds.width, y: 0)
            tableView.reloadData()
            updateEmptyState()

            UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.85,
                           initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
                self.tableView.transform = .identity
                snap.transform = CGAffineTransform(translationX: -slideDirection * self.tableView.bounds.width, y: 0)
                snap.alpha = 0
            }) { _ in
                snap.removeFromSuperview()
            }
        } else {
            tableView.reloadData()
            updateEmptyState()
        }
    }
    
    func updateTabSelection() {
        inProgressButton.setTitleColor(isShowingCompleted ? .gray : .white, for: .normal)
        completedButton.setTitleColor(isShowingCompleted ? .white : .gray, for: .normal)
    }
    
    func setupGlassButton(_ button: UIButton, icon: String) {
        button.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        let config = UIImage.SymbolConfiguration(pointSize: Responsive.font(16), weight: .bold)
        button.setImage(UIImage(systemName: icon, withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
    }
    
    func configureTabButton(_ button: UIButton, title: String) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: Responsive.font(14), weight: .semibold)
        button.setTitleColor(.gray, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return activeBadges.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BadgeCell", for: indexPath) as! BadgeCell
        let badge = activeBadges[indexPath.row]
        cell.configure(with: badge)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return Responsive.size(100)
    }
}

class BadgeCell: UITableViewCell {
    
    private let containerView = UIView()
    private let iconContainer = UIView()
    private let iconImageView = UIImageView()
    private let lockImageView = UIImageView()
    private let titleLabel = UILabel()
    private let descLabel = UILabel()
    private let progressBar = UIProgressView(progressViewStyle: .bar)
    private let progressLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func setupUI() {
        containerView.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        containerView.layer.cornerRadius = Responsive.cornerRadius(20)
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)
        
        iconContainer.backgroundColor = UIColor(red: 0.15, green: 0.1, blue: 0.25, alpha: 1.0)
        iconContainer.layer.cornerRadius = Responsive.cornerRadius(12)
        iconContainer.layer.borderWidth = 1
        iconContainer.clipsToBounds = true
        iconContainer.translatesAutoresizingMaskIntoConstraints = false

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconImageView)

        lockImageView.image = UIImage(named: "lock")
        lockImageView.contentMode = .scaleAspectFit
        lockImageView.tintColor = .white
        lockImageView.translatesAutoresizingMaskIntoConstraints = false
        lockImageView.isHidden = true
        iconContainer.addSubview(lockImageView)
        
        titleLabel.font = .systemFont(ofSize: Responsive.font(16), weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        descLabel.font = .systemFont(ofSize: Responsive.font(12))
        descLabel.textColor = .lightGray
        descLabel.numberOfLines = 2
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        
        progressBar.trackTintColor = UIColor.white.withAlphaComponent(0.1)
        progressBar.progressTintColor = UIColor(red: 0.6, green: 0.4, blue: 1.0, alpha: 1.0)
        progressBar.layer.cornerRadius = 3
        progressBar.clipsToBounds = true
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        
        progressLabel.font = .systemFont(ofSize: Responsive.font(10))
        progressLabel.textColor = .gray
        progressLabel.lineBreakMode = .byClipping
        progressLabel.adjustsFontSizeToFitWidth = true
        progressLabel.minimumScaleFactor = 0.7
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(iconContainer)
        containerView.addSubview(titleLabel)
        containerView.addSubview(descLabel)
        containerView.addSubview(progressBar)
        containerView.addSubview(progressLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Responsive.padding(8)),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Responsive.padding(8)),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Responsive.contentInset),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Responsive.contentInset),

            iconContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: Responsive.padding(15)),
            iconContainer.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: Responsive.size(50)),
            iconContainer.heightAnchor.constraint(equalToConstant: Responsive.size(50)),

            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalTo: iconContainer.widthAnchor, multiplier: 0.85),
            iconImageView.heightAnchor.constraint(equalTo: iconContainer.heightAnchor, multiplier: 0.85),

            lockImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            lockImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            lockImageView.widthAnchor.constraint(equalToConstant: Responsive.size(24)),
            lockImageView.heightAnchor.constraint(equalToConstant: Responsive.size(24)),

            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: Responsive.padding(15)),
            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: Responsive.padding(15)),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Responsive.padding(15)),
            
            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Responsive.padding(4)),
            descLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
            progressBar.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -Responsive.padding(15)),
            progressBar.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: progressLabel.leadingAnchor, constant: -10),
            progressBar.heightAnchor.constraint(equalToConstant: 6),
            
            progressLabel.centerYAnchor.constraint(equalTo: progressBar.centerYAnchor),
            progressLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Responsive.padding(15)),
            progressLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 70)
        ])
    }
    
    func configure(with badge: Badge) {
        titleLabel.text = badge.title
        descLabel.text = badge.description
        progressBar.progress = badge.progress
        progressLabel.text = badge.progressText
        iconImageView.image = UIImage(named: badge.iconName)

        if badge.isLocked {
            // In progress — show badge image at reduced opacity with lock
            iconContainer.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
            iconImageView.alpha = 0.35
            lockImageView.image = UIImage(systemName: "lock.fill")
            lockImageView.tintColor = UIColor.white.withAlphaComponent(0.8)
            lockImageView.isHidden = false
            titleLabel.textColor = .white
        } else {
            // Completed — full opacity, no lock
            iconContainer.layer.borderColor = UIColor(red: 0.6, green: 0.4, blue: 1.0, alpha: 0.5).cgColor
            iconImageView.alpha = 1.0
            lockImageView.isHidden = true
            titleLabel.textColor = .white
        }
    }
}
