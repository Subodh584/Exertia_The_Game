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
        Track(title: "Nova-Station",  videoName: "Nova-Station"),
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
    private let distBtn = UIButton(type: .system)
    private let calBtn = UIButton(type: .system)
    private let distancePicker = CleanPickerView()
    private let calPicker = CleanPickerView()
    private let pickerOverlay = UIButton(type: .custom)
    
    private var rowHeightConstraint: NSLayoutConstraint!

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
            startButton.widthAnchor.constraint(equalToConstant: 240),
            startButton.heightAnchor.constraint(equalToConstant: 58)
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

        // Shift the portal upwards to avoid overlapping the new, higher button positions
        portalBaseView.transform              = CGAffineTransform(translationX: 0, y: -45).scaledBy(x: 5.4, y: 3.5)
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
        distancePicker.dataSource = self
        distancePicker.delegate = self
        calPicker.dataSource = self
        calPicker.delegate = self

        distBtn.addTarget(self, action: #selector(goalButtonTapped(_:)), for: .touchUpInside)
        calBtn.addTarget(self, action: #selector(goalButtonTapped(_:)), for: .touchUpInside)

        let distCol = makeGoalColumn(btn: distBtn, picker: distancePicker)
        let calCol  = makeGoalColumn(btn: calBtn, picker: calPicker)

        let row = UIStackView(arrangedSubviews: [distCol, calCol])
        row.axis         = .horizontal
        row.distribution = .fillEqually
        row.spacing      = 14
        row.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(row)
        view.bringSubviewToFront(row)

        rowHeightConstraint = row.heightAnchor.constraint(equalToConstant: 54)
        
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            row.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            row.bottomAnchor.constraint(equalTo: startButton.topAnchor, constant: -24),
            rowHeightConstraint
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
    private func makeGoalColumn(btn: UIButton, picker: UIPickerView) -> UIView {
        let col = UIView()
        col.translatesAutoresizingMaskIntoConstraints = false

        // Glass pill — fills the entire column
        let pill = makeGlassPill()
        col.addSubview(pill)

        // Text Button for closed state with native placement of the pencil icon
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "pencil")
        config.imagePlacement = .trailing
        config.imagePadding = 6
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)
        config.baseForegroundColor = .white
        btn.configuration = config
        btn.translatesAutoresizingMaskIntoConstraints = false
        
        // Picker for open state
        picker.alpha = 0
        picker.isHidden = true
        picker.translatesAutoresizingMaskIntoConstraints = false
        
        // Pill interior
        pill.addSubview(btn)
        pill.addSubview(picker)

        NSLayoutConstraint.activate([
            pill.topAnchor.constraint(equalTo: col.topAnchor),
            pill.leadingAnchor.constraint(equalTo: col.leadingAnchor),
            pill.trailingAnchor.constraint(equalTo: col.trailingAnchor),
            pill.bottomAnchor.constraint(equalTo: col.bottomAnchor),

            btn.topAnchor.constraint(equalTo: pill.topAnchor),
            btn.bottomAnchor.constraint(equalTo: pill.bottomAnchor),
            btn.leadingAnchor.constraint(equalTo: pill.leadingAnchor),
            btn.trailingAnchor.constraint(equalTo: pill.trailingAnchor),
            
            // Picker constrained strictly over the center
            picker.topAnchor.constraint(equalTo: pill.topAnchor),
            picker.bottomAnchor.constraint(equalTo: pill.bottomAnchor),
            picker.centerXAnchor.constraint(equalTo: btn.centerXAnchor),
            picker.widthAnchor.constraint(equalTo: btn.widthAnchor)
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

    // MARK: — Title Update Logic
    private func updateButtonTitles() {
        let font = UIFont.systemFont(ofSize: 16, weight: .bold)
        
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
        guard let path = Bundle.main.path(forResource: videoName, ofType: "mp4") else {
            print("❌ Video not found: \(videoName).mp4")
            return
        }
        player?.pause()
        playerLayer?.removeFromSuperlayer()

        // Preload asset for faster playback start
        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        asset.loadValuesAsynchronously(forKeys: ["playable"]) { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let item = AVPlayerItem(asset: asset)
                // Buffer ahead for smooth start
                item.preferredForwardBufferDuration = 2.0
                self.player = AVPlayer(playerItem: item)
                self.player?.automaticallyWaitsToMinimizeStalling = false
                AudioManager.shared.applyMutedState(to: self.player)
                self.playerLayer = AVPlayerLayer(player: self.player)
                self.videoContainerView.layoutIfNeeded()
                self.playerLayer?.frame         = self.videoContainerView.bounds
                self.playerLayer?.videoGravity  = .resizeAspectFill
                self.playerLayer?.cornerRadius  = 20
                self.playerLayer?.masksToBounds = true
                self.videoContainerView.layer.addSublayer(self.playerLayer!)
                self.player?.play()
                NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: self.player?.currentItem, queue: .main
                ) { [weak self] _ in self?.player?.seek(to: .zero); self?.player?.play() }
            }
        }
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
        label.font = .systemFont(ofSize: 20, weight: .bold) 
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
        
        let isDist = (sender === distBtn)
        
        pickerOverlay.isHidden = false
        distancePicker.isHidden = false
        calPicker.isHidden = false
        
        self.rowHeightConstraint.constant = 110 // Expands exactly to reveal roughly 3 perfectly framed options natively cut off by the pill mask!
        
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2, options: .curveEaseInOut) {
            self.pickerOverlay.alpha = 1
            self.distancePicker.alpha = 1
            self.calPicker.alpha = 1
            self.distBtn.alpha = 0
            self.calBtn.alpha = 0
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func dismissInlinePicker() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        
        self.rowHeightConstraint.constant = 54
        
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
