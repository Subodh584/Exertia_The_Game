import UIKit

// MARK: - Filter by Status
private enum StatusFilter: Int, CaseIterable {
    case all, completed, abandoned

    var title: String {
        switch self {
        case .all:        return "All"
        case .completed:  return "Completed"
        case .abandoned:  return "Abandoned"
        }
    }
}

// MARK: - Run History — styled to exactly match StatisticsViewController
class RunHistoryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    /// Set to true when launched from the Personal Best card — will auto-scroll to best row
    var scrollToBest: Bool = false

    private var allHistory: [GameSession] = []
    private var filteredHistory: [GameSession] = []
    private var bestIndexInFiltered: Int? = nil
    private var activeFilter: StatusFilter = .all

    // Nav — mirrors Stats page
    private let navBar       = UIView()
    private let backBtn      = UIButton()
    private let titleLabel   = UILabel()
    private let gradientView = UIView()

    // Filter bar
    private var filterButtons: [UIButton] = []
    private let filterScroll  = UIScrollView()

    private let tableView       = UITableView()
    private let emptyLabel      = UILabel()
    private let loadingIndicator = UIActivityIndicatorView(style: .large)

    // IST
    private static let istTZ = TimeZone(identifier: "Asia/Kolkata")!
    private static let cellDateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE, d MMM"; f.timeZone = istTZ; return f
    }()

    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 13/255, green: 5/255, blue: 26/255, alpha: 1.0)
        addGradient()
        configureNavBar()
        configureFilterBar()
        configureTable()

        loadingIndicator.color = .white
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        fetchSessionsFromAPI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backBtn.layer.cornerRadius = backBtn.frame.height / 2
    }

    // MARK: Background gradient — same as Stats page
    private func addGradient() {
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(gradientView)
        view.sendSubviewToBack(gradientView)
        NSLayoutConstraint.activate([
            gradientView.topAnchor.constraint(equalTo: view.topAnchor),
            gradientView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gradientView.heightAnchor.constraint(equalToConstant: 350)
        ])
        let layer = CAGradientLayer()
        layer.colors = [UIColor.neonPink.withAlphaComponent(0.3).cgColor, UIColor.clear.cgColor]
        layer.locations = [0.0, 1.0]
        layer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 350)
        gradientView.layer.addSublayer(layer)
    }

    // MARK: Nav bar — copied exactly from Stats page
    private func configureNavBar() {
        navBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navBar)

        backBtn.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        backBtn.layer.borderWidth = 1
        backBtn.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        let config = UIImage.SymbolConfiguration(weight: .bold)
        backBtn.setImage(UIImage(systemName: "chevron.left", withConfiguration: config), for: .normal)
        backBtn.tintColor = .white
        backBtn.addTarget(self, action: #selector(goBack), for: .touchUpInside)

        titleLabel.text = "Run History"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center

        navBar.addSubview(backBtn)
        navBar.addSubview(titleLabel)
        backBtn.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navBar.heightAnchor.constraint(equalToConstant: 50),

            backBtn.leadingAnchor.constraint(equalTo: navBar.leadingAnchor, constant: 20),
            backBtn.centerYAnchor.constraint(equalTo: navBar.centerYAnchor),
            backBtn.widthAnchor.constraint(equalToConstant: 40),
            backBtn.heightAnchor.constraint(equalToConstant: 40),

            titleLabel.centerXAnchor.constraint(equalTo: navBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: navBar.centerYAnchor)
        ])
    }

    // MARK: Filter chip bar
    private func configureFilterBar() {
        filterScroll.showsHorizontalScrollIndicator = false
        filterScroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(filterScroll)

        let chipStack = UIStackView()
        chipStack.axis    = .horizontal
        chipStack.spacing = 10
        chipStack.translatesAutoresizingMaskIntoConstraints = false
        filterScroll.addSubview(chipStack)

        for (i, filter) in StatusFilter.allCases.enumerated() {
            let btn = UIButton()
            btn.setTitle(filter.title, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
            btn.contentEdgeInsets = UIEdgeInsets(top: 7, left: 16, bottom: 7, right: 16)
            btn.layer.cornerRadius = 14
            btn.tag = i
            btn.addTarget(self, action: #selector(filterTapped(_:)), for: .touchUpInside)
            styleChip(btn, selected: i == 0)
            filterButtons.append(btn)
            chipStack.addArrangedSubview(btn)
        }

        NSLayoutConstraint.activate([
            filterScroll.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 10),
            filterScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            filterScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            filterScroll.heightAnchor.constraint(equalToConstant: 36),

            chipStack.topAnchor.constraint(equalTo: filterScroll.topAnchor),
            chipStack.bottomAnchor.constraint(equalTo: filterScroll.bottomAnchor),
            chipStack.leadingAnchor.constraint(equalTo: filterScroll.leadingAnchor),
            chipStack.trailingAnchor.constraint(equalTo: filterScroll.trailingAnchor),
            chipStack.heightAnchor.constraint(equalTo: filterScroll.heightAnchor)
        ])
    }

    private func styleChip(_ btn: UIButton, selected: Bool) {
        if selected {
            btn.backgroundColor = UIColor.neonPink.withAlphaComponent(0.22)
            btn.layer.borderColor = UIColor.neonPink.withAlphaComponent(0.8).cgColor
            btn.layer.borderWidth = 1
            btn.setTitleColor(.white, for: .normal)
        } else {
            btn.backgroundColor = UIColor.white.withAlphaComponent(0.08)
            btn.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
            btn.layer.borderWidth = 1
            btn.setTitleColor(UIColor.white.withAlphaComponent(0.5), for: .normal)
        }
    }

    @objc private func filterTapped(_ sender: UIButton) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        activeFilter = StatusFilter.allCases[sender.tag]
        filterButtons.enumerated().forEach { i, btn in styleChip(btn, selected: i == sender.tag) }
        applyFilter(animate: true)
    }

    // MARK: Apply filter to history list
    private func applyFilter(animate: Bool) {
        switch activeFilter {
        case .all:
            filteredHistory = allHistory
        case .completed:
            filteredHistory = allHistory.filter { $0.completionStatus == "completed" }
        case .abandoned:
            filteredHistory = allHistory.filter { $0.completionStatus == "abandoned" }
        }

        // Best run is based on distance — only completed sessions are eligible
        let completedIndices = filteredHistory.indices.filter { filteredHistory[$0].completionStatus == "completed" }
        bestIndexInFiltered = completedIndices.max {
            filteredHistory[$0].distanceCovered < filteredHistory[$1].distanceCovered
        }

        let isEmpty = filteredHistory.isEmpty
        emptyLabel.isHidden = !isEmpty
        tableView.isHidden  = isEmpty
        tableView.reloadData()

        if animate { animateCells() }

        // Scroll to best once if launched from the Personal Best card
        if scrollToBest, let idx = bestIndexInFiltered, !isEmpty {
            scrollToBest = false   // only auto-scroll once
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                self.tableView.scrollToRow(at: IndexPath(row: idx, section: 0),
                                           at: .middle, animated: true)
            }
        }
    }

    // MARK: Table
    private func configureTable() {
        tableView.backgroundColor = .clear
        tableView.separatorStyle  = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 50, right: 0)
        tableView.dataSource = self
        tableView.delegate   = self
        tableView.register(HistoryRowCell.self, forCellReuseIdentifier: "Row")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        emptyLabel.text = "No runs yet.\nPlay your first session!"
        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center
        emptyLabel.font = .systemFont(ofSize: 16, weight: .medium)
        emptyLabel.textColor = UIColor.white.withAlphaComponent(0.3)
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.isHidden = true
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: filterScroll.bottomAnchor, constant: 10),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // MARK: API
    func fetchSessionsFromAPI() {
        guard let userId = UserDefaults.standard.string(forKey: "supabaseUserID") else { return }
        loadingIndicator.startAnimating()
        Task {
            do {
                let sessions = try await SupabaseManager.shared.getUserSessions(userId: userId)
                let converted: [GameSession] = sessions.compactMap { s in
                    // Include both completed and abandoned sessions
                    guard s.completion_status == "completed" || s.completion_status == "abandoned" else { return nil }
                    let date = ISODateParser.date(from: s.created_at ?? "") ?? Date()
                    let track = "Nova-Station"
                    return GameSession(
                        date: date,
                        durationMinutes:  s.duration_minutes  ?? 0,
                        caloriesBurned:   s.calories_burned   ?? 0,
                        trackName:        track,
                        trackId:          s.track_id          ?? "track_001",
                        characterId:      s.character_id      ?? "p1",
                        totalJumps:       s.total_jumps       ?? 0,
                        totalCrouches:    s.total_crouches    ?? 0,
                        totalLeftLeans:   s.total_left_leans  ?? 0,
                        totalRightLeans:  s.total_right_leans ?? 0,
                        totalSteps:       s.total_steps       ?? 0,
                        distanceCovered:  s.distance_covered  ?? 0,
                        averageSpeed:     s.average_speed,
                        characterImageName: "CharacterAssetThumbnail",
                        completionStatus: s.completion_status ?? "completed"
                    )
                }.sorted { $0.date > $1.date }

                DispatchQueue.main.async {
                    self.loadingIndicator.stopAnimating()
                    self.allHistory = converted
                    self.applyFilter(animate: true)
                }
            } catch {
                DispatchQueue.main.async { self.loadingIndicator.stopAnimating() }
                print("❌ Run history fetch: \(error)")
            }
        }
    }

    private func animateCells() {
        tableView.visibleCells.enumerated().forEach { i, cell in
            cell.alpha     = 0
            cell.transform = CGAffineTransform(translationX: 0, y: 24)
            UIView.animate(withDuration: 0.38, delay: Double(i) * 0.055,
                           usingSpringWithDamping: 0.82, initialSpringVelocity: 0,
                           options: .curveEaseOut) {
                cell.alpha = 1; cell.transform = .identity
            }
        }
    }

    @objc private func goBack() { dismiss(animated: true) }

    // MARK: UITableViewDataSource / Delegate
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredHistory.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Row", for: indexPath) as! HistoryRowCell
        cell.configure(session: filteredHistory[indexPath.row],
                       isLatest: indexPath.row == 0,
                       isBest:   indexPath.row == bestIndexInFiltered,
                       dateFmt:  Self.cellDateFmt)
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 100 }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if let cell = tableView.cellForRow(at: indexPath) {
            UIView.animate(withDuration: 0.1,
                           animations: { cell.transform = CGAffineTransform(scaleX: 0.97, y: 0.97) }) { _ in
                UIView.animate(withDuration: 0.1) { cell.transform = .identity }
            }
        }
        let s = filteredHistory[indexPath.row]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let vc = SessionDetailViewController()
            vc.session = s
            vc.isBest  = indexPath.row == self.bestIndexInFiltered
            vc.modalPresentationStyle = .fullScreen
            vc.modalTransitionStyle   = .crossDissolve
            self.present(vc, animated: true)
        }
    }
}

