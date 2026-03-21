import UIKit

class FullCalendarViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    let monthLabel = UILabel()
    var currentMonthDate = Date()
    var collectionView: UICollectionView!
    var activeDateStrings: Set<String> = []   // injected from StatisticsViewController

    // IST timezone — backend stores dates in IST
    private static let istTimeZone = TimeZone(identifier: "Asia/Kolkata")!

    private let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        return f
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.frame = view.bounds
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(blur)
        
        setupModalUI()
    }
    
    func setupModalUI() {
        let container = UIView()
        container.backgroundColor = UIColor(red: 0.05, green: 0.02, blue: 0.1, alpha: 0.95)
        container.layer.cornerRadius = 28
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.6
        container.layer.shadowRadius = 30
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)
        monthLabel.font = .systemFont(ofSize: 22, weight: .bold)
        monthLabel.textColor = .white
        monthLabel.textAlignment = .center
        monthLabel.translatesAutoresizingMaskIntoConstraints = false
        updateMonthLabel()
        let prevBtn = UIButton()
        prevBtn.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        prevBtn.tintColor = .white
        prevBtn.addTarget(self, action: #selector(prevMonth), for: .touchUpInside)
        prevBtn.translatesAutoresizingMaskIntoConstraints = false
        
        let nextBtn = UIButton()
        nextBtn.setImage(UIImage(systemName: "chevron.right"), for: .normal)
        nextBtn.tintColor = .white
        nextBtn.addTarget(self, action: #selector(nextMonth), for: .touchUpInside)
        nextBtn.translatesAutoresizingMaskIntoConstraints = false
        let closeBtn = UIButton()
        closeBtn.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeBtn.tintColor = .white.withAlphaComponent(0.5)
        closeBtn.addTarget(self, action: #selector(dismissModal), for: .touchUpInside)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        let weekdaysStack = UIStackView()
        weekdaysStack.axis = .horizontal
        weekdaysStack.distribution = .fillEqually
        weekdaysStack.translatesAutoresizingMaskIntoConstraints = false
        
        let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        for day in days {
            let lbl = UILabel()
            lbl.text = day
            lbl.font = .systemFont(ofSize: 13, weight: .semibold)
            lbl.textColor = .gray
            lbl.textAlignment = .center
            weekdaysStack.addArrangedSubview(lbl)
        }

        let layout = UICollectionViewFlowLayout()
        let itemWidth = (340 - 20) / 7
        layout.itemSize = CGSize(width: itemWidth, height: 65)
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(CalendarDayCell.self, forCellWithReuseIdentifier: "GridCell")
        collectionView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(monthLabel)
        container.addSubview(prevBtn)
        container.addSubview(nextBtn)
        container.addSubview(closeBtn)
        container.addSubview(weekdaysStack)
        container.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            container.widthAnchor.constraint(equalToConstant: 340),
            container.heightAnchor.constraint(equalToConstant: 550),

            monthLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 25),
            monthLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            
            prevBtn.centerYAnchor.constraint(equalTo: monthLabel.centerYAnchor),
            prevBtn.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 25),
            
            nextBtn.centerYAnchor.constraint(equalTo: monthLabel.centerYAnchor),
            nextBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -60),
            
            closeBtn.centerYAnchor.constraint(equalTo: monthLabel.centerYAnchor),
            closeBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -15),

            weekdaysStack.topAnchor.constraint(equalTo: monthLabel.bottomAnchor, constant: 25),
            weekdaysStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            weekdaysStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            weekdaysStack.heightAnchor.constraint(equalToConstant: 20),

            collectionView.topAnchor.constraint(equalTo: weekdaysStack.bottomAnchor, constant: 10),
            collectionView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            collectionView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            collectionView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20)
        ])
    }

    @objc func prevMonth() {
        currentMonthDate = istCalendar.date(byAdding: .month, value: -1, to: currentMonthDate) ?? Date()
        updateMonthLabel()
        collectionView.reloadData()
    }

    @objc func nextMonth() {
        currentMonthDate = istCalendar.date(byAdding: .month, value: 1, to: currentMonthDate) ?? Date()
        updateMonthLabel()
        collectionView.reloadData()
    }
    
    func updateMonthLabel() {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        monthLabel.text = formatter.string(from: currentMonthDate)
    }
    
    @objc func dismissModal() { dismiss(animated: true) }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return daysInMonth(date: currentMonthDate) + firstWeekday(date: currentMonthDate) - 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GridCell", for: indexPath) as! CalendarDayCell
        
        let firstDayIndex = firstWeekday(date: currentMonthDate) - 1
        
        if indexPath.item < firstDayIndex {
            cell.isHidden = true
        } else {
            cell.isHidden = false
            let day = indexPath.item - firstDayIndex + 1
            var istCal = Calendar.current
            istCal.timeZone = Self.istTimeZone
            if let date = istCal.date(byAdding: .day, value: day - 1, to: startOfMonth(date: currentMonthDate)) {
                let isToday = istCal.isDateInToday(date)
                let dateKey = dateKeyFormatter.string(from: date)
                let targetMet = activeDateStrings.contains(dateKey)
                cell.configure(date: date, isToday: isToday, targetMet: targetMet)
                // dateLabel is handled inside configure(), dayLabel is overridden here
                // to show just the numeric day for the grid calendar view
                let numFmt = DateFormatter()
                numFmt.dateFormat = "d"
                numFmt.timeZone = Self.istTimeZone
                cell.dayLabel.text = istCal.component(.weekday, from: date).weekdayAbbr
                cell.dateLabel.text = numFmt.string(from: date)
            }
        }
        return cell
    }
    
    private var istCalendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = Self.istTimeZone
        return cal
    }

    func daysInMonth(date: Date) -> Int {
        return istCalendar.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    func firstWeekday(date: Date) -> Int {
        let components = istCalendar.dateComponents([.year, .month], from: date)
        let som = istCalendar.date(from: components)!
        return istCalendar.component(.weekday, from: som)
    }

    func startOfMonth(date: Date) -> Date {
        let components = istCalendar.dateComponents([.year, .month], from: date)
        return istCalendar.date(from: components)!
    }
}

private extension Int {
    /// Converts Calendar.weekday (1=Sun … 7=Sat) to short abbreviation
    var weekdayAbbr: String {
        switch self {
        case 1: return "SUN"
        case 2: return "MON"
        case 3: return "TUE"
        case 4: return "WED"
        case 5: return "THU"
        case 6: return "FRI"
        case 7: return "SAT"
        default: return ""
        }
    }
}
