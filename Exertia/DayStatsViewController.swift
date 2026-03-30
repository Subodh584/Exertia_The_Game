import UIKit

// MARK: - Day Stats — bottom sheet shown when a calendar day is tapped
class DayStatsViewController: UIViewController {

    var date: Date = Date()
    var sessions: [AppSession] = []
    var targetMet: Bool = false

    // Sorted session list — used by button taps to find the right session
    private var sortedSessions: [AppSession] = []
    private var bestSessionIndex: Int? = nil

    private static let istTZ = TimeZone(identifier: "Asia/Kolkata")!
    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEEE, d MMMM yyyy"; f.timeZone = istTZ; return f
    }()
    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; f.timeZone = istTZ; return f
    }()
    // Use ISODateParser.date(from:) for flexible ISO8601 parsing
    private static let trackFmt: (String) -> String = { _ in
        "Nova-Station"
    }

    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 13/255, green: 5/255, blue: 26/255, alpha: 1.0)

        // Sort by time and find best (highest distance)
        sortedSessions = sessions.sorted { ($0.created_at ?? "") < ($1.created_at ?? "") }
        bestSessionIndex = sortedSessions.indices.max {
            (sortedSessions[$0].distance_covered ?? 0) < (sortedSessions[$1].distance_covered ?? 0)
        }
        buildUI()
    }

    // MARK: Build UI
    private func buildUI() {
        let scroll = UIScrollView()
        scroll.showsVerticalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)

        let stack = UIStackView()
        stack.axis      = .vertical
        stack.spacing   = 16
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -32),
            stack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -40)
        ])

        stack.addArrangedSubview(buildHeader())

        if sortedSessions.isEmpty {
            stack.addArrangedSubview(buildEmptyState())
        } else {
            stack.addArrangedSubview(buildTotalsCard())

            let sectionLbl = makeLbl("Sessions", size: 13, weight: .semibold,
                                     color: UIColor.white.withAlphaComponent(0.4))
            stack.addArrangedSubview(sectionLbl)

            for (i, s) in sortedSessions.enumerated() {
                stack.addArrangedSubview(buildSessionCard(s, index: i))
            }
        }
    }

    // MARK: Header
    private func buildHeader() -> UIView {
        let row = UIStackView()
        row.axis = .horizontal; row.alignment = .center; row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false

        let dateLbl = makeLbl(Self.dateFmt.string(from: date), size: 17, weight: .bold, color: .white)
        dateLbl.numberOfLines = 2
        row.addArrangedSubview(dateLbl)

        if targetMet { row.addArrangedSubview(buildTargetBadge()) }

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)
        return row
    }

    private func buildTargetBadge() -> UIView {
        let gold = UIColor(red: 1, green: 0.86, blue: 0.24, alpha: 1)
        let v = UIView()
        v.backgroundColor = gold.withAlphaComponent(0.15)
        v.layer.cornerRadius = 12; v.layer.borderWidth = 1
        v.layer.borderColor = gold.withAlphaComponent(0.6).cgColor
        v.translatesAutoresizingMaskIntoConstraints = false

        let img = UIImageView(image: UIImage(systemName: "checkmark.seal.fill"))
        img.tintColor = gold; img.contentMode = .scaleAspectFit
        img.translatesAutoresizingMaskIntoConstraints = false
        img.widthAnchor.constraint(equalToConstant: 13).isActive = true
        img.heightAnchor.constraint(equalToConstant: 13).isActive = true

        let l = makeLbl("Target Met", size: 11, weight: .bold, color: gold)
        let sv = UIStackView(arrangedSubviews: [img, l])
        sv.spacing = 4; sv.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(sv)
        NSLayoutConstraint.activate([
            sv.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 8),
            sv.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -8),
            sv.topAnchor.constraint(equalTo: v.topAnchor, constant: 5),
            sv.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -5)
        ])
        return v
    }

    // MARK: Empty state
    private func buildEmptyState() -> UIView {
        let card = glassCard(h: 100)
        let lbl = makeLbl("No runs on this day", size: 15, weight: .medium,
                           color: UIColor.white.withAlphaComponent(0.3))
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(lbl)
        NSLayoutConstraint.activate([
            lbl.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            lbl.centerYAnchor.constraint(equalTo: card.centerYAnchor)
        ])
        return card
    }

    // MARK: Day totals card
    private func buildTotalsCard() -> UIView {
        let totalDist     = sortedSessions.compactMap { $0.distance_covered }.reduce(0, +)
        let totalCal      = sortedSessions.compactMap { $0.calories_burned  }.reduce(0, +)
        let totalMins     = sortedSessions.compactMap { $0.duration_minutes }.reduce(0, +)
        let totalJumps    = sortedSessions.compactMap { $0.total_jumps      }.reduce(0, +)
        let totalCrouches = sortedSessions.compactMap { $0.total_crouches   }.reduce(0, +)

        let card = glassCard(h: nil)

        let titleLbl = makeLbl("Day Summary", size: 13, weight: .semibold,
                               color: UIColor.white.withAlphaComponent(0.45))
        let distNum  = makeLbl(String(format: "%.2f", totalDist), size: 40, weight: .heavy, color: .white)
        let distUnit = makeLbl("km", size: 16, weight: .semibold, color: UIColor.white.withAlphaComponent(0.5))
        let distSub  = makeLbl("Total Distance", size: 11, weight: .medium,
                               color: UIColor.white.withAlphaComponent(0.35))
        [titleLbl, distNum, distUnit, distSub].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview($0)
        }

        let gridItems: [(String, String, String, UIColor)] = [
            ("flame.fill",             "\(totalCal)",      "Calories", .systemOrange),
            ("stopwatch.fill",         "\(totalMins) min", "Duration", .systemCyan),
            ("arrow.up.circle.fill",   "\(totalJumps)",    "Jumps",    .systemGreen),
            ("arrow.down.circle.fill", "\(totalCrouches)", "Crouches", .systemYellow)
        ]
        let gridRow = UIStackView()
        gridRow.axis = .horizontal; gridRow.distribution = .fillEqually
        gridRow.spacing = 12; gridRow.translatesAutoresizingMaskIntoConstraints = false
        gridItems.forEach { gridRow.addArrangedSubview(miniStatView(icon: $0.0, value: $0.1, title: $0.2, color: $0.3)) }
        card.addSubview(gridRow)

        NSLayoutConstraint.activate([
            titleLbl.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            titleLbl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),

            distNum.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            distNum.topAnchor.constraint(equalTo: titleLbl.bottomAnchor, constant: 6),

            distUnit.leadingAnchor.constraint(equalTo: distNum.trailingAnchor, constant: 5),
            distUnit.bottomAnchor.constraint(equalTo: distNum.bottomAnchor, constant: -6),

            distSub.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            distSub.topAnchor.constraint(equalTo: distNum.bottomAnchor, constant: 2),

            gridRow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            gridRow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            gridRow.topAnchor.constraint(equalTo: distSub.bottomAnchor, constant: 16),
            gridRow.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
            gridRow.heightAnchor.constraint(equalToConstant: 56)
        ])
        return card
    }

    private func miniStatView(icon: String, value: String, title: String, color: UIColor) -> UIView {
        let v = UIView(); v.translatesAutoresizingMaskIntoConstraints = false
        let img = UIImageView(image: UIImage(systemName: icon))
        img.tintColor = color; img.contentMode = .scaleAspectFit
        img.translatesAutoresizingMaskIntoConstraints = false
        img.widthAnchor.constraint(equalToConstant: 16).isActive = true
        img.heightAnchor.constraint(equalToConstant: 16).isActive = true

        let valLbl   = makeLbl(value, size: 14, weight: .bold,   color: .white)
        let titleLbl = makeLbl(title, size: 9,  weight: .medium, color: UIColor.white.withAlphaComponent(0.35))
        let sv = UIStackView(arrangedSubviews: [img, valLbl, titleLbl])
        sv.axis = .vertical; sv.spacing = 2; sv.alignment = .leading
        sv.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(sv)
        NSLayoutConstraint.activate([
            sv.leadingAnchor.constraint(equalTo: v.leadingAnchor),
            sv.trailingAnchor.constraint(equalTo: v.trailingAnchor),
            sv.centerYAnchor.constraint(equalTo: v.centerYAnchor)
        ])
        return v
    }

    // MARK: Tappable session card
    private func buildSessionCard(_ s: AppSession, index: Int) -> UIView {
        let isBest = (index == bestSessionIndex)
        let card   = glassCard(h: nil, isBest: isBest)

        let timeStr  = s.created_at.flatMap { raw -> String? in
            guard let ts = ISODateParser.date(from: raw) else { return nil }
            return Self.timeFmt.string(from: ts)
        } ?? "--:--"
        let trackStr = Self.trackFmt(s.track_id ?? "Unknown Track")

        let timeLbl  = makeLbl(timeStr,  size: 11, weight: .semibold, color: UIColor.white.withAlphaComponent(0.4))
        let trackLbl = makeLbl(trackStr, size: 15, weight: .bold,     color: .white)
        let distStr  = s.distance_covered.map { String(format: "%.1f km", $0) } ?? "--"
        let calStr   = s.calories_burned.map  { "\($0) kcal" } ?? "--"
        let distLbl  = makeLbl(distStr, size: 18, weight: .heavy,  color: .neonPink)
        let calLbl   = makeLbl(calStr,  size: 11, weight: .medium, color: UIColor.white.withAlphaComponent(0.4))
        distLbl.textAlignment = .right
        calLbl.textAlignment  = .right
        distLbl.setContentHuggingPriority(.required, for: .horizontal)
        distLbl.setContentCompressionResistancePriority(.required, for: .horizontal)
        calLbl.setContentHuggingPriority(.required, for: .horizontal)

        let leftStack  = UIStackView(arrangedSubviews: [timeLbl, trackLbl])
        leftStack.axis = .vertical; leftStack.spacing = 2

        let rightStack = UIStackView(arrangedSubviews: [distLbl, calLbl])
        rightStack.axis = .vertical; rightStack.spacing = 2; rightStack.alignment = .trailing

        // Chevron
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = UIColor.white.withAlphaComponent(0.25)
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.widthAnchor.constraint(equalToConstant: 10).isActive  = true
        chevron.heightAnchor.constraint(equalToConstant: 10).isActive = true

        let row = UIStackView(arrangedSubviews: [leftStack, rightStack, chevron])
        row.axis = .horizontal; row.alignment = .center; row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)

        let jumpStr   = s.total_jumps.map    { "\($0) jumps"    }
        let crouchStr = s.total_crouches.map { "\($0) crouches" }
        let durStr    = s.duration_minutes.map { "\($0) min"    }
        let extras    = [jumpStr, crouchStr, durStr].compactMap { $0 }
        let extraLbl  = makeLbl(extras.joined(separator: "  ·  "), size: 10,
                                weight: .medium, color: UIColor.white.withAlphaComponent(0.3))
        extraLbl.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(extraLbl)

        // Transparent button overlay — handles tap + bounce animation
        let btn = UIButton()
        btn.tag = index
        btn.backgroundColor = .clear
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(sessionTapped(_:)), for: .touchUpInside)
        btn.addTarget(self, action: #selector(sessionTouchDown(_:)), for: .touchDown)
        btn.addTarget(self, action: #selector(sessionTouchUp(_:)), for: [.touchUpOutside, .touchCancel])
        card.addSubview(btn)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),

            extraLbl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            extraLbl.topAnchor.constraint(equalTo: row.bottomAnchor, constant: 6),
            extraLbl.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),

            btn.topAnchor.constraint(equalTo: card.topAnchor),
            btn.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            btn.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            btn.trailingAnchor.constraint(equalTo: card.trailingAnchor)
        ])
        return card
    }

    // MARK: Tap handlers
    @objc private func sessionTouchDown(_ sender: UIButton) {
        guard let card = sender.superview else { return }
        UIView.animate(withDuration: 0.12) { card.transform = CGAffineTransform(scaleX: 0.97, y: 0.97) }
    }

    @objc private func sessionTouchUp(_ sender: UIButton) {
        guard let card = sender.superview else { return }
        UIView.animate(withDuration: 0.2, delay: 0,
                       usingSpringWithDamping: 0.6, initialSpringVelocity: 0,
                       options: [], animations: { card.transform = .identity }, completion: nil)
    }

    @objc private func sessionTapped(_ sender: UIButton) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        guard let card = sender.superview else { return }

        // Bounce animation then open detail
        UIView.animate(withDuration: 0.12, animations: {
            card.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
        }) { _ in
            UIView.animate(withDuration: 0.2, delay: 0,
                           usingSpringWithDamping: 0.6, initialSpringVelocity: 0) {
                card.transform = .identity
            }
        }

        let index = sender.tag
        guard index < sortedSessions.count else { return }
        let appSession = sortedSessions[index]

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            let vc = SessionDetailViewController()
            vc.session = self.toGameSession(appSession)
            vc.isBest  = (index == self.bestSessionIndex)
            vc.modalPresentationStyle = .fullScreen
            vc.modalTransitionStyle   = .crossDissolve
            self.present(vc, animated: true)
        }
    }

    // MARK: AppSession → GameSession converter
    private func toGameSession(_ s: AppSession) -> GameSession {
        let date  = s.created_at.flatMap { ISODateParser.date(from: $0) } ?? Date()
        let track = Self.trackFmt(s.track_id ?? "unknown")
        return GameSession(
            date:               date,
            durationMinutes:    s.duration_minutes  ?? 0,
            caloriesBurned:     s.calories_burned   ?? 0,
            trackName:          track,
            trackId:            s.track_id          ?? "track_001",
            characterId:        s.character_id      ?? "p1",
            totalJumps:         s.total_jumps       ?? 0,
            totalCrouches:      s.total_crouches    ?? 0,
            totalLeftLeans:     s.total_left_leans  ?? 0,
            totalRightLeans:    s.total_right_leans ?? 0,
            distanceCovered:    s.distance_covered  ?? 0,
            averageSpeed:       s.average_speed,
            characterImageName: "character1",
            completionStatus:   s.completion_status ?? "completed"
        )
    }

    // MARK: Helpers
    private func glassCard(h: CGFloat?, isBest: Bool = false) -> UIView {
        let gold = UIColor(red: 1, green: 0.86, blue: 0.24, alpha: 1)
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        if let h { v.heightAnchor.constraint(equalToConstant: h).isActive = true }

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = 20; blur.clipsToBounds = true
        blur.layer.borderColor  = isBest
            ? gold.withAlphaComponent(0.5).cgColor
            : UIColor.white.withAlphaComponent(0.15).cgColor
        blur.layer.borderWidth = isBest ? 1.5 : 1
        v.addSubview(blur)
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: v.topAnchor),
            blur.bottomAnchor.constraint(equalTo: v.bottomAnchor),
            blur.leadingAnchor.constraint(equalTo: v.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: v.trailingAnchor)
        ])
        return v
    }

    private func makeLbl(_ text: String, size: CGFloat, weight: UIFont.Weight, color: UIColor) -> UILabel {
        let l = UILabel()
        l.text = text; l.font = .systemFont(ofSize: size, weight: weight)
        l.textColor = color; l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }
}
