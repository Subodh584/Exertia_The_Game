import UIKit

// MARK: - Day Stats — bottom sheet shown when a calendar day is tapped
// Inspired by Samsung Health's daily summary view
class DayStatsViewController: UIViewController {

    var date: Date = Date()
    var sessions: [DjangoSession] = []
    var targetMet: Bool = false

    private static let istTZ = TimeZone(identifier: "Asia/Kolkata")!
    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMMM yyyy"
        f.timeZone   = istTZ; return f
    }()
    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        f.timeZone   = istTZ; return f
    }()
    private static let trackFmt: (String) -> String = { raw in
        raw.replacingOccurrences(of: "track_", with: "")
           .replacingOccurrences(of: "_", with: " ")
           .capitalized
    }

    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 13/255, green: 5/255, blue: 26/255, alpha: 1.0)
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

        // Header
        stack.addArrangedSubview(buildHeader())

        if sessions.isEmpty {
            stack.addArrangedSubview(buildEmptyState())
        } else {
            // Totals summary card
            stack.addArrangedSubview(buildTotalsCard())
            // Individual session cards
            let sectionLbl = makeLbl("Sessions", size: 13, weight: .semibold,
                                     color: UIColor.white.withAlphaComponent(0.4))
            stack.addArrangedSubview(sectionLbl)
            for s in sessions.sorted(by: { ($0.createdAt ?? "") < ($1.createdAt ?? "") }) {
                stack.addArrangedSubview(buildSessionCard(s))
            }
        }
    }

    // MARK: Header — date + target badge
    private func buildHeader() -> UIView {
        let row = UIStackView()
        row.axis      = .horizontal
        row.alignment = .center
        row.spacing   = 10
        row.translatesAutoresizingMaskIntoConstraints = false

        let dateLbl = makeLbl(Self.dateFmt.string(from: date),
                              size: 17, weight: .bold, color: .white)
        dateLbl.numberOfLines = 2
        row.addArrangedSubview(dateLbl)

        if targetMet {
            let badge = buildTargetBadge()
            row.addArrangedSubview(badge)
        }

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.insertArrangedSubview(spacer, at: row.arrangedSubviews.count)

        return row
    }

    private func buildTargetBadge() -> UIView {
        let gold = UIColor(red: 1, green: 0.86, blue: 0.24, alpha: 1)
        let v = UIView()
        v.backgroundColor    = gold.withAlphaComponent(0.15)
        v.layer.cornerRadius = 12
        v.layer.borderWidth  = 1
        v.layer.borderColor  = gold.withAlphaComponent(0.6).cgColor
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
        let lbl  = makeLbl("No runs on this day", size: 15, weight: .medium,
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
        let totalDist = sessions.compactMap { $0.distanceCovered }.reduce(0, +)
        let totalCal  = sessions.compactMap { $0.caloriesBurned  }.reduce(0, +)
        let totalMins = sessions.compactMap { $0.durationMinutes }.reduce(0, +)
        let totalJumps    = sessions.compactMap { $0.totalJumps    }.reduce(0, +)
        let totalCrouches = sessions.compactMap { $0.totalCrouches }.reduce(0, +)

        let card = glassCard(h: nil)

        let titleLbl = makeLbl("Day Summary", size: 13, weight: .semibold,
                               color: UIColor.white.withAlphaComponent(0.45))
        titleLbl.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLbl)

        // Big distance value
        let distNum  = makeLbl(String(format: "%.2f", totalDist), size: 40, weight: .heavy, color: .white)
        let distUnit = makeLbl("km", size: 16, weight: .semibold, color: UIColor.white.withAlphaComponent(0.5))
        let distSub  = makeLbl("Total Distance", size: 11, weight: .medium, color: UIColor.white.withAlphaComponent(0.35))
        distNum.translatesAutoresizingMaskIntoConstraints  = false
        distUnit.translatesAutoresizingMaskIntoConstraints = false
        distSub.translatesAutoresizingMaskIntoConstraints  = false
        card.addSubview(distNum); card.addSubview(distUnit); card.addSubview(distSub)

        // Stat grid row
        let gridItems: [(String, String, String, UIColor)] = [
            ("flame.fill",            "\(totalCal)",      "Calories",  .systemOrange),
            ("stopwatch.fill",        "\(totalMins) min", "Duration",  .systemCyan),
            ("arrow.up.circle.fill",  "\(totalJumps)",    "Jumps",     .systemGreen),
            ("arrow.down.circle.fill","\(totalCrouches)", "Crouches",  .systemYellow)
        ]

        let gridRow = UIStackView()
        gridRow.axis         = .horizontal
        gridRow.distribution = .fillEqually
        gridRow.spacing      = 12
        gridRow.translatesAutoresizingMaskIntoConstraints = false

        for (icon, val, title, color) in gridItems {
            gridRow.addArrangedSubview(miniStatView(icon: icon, value: val, title: title, color: color))
        }
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

    // MARK: Individual session card
    private func buildSessionCard(_ s: DjangoSession) -> UIView {
        let card = glassCard(h: nil)

        // Time + track name row
        let timeStr  = s.createdAt.flatMap { raw -> String? in
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let ts = iso.date(from: raw) else { return nil }
            return Self.timeFmt.string(from: ts)
        } ?? "--:--"
        let trackStr = Self.trackFmt(s.trackId ?? "Unknown Track")

        let timeLbl  = makeLbl(timeStr,  size: 11, weight: .semibold, color: UIColor.white.withAlphaComponent(0.4))
        let trackLbl = makeLbl(trackStr, size: 15, weight: .bold,     color: .white)

        let distStr = s.distanceCovered.map { String(format: "%.1f km", $0) } ?? "--"
        let calStr  = s.caloriesBurned.map  { "\($0) kcal" } ?? "--"

        let distLbl = makeLbl(distStr, size: 18, weight: .heavy,  color: .neonPink)
        let calLbl  = makeLbl(calStr,  size: 11, weight: .medium, color: UIColor.white.withAlphaComponent(0.4))
        distLbl.textAlignment = .right
        calLbl.textAlignment  = .right
        distLbl.setContentHuggingPriority(.required, for: .horizontal)
        distLbl.setContentCompressionResistancePriority(.required, for: .horizontal)
        calLbl.setContentHuggingPriority(.required, for: .horizontal)

        let leftStack = UIStackView(arrangedSubviews: [timeLbl, trackLbl])
        leftStack.axis = .vertical; leftStack.spacing = 2

        let rightStack = UIStackView(arrangedSubviews: [distLbl, calLbl])
        rightStack.axis = .vertical; rightStack.spacing = 2; rightStack.alignment = .trailing

        let row = UIStackView(arrangedSubviews: [leftStack, rightStack])
        row.axis = .horizontal; row.alignment = .center; row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)

        // Extra stats (jumps, crouches, duration) in a sub-row
        let jumpStr   = s.totalJumps.map    { "\($0) jumps"    }
        let crouchStr = s.totalCrouches.map { "\($0) crouches" }
        let durStr    = s.durationMinutes.map { "\($0) min"    }

        let extras = [jumpStr, crouchStr, durStr].compactMap { $0 }
        let extraLbl = makeLbl(extras.joined(separator: "  ·  "), size: 10,
                               weight: .medium, color: UIColor.white.withAlphaComponent(0.3))
        extraLbl.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(extraLbl)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),

            extraLbl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            extraLbl.topAnchor.constraint(equalTo: row.bottomAnchor, constant: 6),
            extraLbl.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])

        return card
    }

    // MARK: Helpers
    private func glassCard(h: CGFloat?) -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        if let h { v.heightAnchor.constraint(equalToConstant: h).isActive = true }

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = 20; blur.clipsToBounds = true
        blur.layer.borderColor  = UIColor.white.withAlphaComponent(0.15).cgColor
        blur.layer.borderWidth  = 1
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
