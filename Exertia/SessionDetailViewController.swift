import UIKit

class SessionDetailViewController: UIViewController {

    var session: GameSession?
    var isBest: Bool = false

    private static let istTZ = TimeZone(identifier: "Asia/Kolkata")!
    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE, d MMM yyyy"; f.timeZone = istTZ; return f
    }()
    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; f.timeZone = istTZ; return f
    }()

    // Nav — same as Stats page
    private let navBar       = UIView()
    private let backBtn      = UIButton()
    private let titleLabel   = UILabel()
    private let gradientView = UIView()

    private let scrollView   = UIScrollView()
    private let stackContainer = UIStackView()

    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 13/255, green: 5/255, blue: 26/255, alpha: 1.0)
        addGradient()
        configureNavBar()
        configureScroll()
        buildContent()
        animateIn()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backBtn.layer.cornerRadius = backBtn.frame.height / 2
    }

    // MARK: Entry animation
    private func animateIn() {
        stackContainer.alpha     = 0
        stackContainer.transform = CGAffineTransform(translationX: 0, y: 30)
        UIView.animate(withDuration: 0.42, delay: 0.06,
                       usingSpringWithDamping: 0.84, initialSpringVelocity: 0) {
            self.stackContainer.alpha     = 1
            self.stackContainer.transform = .identity
        }
    }

    // MARK: Background gradient — exactly same as Stats
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

    // MARK: Nav bar — exactly same as Stats
    private func configureNavBar() {
        navBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navBar)

        backBtn.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        backBtn.layer.borderWidth = 1
        backBtn.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        let cfg = UIImage.SymbolConfiguration(weight: .bold)
        backBtn.setImage(UIImage(systemName: "chevron.left", withConfiguration: cfg), for: .normal)
        backBtn.tintColor = .white
        backBtn.addTarget(self, action: #selector(goBack), for: .touchUpInside)

        titleLabel.text = session?.trackName ?? "Session"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center

        navBar.addSubview(backBtn)
        navBar.addSubview(titleLabel)
        backBtn.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Personal Best badge top-right (if applicable)
        if isBest {
            let badge = buildBestBadge()
            navBar.addSubview(badge)
            NSLayoutConstraint.activate([
                badge.trailingAnchor.constraint(equalTo: navBar.trailingAnchor, constant: -20),
                badge.centerYAnchor.constraint(equalTo: navBar.centerYAnchor)
            ])
        }

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

    // MARK: Scroll container — same as Stats
    private func configureScroll() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)

        stackContainer.axis      = .vertical
        stackContainer.spacing   = 20
        stackContainer.alignment = .fill
        stackContainer.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackContainer)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackContainer.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 10),
            stackContainer.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stackContainer.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stackContainer.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -40),
            stackContainer.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
    }

    // MARK: Content
    private func buildContent() {
        guard let s = session else { return }

        // 1. Hero card: track + date + time + character
        stackContainer.addArrangedSubview(buildHeroCard(s))

        // 2. Distance — primary stat card
        stackContainer.addArrangedSubview(buildDistCard(s))

        // 3. Stats grid — 2 columns, 5 stats (no duplicate distance)
        stackContainer.addArrangedSubview(buildStatsGrid(s))
    }

    // MARK: Hero card
    private func buildHeroCard(_ s: GameSession) -> UIView {
        let card = glassCard(h: nil)

        let charImg = UIImageView(image: UIImage(named: s.characterImageName))
        charImg.contentMode = .scaleAspectFit
        charImg.layer.cornerRadius = 30
        charImg.layer.borderWidth  = 1.5
        charImg.layer.borderColor  = UIColor.white.withAlphaComponent(0.2).cgColor
        charImg.clipsToBounds = true
        charImg.translatesAutoresizingMaskIntoConstraints = false

        let trackLbl = makeLbl(s.trackName,                      size: 20, weight: .bold,    color: .white)
        let dateLbl  = makeLbl(Self.dateFmt.string(from: s.date), size: 13, weight: .medium,  color: UIColor.white.withAlphaComponent(0.5))
        let timeLbl  = makeLbl(Self.timeFmt.string(from: s.date), size: 13, weight: .medium,  color: UIColor.white.withAlphaComponent(0.35))

        let infoStack = UIStackView(arrangedSubviews: [trackLbl, dateLbl, timeLbl])
        infoStack.axis = .vertical; infoStack.spacing = 4
        infoStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(charImg)
        card.addSubview(infoStack)
        NSLayoutConstraint.activate([
            charImg.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            charImg.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            charImg.widthAnchor.constraint(equalToConstant: 62),
            charImg.heightAnchor.constraint(equalToConstant: 62),
            charImg.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -20),

            infoStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            infoStack.trailingAnchor.constraint(equalTo: charImg.leadingAnchor, constant: -12),
            infoStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            infoStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
        ])
        return card
    }

    // MARK: Distance card
    private func buildDistCard(_ s: GameSession) -> UIView {
        let card = glassCard(h: 100)

        let icon = UIImageView(image: UIImage(systemName: "figure.run"))
        icon.tintColor = .neonPink; icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let numLbl  = makeLbl(String(format: "%.2f", s.distanceCovered), size: 46, weight: .heavy, color: .white)
        let unitLbl = makeLbl("km",  size: 18, weight: .semibold, color: UIColor.white.withAlphaComponent(0.55))
        let subLbl  = makeLbl("Distance Covered", size: 12, weight: .medium, color: UIColor.white.withAlphaComponent(0.4))

        card.addSubview(icon); card.addSubview(numLbl); card.addSubview(unitLbl); card.addSubview(subLbl)
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            icon.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 28),
            icon.heightAnchor.constraint(equalToConstant: 28),

            numLbl.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 14),
            numLbl.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),

            unitLbl.leadingAnchor.constraint(equalTo: numLbl.trailingAnchor, constant: 5),
            unitLbl.bottomAnchor.constraint(equalTo: numLbl.bottomAnchor, constant: -7),

            subLbl.leadingAnchor.constraint(equalTo: numLbl.leadingAnchor),
            subLbl.topAnchor.constraint(equalTo: numLbl.bottomAnchor, constant: 1),
            subLbl.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        return card
    }

    // MARK: Stats grid
    private func buildStatsGrid(_ s: GameSession) -> UIView {
        let speedStr = (s.averageSpeed ?? 0) > 0
            ? String(format: "%.1f km/h", s.averageSpeed!)
            : "—"

        let items: [(String, String, String, UIColor)] = [
            ("flame.fill",           "\(s.caloriesBurned)",     "Calories",  .systemOrange),
            ("stopwatch.fill",       "\(s.durationMinutes) min", "Duration",  .systemCyan),
            ("arrow.up.circle.fill", "\(s.totalJumps)",         "Jumps",     .systemGreen),
            ("arrow.down.circle.fill","\(s.totalCrouches)",     "Crouches",  .systemYellow),
            ("speedometer",          speedStr,                   "Avg Speed", UIColor(red:0.7,green:0.5,blue:1,alpha:1))
        ]

        var col1: [UIView] = []; var col2: [UIView] = []
        for (i, item) in items.enumerated() {
            let c = statCell(icon: item.0, value: item.1, title: item.2, color: item.3)
            if i % 2 == 0 { col1.append(c) } else { col2.append(c) }
        }
        // Pad shorter column with transparent spacer
        while col2.count < col1.count {
            let sp = UIView()
            sp.translatesAutoresizingMaskIntoConstraints = false
            sp.heightAnchor.constraint(equalToConstant: 88).isActive = true
            col2.append(sp)
        }

        func vstack(_ views: [UIView]) -> UIStackView {
            let sv = UIStackView(arrangedSubviews: views)
            sv.axis = .vertical; sv.spacing = 14; sv.translatesAutoresizingMaskIntoConstraints = false
            return sv
        }
        let row = UIStackView(arrangedSubviews: [vstack(col1), vstack(col2)])
        row.axis = .horizontal; row.spacing = 14; row.distribution = .fillEqually
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    private func statCell(icon: String, value: String, title: String, color: UIColor) -> UIView {
        let card = glassCard(h: 88)
        let img = UIImageView(image: UIImage(systemName: icon))
        img.tintColor = color; img.contentMode = .scaleAspectFit
        img.translatesAutoresizingMaskIntoConstraints = false
        img.widthAnchor.constraint(equalToConstant: 22).isActive  = true
        img.heightAnchor.constraint(equalToConstant: 22).isActive = true

        let vLbl = makeLbl(value, size: 20, weight: .bold, color: .white)
        let tLbl = makeLbl(title, size: 11, weight: .medium, color: UIColor.white.withAlphaComponent(0.4))
        let sv = UIStackView(arrangedSubviews: [img, vLbl, tLbl])
        sv.axis = .vertical; sv.spacing = 4; sv.alignment = .leading
        sv.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(sv)
        NSLayoutConstraint.activate([
            sv.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            sv.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            sv.centerYAnchor.constraint(equalTo: card.centerYAnchor)
        ])
        return card
    }

    // MARK: Personal Best badge
    private func buildBestBadge() -> UIView {
        let gold = UIColor(red: 1, green: 0.86, blue: 0.24, alpha: 1)
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor    = gold.withAlphaComponent(0.15)
        v.layer.cornerRadius = 12
        v.layer.borderWidth  = 1
        v.layer.borderColor  = gold.withAlphaComponent(0.6).cgColor

        let img = UIImageView(image: UIImage(systemName: "trophy.fill"))
        img.tintColor = gold; img.contentMode = .scaleAspectFit
        img.translatesAutoresizingMaskIntoConstraints = false
        img.widthAnchor.constraint(equalToConstant: 13).isActive  = true
        img.heightAnchor.constraint(equalToConstant: 13).isActive = true

        let l = UILabel()
        l.text = "Best"; l.font = .systemFont(ofSize: 11, weight: .bold); l.textColor = gold
        l.translatesAutoresizingMaskIntoConstraints = false

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

    // MARK: Helpers
    /// Glass card — exact same spec as StatisticsViewController.glassCard()
    private func glassCard(h: CGFloat?) -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        if let h { v.heightAnchor.constraint(equalToConstant: h).isActive = true }
        v.backgroundColor = .clear

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = 24; blur.clipsToBounds = true
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

    @objc private func goBack() {
        UIView.animate(withDuration: 0.1, animations: {
            self.backBtn.transform = CGAffineTransform(scaleX: 0.88, y: 0.88)
        }) { _ in
            UIView.animate(withDuration: 0.1) { self.backBtn.transform = .identity }
            self.dismiss(animated: true)
        }
    }
}
