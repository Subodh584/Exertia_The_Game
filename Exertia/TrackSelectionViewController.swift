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
    /// Passed from HomeViewController if preloading succeeded
    var preloadedPlayer: AVPlayer?

    // MARK: — Track model (duration/calories strings removed — computed from goal)
    struct Track {
        let title: String
        let videoName: String
    }

    let tracks: [Track] = [
        Track(title: "Nova-Station",  videoName: "Nova-Station"),
    ]
    var currentIndex = 0

    // MARK: — Distance / Calories goal
    /// Goal conversion used by the UI: 0.1 km = 10 kcal
    private static let calPerKm: Double = 100
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
    private var minCalories: Int = 10

    // Goal controls built entirely in code
    private let distBtn = UIButton(type: .system)
    private let calBtn = UIButton(type: .system)
    private let distEditBtn = UIButton(type: .system)
    private let calEditBtn = UIButton(type: .system)
    private let distTextField = UITextField()
    private let calTextField = UITextField()
    private let distancePicker = CleanPickerView()
    private let calPicker = CleanPickerView()
    private let pickerOverlay = UIButton(type: .custom)
    
    private var rowHeightConstraint: NSLayoutConstraint!
    private weak var beamView: UIImageView?
    private var skipCalibrationToggle = UISwitch()
    private let skipCalibrationLabel = UILabel()

    private var videoWidth: CGFloat {
        if Responsive.isIPad { return min(view.bounds.width * 0.62, 470) }
        if Responsive.isSmallPhone { return min(view.bounds.width * 0.70, 250) }
        return min(view.bounds.width * 0.72, 330)
    }

    private var videoHeight: CGFloat {
        if Responsive.isIPad { return 300 }
        if Responsive.isSmallPhone { return 188 }
        return 240
    }

    private var videoTopSpacing: CGFloat {
        if Responsive.isIPad { return 38 }
        if Responsive.isSmallPhone { return 34 }
        return 44
    }

    private var portalWidth: CGFloat {
        if Responsive.isIPad { return 360 }
        if Responsive.isSmallPhone { return 228 }
        return 290
    }

    private var portalHeight: CGFloat {
        if Responsive.isIPad { return 210 }
        if Responsive.isSmallPhone { return 145 }
        return 180
    }

    private var portalTopSpacing: CGFloat {
        if Responsive.isIPad { return 112 }
        if Responsive.isSmallPhone { return 54 }
        return 80
    }

    private var portalScaleX: CGFloat {
        if Responsive.isIPad { return 8.4 }
        if Responsive.isSmallPhone { return 4.2 }
        return 5.4
    }

    private var portalScaleY: CGFloat {
        if Responsive.isIPad { return 5.2 }
        if Responsive.isSmallPhone { return 2.8 }
        return 3.5
    }

    private var portalVerticalOffset: CGFloat {
        if Responsive.isIPad { return 4 }
        if Responsive.isSmallPhone { return -18 }
        return -45
    }

    // Flag so the ellipse scan only runs once after layout is real
    private var navEllipsesHidden = false

    // MARK: — Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        AudioManager.shared.stopMusic()

        // Snapshot storyboard subviews BEFORE we add our programmatic controls.
        // Used in hideStoryboardGoalBox() to identify the original container.
        let storyboardSubviews = Set(view.subviews)

        styleNavArea()
        adjustStartButtonAlignment()
        configureResponsiveHeroLayout()
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

        // Default skip calibration: OFF for first-time users, ON if they've played before
        configureSkipCalibrationDefault()
    }

    private func configureSkipCalibrationDefault() {
        guard let userId = UserDefaults.standard.string(forKey: "supabaseUserID") else { return }
        Task {
            do {
                let hasPlayed = try await SupabaseManager.shared.hasCompletedAnySession(userId: userId)
                DispatchQueue.main.async {
                    self.skipCalibrationToggle.isOn = hasPlayed
                }
            } catch {
                print("⚠️ Could not check session history for skip calibration default: \(error)")
            }
        }
    }

    private func adjustStartButtonAlignment() {
        guard let parent = startButton.superview else { return }
        
        // Remove old storyboard constraints for startButton
        let oldConstraints = parent.constraints.filter {
            $0.firstItem === startButton || $0.secondItem === startButton
        }
        NSLayoutConstraint.deactivate(oldConstraints)
        
        // Apply fresh, native iOS constraints (floating above safe area)
        startButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            startButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -35),
            startButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startButton.widthAnchor.constraint(equalToConstant: Responsive.isIPad ? 280 : (Responsive.isSmallPhone ? 170 : Responsive.size(240))),
            startButton.heightAnchor.constraint(equalToConstant: Responsive.isSmallPhone ? 52 : Responsive.size(58))
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AudioManager.shared.stopMusic()
        AudioManager.shared.applyMutedState(to: player)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        startButton.layer.cornerRadius   = startButton.frame.height / 2
        profileButton.layer.cornerRadius = profileButton.frame.height / 2
        profileButton.clipsToBounds      = true
        backButton.layer.cornerRadius    = backButton.frame.height / 2
        backButton.clipsToBounds         = true
        alignBeam()
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
        titleLbl.font          = .systemFont(ofSize: Responsive.font(20), weight: .bold)
        titleLbl.textColor     = .white
        titleLbl.textAlignment = .center
        titleLbl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLbl)
        NSLayoutConstraint.activate([
            titleLbl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLbl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Responsive.isIPad ? 16 : 12)
        ])
    }

    private func configureResponsiveHeroLayout() {
        if let titleTopConstraint = view.constraints.first(where: {
            ($0.firstItem as? UILabel) === trackTitleName && ($0.secondItem as? UILayoutGuide) === view.safeAreaLayoutGuide && $0.firstAttribute == .top && $0.secondAttribute == .top
        }) {
            titleTopConstraint.constant = Responsive.isIPad ? 70 : (Responsive.isSmallPhone ? 52 : 60)
        }

        if let videoWidthConstraint = videoContainerView.constraints.first(where: { $0.firstAttribute == .width }) {
            videoWidthConstraint.constant = videoWidth
        }
        if let videoHeightConstraint = videoContainerView.constraints.first(where: { $0.firstAttribute == .height }) {
            videoHeightConstraint.constant = videoHeight
        }
        if let videoTopConstraint = view.constraints.first(where: {
            ($0.firstItem as? UIView) === videoContainerView && ($0.secondItem as? UILabel) === trackTitleName && $0.firstAttribute == .top && $0.secondAttribute == .bottom
        }) {
            videoTopConstraint.constant = videoTopSpacing
        }

        if let portalWidthConstraint = portalBaseView.constraints.first(where: { $0.firstAttribute == .width }) {
            portalWidthConstraint.constant = portalWidth
        }
        if let portalHeightConstraint = portalBaseView.constraints.first(where: { $0.firstAttribute == .height }) {
            portalHeightConstraint.constant = portalHeight
        }
        if let portalTopConstraint = view.constraints.first(where: {
            ($0.firstItem as? UIImageView) === portalBaseView && ($0.secondItem as? UIView) === videoContainerView && $0.firstAttribute == .top && $0.secondAttribute == .bottom
        }) {
            portalTopConstraint.constant = portalTopSpacing
        }

        trackTitleName.font = UIFont(name: "Audiowide-Regular", size: Responsive.isIPad ? 30 : (Responsive.isSmallPhone ? 18 : Responsive.font(24))) ?? .boldSystemFont(ofSize: Responsive.isIPad ? 30 : (Responsive.isSmallPhone ? 18 : Responsive.font(24)))
    }

    // MARK: — Track visual design
    private func setupTrackDesign() {
        videoContainerView.layer.cornerRadius  = 20
        videoContainerView.clipsToBounds       = false
        videoContainerView.layer.shadowColor   = UIColor(red: 0.7, green: 0.3, blue: 1, alpha: 1).cgColor
        videoContainerView.layer.shadowOpacity = 0.7
        videoContainerView.layer.shadowOffset  = .zero
        videoContainerView.layer.shadowRadius  = 30

        // Shift the portal upwards to avoid overlapping the new, higher button positions
        portalBaseView.transform              = CGAffineTransform(translationX: 0, y: portalVerticalOffset).scaledBy(x: portalScaleX, y: portalScaleY)
        portalBaseView.contentMode            = .scaleAspectFit
        portalBaseView.isUserInteractionEnabled = false

        // Audiowide 24pt — slightly smaller than original to feel balanced
        trackTitleName.font = UIFont(name: "Audiowide-Regular", size: Responsive.isIPad ? 30 : (Responsive.isSmallPhone ? 18 : Responsive.font(24))) ?? .boldSystemFont(ofSize: Responsive.isIPad ? 30 : (Responsive.isSmallPhone ? 18 : Responsive.font(24)))

        startButton.backgroundColor       = UIColor(red: 0.63, green: 0.31, blue: 0.94, alpha: 0.6)
        startButton.layer.shadowColor     = UIColor(red: 0.8, green: 0.5, blue: 1, alpha: 1).cgColor
        startButton.layer.shadowOpacity   = 0.8
        startButton.layer.shadowRadius    = 20
        startButton.layer.shadowOffset    = .zero
        startButton.layer.borderWidth     = 1.5
        startButton.layer.borderColor     = UIColor(red: 0.9, green: 0.8, blue: 1, alpha: 0.4).cgColor
        startButton.setTitleColor(UIColor(red: 1, green: 0.9, blue: 0.8, alpha: 1), for: .normal)
        startButton.titleLabel?.font      = UIFont(name: "Audiowide-Regular", size: Responsive.font(22)) ?? .boldSystemFont(ofSize: Responsive.font(22))
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

    private func alignBeam() {
        guard let beamView = beamView ?? findBeamView() else { return }
        self.beamView = beamView

        beamView.center.x = videoContainerView.center.x
        beamView.layer.zPosition = 1
        portalBaseView.layer.zPosition = 0
        videoContainerView.layer.zPosition = 2

        view.bringSubviewToFront(portalBaseView)
        view.bringSubviewToFront(beamView)
        view.bringSubviewToFront(backButton)
        view.bringSubviewToFront(profileButton)
        view.bringSubviewToFront(startButton)
    }

    private func findBeamView() -> UIImageView? {
        allImageViews(in: view).first { imageView in
            imageView !== portalBaseView &&
            imageView.bounds.width > 120 &&
            abs(imageView.center.x - videoContainerView.center.x) < 40 &&
            imageView.frame.minY >= videoContainerView.frame.maxY - 20 &&
            imageView.frame.maxY <= portalBaseView.frame.maxY + 20
        }
    }

    private func allImageViews(in root: UIView) -> [UIImageView] {
        var results: [UIImageView] = []
        for subview in root.subviews {
            if let imageView = subview as? UIImageView {
                results.append(imageView)
            }
            results.append(contentsOf: allImageViews(in: subview))
        }
        return results
    }

    // MARK: — Goal controls row (Distance + Calories), built in code
    private func buildGoalControls() {
        distancePicker.dataSource = self
        distancePicker.delegate = self
        calPicker.dataSource = self
        calPicker.delegate = self

        distBtn.addTarget(self, action: #selector(goalButtonTapped(_:)), for: .touchUpInside)
        calBtn.addTarget(self, action: #selector(goalButtonTapped(_:)), for: .touchUpInside)
        distEditBtn.addTarget(self, action: #selector(goalEditTapped(_:)), for: .touchUpInside)
        calEditBtn.addTarget(self, action: #selector(goalEditTapped(_:)), for: .touchUpInside)

        let distCol = makeGoalColumn(btn: distBtn, editBtn: distEditBtn, picker: distancePicker, textField: distTextField, isDistance: true)
        let calCol  = makeGoalColumn(btn: calBtn, editBtn: calEditBtn, picker: calPicker, textField: calTextField, isDistance: false)

        let row = UIStackView(arrangedSubviews: [distCol, calCol])
        row.axis         = .horizontal
        row.distribution = .fillEqually
        row.spacing      = 14
        row.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(row)
        view.bringSubviewToFront(row)

        rowHeightConstraint = row.heightAnchor.constraint(equalToConstant: Responsive.size(54))

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Responsive.contentInset),
            row.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Responsive.contentInset),
            row.bottomAnchor.constraint(equalTo: startButton.topAnchor, constant: Responsive.isSmallPhone ? -18 : -24),
            rowHeightConstraint
        ])
        
        // Skip calibration row — between goal controls and start button
        let skipRow = UIView()
        skipRow.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(skipRow)
        view.bringSubviewToFront(skipRow)

        skipCalibrationLabel.text = "Skip Calibration"
        skipCalibrationLabel.font = UIFont(name: "Audiowide-Regular", size: Responsive.font(12))
            ?? .systemFont(ofSize: Responsive.font(12), weight: .semibold)
        skipCalibrationLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        skipCalibrationLabel.translatesAutoresizingMaskIntoConstraints = false

        skipCalibrationToggle.isOn = false
        skipCalibrationToggle.onTintColor = UIColor(red: 0.63, green: 0.31, blue: 0.94, alpha: 1.0)
        skipCalibrationToggle.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        skipCalibrationToggle.translatesAutoresizingMaskIntoConstraints = false

        skipRow.addSubview(skipCalibrationLabel)
        skipRow.addSubview(skipCalibrationToggle)

        NSLayoutConstraint.activate([
            skipRow.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            skipRow.bottomAnchor.constraint(equalTo: row.topAnchor, constant: Responsive.isSmallPhone ? -10 : -14),
            skipRow.heightAnchor.constraint(equalToConstant: 30),

            skipCalibrationLabel.leadingAnchor.constraint(equalTo: skipRow.leadingAnchor),
            skipCalibrationLabel.centerYAnchor.constraint(equalTo: skipRow.centerYAnchor),

            skipCalibrationToggle.leadingAnchor.constraint(equalTo: skipCalibrationLabel.trailingAnchor, constant: 10),
            skipCalibrationToggle.centerYAnchor.constraint(equalTo: skipRow.centerYAnchor),
            skipCalibrationToggle.trailingAnchor.constraint(equalTo: skipRow.trailingAnchor),
        ])

        // Picker overlay button over the WHOLE screen to catch outside taps gracefully
        pickerOverlay.frame = view.bounds
        pickerOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        pickerOverlay.backgroundColor = UIColor(white: 0, alpha: 0.5)
        pickerOverlay.alpha = 0
        pickerOverlay.isHidden = true
        pickerOverlay.addTarget(self, action: #selector(dismissInlinePicker), for: .touchUpInside)
        view.insertSubview(pickerOverlay, belowSubview: row)

        refreshGoalFields()
    }

    /// One column: glass-pill picker combined layout
    private func makeGoalColumn(btn: UIButton, editBtn: UIButton, picker: UIPickerView, textField: UITextField, isDistance: Bool) -> UIView {
        let col = UIView()
        col.translatesAutoresizingMaskIntoConstraints = false

        // Glass pill — fills the entire column
        let pill = makeGlassPill()
        col.addSubview(pill)

        // Text button for closed state
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = .white
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
        btn.configuration = config
        btn.contentHorizontalAlignment = .leading
        btn.translatesAutoresizingMaskIntoConstraints = false

        let pencilConfig = UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)
        editBtn.setImage(UIImage(systemName: "pencil", withConfiguration: pencilConfig), for: .normal)
        editBtn.tintColor = UIColor.white.withAlphaComponent(0.9)
        editBtn.translatesAutoresizingMaskIntoConstraints = false

        // Inline text field (hidden by default, shown on pencil tap)
        textField.font = .systemFont(ofSize: 16, weight: .bold)
        textField.textColor = .white
        textField.keyboardType = .decimalPad
        textField.textAlignment = .left
        textField.backgroundColor = .clear
        textField.borderStyle = .none
        textField.tintColor = .neonPink
        textField.alpha = 0
        textField.isHidden = true
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.returnKeyType = .done
        textField.tag = isDistance ? 100 : 200
        textField.delegate = self

        // Add a toolbar with Done button for decimal pad
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 100, height: 44))
        toolbar.barStyle = .default
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(textFieldDoneTapped))
        toolbar.items = [flexSpace, doneItem]
        textField.inputAccessoryView = toolbar

        // Picker for open state
        picker.alpha = 0
        picker.isHidden = true
        picker.translatesAutoresizingMaskIntoConstraints = false

        // Pill interior
        pill.addSubview(btn)
        pill.addSubview(textField)
        pill.addSubview(editBtn)
        pill.addSubview(picker)

        NSLayoutConstraint.activate([
            pill.topAnchor.constraint(equalTo: col.topAnchor),
            pill.leadingAnchor.constraint(equalTo: col.leadingAnchor),
            pill.trailingAnchor.constraint(equalTo: col.trailingAnchor),
            pill.bottomAnchor.constraint(equalTo: col.bottomAnchor),

            btn.topAnchor.constraint(equalTo: pill.topAnchor),
            btn.bottomAnchor.constraint(equalTo: pill.bottomAnchor),
            btn.leadingAnchor.constraint(equalTo: pill.leadingAnchor),
            btn.trailingAnchor.constraint(equalTo: editBtn.leadingAnchor, constant: -4),

            textField.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 14),
            textField.trailingAnchor.constraint(equalTo: editBtn.leadingAnchor, constant: -4),
            textField.centerYAnchor.constraint(equalTo: pill.centerYAnchor),

            editBtn.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -12),
            editBtn.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            editBtn.widthAnchor.constraint(equalToConstant: 22),
            editBtn.heightAnchor.constraint(equalToConstant: 22),

            // Picker constrained strictly over the center
            picker.topAnchor.constraint(equalTo: pill.topAnchor),
            picker.bottomAnchor.constraint(equalTo: pill.bottomAnchor),
            picker.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 6),
            picker.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -6)
        ])
        return col
    }

    private func makeGlassPill() -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = Responsive.cornerRadius(14)
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

    // MARK: — Title Update Logic
    private func updateButtonTitles() {
        let font = UIFont.systemFont(ofSize: Responsive.font(16), weight: .bold)
        
        var distCfg = distBtn.configuration
        distCfg?.attributedTitle = AttributedString(String(format: "%.1f km", distanceKm), attributes: AttributeContainer([.font: font]))
        distBtn.configuration = distCfg
        
        var calCfg = calBtn.configuration
        let cal = Int((distanceKm * Self.calPerKm).rounded())
        calCfg?.attributedTitle = AttributedString("\(cal) kcal", attributes: AttributeContainer([.font: font]))
        calBtn.configuration = calCfg
    }

    private func refreshGoalFields() {
        // Find correct row from distanceKm: 0.1 -> 0, 42.2 -> 421
        let targetRow = Int(round((distanceKm - 0.1) * 10))
        let row = max(0, min(421, targetRow))
        
        if distancePicker.selectedRow(inComponent: 0) != row {
            distancePicker.selectRow(row, inComponent: 0, animated: true)
        }
        if calPicker.selectedRow(inComponent: 0) != row {
            calPicker.selectRow(row, inComponent: 0, animated: true)
        }
        
        updateButtonTitles()
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
        player?.pause()
        playerLayer?.removeFromSuperlayer()

        // Use preloaded player from HomeVC if available (instant start)
        if let ready = preloadedPlayer {
            preloadedPlayer = nil
            attachPlayer(ready)
            return
        }

        // Fallback: cold load (only if preload wasn't ready in time)
        guard let path = Bundle.main.path(forResource: videoName, ofType: "mp4") else {
            print("❌ Video not found: \(videoName).mp4")
            return
        }
        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        asset.loadValuesAsynchronously(forKeys: ["playable"]) { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                let item = AVPlayerItem(asset: asset)
                item.preferredForwardBufferDuration = 2.0
                let player = AVPlayer(playerItem: item)
                player.automaticallyWaitsToMinimizeStalling = false
                AudioManager.shared.applyMutedState(to: player)
                self.attachPlayer(player)
            }
        }
    }

    private func attachPlayer(_ player: AVPlayer) {
        self.player = player
        let layer = AVPlayerLayer(player: player)
        videoContainerView.layoutIfNeeded()
        layer.frame         = videoContainerView.bounds
        layer.videoGravity  = .resizeAspectFill
        layer.cornerRadius  = 20
        layer.masksToBounds = true
        videoContainerView.layer.addSublayer(layer)
        self.playerLayer = layer
        player.play()
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem, queue: .main
        ) { [weak self] _ in self?.player?.seek(to: .zero); self?.player?.play() }
    }

    // MARK: — IBActions
    @IBAction func prevTrackAction(_ sender: UIButton) {
        AudioManager.shared.playEffect(.buttonTapped)
        if currentIndex > 0 { currentIndex -= 1; updateTrackUI() }
    }
    @IBAction func nextTrackAction(_ sender: UIButton) {
        AudioManager.shared.playEffect(.buttonTapped)
        if currentIndex < tracks.count - 1 { currentIndex += 1; updateTrackUI() }
    }
    @IBAction func backButtonTapped(_ sender: UIButton) {
        AudioManager.shared.playEffect(.buttonTapped)
        dismiss(animated: true)
    }
    @IBAction func profileButtonTapped(_ sender: UIButton) {
        AudioManager.shared.playEffect(.buttonTapped)
        let vc = UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(withIdentifier: "ProfileViewController")
        vc.modalPresentationStyle = .fullScreen
        vc.modalTransitionStyle   = .coverVertical
        present(vc, animated: true)
    }
    @IBAction func startButtonTapped(_ sender: UIButton) {
        AudioManager.shared.playEffect(.gameStart)
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
                DifficultySettings.shared.setSelectedTrack(
                    id: "nova_station",
                    displayName: "Nova-Station"
                )
                DifficultySettings.shared.setDistanceTarget(km: self.distanceKm)

                // Default to Medium difficulty (only available mode)
                DifficultySettings.shared.setDifficulty(.medium)
                DifficultySettings.shared.setSkipDemo(self.skipCalibrationToggle.isOn)

                // Go directly to CameraViewController, skipping difficulty screen
                let cameraVC = CameraViewController()
                let nav = UINavigationController(rootViewController: cameraVC)
                nav.setNavigationBarHidden(true, animated: false)
                nav.modalPresentationStyle = .fullScreen
                self.present(nav, animated: true)
            }
        }
    }
}

