//
//  ForgotPasswordViewController.swift
//  Exertia
//

import UIKit

class ForgotPasswordViewController: UIViewController {

    // MARK: - UI
    private let backgroundImageView = UIImageView()
    private let scrollView          = UIScrollView()
    private let contentView         = UIView()

    private let glassCard     = UIView()
    private let titleLabel    = UILabel()
    private let subtitleLabel = UILabel()
    private let emailField    = UITextField()
    private let sendButton    = UIButton()
    private let backButton    = UIButton(type: .system)

    // MARK: - Resend Timer
    private var resendTimer: Timer?
    private var resendCountdown: Int = 60

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupKeyboardDismiss()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopResendTimer()
    }

    // MARK: - Actions

    @objc private func sendTapped() {
        let email = emailField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !email.isEmpty else {
            showAlert(title: "Email Required", message: "Please enter your email address.")
            return
        }
        guard email.contains("@") else {
            showAlert(title: "Invalid Email", message: "Please enter a valid email address.")
            return
        }

        setLoading(true)

        Task {
            do {
                // 1. Make sure the email is actually registered
                let exists = try await SupabaseManager.shared.checkEmailExists(email)
                guard exists else {
                    DispatchQueue.main.async {
                        self.setLoading(false)
                        self.showAlert(title: "No Account Found",
                                       message: "We couldn't find an account with that email address.")
                    }
                    return
                }

                // 2. Send reset OTP
                DispatchQueue.main.async { self.setLoading(true, title: "Sending code…") }
                try await MailServerManager.sendOTP(to: email, purpose: "reset")

                print("✅ Reset OTP sent to \(email)")

                // 3. Start the 60s resend timer, then navigate to OTP screen
                DispatchQueue.main.async {
                    self.setLoading(false)
                    self.startResendTimer()

                    let otpVC = OTPViewController()
                    otpVC.mode  = .resetPassword
                    otpVC.email = email
                    otpVC.modalPresentationStyle = .fullScreen
                    otpVC.modalTransitionStyle   = .crossDissolve
                    self.present(otpVC, animated: true)
                }

            } catch {
                DispatchQueue.main.async {
                    self.setLoading(false)
                    self.showAlert(title: "Something Went Wrong", message: error.localizedDescription)
                }
            }
        }
    }

    @objc private func clearFieldsTapped() {
        emailField.text = ""
        updateClearButton()
    }

    @objc private func emailEditingChanged() {
        updateClearButton()
    }

    @objc private func backTapped() {
        dismiss(animated: true)
    }

    // MARK: - Resend Timer

    private func startResendTimer() {
        resendCountdown = 60
        updateTimerButton()
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.resendCountdown -= 1
            if self.resendCountdown <= 0 {
                self.stopResendTimer()
            } else {
                self.updateTimerButton()
            }
        }
    }

    private func stopResendTimer() {
        resendTimer?.invalidate()
        resendTimer = nil
        DispatchQueue.main.async {
            self.sendButton.isEnabled = true
            self.sendButton.alpha     = 1.0
            self.sendButton.setTitle("Send Code", for: .normal)
        }
    }

    private func updateTimerButton() {
        let minutes = resendCountdown / 60
        let seconds = resendCountdown % 60
        sendButton.setTitle(String(format: "Resend in %d:%02d", minutes, seconds), for: .normal)
        sendButton.isEnabled = false
        sendButton.alpha     = 0.6
    }

    // MARK: - Loading helper
    private func setLoading(_ on: Bool, title: String = "Send Code") {
        // Don't re-enable if the resend timer is still running
        if !on && resendTimer != nil { return }
        sendButton.isEnabled = !on
        sendButton.alpha     = on ? 0.7 : 1.0
        sendButton.setTitle(on ? title : "Send Code", for: .normal)
    }

    // MARK: - Clear button helper
    private func updateClearButton() {
        let hasText = !(emailField.text?.isEmpty ?? true)
        emailField.rightViewMode = hasText ? .always : .never
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func dismissKeyboard() { view.endEditing(true) }

    private func setupKeyboardDismiss() {
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard)))
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

        // ── Back button (top-left) ──
        var backConfig = UIButton.Configuration.plain()
        backConfig.image          = UIImage(systemName: "chevron.left")
        backConfig.imagePlacement = .leading
        backConfig.title          = "Back"
        backConfig.baseForegroundColor = .white
        backButton.configuration  = backConfig
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(backButton)

        titleLabel.text          = "Forgot Password"
        titleLabel.font          = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor     = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(titleLabel)

        subtitleLabel.text          = "Enter your email and we'll send\na verification code."
        subtitleLabel.font          = .systemFont(ofSize: 14, weight: .medium)
        subtitleLabel.textColor     = UIColor(white: 0.9, alpha: 1)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(subtitleLabel)

        styleTextField(emailField, placeholder: "Email Address", icon: "envelope", keyboardType: .emailAddress)

        // ── Clear (×) button inside the email field ──
        let clearBtn = UIButton(type: .system)
        clearBtn.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        clearBtn.tintColor = .systemGray3
        clearBtn.frame = CGRect(x: 0, y: 0, width: 36, height: 50)
        clearBtn.contentEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 10)
        clearBtn.addTarget(self, action: #selector(clearFieldsTapped), for: .touchUpInside)
        emailField.rightView     = clearBtn
        emailField.rightViewMode = .never   // shown only when field has text
        emailField.addTarget(self, action: #selector(emailEditingChanged), for: .editingChanged)

        glassCard.addSubview(emailField)

        sendButton.setTitle("Send Code", for: .normal)
        sendButton.backgroundColor    = UIColor(red: 0.0, green: 0.2, blue: 0.4, alpha: 1.0)
        sendButton.layer.cornerRadius = 12
        sendButton.titleLabel?.font   = .systemFont(ofSize: 18, weight: .bold)
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(sendButton)

        NSLayoutConstraint.activate([
            glassCard.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            glassCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            glassCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            glassCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 380),

            backButton.topAnchor.constraint(equalTo: glassCard.topAnchor, constant: 16),
            backButton.leadingAnchor.constraint(equalTo: glassCard.leadingAnchor, constant: 16),

            titleLabel.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 12),
            titleLabel.centerXAnchor.constraint(equalTo: glassCard.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            subtitleLabel.leadingAnchor.constraint(equalTo: glassCard.leadingAnchor, constant: 25),
            subtitleLabel.trailingAnchor.constraint(equalTo: glassCard.trailingAnchor, constant: -25),

            emailField.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 35),
            emailField.leadingAnchor.constraint(equalTo: glassCard.leadingAnchor, constant: 25),
            emailField.trailingAnchor.constraint(equalTo: glassCard.trailingAnchor, constant: -25),
            emailField.heightAnchor.constraint(equalToConstant: 50),

            sendButton.topAnchor.constraint(equalTo: emailField.bottomAnchor, constant: 28),
            sendButton.leadingAnchor.constraint(equalTo: emailField.leadingAnchor),
            sendButton.trailingAnchor.constraint(equalTo: emailField.trailingAnchor),
            sendButton.heightAnchor.constraint(equalToConstant: 50),
            sendButton.bottomAnchor.constraint(equalTo: glassCard.bottomAnchor, constant: -40)
        ])
    }

    private func styleTextField(_ textField: UITextField, placeholder: String, icon: String,
                                 isSecure: Bool = false,
                                 keyboardType: UIKeyboardType = .default) {
        textField.backgroundColor        = .white
        textField.layer.cornerRadius     = 10
        textField.attributedPlaceholder  = NSAttributedString(string: placeholder, attributes: [.foregroundColor: UIColor.systemGray])
        textField.isSecureTextEntry      = isSecure
        textField.textColor              = .black
        textField.autocapitalizationType = .none
        textField.autocorrectionType     = .no
        textField.keyboardType           = keyboardType

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor   = .darkGray
        iconView.contentMode = .scaleAspectFit
        let container        = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 50))
        iconView.frame       = CGRect(x: 12, y: 15, width: 20, height: 20)
        container.addSubview(iconView)
        textField.leftView     = container
        textField.leftViewMode = .always
        textField.translatesAutoresizingMaskIntoConstraints = false
    }
}
