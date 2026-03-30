import UIKit
import AVFoundation

class TrackSelectionViewController: UIViewController {

    // MARK: — Storyboard outlets (video, portal, nav buttons, start)
    @IBOutlet weak var trackTitleName: UILabel!
    @IBOutlet weak var portalBaseView: UIImageView!
    @IBOutlet weak var videoContainerView: UIView!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var profileButton: UIButton!
    @IBOutlet weak var prevTrackTapped: UIButton!
    @IBOutlet weak var nextTrackTapped: UIButton!
    @IBOutlet weak var startButton: UIButton!

    // MARK: — AV
    var player: AVPlayer?
    var playerLayer: AVPlayerLayer?

    // MARK: — Track model (duration/calories strings removed — computed from goal)
    struct Track {
        let title: String
        let videoName: String
    }

    let tracks: [Track] = [
        Track(title: "Earth's Twin",  videoName: "planet_green"),
        Track(title: "Mars Colony",   videoName: "mars_colony"),
        Track(title: "Destroyer",     videoName: "destroyer_planet")
    ]
    var currentIndex = 0

    // MARK: — Distance / Calories goal
    /// Realistic kcal per km for a moderate jog (~70 kg person)
    private static let calPerKm: Double = 70
    private static let minKm:    Double = 0.1   // 100 m floor
    private static let maxKm:    Double = 42.2  // marathon cap
    private static let stepKm:   Double = 0.1   // 100 m per arrow tap

    /// Single source of truth — setting clamps, syncs calories, refreshes UI.
    private var distanceKm: Double = 0.1 {
        didSet {
            distanceKm = max(Self.minKm, min(Self.maxKm, distanceKm))
            distanceKm = (distanceKm * 10).rounded() / 10  // snap to 0.1 km grid
            minCalories = Int((distanceKm * Self.calPerKm).rounded())
            refreshGoalFields()
        }
    }
    /// Slave — always in sync with distanceKm via the ratio. Do not set directly.
    private var minCalories: Int = 7

    // Goal controls built entirely in code
    private let distField = UITextField()
    private let calField  = UITextField()

    // Flag so the ellipse scan only runs once after layout is real
    private var navEllipsesHidden = false

    // MARK: — Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Snapshot storyboard subviews BEFORE we add our programmatic controls.
        // Used in hideStoryboardGoalBox() to identify the original container.
        let storyboardSubviews = Set(view.subviews)

        styleNavArea()
        setupTrackDesign()
        setupPortalAnimation()
        buildGoalControls()
        updateTrackUI()
        fixStoryboardLabels()
        hideStoryboardGoalBox(excluding: storyboardSubviews)