// MARK: - UIPickerView DataSource & Delegate
extension TrackSelectionViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        // From 0.1 to 42.2 in 0.1 increments = 422 rows
        return 422
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let label = (view as? UILabel) ?? UILabel()
        label.textAlignment = .center
        label.backgroundColor = .clear
        
        // Maintain the bold style, using a slightly striking color for the scroll effect
        label.font = .systemFont(ofSize: Responsive.font(20), weight: .bold)
        label.textColor = UIColor(red: 0.8, green: 0.7, blue: 1, alpha: 1.0) 
        
        let km = Double(row + 1) * 0.1
        if pickerView === distancePicker {
            label.text = String(format: "%.1f", km) // We will just show numbers like original custom control
        } else {
            let cal = Int((km * Self.calPerKm).rounded())
            label.text = "\(cal)"
        }
        return label
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        AudioManager.shared.playEffect(.targetButton) // Provide haptic / sound on tick
        
        let newDist = Double(row + 1) * 0.1
        self.distanceKm = newDist // didSet already limits boundaries and updates the paired picker
    }
}

// MARK: - Tap Behaviors
extension TrackSelectionViewController {
    @objc private func goalButtonTapped(_ sender: UIButton) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        AudioManager.shared.playEffect(.buttonTapped)

        pickerOverlay.isHidden = false
        distancePicker.isHidden = false
        calPicker.isHidden = false
        