// MARK: - History Row Cell — glass card matching Stats page style
class HistoryRowCell: UITableViewCell {

    private let blurView   = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let dateLbl    = UILabel()
    private let trackLbl   = UILabel()
    private let distLbl    = UILabel()
    private let calLbl     = UILabel()
    private let arrowImg   = UIImageView()

    // Badge stack — both pinned to the left, collapsed when both hidden
    private let badgeStack     = UIStackView()
    private let newBadge       = BadgePill(text: "NEW",  color: .systemPink)
    private let bestBadge      = BadgePill(text: "BEST", color: UIColor(red: 1, green: 0.86, blue: 0.24, alpha: 1))
    private let abandonedBadge = BadgePill(text: "ABANDONED", color: .systemOrange)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear; selectionStyle = .none
        buildUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        // Glass card
        blurView.layer.cornerRadius = 20
        blurView.clipsToBounds = true
        blurView.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        blurView.layer.borderWidth = 1
        blurView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(blurView)

        // Date
        dateLbl.font = .systemFont(ofSize: 11, weight: .semibold)
        dateLbl.textColor = UIColor.white.withAlphaComponent(0.45)
        dateLbl.translatesAutoresizingMaskIntoConstraints = false
        blurView.contentView.addSubview(dateLbl)

        // Track name
        trackLbl.font = .systemFont(ofSize: 16, weight: .bold)
        trackLbl.textColor = .white
        trackLbl.translatesAutoresizingMaskIntoConstraints = false
        blurView.contentView.addSubview(trackLbl)