        // MARK: Single-map mode — hide prev/next until map 2 ships.
        // To re-enable: delete these two lines. No storyboard changes needed.
        prevTrackTapped.isHidden = true
        nextTrackTapped.isHidden = true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        startButton.layer.cornerRadius   = startButton.frame.height / 2
        profileButton.layer.cornerRadius = profileButton.frame.height / 2
        profileButton.clipsToBounds      = true
        backButton.layer.cornerRadius    = backButton.frame.height / 2
        backButton.clipsToBounds         = true
        hideNavArrowEllipses()
    }

    /// Hides only the small Ellipse droplet UIImageViews at the left/right edges.
    /// Key guard: droplets are narrow (<30 % of screen width); the background image
    /// spans the full width and is therefore never touched.
    private func hideNavArrowEllipses() {
        guard !navEllipsesHidden, view.bounds.width > 0 else { return }
        navEllipsesHidden = true

        let maxDropletWidth = view.bounds.width * 0.30   // droplets are small pill shapes

        func scan(_ root: UIView) {
            for sub in root.subviews {
                if let img = sub as? UIImageView, img !== portalBaseView {
                    // Never touch image views that live inside a UIButton (e.g. back button chevron)
                    let insideButton = sequence(first: img.superview, next: { $0?.superview })
                        .compactMap { $0 }
                        .contains { $0 is UIButton }
                    guard !insideButton else { scan(sub); continue }

                    let f = view.convert(img.bounds, from: img)
                    let isNarrow    = f.width < maxDropletWidth
                    let onLeftEdge  = f.minX < 80
                    let onRightEdge = f.maxX > view.bounds.width - 80
                    if isNarrow && (onLeftEdge || onRightEdge) { img.isHidden = true }
                }
                scan(sub)
            }
        }
        scan(view)
    }

    // MARK: — Nav styling  (matches Statistics page exactly)
    private func styleNavArea() {
        let cfg = UIImage.SymbolConfiguration(weight: .bold)
        backButton.setTitle("", for: .normal)
        backButton.setImage(UIImage(systemName: "chevron.left", withConfiguration: cfg), for: .normal)
        backButton.tintColor         = .white
        backButton.backgroundColor   = UIColor.white.withAlphaComponent(0.1)
        backButton.layer.borderWidth = 1
        backButton.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor

        profileButton.backgroundColor   = UIColor.white.withAlphaComponent(0.1)
        profileButton.layer.borderWidth = 1
        profileButton.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor

        // Hide the storyboard "Track Selection" label — we'll add our own, properly positioned
        allLabels(in: view).forEach { lbl in
            if lbl !== trackTitleName, lbl.text == "Track Selection" { lbl.isHidden = true }
        }

        // Our title: anchored to safeAreaLayoutGuide so it sits correctly on all devices
        let titleLbl = UILabel()
        titleLbl.text          = "Track Selection"
        titleLbl.font          = .systemFont(ofSize: 20, weight: .bold)
        titleLbl.textColor     = .white
        titleLbl.textAlignment = .center
        titleLbl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLbl)
        NSLayoutConstraint.activate([
            titleLbl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLbl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12)
        ])
    }

    // MARK: — Track visual design
    private func setupTrackDesign() {
        videoContainerView.layer.cornerRadius  = 20
        videoContainerView.clipsToBounds       = false
        videoContainerView.layer.shadowColor   = UIColor(red: 0.7, green: 0.3, blue: 1, alpha: 1).cgColor
        videoContainerView.layer.shadowOpacity = 0.7
        videoContainerView.layer.shadowOffset  = .zero
        videoContainerView.layer.shadowRadius  = 30

        portalBaseView.transform              = CGAffineTransform(scaleX: 6, y: 4)
        portalBaseView.contentMode            = .scaleAspectFit
        portalBaseView.isUserInteractionEnabled = false

        // Audiowide 24pt — slightly smaller than original to feel balanced
        trackTitleName.font = UIFont(name: "Audiowide-Regular", size: 24) ?? .boldSystemFont(ofSize: 24)

        startButton.backgroundColor       = UIColor(red: 0.63, green: 0.31, blue: 0.94, alpha: 0.6)
        startButton.layer.shadowColor     = UIColor(red: 0.8, green: 0.5, blue: 1, alpha: 1).cgColor
        startButton.layer.shadowOpacity   = 0.8
        startButton.layer.shadowRadius    = 20
        startButton.layer.shadowOffset    = .zero
        startButton.layer.borderWidth     = 1.5
        startButton.layer.borderColor     = UIColor(red: 0.9, green: 0.8, blue: 1, alpha: 0.4).cgColor
        startButton.setTitleColor(UIColor(red: 1, green: 0.9, blue: 0.8, alpha: 1), for: .normal)
        startButton.titleLabel?.font      = UIFont(name: "Audiowide-Regular", size: 22) ?? .boldSystemFont(ofSize: 22)
    }

    private func setupPortalAnimation() {
        var frames: [UIImage] = []
        for i in 1...60 {
            if let img = UIImage(named: String(format: "portal_anim%04d", i)) { frames.append(img) }
        }
        guard !frames.isEmpty else { return }
        portalBaseView.animationImages   = frames
        portalBaseView.animationDuration = 5
        portalBaseView.startAnimating()
    }

    // MARK: — Goal controls row (Distance + Calories), built in code
    private func buildGoalControls() {
        // Shared "Done" toolbar for the decimal pad keyboard
        let toolbar = UIToolbar(); toolbar.sizeToFit()
        let doneItem = UIBarButtonItem(barButtonSystemItem: .done,
                                       target: self, action: #selector(dismissKeyboard))
        toolbar.items = [UIBarButtonItem(barButtonSystemItem: .flexibleSpace,
                                          target: nil, action: nil), doneItem]

        distField.inputAccessoryView = toolbar
        calField.inputAccessoryView  = toolbar

        let distCol = makeGoalColumn(title: "Distance",       field: distField, isDistance: true)
        let calCol  = makeGoalColumn(title: "Min. Calories",  field: calField,  isDistance: false)

        let row = UIStackView(arrangedSubviews: [distCol, calCol])
        row.axis         = .horizontal
        row.distribution = .fillEqually
        row.spacing      = 14
        row.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(row)
        view.bringSubviewToFront(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            row.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            row.bottomAnchor.constraint(equalTo: startButton.topAnchor, constant: -18),
            row.heightAnchor.constraint(equalToConstant: 54)   // pill-only height, no label row
        ])

        // Dismiss keyboard when tapping anywhere outside
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        refreshGoalFields()
    }

    /// One column: glass-pill stepper (no extra label — storyboard labels handle the titles).
    private func makeGoalColumn(title: String, field: UITextField, isDistance: Bool) -> UIView {
        let col = UIView()
        col.translatesAutoresizingMaskIntoConstraints = false

        // Glass pill — fills the entire column
        let pill = makeGlassPill()
        col.addSubview(pill)

        // Separate up / down buttons (tag: 10=dist▲ 11=dist▼ 20=cal▲ 21=cal▼)
        let upBtn   = makePillArrow(sf: "chevron.up",   tag: isDistance ? 10 : 20)
        let downBtn = makePillArrow(sf: "chevron.down", tag: isDistance ? 11 : 21)

        // Text field
        field.keyboardType    = .decimalPad
        field.textAlignment   = .center
        field.textColor       = .white
        field.font            = .systemFont(ofSize: 16, weight: .bold)
        field.backgroundColor = .clear
        field.tintColor       = .neonPink
        field.translatesAutoresizingMaskIntoConstraints = false
        field.addTarget(self, action: #selector(goalFieldBegan(_:)), for: .editingDidBegin)
        field.addTarget(self, action: #selector(goalFieldEnded(_:)), for: .editingDidEnd)

        // Pill interior: [▼] [field] [▲]
        let pillRow = UIStackView(arrangedSubviews: [downBtn, field, upBtn])
        pillRow.axis      = .horizontal
        pillRow.alignment = .center
        pillRow.spacing   = 0
        pillRow.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(pillRow)

        NSLayoutConstraint.activate([
            pill.topAnchor.constraint(equalTo: col.topAnchor),
            pill.leadingAnchor.constraint(equalTo: col.leadingAnchor),
            pill.trailingAnchor.constraint(equalTo: col.trailingAnchor),
            pill.bottomAnchor.constraint(equalTo: col.bottomAnchor),

            pillRow.topAnchor.constraint(equalTo: pill.topAnchor),
            pillRow.bottomAnchor.constraint(equalTo: pill.bottomAnchor),
            pillRow.leadingAnchor.constraint(equalTo: pill.leadingAnchor),
            pillRow.trailingAnchor.constraint(equalTo: pill.trailingAnchor),

            downBtn.widthAnchor.constraint(equalToConstant: 44),
            upBtn.widthAnchor.constraint(equalToConstant: 44)
        ])
        return col
    }

    private func makeGlassPill() -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 14
        v.layer.cornerCurve  = .continuous
        v.clipsToBounds      = true
        v.layer.borderWidth  = 1
        v.layer.borderColor  = UIColor.white.withAlphaComponent(0.18).cgColor

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.isUserInteractionEnabled = false
        blur.translatesAutoresizingMaskIntoConstraints = false
        v.insertSubview(blur, at: 0)
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: v.topAnchor),
            blur.bottomAnchor.constraint(equalTo: v.bottomAnchor),
            blur.leadingAnchor.constraint(equalTo: v.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: v.trailingAnchor)
        ])
        return v
    }

    private func makePillArrow(sf: String, tag: Int) -> UIButton {
        let btn = UIButton(type: .system)
        btn.tag = tag
        let cfg = UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
        btn.setImage(UIImage(systemName: sf, withConfiguration: cfg), for: .normal)
        btn.tintColor = UIColor.white.withAlphaComponent(0.7)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(arrowTapped(_:)),    for: .touchUpInside)
        btn.addTarget(self, action: #selector(arrowPressed(_:)),   for: .touchDown)
        btn.addTarget(self, action: #selector(arrowReleased(_:)),  for: [.touchUpInside, .touchUpOutside, .touchCancel])
        return btn
    }

    // MARK: — Arrow tap handlers
    @objc private func arrowTapped(_ sender: UIButton) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        view.endEditing(true)
        switch sender.tag {
        case 10, 20: distanceKm += Self.stepKm   // ▲ (both distance and cal arrows move same step)
        case 11, 21: distanceKm -= Self.stepKm   // ▼
        default: break
        }
    }

    @objc private func arrowPressed(_ sender: UIButton) {
        UIView.animate(withDuration: 0.08) { sender.alpha = 0.3 }
    }
    @objc private func arrowReleased(_ sender: UIButton) {
        UIView.animate(withDuration: 0.15) { sender.alpha = 1 }
    }

    // MARK: — Text field handlers
    @objc private func goalFieldBegan(_ sender: UITextField) {
        // Strip unit suffix so user edits a clean number
        if sender === distField {
            sender.text = String(format: "%.1f", distanceKm)
        } else {
            sender.text = "\(minCalories)"
        }
    }

    @objc private func goalFieldEnded(_ sender: UITextField) {
        let raw = sender.text ?? ""
        if sender === distField {
            if let v = Double(raw) { distanceKm = v }   // didSet clamps + syncs
        } else {
            if let cal = Double(raw) {
                distanceKm = cal / Self.calPerKm         // back-calculate; didSet clamps + syncs
            }
        }
        refreshGoalFields()
    }

    @objc private func dismissKeyboard() { view.endEditing(true) }

    private func refreshGoalFields() {
        distField.text = String(format: "%.1f km", distanceKm)
        calField.text  = "\(minCalories) kcal"
    }

    // MARK: — Storyboard junk cleanup

    /// Hides the storyboard UIView container that held the original Duration/Calories controls.
    /// We pass the pre-programmatic snapshot so we only look at storyboard-era subviews.
    /// Only plain UIView containers are hidden — UILabel, UIButton, UIImageView are left alone.
    private func hideStoryboardGoalBox(excluding storyboardSubviews: Set<UIView>) {
        let knownOutlets: Set<UIView> = [
            trackTitleName, portalBaseView, videoContainerView,
            backButton, profileButton, prevTrackTapped, nextTrackTapped, startButton
        ]
        for sub in storyboardSubviews {
            guard !knownOutlets.contains(sub) else { continue }
            // Hide any plain UIView or UIStackView — these are storyboard containers we no
            // longer need. Labels, buttons, and image views are excluded so content stays.
            if type(of: sub) == UIView.self || sub is UIStackView {
                sub.isHidden = true
            }
        }
    }

    /// Renames the storyboard "Duration" label to "Distance" and hides "Minimum Calories".
    private func fixStoryboardLabels() {
        allLabels(in: view).forEach { lbl in
            guard lbl !== trackTitleName else { return }
            switch lbl.text {
            case "Duration":          lbl.text = "Distance"
            case "Minimum Calories":  break   // keep — it's still accurate
            default:                  break
            }
        }
    }

    /// Recursively collects every UILabel in the view hierarchy.
    private func allLabels(in root: UIView) -> [UILabel] {
        var result: [UILabel] = []
        for sub in root.subviews {
            if let lbl = sub as? UILabel { result.append(lbl) }
            result += allLabels(in: sub)
        }
        return result
    }

    // MARK: — Track UI
    func updateTrackUI() {
        trackTitleName.text = tracks[currentIndex].title
        playVideo(named: tracks[currentIndex].videoName)
    }

    func playVideo(named videoName: String) {
        guard let path = Bundle.main.path(forResource: videoName, ofType: "mp4") else { return }
        player?.pause()
        playerLayer?.removeFromSuperlayer()
        player = AVPlayer(url: URL(fileURLWithPath: path))
        playerLayer = AVPlayerLayer(player: player)
        videoContainerView.layoutIfNeeded()
        playerLayer?.frame         = videoContainerView.bounds
        playerLayer?.videoGravity  = .resizeAspectFill
        playerLayer?.cornerRadius  = 20
        playerLayer?.masksToBounds = true
        videoContainerView.layer.addSublayer(playerLayer!)
        player?.play()
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem, queue: .main
        ) { [weak self] _ in self?.player?.seek(to: .zero); self?.player?.play() }
    }

    // MARK: — IBActions
    @IBAction func prevTrackAction(_ sender: UIButton) {
        if currentIndex > 0 { currentIndex -= 1; updateTrackUI() }
    }
    @IBAction func nextTrackAction(_ sender: UIButton) {
        if currentIndex < tracks.count - 1 { currentIndex += 1; updateTrackUI() }
    }
    @IBAction func backButtonTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }
    @IBAction func profileButtonTapped(_ sender: UIButton) {
        let vc = UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(withIdentifier: "ProfileViewController")
        vc.modalPresentationStyle = .fullScreen
        vc.modalTransitionStyle   = .coverVertical
        present(vc, animated: true)
    }
    @IBAction func startButtonTapped(_ sender: UIButton) {
        view.endEditing(true)

        // Bounce animation
        UIView.animate(withDuration: 0.1, animations: {
            sender.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.5,
                           initialSpringVelocity: 0.5, options: [], animations: {
                sender.transform = .identity
            }) { [weak self] _ in
                guard let self = self else { return }
                let trackIds     = ["track_001", "track_002", "track_003"]
                let displayNames = ["Earth's Twin", "Mars Colony", "Destroyer"]
                DifficultySettings.shared.setSelectedTrack(
                    id: trackIds[self.currentIndex],
                    displayName: displayNames[self.currentIndex]
                )
                DifficultySettings.shared.setDistanceTarget(km: self.distanceKm)

                let diffVC = DifficultySelectionViewController()
                let nav    = UINavigationController(rootViewController: diffVC)
                nav.setNavigationBarHidden(true, animated: false)
                nav.modalPresentationStyle = .fullScreen
                diffVC.onDifficultySelected = { [weak nav] in
                    nav?.pushViewController(CameraViewController(), animated: true)
                }
                self.present(nav, animated: true)
            }
        }
    }
}
