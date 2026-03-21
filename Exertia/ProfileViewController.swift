import UIKit

struct Badge {
    let title: String
    let description: String
    let iconName: String
    let progress: Float
    let progressText: String
    let isLocked: Bool
}

class ProfileViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let backgroundImageView = UIImageView()
    private let headerView = UIView()
    private let backButton = UIButton()
    private let settingsButton = UIButton()
    private let titleLabel = UILabel()

    private let avatarImageView = UIImageView()
    private let editLabel = UILabel()
    private let nameLabel = UILabel()
    private let emailLabel = UILabel()
    private let idPillView = UIView()
    private let idLabel = UILabel()

    private let tabContainer = UIView()
    private let inProgressButton = UIButton()
    private let completedButton = UIButton()
    private let tabIndicator = UIView()
    private let tableView = UITableView()

    private var isShowingCompleted = false
    private var inProgressBadges: [Badge] = []
    private var completedBadges: [Badge] = []
    private var activeBadges: [Badge] { return isShowingCompleted ? completedBadges : inProgressBadges }
    private var realUserId: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        setupData()
        setupUI()
        setupActions()
        updateTabSelection()
        fetchRealProfileData()
    }
    
    func fetchRealProfileData() {
        guard let userId = UserDefaults.standard.string(forKey: "djangoUserID") else { return }

        Task {
            do {
                async let userFetch = APIManager.shared.getUser(userId: userId)
                async let badgesFetch = APIManager.shared.getUserBadges(userId: userId)

                let (user, userBadges) = try await (userFetch, badgesFetch)

                DispatchQueue.main.async {
                    // Profile header
                    self.nameLabel.text = user.displayName ?? user.username
                    self.emailLabel.text = "@\(user.username)"
                    let shortId = String(user.id.prefix(8)).uppercased()
                    self.idLabel.text = "ID: \(shortId)"
                    self.realUserId = user.id

                    // Map API badges → local Badge model
                    self.inProgressBadges = userBadges
                        .filter { !$0.isCompleted }
                        .map { ub in
                            let target = ub.badge.targetValue
                            let progress = target > 0 ? Float(ub.currentProgress / target) : 0
                            let progressText = self.formatProgress(ub.currentProgress, target: target, type: ub.badge.badgeType)
                            return Badge(
                                title: ub.badge.name,
                                description: ub.badge.description,
                                iconName: "badge1",
                                progress: min(progress, 1.0),
                                progressText: progressText,
                                isLocked: false
                            )
                        }

                    self.completedBadges = userBadges
                        .filter { $0.isCompleted }
                        .map { ub in
                            Badge(
                                title: ub.badge.name,
                                description: ub.badge.description,
                                iconName: "badge2",
                                progress: 1.0,
                                progressText: "Done",
                                isLocked: false
                            )
                        }

                    self.tableView.reloadData()
                    print("✅ Profile badges loaded from API: \(userBadges.count) total")
                }
            } catch {
                print("❌ Failed to fetch profile data: \(error)")
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
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: tabContainer.bottomAnchor, constant: 10),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    func setupHeader() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)
        
        setupGlassButton(backButton, icon: "chevron.left")
        setupGlassButton(settingsButton, icon: "gearshape")
        
        titleLabel.text = "Profile"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        headerView.addSubview(backButton)
        headerView.addSubview(settingsButton)
        headerView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 60),
            
            backButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            backButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),
            
            settingsButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            settingsButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 44),
            settingsButton.heightAnchor.constraint(equalToConstant: 44),
            
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
        editLabel.text = "Edit"
        editLabel.font = .systemFont(ofSize: 12, weight: .medium)
        editLabel.textColor = .lightGray
        editLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.text = ""
        nameLabel.font = .systemFont(ofSize: 22, weight: .bold)
        nameLabel.textColor = .white
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        emailLabel.text = ""
        emailLabel.font = .systemFont(ofSize: 12)
        emailLabel.textColor = .gray
        emailLabel.translatesAutoresizingMaskIntoConstraints = false
        idPillView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        idPillView.layer.borderWidth = 1
        idPillView.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        idPillView.translatesAutoresizingMaskIntoConstraints = false
        idLabel.text = "ID: ..."
        idLabel.font = .systemFont(ofSize: 12, weight: .bold)
        idLabel.textColor = .white
        idLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let copyIcon = UIImageView(image: UIImage(systemName: "doc.on.doc"))
        copyIcon.tintColor = .lightGray
        copyIcon.contentMode = .scaleAspectFit
        copyIcon.translatesAutoresizingMaskIntoConstraints = false
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(copyIDTapped))
        idPillView.addGestureRecognizer(tap)
        idPillView.isUserInteractionEnabled = true
        
        view.addSubview(avatarImageView)
        view.addSubview(editLabel)
        view.addSubview(nameLabel)
        view.addSubview(emailLabel)
        view.addSubview(idPillView)
        idPillView.addSubview(idLabel)
        idPillView.addSubview(copyIcon)
        
        NSLayoutConstraint.activate([
            avatarImageView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 10),
            avatarImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 100),
            avatarImageView.heightAnchor.constraint(equalToConstant: 100),
            
            editLabel.topAnchor.constraint(equalTo: avatarImageView.bottomAnchor, constant: 8),
            editLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            nameLabel.topAnchor.constraint(equalTo: editLabel.bottomAnchor, constant: 8),
            nameLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            emailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            emailLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            idPillView.topAnchor.constraint(equalTo: emailLabel.bottomAnchor, constant: 12),
            idPillView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            idPillView.heightAnchor.constraint(equalToConstant: 32),
            idPillView.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
            
            idLabel.leadingAnchor.constraint(equalTo: idPillView.leadingAnchor, constant: 16),
            idLabel.centerYAnchor.constraint(equalTo: idPillView.centerYAnchor),
            
            copyIcon.leadingAnchor.constraint(equalTo: idLabel.trailingAnchor, constant: 8),
            copyIcon.trailingAnchor.constraint(equalTo: idPillView.trailingAnchor, constant: -12),
            copyIcon.centerYAnchor.constraint(equalTo: idPillView.centerYAnchor),
            copyIcon.widthAnchor.constraint(equalToConstant: 14),
            copyIcon.heightAnchor.constraint(equalToConstant: 14)
        ])
    }
    
    func setupTabs() {
        tabContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabContainer)
        
        let header = UILabel()
        header.text = "Badges"
        header.font = .systemFont(ofSize: 20, weight: .bold)
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
            header.topAnchor.constraint(equalTo: idPillView.bottomAnchor, constant: 30),
            header.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            tabContainer.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 15),
            tabContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            tabContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            tabContainer.heightAnchor.constraint(equalToConstant: 40),
            
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
    }
    
    @objc func backTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    // 🔥 ADDED THIS: Action to open Settings
    @objc func settingsTapped() {
        print("⚙️ Opening Settings...")
        let settingsVC = SettingsViewController()
        settingsVC.modalPresentationStyle = .fullScreen
        settingsVC.modalTransitionStyle = .crossDissolve
        present(settingsVC, animated: true)
    }
    
    @objc func copyIDTapped() {
        let idToCopy = realUserId.isEmpty ? (UserDefaults.standard.string(forKey: "djangoUserID") ?? "123456") : realUserId
        UIPasteboard.general.string = idToCopy
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    @objc func tabChanged(_ sender: UIButton) {
        let isCompletedTab = (sender == completedButton)
        if isCompletedTab == isShowingCompleted { return }
        
        isShowingCompleted = isCompletedTab
        updateTabSelection()
        
        UIView.animate(withDuration: 0.3) {
            self.tabIndicator.center.x = sender.center.x
        }
        
        UIView.transition(with: tableView, duration: 0.3, options: .transitionCrossDissolve, animations: {
            self.tableView.reloadData()
        }, completion: nil)
    }
    
    func updateTabSelection() {
        inProgressButton.setTitleColor(isShowingCompleted ? .gray : .white, for: .normal)
        completedButton.setTitleColor(isShowingCompleted ? .white : .gray, for: .normal)
    }
    
    func setupGlassButton(_ button: UIButton, icon: String) {
        button.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
        button.setImage(UIImage(systemName: icon, withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
    }
    
    func configureTabButton(_ button: UIButton, title: String) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
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
        return 100
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
        containerView.layer.cornerRadius = 20
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)
        
        iconContainer.backgroundColor = UIColor(red: 0.15, green: 0.1, blue: 0.25, alpha: 1.0)
        iconContainer.layer.cornerRadius = 12
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
        
        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        descLabel.font = .systemFont(ofSize: 12)
        descLabel.textColor = .lightGray
        descLabel.numberOfLines = 2
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        
        progressBar.trackTintColor = UIColor.white.withAlphaComponent(0.1)
        progressBar.progressTintColor = UIColor(red: 0.6, green: 0.4, blue: 1.0, alpha: 1.0)
        progressBar.layer.cornerRadius = 3
        progressBar.clipsToBounds = true
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        
        progressLabel.font = .systemFont(ofSize: 10)
        progressLabel.textColor = .gray
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(iconContainer)
        containerView.addSubview(titleLabel)
        containerView.addSubview(descLabel)
        containerView.addSubview(progressBar)
        containerView.addSubview(progressLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            iconContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 15),
            iconContainer.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 50),
            iconContainer.heightAnchor.constraint(equalToConstant: 50),

            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalTo: iconContainer.widthAnchor, multiplier: 0.7),
            iconImageView.heightAnchor.constraint(equalTo: iconContainer.heightAnchor, multiplier: 0.7),

            lockImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            lockImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            lockImageView.widthAnchor.constraint(equalToConstant: 24),
            lockImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 15),
            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 15),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -15),
            
            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
            progressBar.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -15),
            progressBar.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: progressLabel.leadingAnchor, constant: -10),
            progressBar.heightAnchor.constraint(equalToConstant: 6),
            
            progressLabel.centerYAnchor.constraint(equalTo: progressBar.centerYAnchor),
            progressLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -15),
            progressLabel.widthAnchor.constraint(equalToConstant: 45)
        ])
    }
    
    func configure(with badge: Badge) {
        titleLabel.text = badge.title
        descLabel.text = badge.description
        progressBar.progress = badge.progress
        progressLabel.text = badge.progressText
        iconImageView.image = UIImage(named: badge.iconName)
        
        if badge.isLocked {
            iconContainer.layer.borderColor = UIColor.gray.withAlphaComponent(0.3).cgColor
            iconImageView.alpha = 0.3
            iconImageView.tintColor = .gray
            lockImageView.isHidden = false
            titleLabel.textColor = .lightGray
        } else {
            iconContainer.layer.borderColor = UIColor(red: 0.6, green: 0.4, blue: 1.0, alpha: 0.5).cgColor
            iconImageView.alpha = 1.0
            iconImageView.tintColor = .white
            lockImageView.isHidden = true
            titleLabel.textColor = .white
        }
    }
}
