import UIKit
import ObjectiveC

/// Key for objc_setAssociatedObject linking eye buttons to their UITextField.
private var eyeBtnKey: UInt8 = 0

class SettingsViewController: UIViewController {

    // MARK: - Nav
    private let navBar     = UIView()
    private let backBtn    = UIButton()
    private let titleLbl   = UILabel()

    // MARK: - Scroll
    private let scrollView      = UIScrollView()
    private let stackContainer  = UIStackView()

    // MARK: - Audio state
    private var musicMuted: Bool  = false
    private var sfxMuted: Bool    = false
    private let musicSlider       = UISlider()
    private let sfxSlider         = UISlider()
    private let musicPctLabel     = UILabel()
    private let sfxPctLabel       = UILabel()
    private let musicMuteBtn      = UIButton()
    private let sfxMuteBtn        = UIButton()

    // MARK: - Password expand
    private var pwExpanded            = false
    private let pwExpandContainer     = UIView()
    private let pwChevron             = UIImageView()
    private var pwExpandHeight: NSLayoutConstraint!
    private lazy var currentPwField  = makePwField("Current Password")
    private lazy var newPwField      = makePwField("New Password")
    private lazy var confirmPwField  = makePwField("Confirm New Password")

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.05, green: 0.02, blue: 0.1, alpha: 1)
        addBackground()
        buildNav()
        buildScroll()
        loadAudioPrefs()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backBtn.layer.cornerRadius = backBtn.frame.height / 2
    }

    // MARK: - Background (matches Profile page)

    private func addBackground() {
        let bg = UIImageView()
        bg.image = UIImage(named: "WhatsApp Image 2025-09-24 at 14.26.03")
        bg.contentMode = .scaleAspectFill
        bg.alpha = 0.4
        bg.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bg)
        view.sendSubviewToBack(bg)
        NSLayoutConstraint.activate([
            bg.topAnchor.constraint(equalTo: view.topAnchor),
            bg.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bg.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    // MARK: - Nav bar

    private func buildNav() {
        navBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navBar)

        backBtn.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        backBtn.layer.borderWidth = 1
        backBtn.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        let cfg = UIImage.SymbolConfiguration(weight: .bold)
        backBtn.setImage(UIImage(systemName: "chevron.left", withConfiguration: cfg), for: .normal)
        backBtn.tintColor = .white
        backBtn.translatesAutoresizingMaskIntoConstraints = false
        backBtn.addTarget(self, action: #selector(backTapped), for: .touchUpInside)

        titleLbl.text = "Settings"
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

    // MARK: - Scroll + sections

    private func buildScroll() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        stackContainer.axis      = .vertical
        stackContainer.spacing   = 20
        stackContainer.alignment = .fill
        stackContainer.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackContainer)
        NSLayoutConstraint.activate([
            stackContainer.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stackContainer.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stackContainer.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stackContainer.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -50),
            stackContainer.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])

        stackContainer.addArrangedSubview(buildAudioCard())
        stackContainer.addArrangedSubview(buildAccountCard())
        stackContainer.addArrangedSubview(buildDangerSection())
    }

    // MARK: - Audio Card

    private func buildAudioCard() -> UIView {
        let card = glassCard()

        let sectionLbl = sectionHeader("Audio")

        // Music row
        let musicRow = buildChannelRow(
            label: "Background Music",
            slider: musicSlider,
            pctLabel: musicPctLabel,
            muteBtn: musicMuteBtn,
            muteAction: #selector(toggleMusicMute)
        )

        let sep = makeSeparator()

        // SFX row
        let sfxRow = buildChannelRow(
            label: "Sound Effects",
            slider: sfxSlider,
            pctLabel: sfxPctLabel,
            muteBtn: sfxMuteBtn,
            muteAction: #selector(toggleSFXMute)
        )

        musicSlider.addTarget(self, action: #selector(musicSliderMoved), for: .valueChanged)
        sfxSlider.addTarget(self, action: #selector(sfxSliderMoved), for: .valueChanged)

        let inner = UIStackView()
        inner.axis    = .vertical
        inner.spacing = 18
        inner.translatesAutoresizingMaskIntoConstraints = false
        inner.addArrangedSubview(sectionLbl)
        inner.addArrangedSubview(musicRow)
        inner.addArrangedSubview(sep)
        inner.addArrangedSubview(sfxRow)

        card.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20)
        ])
        return card
    }

    /// Builds a single audio channel block: label + mute button on top, slider + % below.
    private func buildChannelRow(label: String,
                                 slider: UISlider,
                                 pctLabel: UILabel,
                                 muteBtn: UIButton,
                                 muteAction: Selector) -> UIView {
        // Top: label on left, mute icon-button on right
        let nameLbl = UILabel()
        nameLbl.text = label
        nameLbl.font = .systemFont(ofSize: 14, weight: .semibold)
        nameLbl.textColor = .white
        nameLbl.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let symCfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        muteBtn.setImage(UIImage(systemName: "speaker.wave.2.fill", withConfiguration: symCfg), for: .normal)
        muteBtn.tintColor = UIColor(red: 0.6, green: 0.4, blue: 1.0, alpha: 1)
        muteBtn.translatesAutoresizingMaskIntoConstraints = false
        muteBtn.setContentHuggingPriority(.required, for: .horizontal)
        muteBtn.addTarget(self, action: muteAction, for: .touchUpInside)

        let topRow = UIStackView(arrangedSubviews: [nameLbl, muteBtn])
        topRow.axis      = .horizontal
        topRow.alignment = .center
        topRow.spacing   = 8

        // Bottom: slider + percentage
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.tintColor    = UIColor(red: 0.6, green: 0.4, blue: 1.0, alpha: 1)
        slider.translatesAutoresizingMaskIntoConstraints = false

        pctLabel.font          = .systemFont(ofSize: 11, weight: .semibold)
        pctLabel.textColor     = UIColor.white.withAlphaComponent(0.45)
        pctLabel.textAlignment = .right
        pctLabel.setContentHuggingPriority(.required, for: .horizontal)
        pctLabel.widthAnchor.constraint(equalToConstant: 36).isActive = true

        let sliderRow = UIStackView(arrangedSubviews: [slider, pctLabel])
        sliderRow.axis      = .horizontal
        sliderRow.alignment = .center
        sliderRow.spacing   = 8

        let col = UIStackView(arrangedSubviews: [topRow, sliderRow])
        col.axis    = .vertical
        col.spacing = 10
        return col
    }

    // MARK: - Account Card (Change Password)

    private func buildAccountCard() -> UIView {
        let card = glassCard()

        let sectionLbl = sectionHeader("Account")

        // Tappable "Change Password" row
        let rowLabel = UILabel()
        rowLabel.text      = "Change Password"
        rowLabel.font      = .systemFont(ofSize: 15, weight: .semibold)
        rowLabel.textColor = .white
        rowLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let symCfg = UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
        pwChevron.image       = UIImage(systemName: "chevron.down", withConfiguration: symCfg)
        pwChevron.tintColor   = UIColor.white.withAlphaComponent(0.4)
        pwChevron.contentMode = .scaleAspectFit
        pwChevron.translatesAutoresizingMaskIntoConstraints = false
        pwChevron.setContentHuggingPriority(.required, for: .horizontal)

        let headerRow = UIStackView(arrangedSubviews: [rowLabel, pwChevron])
        headerRow.axis      = .horizontal
        headerRow.alignment = .center
        headerRow.spacing   = 8
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        headerRow.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let tapBtn = UIButton()
        tapBtn.translatesAutoresizingMaskIntoConstraints = false
        tapBtn.addTarget(self, action: #selector(togglePasswordExpand), for: .touchUpInside)

        // Expand container
        pwExpandContainer.clipsToBounds = true
        pwExpandContainer.translatesAutoresizingMaskIntoConstraints = false

        let savePwBtn = UIButton(type: .system)
        savePwBtn.setTitle("Save Password", for: .normal)
        savePwBtn.setTitleColor(.white, for: .normal)
        savePwBtn.titleLabel?.font  = .systemFont(ofSize: 15, weight: .bold)
        savePwBtn.backgroundColor   = UIColor(red: 0.6, green: 0.4, blue: 1.0, alpha: 1)
        savePwBtn.layer.cornerRadius = 14
        savePwBtn.translatesAutoresizingMaskIntoConstraints = false
        savePwBtn.heightAnchor.constraint(equalToConstant: 46).isActive = true
        savePwBtn.addTarget(self, action: #selector(savePasswordTapped), for: .touchUpInside)

        let expandStack = UIStackView()
        expandStack.axis    = .vertical
        expandStack.spacing = 12
        expandStack.translatesAutoresizingMaskIntoConstraints = false
        expandStack.addArrangedSubview(currentPwField)
        expandStack.addArrangedSubview(newPwField)
        expandStack.addArrangedSubview(confirmPwField)
        expandStack.addArrangedSubview(savePwBtn)

        pwExpandContainer.addSubview(expandStack)
        NSLayoutConstraint.activate([
            expandStack.topAnchor.constraint(equalTo: pwExpandContainer.topAnchor, constant: 12),
            expandStack.leadingAnchor.constraint(equalTo: pwExpandContainer.leadingAnchor),
            expandStack.trailingAnchor.constraint(equalTo: pwExpandContainer.trailingAnchor),
            expandStack.bottomAnchor.constraint(equalTo: pwExpandContainer.bottomAnchor, constant: -4)
        ])

        pwExpandHeight = pwExpandContainer.heightAnchor.constraint(equalToConstant: 0)
        pwExpandHeight.isActive = true

        // Inner stack
        let inner = UIStackView()
        inner.axis    = .vertical
        inner.spacing = 4
        inner.translatesAutoresizingMaskIntoConstraints = false
        inner.addArrangedSubview(sectionLbl)
        inner.setCustomSpacing(14, after: sectionLbl)
        inner.addArrangedSubview(headerRow)
        inner.addArrangedSubview(pwExpandContainer)

        card.addSubview(inner)
        card.addSubview(tapBtn)

        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            tapBtn.topAnchor.constraint(equalTo: headerRow.topAnchor),
            tapBtn.bottomAnchor.constraint(equalTo: headerRow.bottomAnchor),
            tapBtn.leadingAnchor.constraint(equalTo: inner.leadingAnchor),
            tapBtn.trailingAnchor.constraint(equalTo: inner.trailingAnchor)
        ])
        return card
    }

    // MARK: - Danger Section

    private func buildDangerSection() -> UIView {
        let logoutBtn = UIButton(type: .system)
        logoutBtn.setTitle("Log Out", for: .normal)
        logoutBtn.setTitleColor(.white, for: .normal)
        logoutBtn.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        logoutBtn.translatesAutoresizingMaskIntoConstraints = false
        logoutBtn.addTarget(self, action: #selector(logoutTapped), for: .touchUpInside)

        // Glass style matching Stats cards
        let logoutCard = glassCard()
        logoutCard.addSubview(logoutBtn)
        NSLayoutConstraint.activate([
            logoutBtn.centerXAnchor.constraint(equalTo: logoutCard.centerXAnchor),
            logoutBtn.centerYAnchor.constraint(equalTo: logoutCard.centerYAnchor),
            logoutCard.heightAnchor.constraint(equalToConstant: 56)
        ])

        let deleteBtn = UIButton(type: .system)
        deleteBtn.setTitle("Delete Account", for: .normal)
        deleteBtn.setTitleColor(.white, for: .normal)
        deleteBtn.titleLabel?.font  = .systemFont(ofSize: 16, weight: .bold)
        deleteBtn.backgroundColor   = UIColor.systemRed.withAlphaComponent(0.85)
        deleteBtn.layer.cornerRadius = 24
        deleteBtn.translatesAutoresizingMaskIntoConstraints = false
        deleteBtn.heightAnchor.constraint(equalToConstant: 56).isActive = true
        deleteBtn.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [logoutCard, deleteBtn])
        stack.axis    = .vertical
        stack.spacing = 14
        return stack
    }

    // MARK: - Audio Preferences

    private func loadAudioPrefs() {
        musicMuted   = UserDefaults.standard.bool(forKey: "audio_music_muted")
        sfxMuted     = UserDefaults.standard.bool(forKey: "audio_sfx_muted")
        let musicVol = UserDefaults.standard.object(forKey: "audio_music_volume") as? Float ?? 0.8
        let sfxVol   = UserDefaults.standard.object(forKey: "audio_sfx_volume")   as? Float ?? 0.8

        musicSlider.value = musicVol
        sfxSlider.value   = sfxVol
        updatePctLabel(musicPctLabel, value: musicVol)
        updatePctLabel(sfxPctLabel,   value: sfxVol)
        applyMuteState(muteBtn: musicMuteBtn, slider: musicSlider, pctLabel: musicPctLabel, muted: musicMuted)
        applyMuteState(muteBtn: sfxMuteBtn,   slider: sfxSlider,   pctLabel: sfxPctLabel,   muted: sfxMuted)
    }

    private func updatePctLabel(_ lbl: UILabel, value: Float) {
        lbl.text = "\(Int(value * 100))%"
    }

    private func applyMuteState(muteBtn: UIButton, slider: UISlider, pctLabel: UILabel, muted: Bool) {
        let symCfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let iconName = muted ? "speaker.slash.fill" : "speaker.wave.2.fill"
        muteBtn.setImage(UIImage(systemName: iconName, withConfiguration: symCfg), for: .normal)
        let activeColor = UIColor(red: 0.6, green: 0.4, blue: 1.0, alpha: 1)
        muteBtn.tintColor      = muted ? UIColor.white.withAlphaComponent(0.35) : activeColor
        slider.isEnabled       = !muted
        slider.alpha           = muted ? 0.35 : 1.0
        pctLabel.alpha         = muted ? 0.35 : 1.0
    }

    @objc private func toggleMusicMute() {
        musicMuted.toggle()
        UserDefaults.standard.set(musicMuted, forKey: "audio_music_muted")
        UIView.animate(withDuration: 0.2) {
            self.applyMuteState(muteBtn: self.musicMuteBtn, slider: self.musicSlider,
                                pctLabel: self.musicPctLabel, muted: self.musicMuted)
        }
        // TODO: AudioManager.shared.setMusicMuted(musicMuted)
    }

    @objc private func toggleSFXMute() {
        sfxMuted.toggle()
        UserDefaults.standard.set(sfxMuted, forKey: "audio_sfx_muted")
        UIView.animate(withDuration: 0.2) {
            self.applyMuteState(muteBtn: self.sfxMuteBtn, slider: self.sfxSlider,
                                pctLabel: self.sfxPctLabel, muted: self.sfxMuted)
        }
        // TODO: AudioManager.shared.setSFXMuted(sfxMuted)
    }

    @objc private func musicSliderMoved() {
        let val = musicSlider.value
        UserDefaults.standard.set(val, forKey: "audio_music_volume")
        updatePctLabel(musicPctLabel, value: val)
        // TODO: AudioManager.shared.setMusicVolume(val)
    }

    @objc private func sfxSliderMoved() {
        let val = sfxSlider.value
        UserDefaults.standard.set(val, forKey: "audio_sfx_volume")
        updatePctLabel(sfxPctLabel, value: val)
        // TODO: AudioManager.shared.setSFXVolume(val)
    }

    // MARK: - Password Expand

    @objc private func togglePasswordExpand() {
        pwExpanded.toggle()
        // 3 pw fields × 46 + save btn 46 + 3 gaps × 12 + top 12 + bottom 4 = 240
        let openH: CGFloat   = 240.0
        let closedH: CGFloat = 0.0
        pwExpandHeight.constant = pwExpanded ? openH : closedH

        let rotated: CGAffineTransform  = CGAffineTransform(rotationAngle: CGFloat.pi)
        let identity: CGAffineTransform = CGAffineTransform.identity
        UIView.animate(withDuration: 0.35, delay: 0,
                       usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3,
                       options: .curveEaseInOut) {
            self.pwChevron.transform = self.pwExpanded ? rotated : identity
            self.view.layoutIfNeeded()
        }
        if pwExpanded { currentPwField.becomeFirstResponder() }
        else {
            currentPwField.resignFirstResponder()
            newPwField.resignFirstResponder()
            confirmPwField.resignFirstResponder()
        }
    }

    @objc private func savePasswordTapped() {
        guard let current = currentPwField.text, !current.isEmpty else {
            showAlert("Missing Fields", "Please fill in all three fields."); return
        }
        guard let newPw = newPwField.text, !newPw.isEmpty else {
            showAlert("Missing Fields", "Please fill in all three fields."); return
        }
        guard let confirm = confirmPwField.text, !confirm.isEmpty else {
            showAlert("Missing Fields", "Please fill in all three fields."); return
        }
        guard newPw == confirm else {
            showAlert("Passwords Don't Match", "New password and confirmation must match."); return
        }
        guard newPw.count >= 6 else {
            showAlert("Too Short", "Password must be at least 6 characters."); return
        }

        Task {
            do {
                try await APIManager.shared.changePassword(
                    currentPassword: current,
                    newPassword: newPw
                )
                await MainActor.run {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    self.showAlert("Password Updated", "Your password has been changed successfully.") {
                        self.currentPwField.text = ""
                        self.newPwField.text     = ""
                        self.confirmPwField.text = ""
                        if self.pwExpanded { self.togglePasswordExpand() }
                    }
                }
            } catch {
                await MainActor.run {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    // Show the server's message (e.g. "Wrong current password")
                    let msg = error.localizedDescription
                    self.showAlert("Could Not Change Password", msg)
                }
            }
        }
    }

    // MARK: - Account Actions

    @objc private func backTapped() { dismiss(animated: true) }

    @objc private func logoutTapped() {
        if let uid = UserDefaults.standard.string(forKey: "djangoUserID") {
            Task { try? await APIManager.shared.setUserOffline(userId: uid) }
        }
        TokenManager.shared.clear()
        UserDefaults.standard.removeObject(forKey: "djangoUserID")
        navigateToLogin()
    }

    @objc private func deleteTapped() {
        let modal = DeleteConfirmModalController { [weak self] password in
            guard let self = self else { return }
            Task {
                do {
                    // Verify password + delete on the Django backend
                    try await APIManager.shared.deleteUserAccount(password: password)
                    // Clean up local state
                    if let uid = UserDefaults.standard.string(forKey: "djangoUserID") {
                        try? await APIManager.shared.setUserOffline(userId: uid)
                    }
                    TokenManager.shared.clear()
                    UserDefaults.standard.removeObject(forKey: "djangoUserID")
                    await MainActor.run { self.navigateToLogin() }
                } catch {
                    await MainActor.run {
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                        self.showAlert("Could Not Delete Account", error.localizedDescription)
                    }
                }
            }
        }
        modal.modalPresentationStyle = .overFullScreen
        modal.modalTransitionStyle   = .crossDissolve
        present(modal, animated: true)
    }

    private func navigateToLogin() {
        DispatchQueue.main.async {
            let sb = UIStoryboard(name: "Main", bundle: nil)
            if let vc = sb.instantiateViewController(withIdentifier: "LoginViewController") as? LoginViewController {
                vc.modalPresentationStyle = .fullScreen
                self.present(vc, animated: true)
            }
        }
    }

    // MARK: - Factory Helpers

    /// Glass card matching the Stats page style exactly.
    private func glassCard() -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .clear

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = 24
        blur.clipsToBounds      = true
        blur.layer.borderColor  = UIColor.white.withAlphaComponent(0.15).cgColor
        blur.layer.borderWidth  = 1
        blur.isUserInteractionEnabled = false
        v.addSubview(blur)
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: v.topAnchor),
            blur.bottomAnchor.constraint(equalTo: v.bottomAnchor),
            blur.leadingAnchor.constraint(equalTo: v.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: v.trailingAnchor)
        ])
        return v
    }

    private func sectionHeader(_ text: String) -> UILabel {
        let l = UILabel()
        l.text      = text.uppercased()
        l.font      = .systemFont(ofSize: 11, weight: .bold)
        l.textColor = UIColor.white.withAlphaComponent(0.4)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    private func makeSeparator() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return v
    }

    private func makePwField(_ placeholder: String) -> UITextField {
        let tf = UITextField()
        tf.isSecureTextEntry      = true
        tf.autocorrectionType     = .no
        tf.autocapitalizationType = .none
        tf.textColor              = .white
        tf.font                   = .systemFont(ofSize: 14)
        tf.backgroundColor        = UIColor.white.withAlphaComponent(0.07)
        tf.layer.cornerRadius     = 14
        tf.layer.borderWidth      = 1
        tf.layer.borderColor      = UIColor.white.withAlphaComponent(0.15).cgColor

        let placeholderColor: UIColor = UIColor.white.withAlphaComponent(0.3)
        let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: placeholderColor]
        tf.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: attrs)

        // Left padding
        let pad = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
        tf.leftView     = pad
        tf.leftViewMode = .always

        // Eye toggle button on the right
        let eyeBtn = UIButton(type: .system)
        let symCfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        eyeBtn.setImage(UIImage(systemName: "eye.slash", withConfiguration: symCfg), for: .normal)
        eyeBtn.tintColor = UIColor.white.withAlphaComponent(0.4)
        eyeBtn.frame = CGRect(x: 0, y: 0, width: 40, height: 46)
        eyeBtn.addTarget(self, action: #selector(toggleEye(_:)), for: .touchUpInside)
        // Store the linked text field in the button's tag via association
        objc_setAssociatedObject(eyeBtn, &eyeBtnKey, tf, .OBJC_ASSOCIATION_ASSIGN)
        tf.rightView     = eyeBtn
        tf.rightViewMode = .always

        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.heightAnchor.constraint(equalToConstant: 46).isActive = true
        return tf
    }

    @objc private func toggleEye(_ sender: UIButton) {
        guard let tf = objc_getAssociatedObject(sender, &eyeBtnKey) as? UITextField else { return }
        tf.isSecureTextEntry.toggle()
        let symCfg  = UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        let iconName = tf.isSecureTextEntry ? "eye.slash" : "eye"
        sender.setImage(UIImage(systemName: iconName, withConfiguration: symCfg), for: .normal)
        sender.tintColor = tf.isSecureTextEntry
            ? UIColor.white.withAlphaComponent(0.4)
            : UIColor(red: 0.6, green: 0.4, blue: 1.0, alpha: 1)
    }

    private func showAlert(_ title: String, _ message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completion?() })
        present(alert, animated: true)
    }
}

