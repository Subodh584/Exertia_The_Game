import UIKit

extension UIColor {
    static let neonPink = UIColor(red: 255/255, green: 92/255, blue: 255/255, alpha: 1.0)
    static let neonYellow = UIColor(red: 255/255, green: 239/255, blue: 190/255, alpha: 1.0)
}

class StatisticsViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

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
        fetchRealUserName()
        fetchStatsData()
    }
    
    // MARK: - Cached API data for display
    private var apiTotalCalories: Int = 0
    private var apiTotalMinutes: Int = 0
    private var apiCompletedSessions: Int = 0
    private var apiLastSessionDuration: Int? = nil
    private var apiLastSessionCalories: Int? = nil
    private var apiBestSessionDuration: Int? = nil
    private var apiBestSessionCalories: Int? = nil
    private var apiDailyTargetCalories: Int = 500
    private var apiDailyTargetDistance: Double = 5.0
    
    func fetchRealUserName() {
            guard let userId = UserDefaults.standard.string(forKey: "djangoUserID") else { return }
            
            Task {
                do {
                    let user = try await APIManager.shared.getUser(userId: userId)
                    DispatchQueue.main.async {
                        self.nameLabel.text = user.displayName ?? user.username
                        self.apiDailyTargetCalories = user.dailyTargetCalories ?? 500
                        self.apiDailyTargetDistance = user.dailyTargetDistance ?? 5.0
                    }
                } catch {
                    print("❌ Failed to fetch user name for stats page: \(error)")
                }
            }
        }
    
    func fetchStatsData() {
        guard let userId = UserDefaults.standard.string(forKey: "djangoUserID") else { return }
        
        Task {
            do {
                // Fetch aggregated stats
                let stats = try await APIManager.shared.getUserStats(userId: userId)
                self.apiTotalCalories = stats.totalCalories
                self.apiTotalMinutes = stats.totalMinutes
                self.apiCompletedSessions = stats.completedSessions
                
                // Fetch all sessions to find last run & personal best
                let sessions = try await APIManager.shared.getUserSessions(userId: userId)
                let completed = sessions.filter { $0.completionStatus == "completed" }
                
                // Sort by created_at to find the most recent
                let sorted = completed.sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") }
                
                if let lastSession = sorted.first {
                    self.apiLastSessionDuration = lastSession.durationMinutes
                    self.apiLastSessionCalories = lastSession.caloriesBurned
                }
                
                // Personal best = highest calories in a single session
                if let bestSession = completed.max(by: { ($0.caloriesBurned ?? 0) < ($1.caloriesBurned ?? 0) }) {
                    self.apiBestSessionDuration = bestSession.durationMinutes
                    self.apiBestSessionCalories = bestSession.caloriesBurned
                }
                
                DispatchQueue.main.async {
                    self.refreshUI()
                    print("✅ Statistics UI hydrated with real API data!")
                }
            } catch {
                print("❌ Failed to fetch stats data: \(error). Using defaults.")
                DispatchQueue.main.async { self.refreshUI() }
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backBtn.layer.cornerRadius = backBtn.frame.height / 2
        profileImg.layer.cornerRadius = profileImg.frame.height / 2
        moveBubble()
        
        tabContainer.layoutIfNeeded()
        if tabWrappers.indices.contains(3) {
            moveIndicator(to: tabWrappers[3], animated: false)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshUI()
    }
    
    func loadDates() {
        let calendar = Calendar.current
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
            gradientView.heightAnchor.constraint(equalToConstant: 350)
        ])
        let layer = CAGradientLayer()
        layer.colors = [UIColor.neonPink.withAlphaComponent(0.3).cgColor, UIColor.clear.cgColor]
        layer.locations = [0.0, 1.0]
        layer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 350)
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
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
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
            navBar.heightAnchor.constraint(equalToConstant: 50),
            
            backBtn.leadingAnchor.constraint(equalTo: navBar.leadingAnchor, constant: 20),
            backBtn.centerYAnchor.constraint(equalTo: navBar.centerYAnchor),
            backBtn.widthAnchor.constraint(equalToConstant: 40),
            backBtn.heightAnchor.constraint(equalToConstant: 40),
            
            titleLabel.centerXAnchor.constraint(equalTo: navBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: navBar.centerYAnchor),
            
            profileImg.trailingAnchor.constraint(equalTo: navBar.trailingAnchor, constant: -20),
            profileImg.centerYAnchor.constraint(equalTo: navBar.centerYAnchor),
            profileImg.widthAnchor.constraint(equalToConstant: 36),
            profileImg.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    func configureScroll() {
        view.addSubview(mainScroll)
        view.addSubview(tabContainer)
        mainScroll.translatesAutoresizingMaskIntoConstraints = false
        tabContainer.translatesAutoresizingMaskIntoConstraints = false
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
            tabContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            tabContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            tabContainer.heightAnchor.constraint(equalToConstant: 70),
            
            stackContainer.topAnchor.constraint(equalTo: mainScroll.topAnchor),
            stackContainer.leadingAnchor.constraint(equalTo: mainScroll.leadingAnchor, constant: 20),
            stackContainer.trailingAnchor.constraint(equalTo: mainScroll.trailingAnchor, constant: -20),
            stackContainer.bottomAnchor.constraint(equalTo: mainScroll.bottomAnchor, constant: -100),
            stackContainer.widthAnchor.constraint(equalTo: mainScroll.widthAnchor, constant: -40)
        ])
    }
    
    func addHeader() {
        let container = UIView()
        helloLabel.text = "Welcome Back,"
        helloLabel.font = .systemFont(ofSize: 16, weight: .medium)
        helloLabel.textColor = .lightGray
        nameLabel.text = "Player"
        nameLabel.font = .systemFont(ofSize: 28, weight: .bold)
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
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            container.heightAnchor.constraint(equalToConstant: 70)
        ])
    }
    
    func addMainCard() {
        let card = glassCard(h: 200)
        let toggleBox = UIView()
        toggleBox.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        toggleBox.layer.cornerRadius = 16
        toggleBox.translatesAutoresizingMaskIntoConstraints = false
        
        calBtn = makeToggleBtn(text: "CAL BURN", color: .neonPink, on: true)
        timeBtn = makeToggleBtn(text: "RUNTIME", color: .neonYellow, on: false)
        
        calBtn.addTarget(self, action: #selector(clickedCal), for: .touchUpInside)
        timeBtn.addTarget(self, action: #selector(clickedTime), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [calBtn, timeBtn])
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        toggleBox.addSubview(stack)
        
        bigStatLabel.font = .systemFont(ofSize: 48, weight: .bold)
        bigStatLabel.textColor = .white
        bigStatLabel.textAlignment = .center
        
        subStatLabel.font = .systemFont(ofSize: 14, weight: .medium)
        subStatLabel.textAlignment = .center
        
        let textStack = UIStackView(arrangedSubviews: [bigStatLabel, subStatLabel])
        textStack.axis = .vertical
        textStack.spacing = 0
        textStack.translatesAutoresizingMaskIntoConstraints = false
        
        let ringBox = UIView()
        ringBox.translatesAutoresizingMaskIntoConstraints = false
        drawRings(in: ringBox)
        
        card.addSubview(toggleBox)
        card.addSubview(textStack)
        card.addSubview(ringBox)
        
        NSLayoutConstraint.activate([
            toggleBox.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            toggleBox.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            toggleBox.widthAnchor.constraint(equalToConstant: 180),
            toggleBox.heightAnchor.constraint(equalToConstant: 32),
            stack.topAnchor.constraint(equalTo: toggleBox.topAnchor),
            stack.bottomAnchor.constraint(equalTo: toggleBox.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: toggleBox.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: toggleBox.trailingAnchor),
            textStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 30),
            textStack.centerYAnchor.constraint(equalTo: card.centerYAnchor, constant: 20),
            ringBox.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            ringBox.centerYAnchor.constraint(equalTo: card.centerYAnchor, constant: 10),
            ringBox.widthAnchor.constraint(equalToConstant: 120),
            ringBox.heightAnchor.constraint(equalToConstant: 120)
        ])
        stackContainer.addArrangedSubview(card)
    }
    
    func addGridCards() {
        let stack = UIStackView()
        stack.spacing = 15
        stack.distribution = .fillEqually
        
        runCard = glassCard(h: 130)
        fillSmallCard(view: runCard!, title: "Last Run", tLabel: lastTimeLabel, cLabel: lastCalLabel)
        
        bestCard = glassCard(h: 130)
        fillSmallCard(view: bestCard!, title: "Personal Best", tLabel: bestTimeLabel, cLabel: bestCalLabel)
        
        let t1 = UITapGestureRecognizer(target: self, action: #selector(openHistory))
        runCard?.addGestureRecognizer(t1)
        runCard?.isUserInteractionEnabled = true
        
        let t2 = UITapGestureRecognizer(target: self, action: #selector(openHistory))
        bestCard?.addGestureRecognizer(t2)
        bestCard?.isUserInteractionEnabled = true
        
        stack.addArrangedSubview(runCard!)
        stack.addArrangedSubview(bestCard!)
        stackContainer.addArrangedSubview(stack)
    }
    
    func addWeightView() {
        let card = glassCard(h: 120)
        let title = UILabel()
        title.text = "Weight Goal Progress"
        title.font = .systemFont(ofSize: 14, weight: .bold)
        title.textColor = .white
        title.translatesAutoresizingMaskIntoConstraints = false
        
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
        
        let start = UILabel()
        start.text = "78 kg"
        start.textColor = .white
        start.font = .systemFont(ofSize: 12, weight: .bold)
        let end = UILabel()
        end.text = "73 kg"
        end.textColor = .white
        end.font = .systemFont(ofSize: 12, weight: .bold)
        weightMsg.text = "Good Job! You are 6.5 kg down."
        weightMsg.textColor = .gray
        weightMsg.font = .systemFont(ofSize: 10)
        weightMsg.textAlignment = .center
        let bottom = UIStackView(arrangedSubviews: [start, weightMsg, end])
        bottom.distribution = .equalCentering
        bottom.alignment = .center
        bottom.translatesAutoresizingMaskIntoConstraints = false
        
        card.addSubview(title)
        card.addSubview(weightBar)
        card.addSubview(bubbleView)
        card.addSubview(bottom)
        
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: card.topAnchor, constant: 15),
            title.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            weightBar.centerYAnchor.constraint(equalTo: card.centerYAnchor, constant: 5),
            weightBar.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            weightBar.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            weightBar.heightAnchor.constraint(equalToConstant: 12),
            bubbleLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 2),
            bubbleLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -2),
            bubbleLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 6),
            bubbleLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -6),
            bubbleView.bottomAnchor.constraint(equalTo: weightBar.topAnchor, constant: -4),
            bottom.topAnchor.constraint(equalTo: weightBar.bottomAnchor, constant: 8),
            bottom.leadingAnchor.constraint(equalTo: weightBar.leadingAnchor),
            bottom.trailingAnchor.constraint(equalTo: weightBar.trailingAnchor)
        ])
        bubbleConstraint = bubbleView.leadingAnchor.constraint(equalTo: weightBar.leadingAnchor, constant: 0)
        bubbleConstraint?.isActive = true
        stackContainer.addArrangedSubview(card)
        stackContainer.setCustomSpacing(50, after: card)
    }
    
    func addStreakView() {
        let card = glassCard(h: 250)
        card.clipsToBounds = false
        
        let fireImg = UIImageView(image: UIImage(named: "Streaks"))
        fireImg.contentMode = .scaleAspectFit
        fireImg.translatesAutoresizingMaskIntoConstraints = false

        let t1 = UILabel()
        t1.text = "\(apiCompletedSessions) Day Streak!"
        t1.font = .systemFont(ofSize: 22, weight: .bold)
        t1.textColor = .white
        t1.tag = 999 // Tag for updating later
        
        let t2 = UILabel()
        t2.text = "Keep going, you are almost there"
        t2.font = .systemFont(ofSize: 12)
        t2.textColor = .gray
        
        let txtStack = UIStackView(arrangedSubviews: [t1, t2])
        txtStack.axis = .vertical
        txtStack.spacing = 4
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
        layout.itemSize = CGSize(width: 50, height: 75)
        layout.minimumLineSpacing = 10
        
        streakCollection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        streakCollection.backgroundColor = .clear
        streakCollection.showsHorizontalScrollIndicator = false
        streakCollection.dataSource = self
        streakCollection.delegate = self
        streakCollection.register(CalendarDayCell.self, forCellWithReuseIdentifier: "Cell")
        streakCollection.translatesAutoresizingMaskIntoConstraints = false
        
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

            txtStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 50),
            txtStack.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            streakCollection.topAnchor.constraint(equalTo: txtStack.bottomAnchor, constant: 20),
            streakCollection.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 15),
            streakCollection.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -15),
            streakCollection.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
        ])
        stackContainer.addArrangedSubview(card)
        DispatchQueue.main.async { self.goToToday() }
    }
    
    @objc func goBack() { self.dismiss(animated: true) }
    
    @objc func openProfile() {
            let sb = UIStoryboard(name: "Main", bundle: nil)
            if let vc = sb.instantiateViewController(withIdentifier: "ProfileViewController") as? ProfileViewController {
                vc.modalPresentationStyle = .fullScreen
                vc.modalTransitionStyle = .crossDissolve
                self.present(vc, animated: true)
            }
        }
    
    @objc func openHistory() {
        let vc = RunHistoryViewController()
        vc.modalPresentationStyle = .overCurrentContext
        vc.modalTransitionStyle = .crossDissolve
        present(vc, animated: true)
    }
    
    @objc func openCalendar() {
        let vc = FullCalendarViewController()
        vc.modalPresentationStyle = .overCurrentContext
        vc.modalTransitionStyle = .crossDissolve
        present(vc, animated: true)
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
        let isToday = Calendar.current.isDateInToday(date)
        let daysSince = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 99
        let active = (date < Date()) && (daysSince >= 0 && daysSince < 4)
        cell.configure(date: date, isToday: isToday, hasActivity: active)
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
    
    func fillSmallCard(view: UIView, title: String, tLabel: UILabel, cLabel: UILabel) {
        let l = UILabel()
        l.text = title
        l.font = .systemFont(ofSize: 14, weight: .bold)
        l.textColor = .white
        let img = UIImageView(image: UIImage(systemName: "chevron.right"))
        img.tintColor = .white
        let top = UIStackView(arrangedSubviews: [l, UIView(), img])
        top.distribution = .fill
        
        let r1 = makeRow(icon: "clock", c: .neonYellow, l: tLabel)
        let r2 = makeRow(icon: "fire", c: .neonPink, l: cLabel)
        
        let box = UIStackView(arrangedSubviews: [top, r1, r2])
        box.axis = .vertical
        box.spacing = 10
        box.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(box)
        NSLayoutConstraint.activate([
            box.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            box.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            box.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    func makeRow(icon: String, c: UIColor, l: UILabel) -> UIStackView {
        let i = UIImageView(image: UIImage(named: icon))
        i.tintColor = c
        i.contentMode = .scaleAspectFit
        i.widthAnchor.constraint(equalToConstant: 16).isActive = true
        i.heightAnchor.constraint(equalToConstant: 16).isActive = true
        
        let t = UILabel()
        t.text = (icon == "clock") ? "Duration" : "Calories"
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
        // Use API data (falls back to 0 if not yet loaded)
        let cal = apiTotalCalories
        let time = apiTotalMinutes
        
        UIView.transition(with: bigStatLabel, duration: 0.3, options: .transitionCrossDissolve) {
            self.bigStatLabel.text = self.showCalories ? "\(cal)" : "\(time)"
            self.subStatLabel.text = self.showCalories ? "Calories Burned" : "Minutes Ran"
            self.subStatLabel.textColor = self.showCalories ? .neonPink : .neonYellow
        }
        
        // Ring progress based on daily targets
        let calProgress = apiDailyTargetCalories > 0 ? min(CGFloat(cal) / CGFloat(apiDailyTargetCalories), 1.0) : 0.0
        let timeProgress = apiDailyTargetDistance > 0 ? min(CGFloat(time) / CGFloat(apiDailyTargetDistance * 10), 1.0) : 0.0
        outerRing.strokeEnd = calProgress
        innerRing.strokeEnd = timeProgress
        outerRing.opacity = showCalories ? 1.0 : 0.2
        innerRing.opacity = showCalories ? 0.2 : 1.0
        
        // Last Run card
        if let lastDur = apiLastSessionDuration, let lastCal = apiLastSessionCalories {
            lastTimeLabel.text = "\(lastDur) min"
            lastCalLabel.text = "\(lastCal) cal"
        } else {
            lastTimeLabel.text = "-- min"
            lastCalLabel.text = "-- cal"
        }
        
        // Personal Best card
        if let bestDur = apiBestSessionDuration, let bestCal = apiBestSessionCalories {
            bestTimeLabel.text = "\(bestDur) min"
            bestCalLabel.text = "\(bestCal) cal"
        } else {
            bestTimeLabel.text = "-- min"
            bestCalLabel.text = "-- cal"
        }
        
        // Weight & streak (keep existing logic for now)
        weightBar.progress = 0.6
        bubbleLabel.text = "75.0"
        moveBubble()
    }
    
    @objc func clickedCal() {
        showCalories = true
        animateToggle(b: calBtn, on: true, c: .neonPink)
        animateToggle(b: timeBtn, on: false, c: .gray)
        refreshUI()
    }
    @objc func clickedTime() {
        showCalories = false
        animateToggle(b: calBtn, on: false, c: .gray)
        animateToggle(b: timeBtn, on: true, c: .neonYellow)
        refreshUI()
    }

    func styleTabBar() {
        tabContainer.backgroundColor = .clear
        tabContainer.subviews.filter { $0 is UIVisualEffectView }.forEach { $0.removeFromSuperview() }
        
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
        blur.isUserInteractionEnabled = false
        blur.layer.cornerRadius = 35
        blur.clipsToBounds = true
        blur.translatesAutoresizingMaskIntoConstraints = false
        
        tabContainer.insertSubview(blur, at: 0)
        
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: tabContainer.topAnchor),
            blur.bottomAnchor.constraint(equalTo: tabContainer.bottomAnchor),
            blur.leadingAnchor.constraint(equalTo: tabContainer.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: tabContainer.trailingAnchor)
        ])
        
        tabContainer.layer.cornerRadius = 35
        tabContainer.layer.borderWidth = 1.0
        tabContainer.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        
        tabIndicator.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        tabIndicator.layer.cornerRadius = 30
        tabIndicator.layer.cornerCurve = .continuous
        tabContainer.insertSubview(tabIndicator, at: 1)
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
        let list = [("home2", "Home"), ("multiplayer2", "Multiplayer"), ("customize2", "Customize"), ("statistics2", "Statistics")]
        for (i, (icon, txt)) in list.enumerated() {
            let stack = UIStackView()
            stack.axis = .vertical
            stack.alignment = .center
            stack.spacing = 2
            stack.isUserInteractionEnabled = false
            let img = UIImageView(image: UIImage(named: icon))
            img.contentMode = .scaleAspectFit
            img.translatesAutoresizingMaskIntoConstraints = false
            img.widthAnchor.constraint(equalToConstant: 44).isActive = true
            img.heightAnchor.constraint(equalToConstant: 34).isActive = true
            let l = UILabel()
            l.text = txt
            l.font = UIFont.systemFont(ofSize: 10, weight: .semibold)
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
        let i = sender.tag
        moveIndicator(to: tabWrappers[i], animated: true)
        
        switch i {
        case 0:
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
            let sb = UIStoryboard(name: "Main", bundle: nil)
            if let vc = sb.instantiateViewController(withIdentifier: "MultiplayerViewController") as? MultiplayerViewController {
                vc.modalPresentationStyle = .fullScreen
                vc.modalTransitionStyle = .crossDissolve
                self.present(vc, animated: true)
            }
        case 2:
            let sb = UIStoryboard(name: "Main", bundle: nil)
            if let vc = sb.instantiateViewController(withIdentifier: "CharacterSelectionViewController") as? CharacterSelectionViewController {
                vc.modalPresentationStyle = .fullScreen
                vc.modalTransitionStyle = .crossDissolve
                self.present(vc, animated: true)
            }
        case 3: break
        default: break
        }
    }
    
    func moveIndicator(to v: UIView, animated: Bool) {
        let frame = v.convert(v.bounds, to: tabContainer)
        let newFrame = frame.insetBy(dx: 4, dy: 4)
        UIView.animate(withDuration: animated ? 0.4 : 0.0, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
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