        // Distance — neon pink, large
        distLbl.font = .systemFont(ofSize: 20, weight: .heavy)
        distLbl.textColor = .neonPink
        distLbl.textAlignment = .right
        distLbl.setContentHuggingPriority(.required, for: .horizontal)
        distLbl.setContentCompressionResistancePriority(.required, for: .horizontal)
        distLbl.translatesAutoresizingMaskIntoConstraints = false
        blurView.contentView.addSubview(distLbl)

        // Calories
        calLbl.font = .systemFont(ofSize: 11, weight: .medium)
        calLbl.textColor = UIColor.white.withAlphaComponent(0.4)
        calLbl.textAlignment = .right
        calLbl.setContentHuggingPriority(.required, for: .horizontal)
        calLbl.translatesAutoresizingMaskIntoConstraints = false
        blurView.contentView.addSubview(calLbl)

        // Arrow
        arrowImg.image = UIImage(systemName: "chevron.right")
        arrowImg.tintColor = UIColor.white.withAlphaComponent(0.25)
        arrowImg.contentMode = .scaleAspectFit
        arrowImg.translatesAutoresizingMaskIntoConstraints = false
        blurView.contentView.addSubview(arrowImg)

        // Badge stack — horizontal, both anchored to leading edge
        badgeStack.axis      = .horizontal
        badgeStack.spacing   = 6
        badgeStack.alignment = .center
        badgeStack.addArrangedSubview(newBadge)
        badgeStack.addArrangedSubview(bestBadge)
        badgeStack.addArrangedSubview(abandonedBadge)
        badgeStack.translatesAutoresizingMaskIntoConstraints = false
        blurView.contentView.addSubview(badgeStack)

