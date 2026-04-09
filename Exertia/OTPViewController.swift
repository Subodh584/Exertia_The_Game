import UIKit

// MARK: - Mode
enum OTPMode {
    case register       // verify email → create Supabase account
    case resetPassword  // verify email → set new password
}

class OTPViewController: UIViewController, UITextFieldDelegate {

    // MARK: - Configuration (set before presenting)
    var mode: OTPMode = .register
    var email: String = ""

    // Register-only
    var password: String = ""
    var displayName: String = ""
    var username: String = ""

    // MARK: - UI
    private let backgroundImageView = UIImageView()
    private let scrollView          = UIScrollView()
    private let contentView         = UIView()
    private let glassCard           = UIView()
    private let titleLabel          = UILabel()
    private let subtitleLabel       = UILabel()

    private let otpFields: [OTPDigitField] = (0..<6).map { _ in OTPDigitField() }
    private let otpStackView = UIStackView()

    private let backButton     = UIButton(type: .system)
    private let actionButton   = UIButton(type: .system)
    private let resendButton   = UIButton(type: .system)

    private var resendTimer: Timer?
    private var resendCountdown: Int = 0

    // Reset-password — new password step (hidden initially)
    private let newPasswordCard    = UIView()
    private let newPasswordField   = UITextField()
    private let confirmPasswordField = UITextField()
    private let resetButton        = UIButton(type: .system)

    // Eye toggle buttons for reset-password fields
    private let newPwEyeButton     = UIButton(type: .custom)
    private let confirmPwEyeButton = UIButton(type: .custom)

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupKeyboardDismiss()

