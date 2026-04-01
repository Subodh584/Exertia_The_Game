import UIKit

// MARK: - Full Calendar — full-screen, Stats-page style
class FullCalendarViewController: UIViewController,
                                   UICollectionViewDataSource,
                                   UICollectionViewDelegateFlowLayout {

    // Injected from StatisticsViewController
    var activeDateStrings: Set<String> = []
    var sessionsByDate: [String: [AppSession]] = [:]

    // IST
    private static let istTZ = TimeZone(identifier: "Asia/Kolkata")!
    private var istCalendar: Calendar {
        var c = Calendar.current; c.timeZone = Self.istTZ; return c
    }
    private let dateKeyFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Asia/Kolkata")!; return f
    }()

    // State
    var currentMonthDate = Date()

    // Nav — same pattern as Stats page
    private let navBar       = UIView()
    private let backBtn      = UIButton()
    private let gradientView = UIView()

    // Month navigation row
    private let monthLabel = UILabel()
    private let prevBtn    = UIButton()
    private let nextBtn    = UIButton()

    // Weekday header
    private let weekdayStack = UIStackView()

    // Grid
    private var collectionView: UICollectionView!

    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 13/255, green: 5/255, blue: 26/255, alpha: 1.0)
        addGradient()
        configureNavBar()
        configureMonthRow()
        configureWeekdayHeader()
        configureGrid()
        addSwipeGestures()
    }

    private func addSwipeGestures() {
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(nextMonth))
        swipeLeft.direction = .left
        view.addGestureRecognizer(swipeLeft)

        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(prevMonth))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeRight)
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
        let gl = CAGradientLayer()
        gl.colors = [UIColor.neonPink.withAlphaComponent(0.28).cgColor, UIColor.clear.cgColor]
        gl.locations = [0.0, 1.0]
        gl.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 350)
        gradientView.layer.addSublayer(gl)
    }

    // MARK: Nav bar — same as Stats page
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
        backBtn.translatesAutoresizingMaskIntoConstraints = false

        let titleLbl = UILabel()
        titleLbl.text = "Streak Calendar"
        titleLbl.font = .systemFont(ofSize: 20, weight: .bold)
        titleLbl.textColor = .white
        titleLbl.textAlignment = .center
        titleLbl.translatesAutoresizingMaskIntoConstraints = false

        navBar.addSubview(backBtn)
        navBar.addSubview(titleLbl)

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navBar.heightAnchor.constraint(equalToConstant: 50),

            backBtn.leadingAnchor.constraint(equalTo: navBar.leadingAnchor, constant: 20),
            backBtn.centerYAnchor.constraint(equalTo: navBar.centerYAnchor),
            backBtn.widthAnchor.constraint(equalToConstant: 40),
            backBtn.heightAnchor.constraint(equalToConstant: 40),

            titleLbl.centerXAnchor.constraint(equalTo: navBar.centerXAnchor),
            titleLbl.centerYAnchor.constraint(equalTo: navBar.centerYAnchor)
        ])
    }

    // MARK: Month navigation row
    private func configureMonthRow() {
        let monthCard = UIView()
        monthCard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(monthCard)

        // Glass pill background
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.layer.cornerRadius = 18; blur.clipsToBounds = true
        blur.layer.borderColor  = UIColor.white.withAlphaComponent(0.15).cgColor
        blur.layer.borderWidth  = 1
        blur.translatesAutoresizingMaskIntoConstraints = false
        monthCard.addSubview(blur)

        monthLabel.font      = .systemFont(ofSize: 18, weight: .bold)
        monthLabel.textColor = .white
        monthLabel.textAlignment = .center
        monthLabel.translatesAutoresizingMaskIntoConstraints = false
        updateMonthLabel()

        func arrowBtn(_ sys: String) -> UIButton {
            let b = UIButton()
            let cfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
            b.setImage(UIImage(systemName: sys, withConfiguration: cfg), for: .normal)
            b.tintColor = .white
            b.translatesAutoresizingMaskIntoConstraints = false
            return b
        }

        prevBtn.setImage(UIImage(systemName: "chevron.left",
                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)), for: .normal)
        prevBtn.tintColor = .white
        prevBtn.addTarget(self, action: #selector(prevMonth), for: .touchUpInside)
        prevBtn.translatesAutoresizingMaskIntoConstraints = false

        nextBtn.setImage(UIImage(systemName: "chevron.right",
                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)), for: .normal)
        nextBtn.tintColor = .white
        nextBtn.addTarget(self, action: #selector(nextMonth), for: .touchUpInside)
        nextBtn.translatesAutoresizingMaskIntoConstraints = false

        monthCard.addSubview(monthLabel)
        monthCard.addSubview(prevBtn)
        monthCard.addSubview(nextBtn)

        NSLayoutConstraint.activate([
            monthCard.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 14),
            monthCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            monthCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            monthCard.heightAnchor.constraint(equalToConstant: 52),

            blur.topAnchor.constraint(equalTo: monthCard.topAnchor),
            blur.bottomAnchor.constraint(equalTo: monthCard.bottomAnchor),
            blur.leadingAnchor.constraint(equalTo: monthCard.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: monthCard.trailingAnchor),

            prevBtn.leadingAnchor.constraint(equalTo: monthCard.leadingAnchor, constant: 18),
            prevBtn.centerYAnchor.constraint(equalTo: monthCard.centerYAnchor),
            prevBtn.widthAnchor.constraint(equalToConstant: 32),
            prevBtn.heightAnchor.constraint(equalToConstant: 32),

            nextBtn.trailingAnchor.constraint(equalTo: monthCard.trailingAnchor, constant: -18),
            nextBtn.centerYAnchor.constraint(equalTo: monthCard.centerYAnchor),
            nextBtn.widthAnchor.constraint(equalToConstant: 32),
            nextBtn.heightAnchor.constraint(equalToConstant: 32),

            monthLabel.centerXAnchor.constraint(equalTo: monthCard.centerXAnchor),
            monthLabel.centerYAnchor.constraint(equalTo: monthCard.centerYAnchor)
        ])

        // Store reference so weekday row can pin below it
        self._monthCard = monthCard
    }
    private var _monthCard: UIView?

    // MARK: Weekday header row
    private func configureWeekdayHeader() {
        weekdayStack.axis         = .horizontal
        weekdayStack.distribution = .fillEqually
        weekdayStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(weekdayStack)

        for day in ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"] {
            let l = UILabel()
            l.text          = day
            l.font          = .systemFont(ofSize: 11, weight: .semibold)
            l.textColor     = UIColor.white.withAlphaComponent(0.35)
            l.textAlignment = .center
            weekdayStack.addArrangedSubview(l)
        }

        NSLayoutConstraint.activate([
            weekdayStack.topAnchor.constraint(equalTo: _monthCard!.bottomAnchor, constant: 16),
            weekdayStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            weekdayStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            weekdayStack.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    // MARK: Collection view grid
    private func configureGrid() {
        let w = UIScreen.main.bounds.width - 32
        let itemW = w / 7

        let layout = UICollectionViewFlowLayout()
        layout.itemSize              = CGSize(width: itemW, height: 68)
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing    = 4

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate   = self
        collectionView.register(CalendarDayCell.self, forCellWithReuseIdentifier: "Day")
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        // Legend row at the bottom
        let legend = buildLegend()
        view.addSubview(legend)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: weekdayStack.bottomAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            collectionView.bottomAnchor.constraint(equalTo: legend.topAnchor, constant: -12),

            legend.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            legend.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            legend.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            legend.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    private func buildLegend() -> UIView {
        let row = UIStackView()
        row.axis    = .horizontal
        row.spacing = 20
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false

        func dot(_ color: UIColor) -> UIView {
            let v = UIView(); v.backgroundColor = color
            v.layer.cornerRadius = 5; v.clipsToBounds = true
            v.translatesAutoresizingMaskIntoConstraints = false
            v.widthAnchor.constraint(equalToConstant: 10).isActive = true
            v.heightAnchor.constraint(equalToConstant: 10).isActive = true
            return v
        }
        func lbl(_ text: String) -> UILabel {
            let l = UILabel(); l.text = text
            l.font = .systemFont(ofSize: 11, weight: .medium)
            l.textColor = UIColor.white.withAlphaComponent(0.45)
            return l
        }

        let gold = UIColor(red: 1, green: 0.86, blue: 0.24, alpha: 1)
        let orange = UIColor(red: 1.0, green: 0.62, blue: 0.18, alpha: 1.0)
        for (color, title) in [
            (gold,           "Target Met"),
            (orange,         "Abandoned"),
            (UIColor.neonPink, "Today"),
            (UIColor.white.withAlphaComponent(0.2), "No Run")
        ] {
            let pair = UIStackView(arrangedSubviews: [dot(color), lbl(title)])
            pair.axis = .horizontal; pair.spacing = 6; pair.alignment = .center
            row.addArrangedSubview(pair)
        }

        let spacer = UIView(); spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)
        return row
    }

    // MARK: Collection data source
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        daysInMonth + firstWeekdayOffset
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Day", for: indexPath) as! CalendarDayCell
        let offset = firstWeekdayOffset

        if indexPath.item < offset {
            cell.isHidden = true
        } else {
            cell.isHidden = false
            let dayNum = indexPath.item - offset + 1
            var cal = istCalendar
            if let date = cal.date(byAdding: .day, value: dayNum - 1, to: startOfMonth) {
                let key       = dateKeyFmt.string(from: date)
                let isToday   = cal.isDateInToday(date)
                let targetMet = activeDateStrings.contains(key)
                let daySessions = sessionsByDate[key] ?? []
                let hasSessions = !daySessions.isEmpty
                let hasAbandonedSession = daySessions.contains { ($0.completion_status?.lowercased() ?? "") == "abandoned" }

                cell.configure(date: date, isToday: isToday, targetMet: targetMet, hasAbandonedSession: hasAbandonedSession)

                // Subtle dot if there are sessions but target not met
                if hasSessions && !targetMet && !isToday && !hasAbandonedSession {
                    cell.showSessionDot(true)
                } else {
                    cell.showSessionDot(false)
                }
            }
        }
        return cell
    }

    // MARK: Collection delegate — date tap → DayStatsViewController
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let offset = firstWeekdayOffset
        guard indexPath.item >= offset else { return }
        let dayNum = indexPath.item - offset + 1
        guard let date = istCalendar.date(byAdding: .day, value: dayNum - 1, to: startOfMonth) else { return }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Scale-bounce on the cell
        if let cell = collectionView.cellForItem(at: indexPath) {
            UIView.animate(withDuration: 0.1, animations: { cell.transform = CGAffineTransform(scaleX: 0.88, y: 0.88) }) { _ in
                UIView.animate(withDuration: 0.15, delay: 0,
                               usingSpringWithDamping: 0.6, initialSpringVelocity: 0) {
                    cell.transform = .identity
                }
            }
        }

        let key = dateKeyFmt.string(from: date)
        let daySessions = sessionsByDate[key] ?? []

        let vc = DayStatsViewController()
        vc.date        = date
        vc.sessions    = daySessions
        vc.targetMet   = activeDateStrings.contains(key)
        vc.modalPresentationStyle = .pageSheet
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 28
        }
        present(vc, animated: true)
    }

    // MARK: Month nav
    @objc private func prevMonth() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        animateMonthTransition(direction: .right) {
            self.currentMonthDate = self.istCalendar.date(byAdding: .month, value: -1, to: self.currentMonthDate) ?? Date()
            self.updateMonthLabel()
            self.collectionView.reloadData()
        }
    }

    @objc private func nextMonth() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        animateMonthTransition(direction: .left) {
            self.currentMonthDate = self.istCalendar.date(byAdding: .month, value: 1, to: self.currentMonthDate) ?? Date()
            self.updateMonthLabel()
            self.collectionView.reloadData()
        }
    }

    private enum SlideDirection { case left, right }

    private func animateMonthTransition(direction: SlideDirection, update: @escaping () -> Void) {
        let offset: CGFloat = direction == .left ? -collectionView.bounds.width : collectionView.bounds.width

        // Slide out current content
        UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseIn, animations: {
            self.collectionView.transform = CGAffineTransform(translationX: offset, y: 0)
            self.collectionView.alpha = 0
        }) { _ in
            // Update data while off-screen
            update()

            // Position on opposite side
            self.collectionView.transform = CGAffineTransform(translationX: -offset, y: 0)

            // Slide in new content
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: {
                self.collectionView.transform = .identity
                self.collectionView.alpha = 1
            })
        }
    }

    private func updateMonthLabel() {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        f.timeZone   = Self.istTZ
        monthLabel.text = f.string(from: currentMonthDate)
    }

    @objc private func goBack() {
        UIView.animate(withDuration: 0.1, animations: {
            self.backBtn.transform = CGAffineTransform(scaleX: 0.88, y: 0.88)
        }) { _ in
            UIView.animate(withDuration: 0.1) { self.backBtn.transform = .identity }
            self.dismiss(animated: true)
        }
    }

    // MARK: Calendar helpers
    private var daysInMonth: Int {
        istCalendar.range(of: .day, in: .month, for: currentMonthDate)?.count ?? 30
    }
    private var firstWeekdayOffset: Int {
        var comp = istCalendar.dateComponents([.year, .month], from: currentMonthDate)
        guard let som = istCalendar.date(from: comp) else { return 0 }
        return istCalendar.component(.weekday, from: som) - 1  // 0-based (Sun=0)
    }
    private var startOfMonth: Date {
        let comp = istCalendar.dateComponents([.year, .month], from: currentMonthDate)
        return istCalendar.date(from: comp) ?? currentMonthDate
    }
}

// MARK: - CalendarDayCell session-dot extension
extension CalendarDayCell {
    /// Shows a tiny neonPink dot at the bottom if there are sessions but target not met
    func showSessionDot(_ show: Bool) {
        // Tag 9999 is the session dot
        viewWithTag(9999)?.removeFromSuperview()
        guard show else { return }
        let dot = UIView()
        dot.tag = 9999
        dot.backgroundColor = UIColor.neonPink.withAlphaComponent(0.6)
        dot.layer.cornerRadius = 2.5
        dot.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dot)
        NSLayoutConstraint.activate([
            dot.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            dot.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),
            dot.widthAnchor.constraint(equalToConstant: 5),
            dot.heightAnchor.constraint(equalToConstant: 5)
        ])
    }
}

// MARK: - Int weekday abbreviation (1=Sun…7=Sat)
private extension Int {
    var weekdayAbbr: String {
        switch self {
        case 1: return "SUN"; case 2: return "MON"; case 3: return "TUE"
        case 4: return "WED"; case 5: return "THU"; case 6: return "FRI"
        case 7: return "SAT"; default: return ""
        }
    }
}
