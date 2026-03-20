import UIKit

class RunHistoryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    var history: [GameSession] = []
    var selectedSession: GameSession?

    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let containerView = UIView()
    private let closeButton = UIButton()
    private let titleLabel = UILabel()
    
    private let heroContainer = UIView()
    private let charImageView = UIImageView()
    private let dateLabel = UILabel()
    private let trackLabel = UILabel()

    private let bigCalLabel = UILabel()
    private let bigTimeLabel = UILabel()
    private let bigJumpLabel = UILabel()
    private let bigCrouchLabel = UILabel()

    private let listTitleLabel = UILabel()
    private let tableView = UITableView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        
        // Start with empty history, will be populated from API
        history = []
        
        setupUI()
        updateHeroView(with: selectedSession)
        
        // Fetch from API
        fetchSessionsFromAPI()
    }
    
    func fetchSessionsFromAPI() {
        guard let userId = UserDefaults.standard.string(forKey: "djangoUserID") else { return }
        
        Task {
            do {
                let sessions = try await APIManager.shared.getUserSessions(userId: userId)
                let completed = sessions.filter { $0.completionStatus == "completed" }
                
                // Convert DjangoSession -> GameSession for display
                let dateFormatter = ISO8601DateFormatter()
                dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                
                let convertedHistory: [GameSession] = completed.compactMap { s in
                    let date = dateFormatter.date(from: s.createdAt ?? "") ?? Date()
                    return GameSession(
                        date: date,
                        durationMinutes: s.durationMinutes ?? 0,
                        caloriesBurned: s.caloriesBurned ?? 0,
                        trackName: s.trackId?.replacingOccurrences(of: "track_", with: "").replacingOccurrences(of: "_", with: " ").capitalized ?? "Unknown",
                        trackId: s.trackId ?? "track_001",
                        characterId: s.characterId ?? "p1",
                        totalJumps: s.totalJumps ?? 0,
                        totalCrouches: s.totalCrouches ?? 0,
                        totalLeftLeans: 0,
                        totalRightLeans: 0,
                        distanceCovered: s.distanceCovered ?? 0,
                        averageSpeed: s.averageSpeed,
                        characterImageName: "character1",
                        completionStatus: s.completionStatus ?? "completed"
                    )
                }
                
                DispatchQueue.main.async {
                    if !convertedHistory.isEmpty {
                        self.history = convertedHistory.sorted(by: { $0.date > $1.date })
                        self.selectedSession = self.history.first
                        self.updateHeroView(with: self.selectedSession)
                        self.tableView.reloadData()
                        print("✅ Run history hydrated from API! \(self.history.count) sessions loaded.")
                    }
                }
            } catch {
                print("❌ Failed to fetch sessions for history: \(error)")
            }
        }
    }

    func setupUI() {
        blurView.frame = view.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(blurView)
        
        containerView.backgroundColor = UIColor(red: 0.05, green: 0.02, blue: 0.1, alpha: 0.98)
        containerView.layer.cornerRadius = 32
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.6
        containerView.layer.shadowRadius = 30
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        titleLabel.text = "Session Analysis"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .white.withAlphaComponent(0.4)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(dismissModal), for: .touchUpInside)
        
        setupHeroCard()
        
        listTitleLabel.text = "HISTORY LOG"
        listTitleLabel.font = .systemFont(ofSize: 12, weight: .bold)
        listTitleLabel.textColor = .white.withAlphaComponent(0.5)
        listTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(AestheticHistoryCell.self, forCellReuseIdentifier: "HistoryCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(titleLabel)
        containerView.addSubview(closeButton)
        containerView.addSubview(heroContainer)
        containerView.addSubview(listTitleLabel)
        containerView.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 360),
            containerView.heightAnchor.constraint(equalToConstant: 680),
            
            closeButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            closeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32),
            
            titleLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            
            heroContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 25),
            heroContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            heroContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            heroContainer.heightAnchor.constraint(equalToConstant: 220),
            
            listTitleLabel.topAnchor.constraint(equalTo: heroContainer.bottomAnchor, constant: 30),
            listTitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            
            tableView.topAnchor.constraint(equalTo: listTitleLabel.bottomAnchor, constant: 10),
            tableView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 15),
            tableView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -15),
            tableView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])
    }
    
    func setupHeroCard() {
        heroContainer.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        heroContainer.layer.cornerRadius = 24
        heroContainer.layer.borderWidth = 1
        heroContainer.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
        heroContainer.translatesAutoresizingMaskIntoConstraints = false
        
        charImageView.contentMode = .scaleAspectFit
        charImageView.layer.cornerRadius = 30
        charImageView.layer.borderWidth = 1
        charImageView.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        charImageView.clipsToBounds = true
        charImageView.translatesAutoresizingMaskIntoConstraints = false
        
        trackLabel.font = .systemFont(ofSize: 18, weight: .bold)
        trackLabel.textColor = .white
        
        dateLabel.font = .systemFont(ofSize: 14, weight: .medium)
        dateLabel.textColor = .gray
        
        let headerStack = UIStackView(arrangedSubviews: [trackLabel, dateLabel])
        headerStack.axis = .vertical
        headerStack.spacing = 2
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        
        let row1 = createStatRow(icon1: "flame.fill", color1: .systemPink, label1: bigCalLabel,
                                 icon2: "stopwatch.fill", color2: .systemCyan, label2: bigTimeLabel)
        let row2 = createStatRow(icon1: "arrow.up.circle.fill", color1: .systemGreen, label1: bigJumpLabel,
                                 icon2: "arrow.down.circle.fill", color2: .systemYellow, label2: bigCrouchLabel)
        
        let statsStack = UIStackView(arrangedSubviews: [row1, row2])
        statsStack.axis = .vertical
        statsStack.distribution = .fillEqually
        statsStack.spacing = 15
        statsStack.translatesAutoresizingMaskIntoConstraints = false
        
        heroContainer.addSubview(charImageView)
        heroContainer.addSubview(headerStack)
        heroContainer.addSubview(statsStack)
        
        NSLayoutConstraint.activate([
            charImageView.topAnchor.constraint(equalTo: heroContainer.topAnchor, constant: 20),
            charImageView.trailingAnchor.constraint(equalTo: heroContainer.trailingAnchor, constant: -20),
            charImageView.widthAnchor.constraint(equalToConstant: 60),
            charImageView.heightAnchor.constraint(equalToConstant: 60),
            
            headerStack.topAnchor.constraint(equalTo: heroContainer.topAnchor, constant: 25),
            headerStack.leadingAnchor.constraint(equalTo: heroContainer.leadingAnchor, constant: 20),
            headerStack.trailingAnchor.constraint(equalTo: charImageView.leadingAnchor, constant: -10),
            
            statsStack.topAnchor.constraint(equalTo: charImageView.bottomAnchor, constant: 20),
            statsStack.leadingAnchor.constraint(equalTo: heroContainer.leadingAnchor, constant: 20),
            statsStack.trailingAnchor.constraint(equalTo: heroContainer.trailingAnchor, constant: -20),
            statsStack.bottomAnchor.constraint(equalTo: heroContainer.bottomAnchor, constant: -20)
        ])
    }

    func updateHeroView(with session: GameSession?) {
        guard let s = session else { return }
        
        charImageView.image = UIImage(named: s.characterImageName)
        trackLabel.text = s.trackName
        
        let df = DateFormatter()
        df.dateFormat = "MMM d, yyyy • h:mm a"
        dateLabel.text = df.string(from: s.date)
        
        bigCalLabel.text = "\(s.caloriesBurned) kcal"
        bigTimeLabel.text = "\(s.durationMinutes) min"
        bigJumpLabel.text = "\(s.totalJumps) Jumps"
        bigCrouchLabel.text = "\(s.totalCrouches) Crouches"
        
        if let index = history.firstIndex(where: { $0.date == s.date }) {
            tableView.selectRow(at: IndexPath(row: index, section: 0), animated: true, scrollPosition: .none)
        }
    }
    
    func createStatRow(icon1: String, color1: UIColor, label1: UILabel, icon2: String, color2: UIColor, label2: UILabel) -> UIStackView {
        func createItem(icon: String, color: UIColor, label: UILabel) -> UIStackView {
            let img = UIImageView(image: UIImage(systemName: icon))
            img.tintColor = color
            img.contentMode = .scaleAspectFit
            img.widthAnchor.constraint(equalToConstant: 20).isActive = true
            
            label.font = .systemFont(ofSize: 16, weight: .bold)
            label.textColor = .white
            
            let s = UIStackView(arrangedSubviews: [img, label])
            s.spacing = 10
            return s
        }
        let item1 = createItem(icon: icon1, color: color1, label: label1)
        let item2 = createItem(icon: icon2, color: color2, label: label2)
        let row = UIStackView(arrangedSubviews: [item1, item2])
        row.distribution = .fillEqually
        return row
    }
    
    @objc func dismissModal() { dismiss(animated: true) }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { return history.count }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "HistoryCell", for: indexPath) as! AestheticHistoryCell
        let session = history[indexPath.row]
        let isLatest = (indexPath.row == 0)
        let isPB = (session.caloriesBurned == GameData.shared.personalBest?.caloriesBurned)
        cell.configure(session: session, isLatest: isLatest, isPB: isPB)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedSession = history[indexPath.row]
        updateHeroView(with: selectedSession)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { return 90 }
}