        NSLayoutConstraint.activate([
            // Card fills cell with vertical margin
            blurView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            blurView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            blurView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            // Arrow — far right, vertically centered
            arrowImg.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -16),
            arrowImg.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
            arrowImg.widthAnchor.constraint(equalToConstant: 12),
            arrowImg.heightAnchor.constraint(equalToConstant: 12),

            // Distance — top right, left of arrow
            distLbl.trailingAnchor.constraint(equalTo: arrowImg.leadingAnchor, constant: -8),
            distLbl.topAnchor.constraint(equalTo: blurView.contentView.topAnchor, constant: 18),

            // Calories — below distance
            calLbl.trailingAnchor.constraint(equalTo: distLbl.trailingAnchor),
            calLbl.topAnchor.constraint(equalTo: distLbl.bottomAnchor, constant: 3),

            // Date — top left
            dateLbl.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 18),
            dateLbl.topAnchor.constraint(equalTo: blurView.contentView.topAnchor, constant: 18),
            dateLbl.trailingAnchor.constraint(lessThanOrEqualTo: distLbl.leadingAnchor, constant: -8),

            // Track — below date
            trackLbl.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 18),
            trackLbl.topAnchor.constraint(equalTo: dateLbl.bottomAnchor, constant: 2),
            trackLbl.trailingAnchor.constraint(lessThanOrEqualTo: distLbl.leadingAnchor, constant: -8),

            // Badges — always pinned to the LEFT, directly below track name
            badgeStack.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 18),
            badgeStack.topAnchor.constraint(equalTo: trackLbl.bottomAnchor, constant: 7),
            badgeStack.bottomAnchor.constraint(lessThanOrEqualTo: blurView.contentView.bottomAnchor, constant: -10)
        ])
    }

    func configure(session: GameSession, isLatest: Bool, isBest: Bool, dateFmt: DateFormatter) {
        dateLbl.text  = dateFmt.string(from: session.date)
        trackLbl.text = session.trackName
        distLbl.text  = formatDistanceKm(session.distanceCovered)
        calLbl.text   = "\(session.caloriesBurned) kcal"

        let isAbandoned = session.completionStatus == "abandoned"

        newBadge.isHidden       = !isLatest || isAbandoned
        bestBadge.isHidden      = !isBest || isAbandoned
        abandonedBadge.isHidden = !isAbandoned
        badgeStack.isHidden     = newBadge.isHidden && bestBadge.isHidden && abandonedBadge.isHidden

        let gold = UIColor(red: 1, green: 0.86, blue: 0.24, alpha: 1)
        if isAbandoned {
            blurView.layer.borderColor = UIColor.systemOrange.withAlphaComponent(0.4).cgColor
            blurView.layer.borderWidth = 1.0
            distLbl.textColor = .systemOrange
        } else if isBest {
            blurView.layer.borderColor = gold.withAlphaComponent(0.5).cgColor
            blurView.layer.borderWidth = 1.5
            distLbl.textColor = .neonPink
        } else {
            blurView.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
            blurView.layer.borderWidth = 1.0
            distLbl.textColor = .neonPink
        }
    }
}

// MARK: - Reusable Badge Pill
class BadgePill: UIView {
    init(text: String, color: UIColor) {
        super.init(frame: .zero)
        backgroundColor    = color.withAlphaComponent(0.15)
        layer.cornerRadius = 5
        layer.borderWidth  = 1
        layer.borderColor  = color.withAlphaComponent(0.6).cgColor
        let l = UILabel()
        l.text = text; l.font = .systemFont(ofSize: 9, weight: .bold); l.textColor = color
        l.translatesAutoresizingMaskIntoConstraints = false
        addSubview(l)
        NSLayoutConstraint.activate([
            l.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            l.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
            l.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 7),
            l.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -7)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
}