        self.rowHeightConstraint.constant = Responsive.size(110) // Expands exactly to reveal roughly 3 perfectly framed options natively cut off by the pill mask!
        
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2, options: .curveEaseInOut) {
            self.pickerOverlay.alpha = 1
            self.distancePicker.alpha = 1
            self.calPicker.alpha = 1
            self.distBtn.alpha = 0
            self.calBtn.alpha = 0
            self.view.layoutIfNeeded()
        }
    }

    @objc private func goalEditTapped(_ sender: UIButton) {
        AudioManager.shared.playEffect(.targetButton)
        dismissInlinePickerIfNeeded()

        let isDistance = (sender === distEditBtn)
        let tf = isDistance ? distTextField : calTextField
        let btn = isDistance ? distBtn : calBtn

        // Pre-fill with current value
        tf.text = isDistance
            ? String(format: "%.1f", distanceKm)
            : "\(minCalories)"

        // Swap: hide button, show text field
        tf.isHidden = false
        UIView.animate(withDuration: 0.2) {
            btn.alpha = 0
            tf.alpha = 1
        }
        tf.becomeFirstResponder()
        tf.selectAll(nil)
    }

    @objc private func textFieldDoneTapped() {
        if distTextField.isFirstResponder {
            commitTextField(distTextField)
        } else if calTextField.isFirstResponder {
            commitTextField(calTextField)
        }
    }

    private func commitTextField(_ tf: UITextField) {
        guard !tf.isHidden else { return }  // already committed
        tf.resignFirstResponder()
        let isDistance = (tf.tag == 100)
        let btn = isDistance ? distBtn : calBtn

        if let raw = tf.text?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            if isDistance, let km = Double(raw) {
                distanceKm = km
            } else if !isDistance, let cal = Double(raw) {
                distanceKm = cal / Self.calPerKm
            }
        }

        // Swap back: hide text field, show button
        UIView.animate(withDuration: 0.2) {
            tf.alpha = 0
            btn.alpha = 1
        } completion: { _ in
            tf.isHidden = true
        }
        refreshGoalFields()
    }

    private func dismissInlinePickerIfNeeded() {
        guard !pickerOverlay.isHidden else { return }
        pickerOverlay.alpha = 0
        distancePicker.alpha = 0
        calPicker.alpha = 0
        distBtn.alpha = 1
        calBtn.alpha = 1
        rowHeightConstraint.constant = Responsive.size(54)
        pickerOverlay.isHidden = true
        distancePicker.isHidden = true
        calPicker.isHidden = true
        view.layoutIfNeeded()
    }
    
    @objc private func dismissInlinePicker() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        
        self.rowHeightConstraint.constant = Responsive.size(54)

        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2, options: .curveEaseInOut, animations: {
            self.pickerOverlay.alpha = 0
            self.distancePicker.alpha = 0
            self.calPicker.alpha = 0
            self.distBtn.alpha = 1
            self.calBtn.alpha = 1
            self.view.layoutIfNeeded()
        }) { _ in
            self.pickerOverlay.isHidden = true
            self.distancePicker.isHidden = true
            self.calPicker.isHidden = true
        }
    }
}

// MARK: — UITextFieldDelegate
extension TrackSelectionViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        commitTextField(textField)
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        commitTextField(textField)
    }
}

class CleanPickerView: UIPickerView {
    override func layoutSubviews() {
        super.layoutSubviews()
        for subview in subviews {
            if subview.frame.height <= self.frame.height, subview.backgroundColor != nil {
                subview.backgroundColor = .clear
            }
        }
    }
}