class AestheticHistoryCell: UITableViewCell {
    
    private let container = UIView()
    private let dateLabel = UILabel()
    private let statsLabel = UILabel()
    private let badgeStack = UIStackView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        setupUI()
    }
    required init?(coder: NSCoder) { fatalError() }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        UIView.animate(withDuration: 0.2) {
            self.container.layer.borderColor = selected ? UIColor.systemPink.cgColor : UIColor.white.withAlphaComponent(0.1).cgColor
            self.container.layer.borderWidth = selected ? 1.5 : 1.0
            self.container.backgroundColor = selected ? UIColor.systemPink.withAlphaComponent(0.15) : UIColor.white.withAlphaComponent(0.05)
        }
    }
    
    func setupUI() {
        container.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        container.layer.cornerRadius = 18
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
        container.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(container)
        
        dateLabel.font = .systemFont(ofSize: 15, weight: .bold)
        dateLabel.textColor = .white
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        
        statsLabel.font = .systemFont(ofSize: 13, weight: .medium)
        statsLabel.textColor = .lightGray
        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        
        badgeStack.axis = .horizontal
        badgeStack.spacing = 6
        badgeStack.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(dateLabel)
        container.addSubview(statsLabel)
        container.addSubview(badgeStack)
        
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 5),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -5),
            container.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            
            dateLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            dateLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            
            badgeStack.leadingAnchor.constraint(equalTo: dateLabel.trailingAnchor, constant: 10),
            badgeStack.centerYAnchor.constraint(equalTo: dateLabel.centerYAnchor),
            
            statsLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14),
            statsLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            statsLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16)
        ])
    }
    
    func configure(session: GameSession, isLatest: Bool, isPB: Bool) {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        dateLabel.text = df.string(from: session.date)
        
        statsLabel.text = "\(session.caloriesBurned) cal  |  \(session.durationMinutes) min"
        
        badgeStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        if isLatest { badgeStack.addArrangedSubview(createBadge(text: "NEW", color: .systemPink)) }
        if isPB { badgeStack.addArrangedSubview(createBadge(text: "BEST", color: .systemYellow)) }
    }
    
    func createBadge(text: String, color: UIColor) -> UIView {
        let v = UIView()
        v.backgroundColor = color.withAlphaComponent(0.2)
        v.layer.cornerRadius = 5
        v.layer.borderWidth = 1
        v.layer.borderColor = color.cgColor
        
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: 9, weight: .bold)
        l.textColor = color
        l.translatesAutoresizingMaskIntoConstraints = false
        
        v.addSubview(l)
        NSLayoutConstraint.activate([
            l.topAnchor.constraint(equalTo: v.topAnchor, constant: 2),
            l.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -2),
            l.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 6),
            l.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -6)
        ])
        return v
    }
}