        subtitleLabel.text = "Enter the 6-digit code sent to\n\(email)"
        titleLabel.text    = mode == .register ? "Verify Email" : "Reset Password"
        actionButton.setTitle(mode == .register ? "Verify & Create Account" : "Verify Code", for: .normal)
    }

    // MARK: - Actions

    @objc private func actionButtonTapped() {
        let otp = otpFields.compactMap { $0.text }.joined()
        guard otp.count == 6 else {
            showAlert(title: "Incomplete Code", message: "Please enter all 6 digits.")
            return
        }

        setLoading(true)

        Task {
            defer { DispatchQueue.main.async { self.setLoading(false) } }

            do {
                try await MailServerManager.verifyOTP(email: email, otp: otp)

                switch mode {
                case .register:
                    await handleRegisterVerified()
                case .resetPassword:
                    DispatchQueue.main.async { self.transitionToNewPasswordStep() }
                }

            } catch {
                DispatchQueue.main.async {
                    self.shakeOTPFields()
                    self.clearOTPFields()
                    let alert = UIAlertController(title: "Verification Failed",
                                                  message: error.localizedDescription,
                                                  preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                        self?.otpFields.first?.becomeFirstResponder()
                    })
                    self.present(alert, animated: true)
                }
            }
        }
    }

    // Register: create Supabase account after OTP passes
    private func handleRegisterVerified() async {
        do {
            let userId = try await performSignUp()
            UserDefaults.standard.set(userId, forKey: "supabaseUserID")
            print("✅ Signup complete. User ID: \(userId)")
            DispatchQueue.main.async { self.navigateToOnboarding() }

        } catch {
            let msg = error.localizedDescription.lowercased()
            if msg.contains("already registered")
                || msg.contains("user already exists")
                || msg.contains("couldn't be read")
                || error is DecodingError {
                await handleOrphanedAuthUser()
            } else {
                DispatchQueue.main.async {
                    self.showAlert(title: "Account Creation Failed", message: error.localizedDescription)
                }
            }
        }
    }

    private func handleOrphanedAuthUser() async {
        do {
            let cleaned = try await MailServerManager.cleanupOrphanedUser(email: email)

            if cleaned {
                print("♻️  Orphaned auth user cleaned up, retrying signup…")
                let userId = try await performSignUp()
                UserDefaults.standard.set(userId, forKey: "supabaseUserID")
                print("✅ Signup complete after cleanup. User ID: \(userId)")
                DispatchQueue.main.async { self.navigateToOnboarding() }
            } else {
                DispatchQueue.main.async {
                    self.showAlert(
                        title: "Email Already In Use",
                        message: "An account with this email already exists. Please log in or use Forgot Password to regain access."
                    )
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.showAlert(title: "Account Creation Failed", message: error.localizedDescription)
            }
        }
    }

    private func performSignUp() async throws -> String {
        try await SupabaseManager.shared.signUp(
            email: email,
            password: password,
            username: username,
            displayName: displayName
        )
    }

    private func navigateToOnboarding() {
        let onboardingVC = OnboardingProfileViewController()
        onboardingVC.modalPresentationStyle = .fullScreen
        onboardingVC.modalTransitionStyle   = .crossDissolve
        present(onboardingVC, animated: true)
    }

    // Reset: show the new password fields
    private func transitionToNewPasswordStep() {
        UIView.animate(withDuration: 0.25, animations: {
            self.otpStackView.alpha  = 0
            self.actionButton.alpha  = 0
            self.resendButton.alpha  = 0
        }) { _ in
            self.otpStackView.isHidden  = true
            self.actionButton.isHidden  = true
            self.resendButton.isHidden  = true

            self.titleLabel.text    = "New Password"
            self.subtitleLabel.text = "Choose a new password for\n\(self.email)"

            self.newPasswordCard.isHidden = false
            UIView.animate(withDuration: 0.25) { self.newPasswordCard.alpha = 1 }
            self.newPasswordField.becomeFirstResponder()
        }
    }

    @objc private func resetButtonTapped() {
        let newPw  = newPasswordField.text ?? ""
        let confPw = confirmPasswordField.text ?? ""

        guard newPw.count >= 6 else {
            showAlert(title: "Too Short", message: "Password must be at least 6 characters.")
            return
        }
        guard newPw == confPw else {
            showAlert(title: "Passwords Don't Match", message: "Please make sure both passwords are the same.")
            return
        }

        setResetLoading(true)

        Task {
            defer { DispatchQueue.main.async { self.setResetLoading(false) } }

            do {
                try await MailServerManager.resetPassword(email: email, newPassword: newPw)
                print("✅ Password reset for \(email)")

                DispatchQueue.main.async {
                    let alert = UIAlertController(
                        title: "Password Updated",
                        message: "Your password has been changed successfully. Please log in.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "Log In", style: .default) { [weak self] _ in
                        self?.view.window?.rootViewController?.dismiss(animated: true)
                    })
                    self.present(alert, animated: true)
                }
            } catch {
                DispatchQueue.main.async {
                    self.showAlert(title: "Reset Failed", message: error.localizedDescription)
                }
            }
        }
    }

    @objc private func backTapped() {
        dismiss(animated: true)
    }

    @objc private func resendTapped() {
        resendButton.isEnabled = false
        startResendTimer()

        Task {
            do {
                let purpose = mode == .register ? "register" : "reset"
                try await MailServerManager.sendOTP(to: email, purpose: purpose)
                DispatchQueue.main.async {
                    self.showAlert(title: "Code Resent", message: "A new 6-digit code was sent to \(self.email).")
                }
            } catch {
                DispatchQueue.main.async {
                    self.showAlert(title: "Resend Failed", message: error.localizedDescription)
                    self.stopResendTimer()
                }
            }
        }
    }

    private func startResendTimer() {
        resendCountdown = 30
        updateResendButton()
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.resendCountdown -= 1
            if self.resendCountdown <= 0 {
                self.stopResendTimer()
            } else {
                self.updateResendButton()
            }
        }
    }

    private func stopResendTimer() {
        resendTimer?.invalidate()
        resendTimer = nil
        DispatchQueue.main.async {
            self.resendButton.isEnabled = true
            self.resendButton.setTitle("Resend Code", for: .normal)
            self.resendButton.setTitleColor(UIColor(white: 0.75, alpha: 1), for: .normal)
        }
    }

    private func updateResendButton() {
        DispatchQueue.main.async {
            self.resendButton.setTitle("Resend in \(self.resendCountdown)s", for: .normal)
            self.resendButton.setTitleColor(UIColor(white: 0.5, alpha: 1), for: .normal)
        }
    }

    // MARK: - Loading helpers
    private func setLoading(_ on: Bool) {
        actionButton.isEnabled = !on
        actionButton.alpha     = on ? 0.6 : 1.0
        let title = mode == .register ? "Verify & Create Account" : "Verify Code"
        actionButton.setTitle(on ? "Verifying…" : title, for: .normal)
    }

    private func setResetLoading(_ on: Bool) {
        resetButton.isEnabled = !on
        resetButton.alpha     = on ? 0.6 : 1.0
        resetButton.setTitle(on ? "Updating…" : "Reset Password", for: .normal)
    }

    private func shakeOTPFields() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration  = 0.5
        animation.values    = [-10, 10, -8, 8, -5, 5, 0]
        otpStackView.layer.add(animation, forKey: "shake")
    }

    private func clearOTPFields() {
        otpFields.forEach { $0.text = "" }
    }

    // MARK: - Alert helper
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Eye toggles (reset password)
    @objc private func toggleNewPwVisibility(_ sender: UIButton) {
        newPasswordField.isSecureTextEntry.toggle()
        let icon = newPasswordField.isSecureTextEntry ? "eye.slash" : "eye"
        sender.setImage(UIImage(systemName: icon), for: .normal)
    }

    @objc private func toggleConfirmPwVisibility(_ sender: UIButton) {
        confirmPasswordField.isSecureTextEntry.toggle()
        let icon = confirmPasswordField.isSecureTextEntry ? "eye.slash" : "eye"
        sender.setImage(UIImage(systemName: icon), for: .normal)
    }

    private func makeEyeButton(action: Selector) -> UIButton {
        let btn = UIButton(type: .custom)
        btn.setImage(UIImage(systemName: "eye.slash"), for: .normal)
        btn.tintColor = .darkGray
        btn.frame = CGRect(x: 0, y: 0, width: 44, height: 50)
        btn.contentEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 12)
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }

    // MARK: - UITextFieldDelegate (OTP auto-advance)
    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        guard let index = otpFields.firstIndex(of: textField as! OTPDigitField) else { return false }

        if string.isEmpty {
            textField.text = ""
            if index > 0 { otpFields[index - 1].becomeFirstResponder() }
            return false
        }
        if string.count == 1 {
            textField.text = string
            if index < otpFields.count - 1 {
                otpFields[index + 1].becomeFirstResponder()
            }
            // Last field: keep focus so the user can still backspace to correct a digit
            return false
        }
        return false
    }

    @objc private func dismissKeyboard() { view.endEditing(true) }

    private func setupKeyboardDismiss() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
    }

    // MARK: - UI Setup
    private func setupUI() {
        backgroundImageView.image       = UIImage(named: "loading background")
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundImageView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        setupGlassCard()

        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            contentView.heightAnchor.constraint(greaterThanOrEqualTo: view.heightAnchor)
        ])
    }

    private func setupGlassCard() {
        glassCard.backgroundColor    = UIColor.white.withAlphaComponent(0.15)
        glassCard.layer.cornerRadius = 24
        glassCard.layer.borderWidth  = 1
        glassCard.layer.borderColor  = UIColor.white.withAlphaComponent(0.3).cgColor
        glassCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(glassCard)

        // ── Back button ──
        var backConfig = UIButton.Configuration.plain()
        backConfig.image = UIImage(systemName: "chevron.left")
        backConfig.imagePlacement = .leading
        backConfig.title = "Back"
        backConfig.baseForegroundColor = .white
        backButton.configuration = backConfig
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(backButton)

        // ── Title ──
        titleLabel.font          = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor     = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(titleLabel)

        // ── Subtitle ──
        subtitleLabel.font          = .systemFont(ofSize: 14, weight: .medium)
        subtitleLabel.textColor     = UIColor(white: 0.9, alpha: 1)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(subtitleLabel)

        // ── OTP fields ──
        otpStackView.axis         = .horizontal
        otpStackView.spacing      = 10
        otpStackView.distribution = .fillEqually
        otpStackView.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(otpStackView)

        for (i, field) in otpFields.enumerated() {
            field.backgroundColor    = .white
            field.layer.cornerRadius = 12
            field.textColor          = .black
            field.font               = .systemFont(ofSize: 24, weight: .bold)
            field.textAlignment      = .center
            field.keyboardType       = .numberPad
            field.delegate           = self
            field.layer.shadowColor   = UIColor.black.cgColor
            field.layer.shadowOpacity = 0.1
            field.layer.shadowOffset  = CGSize(width: 0, height: 2)
            field.layer.shadowRadius  = 4
            field.onDeleteBackward = { [weak self] in
                guard let self, i > 0 else { return }
                self.otpFields[i - 1].text = ""
                self.otpFields[i - 1].becomeFirstResponder()
            }
            otpStackView.addArrangedSubview(field)
            field.heightAnchor.constraint(equalTo: field.widthAnchor).isActive = true
        }

        // ── Action (verify) button ──
        actionButton.backgroundColor    = UIColor(red: 0.0, green: 0.2, blue: 0.4, alpha: 1.0)
        actionButton.setTitleColor(.white, for: .normal)
        actionButton.layer.cornerRadius = 27.5
        actionButton.titleLabel?.font   = .systemFont(ofSize: 17, weight: .bold)
        actionButton.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(actionButton)

        // ── Resend button ──
        resendButton.setTitle("Resend Code", for: .normal)
        resendButton.setTitleColor(UIColor(white: 0.75, alpha: 1), for: .normal)
        resendButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        resendButton.addTarget(self, action: #selector(resendTapped), for: .touchUpInside)
        resendButton.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(resendButton)

        // ── New-password card (hidden initially) ──
        setupNewPasswordCard()

        NSLayoutConstraint.activate([
            glassCard.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            glassCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            glassCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            glassCard.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 40),
            glassCard.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -40),

            backButton.topAnchor.constraint(equalTo: glassCard.topAnchor, constant: 16),
            backButton.leadingAnchor.constraint(equalTo: glassCard.leadingAnchor, constant: 16),

            titleLabel.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: glassCard.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: glassCard.trailingAnchor, constant: -20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: glassCard.leadingAnchor, constant: 25),
            subtitleLabel.trailingAnchor.constraint(equalTo: glassCard.trailingAnchor, constant: -25),

            otpStackView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 40),
            otpStackView.centerXAnchor.constraint(equalTo: glassCard.centerXAnchor),
            otpStackView.widthAnchor.constraint(equalToConstant: 300),

            actionButton.topAnchor.constraint(equalTo: otpStackView.bottomAnchor, constant: 40),
            actionButton.leadingAnchor.constraint(equalTo: glassCard.leadingAnchor, constant: 25),
            actionButton.trailingAnchor.constraint(equalTo: glassCard.trailingAnchor, constant: -25),
            actionButton.heightAnchor.constraint(equalToConstant: 55),

            resendButton.topAnchor.constraint(equalTo: actionButton.bottomAnchor, constant: 16),
            resendButton.centerXAnchor.constraint(equalTo: glassCard.centerXAnchor),

            newPasswordCard.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 30),
            newPasswordCard.leadingAnchor.constraint(equalTo: glassCard.leadingAnchor, constant: 25),
            newPasswordCard.trailingAnchor.constraint(equalTo: glassCard.trailingAnchor, constant: -25),

            resendButton.bottomAnchor.constraint(equalTo: glassCard.bottomAnchor, constant: -35)
        ])
    }

    private func setupNewPasswordCard() {
        newPasswordCard.isHidden = true
        newPasswordCard.alpha    = 0
        newPasswordCard.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(newPasswordCard)

        styleTextField(newPasswordField,     placeholder: "New Password",     icon: "lock",    isSecure: true)
        styleTextField(confirmPasswordField, placeholder: "Confirm Password", icon: "lock.fill", isSecure: true)

        // Eye buttons for reset password fields
        let eye1 = makeEyeButton(action: #selector(toggleNewPwVisibility))
        newPasswordField.rightView     = eye1
        newPasswordField.rightViewMode = .always

        let eye2 = makeEyeButton(action: #selector(toggleConfirmPwVisibility))
        confirmPasswordField.rightView     = eye2
        confirmPasswordField.rightViewMode = .always

        newPasswordCard.addSubview(newPasswordField)
        newPasswordCard.addSubview(confirmPasswordField)

        resetButton.setTitle("Reset Password", for: .normal)
        resetButton.backgroundColor    = UIColor(red: 0.0, green: 0.5, blue: 0.3, alpha: 1.0)
        resetButton.setTitleColor(.white, for: .normal)
        resetButton.layer.cornerRadius = 27.5
        resetButton.titleLabel?.font   = .systemFont(ofSize: 17, weight: .bold)
        resetButton.addTarget(self, action: #selector(resetButtonTapped), for: .touchUpInside)
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        newPasswordCard.addSubview(resetButton)

        NSLayoutConstraint.activate([
            newPasswordField.topAnchor.constraint(equalTo: newPasswordCard.topAnchor),
            newPasswordField.leadingAnchor.constraint(equalTo: newPasswordCard.leadingAnchor),
            newPasswordField.trailingAnchor.constraint(equalTo: newPasswordCard.trailingAnchor),
            newPasswordField.heightAnchor.constraint(equalToConstant: 50),

            confirmPasswordField.topAnchor.constraint(equalTo: newPasswordField.bottomAnchor, constant: 14),
            confirmPasswordField.leadingAnchor.constraint(equalTo: newPasswordCard.leadingAnchor),
            confirmPasswordField.trailingAnchor.constraint(equalTo: newPasswordCard.trailingAnchor),
            confirmPasswordField.heightAnchor.constraint(equalToConstant: 50),

            resetButton.topAnchor.constraint(equalTo: confirmPasswordField.bottomAnchor, constant: 28),
            resetButton.leadingAnchor.constraint(equalTo: newPasswordCard.leadingAnchor),
            resetButton.trailingAnchor.constraint(equalTo: newPasswordCard.trailingAnchor),
            resetButton.heightAnchor.constraint(equalToConstant: 55),
            resetButton.bottomAnchor.constraint(equalTo: newPasswordCard.bottomAnchor)
        ])
    }

    private func styleTextField(_ textField: UITextField, placeholder: String, icon: String,
                                 isSecure: Bool = false) {
        textField.backgroundColor    = .white
        textField.layer.cornerRadius = 10
        textField.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [.foregroundColor: UIColor.systemGray])
        textField.isSecureTextEntry  = isSecure
        textField.textColor          = .black
        textField.autocapitalizationType = .none
        textField.autocorrectionType     = .no

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor    = .darkGray
        iconView.contentMode  = .scaleAspectFit
        let container         = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 50))
        iconView.frame        = CGRect(x: 12, y: 15, width: 20, height: 20)
        container.addSubview(iconView)
        textField.leftView    = container
        textField.leftViewMode = .always
        textField.translatesAutoresizingMaskIntoConstraints = false
    }
}

// MARK: - OTPDigitField
class OTPDigitField: UITextField {
    var onDeleteBackward: (() -> Void)?

    override func deleteBackward() {
        if text?.isEmpty == true {
            onDeleteBackward?()
        } else {
            super.deleteBackward()
        }
    }
}
