import UIKit

// MARK: - Run History — styled to exactly match StatisticsViewController
class RunHistoryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    var history: [GameSession] = []
    private var bestSessionIndex: Int? = nil

    // Nav — mirrors Stats page
    private let navBar      = UIView()
    private let backBtn     = UIButton()
    private let titleLabel  = UILabel()
    private let gradientView = UIView()

    private let tableView  = UITableView()
    private let emptyLabel = UILabel()

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
        configureTable()
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
            tableView.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 10),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // MARK: API
    func fetchSessionsFromAPI() {
        guard let userId = UserDefaults.standard.string(forKey: "djangoUserID") else { return }
        Task {
            do {
                let sessions = try await APIManager.shared.getUserSessions(userId: userId)
                let completed = sessions.filter { $0.completionStatus == "completed" }
                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                let converted: [GameSession] = completed.compactMap { s in
                    let date = iso.date(from: s.createdAt ?? "") ?? Date()
                    let track = s.trackId?
                        .replacingOccurrences(of: "track_", with: "")
                        .replacingOccurrences(of: "_", with: " ")
                        .capitalized ?? "Unknown"
                    return GameSession(
                        date: date,
                        durationMinutes:  s.durationMinutes ?? 0,
                        caloriesBurned:   s.caloriesBurned  ?? 0,
                        trackName:        track,
                        trackId:          s.trackId         ?? "track_001",
                        characterId:      s.characterId     ?? "p1",
                        totalJumps:       s.totalJumps      ?? 0,
                        totalCrouches:    s.totalCrouches   ?? 0,
                        totalLeftLeans:   0,
                        totalRightLeans:  0,
                        distanceCovered:  s.distanceCovered ?? 0,
                        averageSpeed:     s.averageSpeed,
                        characterImageName: "character1",
                        completionStatus: s.completionStatus ?? "completed"
                    )
                }.sorted { $0.date > $1.date }

                let bestIdx = converted.indices.max { converted[$0].distanceCovered < converted[$1].distanceCovered }

                DispatchQueue.main.async {
                    self.history     = converted
                    self.bestSessionIndex = bestIdx
                    self.emptyLabel.isHidden = !converted.isEmpty
                    self.tableView.isHidden  = converted.isEmpty
                    self.tableView.reloadData()
                    self.animateCells()
                }
            } catch { print("❌ Run history fetch: \(error)") }
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

    // MARK: Table data source / delegate
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { history.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Row", for: indexPath) as! HistoryRowCell
        cell.configure(session: history[indexPath.row],
                       isLatest: indexPath.row == 0,
                       isBest:   indexPath.row == bestSessionIndex,
                       dateFmt:  Self.cellDateFmt)
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 90 }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if let cell = tableView.cellForRow(at: indexPath) {
            UIView.animate(withDuration: 0.1, animations: { cell.transform = CGAffineTransform(scaleX: 0.97, y: 0.97) }) { _ in
                UIView.animate(withDuration: 0.1) { cell.transform = .identity }
            }
        }
        let s = history[indexPath.row]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let vc = SessionDetailViewController()
            vc.session = s
            vc.isBest  = indexPath.row == self.bestSessionIndex
            vc.modalPresentationStyle = .fullScreen
            vc.modalTransitionStyle   = .crossDissolve
            self.present(vc, animated: true)
        }
    }
}

// MARK: - History Row Cell — glass card matching Stats page style
class HistoryRowCell: UITableViewCell {

    private let blurView  = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let dateLbl   = UILabel()
    private let trackLbl  = UILabel()
    private let distLbl   = UILabel()
    private let calLbl    = UILabel()
    private let newBadge  = BadgePill(text: "NEW",  color: .systemPink)
    private let bestBadge = BadgePill(text: "BEST", color: UIColor(red: 1, green: 0.86, blue: 0.24, alpha: 1))
    private let arrowImg  = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear; selectionStyle = .none
        buildUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        // Glass card — exact same spec as Stats glassCard()
        blurView.layer.cornerRadius = 24
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

        // Badges
        newBadge.translatesAutoresizingMaskIntoConstraints  = false
        bestBadge.translatesAutoresizingMaskIntoConstraints = false
        blurView.contentView.addSubview(newBadge)
        blurView.contentView.addSubview(bestBadge)

        // Arrow
        arrowImg.image = UIImage(systemName: "chevron.right")
        arrowImg.tintColor = UIColor.white.withAlphaComponent(0.25)
        arrowImg.contentMode = .scaleAspectFit
        arrowImg.translatesAutoresizingMaskIntoConstraints = false
        blurView.contentView.addSubview(arrowImg)

        NSLayoutConstraint.activate([
            // Card fills cell with small vertical margin
            blurView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            blurView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            blurView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            // Arrow — far right
            arrowImg.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -16),
            arrowImg.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
            arrowImg.widthAnchor.constraint(equalToConstant: 12),
            arrowImg.heightAnchor.constraint(equalToConstant: 12),

            // Distance — top right, left of arrow
            distLbl.trailingAnchor.constraint(equalTo: arrowImg.leadingAnchor, constant: -8),
            distLbl.topAnchor.constraint(equalTo: blurView.contentView.topAnchor, constant: 16),

            // Calories — below distance
            calLbl.trailingAnchor.constraint(equalTo: distLbl.trailingAnchor),
            calLbl.topAnchor.constraint(equalTo: distLbl.bottomAnchor, constant: 2),

            // Date — top left
            dateLbl.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 18),
            dateLbl.topAnchor.constraint(equalTo: blurView.contentView.topAnchor, constant: 16),
            dateLbl.trailingAnchor.constraint(lessThanOrEqualTo: distLbl.leadingAnchor, constant: -8),

            // Track — below date, must not overlap distance
            trackLbl.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 18),
            trackLbl.topAnchor.constraint(equalTo: dateLbl.bottomAnchor, constant: 3),
            trackLbl.trailingAnchor.constraint(lessThanOrEqualTo: distLbl.leadingAnchor, constant: -8),

            // Badges — below track
            newBadge.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 18),
            newBadge.topAnchor.constraint(equalTo: trackLbl.bottomAnchor, constant: 6),
            newBadge.bottomAnchor.constraint(lessThanOrEqualTo: blurView.contentView.bottomAnchor, constant: -12),

            bestBadge.leadingAnchor.constraint(equalTo: newBadge.trailingAnchor, constant: 6),
            bestBadge.centerYAnchor.constraint(equalTo: newBadge.centerYAnchor)
        ])
    }

    func configure(session: GameSession, isLatest: Bool, isBest: Bool, dateFmt: DateFormatter) {
        dateLbl.text  = dateFmt.string(from: session.date)
        trackLbl.text = session.trackName
        distLbl.text  = String(format: "%.1f km", session.distanceCovered)
        calLbl.text   = "\(session.caloriesBurned) kcal"
        newBadge.isHidden  = !isLatest
        bestBadge.isHidden = !isBest

        let gold = UIColor(red: 1, green: 0.86, blue: 0.24, alpha: 1)
        blurView.layer.borderColor = isBest
            ? gold.withAlphaComponent(0.5).cgColor
            : UIColor.white.withAlphaComponent(0.15).cgColor
        blurView.layer.borderWidth = isBest ? 1.5 : 1.0
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