// MARK: - Delete Account Confirmation Modal

private final class DeleteConfirmModalController: UIViewController {

    private let onConfirm: (String) -> Void

    private let dimView    = UIView()
    private let cardView   = UIView()
    private var passwordTF: UITextField!
    private var deleteBtn:  UIButton!
    private var cardBottomConstraint: NSLayoutConstraint!

    private let red    = UIColor(red: 0.92, green: 0.28, blue: 0.28, alpha: 1)
    private let dimRed = UIColor(red: 0.92, green: 0.28, blue: 0.28, alpha: 0.12)
    private var eyeBtnKey: UInt8 = 0

    init(onConfirm: @escaping (String) -> Void) {
        self.onConfirm = onConfirm
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupDim()
        setupCard()
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateIn()
    }

    // MARK: - Layout

    private func setupDim() {
        dimView.backgroundColor = .clear
        dimView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dimView)
        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: view.topAnchor),
            dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        let tap = UITapGestureRecognizer(target: self, action: #selector(cancelTapped))
        dimView.addGestureRecognizer(tap)
    }

    private func setupCard() {
        cardView.backgroundColor = UIColor(red: 20/255, green: 10/255, blue: 35/255, alpha: 0.98)
        cardView.layer.cornerRadius    = 28
        cardView.layer.maskedCorners   = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        cardView.layer.borderWidth     = 1
        cardView.layer.borderColor     = UIColor.white.withAlphaComponent(0.12).cgColor
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardView)

        cardBottomConstraint = cardView.bottomAnchor.constraint(
            equalTo: view.bottomAnchor, constant: 600)
        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cardBottomConstraint
        ])

        // Drag handle
        let handle = UIView()
        handle.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        handle.layer.cornerRadius = 2.5
        handle.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(handle)

        // Warning icon circle
        let iconCircle = UIView()
        iconCircle.backgroundColor    = dimRed
        iconCircle.layer.cornerRadius = 28
        iconCircle.layer.borderWidth  = 1
        iconCircle.layer.borderColor  = red.withAlphaComponent(0.4).cgColor
        iconCircle.translatesAutoresizingMaskIntoConstraints = false

        let symCfg  = UIImage.SymbolConfiguration(pointSize: 22, weight: .bold)
        let iconImg = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill",
                                                 withConfiguration: symCfg))
        iconImg.tintColor     = red
        iconImg.contentMode   = .scaleAspectFit
        iconImg.translatesAutoresizingMaskIntoConstraints = false
        iconCircle.addSubview(iconImg)
        cardView.addSubview(iconCircle)

        // Title
        let titleLbl = UILabel()
        titleLbl.text      = "Delete Account"
        titleLbl.font      = .systemFont(ofSize: 22, weight: .bold)
        titleLbl.textColor = .white
        titleLbl.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLbl)

        // Subtitle
        let subLbl = UILabel()
        subLbl.text          = "This action is permanent and cannot be undone."
        subLbl.font          = .systemFont(ofSize: 13, weight: .medium)
        subLbl.textColor     = UIColor.white.withAlphaComponent(0.45)
        subLbl.numberOfLines = 0
        subLbl.textAlignment = .center
        subLbl.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(subLbl)

        // Instruction label
        let instrLbl = UILabel()
        instrLbl.text          = "Enter your password to confirm"
        instrLbl.font          = .systemFont(ofSize: 12, weight: .semibold)
        instrLbl.textColor     = red.withAlphaComponent(0.8)
        instrLbl.textAlignment = .center
        instrLbl.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(instrLbl)

        // Password field
        let tf = UITextField()
        tf.isSecureTextEntry      = true
        tf.autocorrectionType     = .no
        tf.autocapitalizationType = .none
        tf.textColor              = .white
        tf.font                   = .systemFont(ofSize: 16, weight: .medium)
        tf.backgroundColor        = red.withAlphaComponent(0.08)
        tf.layer.cornerRadius     = 14
        tf.layer.borderWidth      = 1
        tf.layer.borderColor      = red.withAlphaComponent(0.3).cgColor
        tf.tintColor              = red
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.heightAnchor.constraint(equalToConstant: 50).isActive = true
        tf.addTarget(self, action: #selector(textChanged), for: .editingChanged)

        let placeholderAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white.withAlphaComponent(0.25)
        ]
        tf.attributedPlaceholder = NSAttributedString(string: "Enter your password", attributes: placeholderAttrs)

        // Left padding
        let padView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
        tf.leftView     = padView
        tf.leftViewMode = .always

        // Eye toggle
        let eyeSymCfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        let eyeBtn = UIButton(type: .system)
        eyeBtn.setImage(UIImage(systemName: "eye.slash", withConfiguration: eyeSymCfg), for: .normal)
        eyeBtn.tintColor = UIColor.white.withAlphaComponent(0.4)
        eyeBtn.frame     = CGRect(x: 0, y: 0, width: 44, height: 50)
        eyeBtn.addTarget(self, action: #selector(togglePasswordEye(_:)), for: .touchUpInside)
        objc_setAssociatedObject(eyeBtn, &eyeBtnKey, tf, .OBJC_ASSOCIATION_ASSIGN)
        tf.rightView     = eyeBtn
        tf.rightViewMode = .always

        cardView.addSubview(tf)
        self.passwordTF = tf

        // Buttons
        let cancelBtn = makeBtn(title: "Cancel", filled: false)
        cancelBtn.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        let delBtn = makeBtn(title: "Delete Account", filled: true)
        delBtn.addTarget(self, action: #selector(confirmDelete), for: .touchUpInside)
        delBtn.alpha = 0.35
        delBtn.isEnabled = false
        cardView.addSubview(delBtn)
        self.deleteBtn = delBtn

        let btnStack = UIStackView(arrangedSubviews: [cancelBtn, delBtn])
        btnStack.spacing      = 12
        btnStack.distribution = .fillEqually
        btnStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(btnStack)

        NSLayoutConstraint.activate([
            handle.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            handle.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            handle.widthAnchor.constraint(equalToConstant: 40),
            handle.heightAnchor.constraint(equalToConstant: 5),

            iconCircle.topAnchor.constraint(equalTo: handle.bottomAnchor, constant: 24),
            iconCircle.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            iconCircle.widthAnchor.constraint(equalToConstant: 56),
            iconCircle.heightAnchor.constraint(equalToConstant: 56),
            iconImg.centerXAnchor.constraint(equalTo: iconCircle.centerXAnchor),
            iconImg.centerYAnchor.constraint(equalTo: iconCircle.centerYAnchor),
            iconImg.widthAnchor.constraint(equalToConstant: 26),
            iconImg.heightAnchor.constraint(equalToConstant: 26),

            titleLbl.topAnchor.constraint(equalTo: iconCircle.bottomAnchor, constant: 16),
            titleLbl.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),

            subLbl.topAnchor.constraint(equalTo: titleLbl.bottomAnchor, constant: 6),
            subLbl.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 32),
            subLbl.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -32),

            instrLbl.topAnchor.constraint(equalTo: subLbl.bottomAnchor, constant: 24),
            instrLbl.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),

            passwordTF.topAnchor.constraint(equalTo: instrLbl.bottomAnchor, constant: 10),
            passwordTF.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 28),
            passwordTF.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -28),

            btnStack.topAnchor.constraint(equalTo: passwordTF.bottomAnchor, constant: 24),
            btnStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 28),
            btnStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -28),
            btnStack.heightAnchor.constraint(equalToConstant: 50),
            btnStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -40)
        ])
    }

    private func makeBtn(title: String, filled: Bool) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
        btn.layer.cornerRadius = 14
        if filled {
            btn.backgroundColor = red
            btn.setTitleColor(.white, for: .normal)
        } else {
            btn.backgroundColor = UIColor.white.withAlphaComponent(0.06)
            btn.setTitleColor(UIColor.white.withAlphaComponent(0.7), for: .normal)
            btn.layer.borderWidth = 1
            btn.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        }
        return btn
    }

    // MARK: - Animations

    private func animateIn() {
        view.layoutIfNeeded()
        cardBottomConstraint.constant = 0
        UIView.animate(withDuration: 0.5, delay: 0,
                       usingSpringWithDamping: 0.85, initialSpringVelocity: 0.5,
                       options: .curveEaseOut) {
            self.dimView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
            self.view.layoutIfNeeded()
        } completion: { _ in
            self.passwordTF.becomeFirstResponder()
        }
    }

    private func animateOut(completion: (() -> Void)? = nil) {
        view.endEditing(true)
        cardBottomConstraint.constant = 600
        UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseIn) {
            self.dimView.backgroundColor = .clear
            self.view.layoutIfNeeded()
        } completion: { _ in
            self.dismiss(animated: false, completion: completion)
        }
    }

    // MARK: - Actions

    @objc private func textChanged() {
        let hasText = !(passwordTF.text ?? "").isEmpty
        UIView.animate(withDuration: 0.2) {
            self.deleteBtn.alpha     = hasText ? 1.0 : 0.35
            self.deleteBtn.isEnabled = hasText
        }
    }

    @objc private func togglePasswordEye(_ sender: UIButton) {
        guard let tf = objc_getAssociatedObject(sender, &eyeBtnKey) as? UITextField else { return }
        tf.isSecureTextEntry.toggle()
        let symCfg   = UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        let iconName = tf.isSecureTextEntry ? "eye.slash" : "eye"
        sender.setImage(UIImage(systemName: iconName, withConfiguration: symCfg), for: .normal)
        sender.tintColor = tf.isSecureTextEntry
            ? UIColor.white.withAlphaComponent(0.4)
            : UIColor(red: 0.92, green: 0.28, blue: 0.28, alpha: 1)
    }

    @objc private func cancelTapped() {
        animateOut()
    }

    @objc private func confirmDelete() {
        let password = passwordTF.text ?? ""
        guard !password.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        animateOut { [weak self] in
            self?.onConfirm(password)
        }
    }

    // MARK: - Keyboard

    @objc private func keyboardWillShow(_ n: Notification) {
        guard let info = n.userInfo,
              let frame = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
              let dur   = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
        else { return }
        cardBottomConstraint.constant = -frame.height
        UIView.animate(withDuration: dur) { self.view.layoutIfNeeded() }
    }

    @objc private func keyboardWillHide(_ n: Notification) {
        guard let dur = n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
        else { return }
        cardBottomConstraint.constant = 0
        UIView.animate(withDuration: dur) { self.view.layoutIfNeeded() }
    }
}
