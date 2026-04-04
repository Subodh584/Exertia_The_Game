//
//  RegisterViewController.swift
//  Exertia
//
//  Created by Ekansh Jindal on 27/02/26.
//

import UIKit

class RegisterViewController: UIViewController, UITextFieldDelegate {

    // MARK: - UI Components
    private let backgroundImageView = UIImageView()
    private let scrollView          = UIScrollView()
    private let contentView         = UIView()

    private let glassCard      = UIView()
    private let titleLabel     = UILabel()
    private let subtitleLabel  = UILabel()

    private let firstNameField       = UITextField()
    private let lastNameField        = UITextField()
    private let usernameField        = UITextField()
    private let emailField           = UITextField()
    private let passwordField        = UITextField()
    private let confirmPasswordField = UITextField()

    // Username live-check
    private let usernameStatusLabel    = UILabel()
    private let usernameCheckIndicator = UIActivityIndicatorView(style: .medium)
    private var debounceTimer: Timer?
    private var usernameValidated = false

    // Password live-match
    private let passwordMatchLabel = UILabel()

    // Eye toggle buttons
    private let passwordEyeButton        = UIButton(type: .custom)
    private let confirmPasswordEyeButton = UIButton(type: .custom)

    private let signUpButton          = UIButton()
    private let loginSwitchStack      = UIStackView()
    private let alreadyHaveAccountLabel = UILabel()
    private let loginSwitchButton     = UIButton()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupKeyboardDismiss()
        usernameField.delegate = self
        usernameField.addTarget(self,         action: #selector(usernameTextChanged),    for: .editingChanged)
        passwordField.addTarget(self,         action: #selector(passwordChanged),        for: .editingChanged)
        confirmPasswordField.addTarget(self,  action: #selector(confirmPasswordChanged), for: .editingChanged)
    }

    // MARK: - Sign Up action

    @objc func signUpTapped() {
        let firstName = firstNameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let lastName  = lastNameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let username  = usernameField.text ?? ""
        let email     = emailField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let password  = passwordField.text ?? ""
        let confirm   = confirmPasswordField.text ?? ""

        guard !firstName.isEmpty else {
            showAlert(title: "First Name Required", message: "Please enter your first name.")
            return
        }
        guard username.count >= 3, usernameValidated else {
            showAlert(title: "Username Required", message: "Please choose an available username (min 3 characters).")
            return
        }
        guard !email.isEmpty else {
            showAlert(title: "Email Required", message: "Please enter your email address.")
            return
        }
        guard email.contains("@") else {
            showAlert(title: "Invalid Email", message: "Please enter a valid email address.")
            return
        }
        guard !password.isEmpty else {
            showAlert(title: "Password Required", message: "Please choose a password.")
            return
        }
        guard password.count >= 6 else {
            showAlert(title: "Password Too Short", message: "Your password must be at least 6 characters.")
            return
        }
        guard !confirm.isEmpty else {
            showAlert(title: "Confirm Password Required", message: "Please confirm your password.")
            return
        }
        guard password == confirm else {
            showAlert(title: "Passwords Don't Match", message: "The passwords you entered don't match.")
            confirmPasswordField.text = ""
            confirmPasswordField.becomeFirstResponder()
            return
        }

        let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        setLoading(true, title: "Checking…")

        Task {
            defer { DispatchQueue.main.async { self.setLoading(false) } }

            do {
                let exists = try await SupabaseManager.shared.checkEmailExists(email)
                if exists {
                    DispatchQueue.main.async {
                        self.showAlert(title: "Email Taken",
                                       message: "An account with this email already exists. Try logging in instead.")
                    }
                    return
                }

                DispatchQueue.main.async { self.setLoading(true, title: "Sending code…") }
                try await MailServerManager.sendOTP(to: email, purpose: "register")
                print("✅ OTP sent to \(email).")

                DispatchQueue.main.async {
                    let otpVC = OTPViewController()
                    otpVC.mode        = .register
                    otpVC.email       = email
                    otpVC.password    = password
                    otpVC.displayName = fullName
                    otpVC.username    = username
                    otpVC.modalPresentationStyle = .fullScreen
                    otpVC.modalTransitionStyle   = .crossDissolve
                    self.present(otpVC, animated: true)
                }

            } catch {
                print("❌ Registration pre-check failed: \(error)")
                DispatchQueue.main.async {
                    self.showAlert(title: "Something Went Wrong", message: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Username live validation

    @objc private func usernameTextChanged() {
        let raw       = usernameField.text ?? ""
        let corrected = String(raw.lowercased().filter { !$0.isWhitespace })
        if raw != corrected { usernameField.text = corrected }

        debounceTimer?.invalidate()
        usernameValidated = false

        let text = corrected
        guard text.count >= 3 else {
            if text.isEmpty { clearUsernameStatus() }
            else            { setUsernameStatus("Min. 3 chars", color: .systemOrange) }
            usernameCheckIndicator.stopAnimating()
            return
        }

        clearUsernameStatus()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
            self?.performUsernameCheck(text)
        }
    }

    private func performUsernameCheck(_ username: String) {
        usernameCheckIndicator.startAnimating()
        usernameStatusLabel.isHidden = true

        Task {
            do {
                let taken = try await SupabaseManager.shared.checkUsernameExists(username)
                DispatchQueue.main.async {
                    self.usernameCheckIndicator.stopAnimating()
                    if taken {
                        self.setUsernameStatus("Already taken", color: .systemRed)
                        self.usernameValidated = false
                    } else {
                        self.setUsernameStatus("Available", color: .systemGreen)
                        self.usernameValidated = true
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.usernameCheckIndicator.stopAnimating()
                    self.setUsernameStatus("Check failed", color: .systemOrange)
                    self.usernameValidated = false
                }
            }
        }
    }

    private func setUsernameStatus(_ text: String, color: UIColor) {
        usernameStatusLabel.isHidden        = false
        usernameStatusLabel.text            = text
        usernameStatusLabel.textColor       = .white
        usernameStatusLabel.backgroundColor = color.withAlphaComponent(0.85)
        UIView.animate(withDuration: 0.25) {
            self.usernameField.layer.borderColor = color.withAlphaComponent(0.8).cgColor
            self.usernameField.layer.borderWidth = 1.5
        }
    }

    private func clearUsernameStatus() {
        usernameStatusLabel.isHidden        = true
        usernameStatusLabel.text            = nil
        usernameStatusLabel.backgroundColor = .clear
        UIView.animate(withDuration: 0.25) {
            self.usernameField.layer.borderWidth = 0
        }
    }

    // MARK: - Password live match

    @objc private func passwordChanged() {
        guard !(confirmPasswordField.text?.isEmpty ?? true) else { return }
        updatePasswordMatchIndicator()
    }

    @objc private func confirmPasswordChanged() {
        updatePasswordMatchIndicator()
    }

    private func updatePasswordMatchIndicator() {
        let pw      = passwordField.text ?? ""
        let confirm = confirmPasswordField.text ?? ""

        guard !confirm.isEmpty else {
            passwordMatchLabel.isHidden = true
            UIView.animate(withDuration: 0.2) { self.confirmPasswordField.layer.borderWidth = 0 }
            return
        }

        let matched = pw == confirm
        passwordMatchLabel.isHidden        = false
        passwordMatchLabel.text            = matched ? "Match" : "No match"
        passwordMatchLabel.textColor       = .white
        passwordMatchLabel.backgroundColor = (matched ? UIColor.systemGreen : UIColor.systemRed).withAlphaComponent(0.85)

        let borderColor = matched ? UIColor.systemGreen : UIColor.systemRed
        UIView.animate(withDuration: 0.2) {
            self.confirmPasswordField.layer.borderColor = borderColor.withAlphaComponent(0.8).cgColor
            self.confirmPasswordField.layer.borderWidth = 1.5
        }
    }

    // MARK: - Eye toggle

    @objc private func togglePasswordVisibility() {
        passwordField.isSecureTextEntry.toggle()
        let icon = passwordField.isSecureTextEntry ? "eye.slash" : "eye"
        passwordEyeButton.setImage(UIImage(systemName: icon), for: .normal)
    }

    @objc private func toggleConfirmPasswordVisibility() {
        confirmPasswordField.isSecureTextEntry.toggle()
        let icon = confirmPasswordField.isSecureTextEntry ? "eye.slash" : "eye"
        confirmPasswordEyeButton.setImage(UIImage(systemName: icon), for: .normal)
    }

    // MARK: - Helpers

    private func setLoading(_ loading: Bool, title: String = "Sign Up") {
        signUpButton.isEnabled = !loading
        signUpButton.setTitle(loading ? title : "Sign Up", for: .normal)
        signUpButton.alpha = loading ? 0.7 : 1.0
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc func loginSwitchTapped() { dismiss(animated: true) }

    // MARK: - Eye button helper
    private func makeEyeButton(action: Selector) -> UIButton {
        let btn = UIButton(type: .custom)
        btn.setImage(UIImage(systemName: "eye.slash"), for: .normal)
        btn.tintColor = .darkGray
        btn.frame = CGRect(x: 0, y: 0, width: 44, height: 50)
        btn.contentEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 12)
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }

    // MARK: - UI Setup

    func setupUI() {
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

    func setupGlassCard() {
        glassCard.backgroundColor    = UIColor.white.withAlphaComponent(0.15)
        glassCard.layer.cornerRadius = Responsive.cornerRadius(24)
        glassCard.layer.borderWidth  = 1
        glassCard.layer.borderColor  = UIColor.white.withAlphaComponent(0.3).cgColor
        glassCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(glassCard)

        // Title
        titleLabel.text          = "Create Account"
        titleLabel.font          = .systemFont(ofSize: Responsive.font(28), weight: .bold)
        titleLabel.textColor     = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(titleLabel)

        // Subtitle
        subtitleLabel.text          = "Start your fitness journey today"
        subtitleLabel.font          = .systemFont(ofSize: Responsive.font(14), weight: .medium)
        subtitleLabel.textColor     = UIColor(white: 0.9, alpha: 1.0)
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(subtitleLabel)

        // ── Name row (side by side) ──
        styleTextField(firstNameField, placeholder: "First Name", icon: "person",    capitalization: .words)
        styleTextField(lastNameField,  placeholder: "Last Name",  icon: "person",    capitalization: .words)
        glassCard.addSubview(firstNameField)
        glassCard.addSubview(lastNameField)

        // ── Username field ──
        styleTextField(usernameField, placeholder: "Username", icon: "at")

        let usernameContainer = UIView(frame: CGRect(x: 0, y: 0, width: 130, height: 50))
        usernameCheckIndicator.color = .darkGray
        usernameCheckIndicator.hidesWhenStopped = true
        usernameCheckIndicator.frame = CGRect(x: 105, y: 15, width: 20, height: 20)
        usernameContainer.addSubview(usernameCheckIndicator)

        usernameStatusLabel.font            = .systemFont(ofSize: 11, weight: .semibold)
        usernameStatusLabel.textAlignment   = .center
        usernameStatusLabel.layer.cornerRadius = 8
        usernameStatusLabel.clipsToBounds   = true
        usernameStatusLabel.frame           = CGRect(x: 5, y: 13, width: 112, height: 24)
        usernameStatusLabel.isHidden        = true
        usernameContainer.addSubview(usernameStatusLabel)

        usernameField.rightView     = usernameContainer
        usernameField.rightViewMode = .always
        glassCard.addSubview(usernameField)

        // ── Email ──
        styleTextField(emailField, placeholder: "Email", icon: "envelope", keyboardType: .emailAddress)
        glassCard.addSubview(emailField)

        // ── Password with eye toggle ──
        styleTextField(passwordField, placeholder: "Password", icon: "lock", isSecure: true)
        let pwEye = makeEyeButton(action: #selector(togglePasswordVisibility))
        passwordField.rightView     = pwEye
        passwordField.rightViewMode = .always
        glassCard.addSubview(passwordField)

        // ── Confirm Password with eye + live match pill ──
        styleTextField(confirmPasswordField, placeholder: "Confirm", icon: "lock.fill", isSecure: true)

        // Combined right view: match pill + eye button
        let confirmRightContainer = UIView(frame: CGRect(x: 0, y: 0, width: 130, height: 50))
        passwordMatchLabel.font            = .systemFont(ofSize: 11, weight: .semibold)
        passwordMatchLabel.textAlignment   = .center
        passwordMatchLabel.layer.cornerRadius = 8
        passwordMatchLabel.clipsToBounds   = true
        passwordMatchLabel.frame           = CGRect(x: 0, y: 13, width: 80, height: 24)
        passwordMatchLabel.isHidden        = true
        confirmRightContainer.addSubview(passwordMatchLabel)

        let cpEye = makeEyeButton(action: #selector(toggleConfirmPasswordVisibility))
        cpEye.frame = CGRect(x: 86, y: 0, width: 44, height: 50)
        confirmRightContainer.addSubview(cpEye)

        confirmPasswordField.rightView     = confirmRightContainer
        confirmPasswordField.rightViewMode = .always
        glassCard.addSubview(confirmPasswordField)

        // ── Sign Up button ──
        signUpButton.setTitle("Sign Up", for: .normal)
        signUpButton.setTitleColor(.white, for: .normal)
        signUpButton.backgroundColor    = UIColor(red: 0.0, green: 0.2, blue: 0.4, alpha: 1.0)
        signUpButton.layer.cornerRadius = Responsive.cornerRadius(12)
        signUpButton.titleLabel?.font   = .systemFont(ofSize: Responsive.font(18), weight: .bold)
        signUpButton.addTarget(self, action: #selector(signUpTapped), for: .touchUpInside)
        signUpButton.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(signUpButton)

        // ── Sign in switch ──
        alreadyHaveAccountLabel.text      = "Already have an account?"
        alreadyHaveAccountLabel.font      = .systemFont(ofSize: Responsive.font(14), weight: .medium)
        alreadyHaveAccountLabel.textColor = UIColor(white: 0.8, alpha: 1.0)

        loginSwitchButton.setTitle("Sign in", for: .normal)
        loginSwitchButton.setTitleColor(.white, for: .normal)
        loginSwitchButton.titleLabel?.font = .systemFont(ofSize: Responsive.font(16), weight: .bold)
        loginSwitchButton.addTarget(self, action: #selector(loginSwitchTapped), for: .touchUpInside)

        loginSwitchStack.spacing = 5
        loginSwitchStack.translatesAutoresizingMaskIntoConstraints = false
        loginSwitchStack.addArrangedSubview(alreadyHaveAccountLabel)
        loginSwitchStack.addArrangedSubview(loginSwitchButton)
        glassCard.addSubview(loginSwitchStack)

        // ── Constraints ──
        let pad: CGFloat  = Responsive.padding(25)
        let gap: CGFloat  = 8
        let rowH: CGFloat = Responsive.size(50)
        let rowGap: CGFloat = Responsive.padding(12)

        NSLayoutConstraint.activate([
            glassCard.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            glassCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Responsive.contentInset),
            glassCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Responsive.contentInset),

            titleLabel.topAnchor.constraint(equalTo: glassCard.topAnchor, constant: Responsive.padding(36)),
            titleLabel.centerXAnchor.constraint(equalTo: glassCard.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Responsive.padding(6)),
            subtitleLabel.centerXAnchor.constraint(equalTo: glassCard.centerXAnchor),

            // Name row — side by side
            firstNameField.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: Responsive.padding(24)),
            firstNameField.leadingAnchor.constraint(equalTo: glassCard.leadingAnchor, constant: pad),
            firstNameField.trailingAnchor.constraint(equalTo: glassCard.centerXAnchor, constant: -(gap / 2)),
            firstNameField.heightAnchor.constraint(equalToConstant: rowH),

            lastNameField.topAnchor.constraint(equalTo: firstNameField.topAnchor),
            lastNameField.leadingAnchor.constraint(equalTo: glassCard.centerXAnchor, constant: gap / 2),
            lastNameField.trailingAnchor.constraint(equalTo: glassCard.trailingAnchor, constant: -pad),
            lastNameField.heightAnchor.constraint(equalToConstant: rowH),

            usernameField.topAnchor.constraint(equalTo: firstNameField.bottomAnchor, constant: rowGap),
            usernameField.leadingAnchor.constraint(equalTo: glassCard.leadingAnchor, constant: pad),
            usernameField.trailingAnchor.constraint(equalTo: glassCard.trailingAnchor, constant: -pad),
            usernameField.heightAnchor.constraint(equalToConstant: rowH),

            emailField.topAnchor.constraint(equalTo: usernameField.bottomAnchor, constant: rowGap),
            emailField.leadingAnchor.constraint(equalTo: glassCard.leadingAnchor, constant: pad),
            emailField.trailingAnchor.constraint(equalTo: glassCard.trailingAnchor, constant: -pad),
            emailField.heightAnchor.constraint(equalToConstant: rowH),

            passwordField.topAnchor.constraint(equalTo: emailField.bottomAnchor, constant: rowGap),
            passwordField.leadingAnchor.constraint(equalTo: glassCard.leadingAnchor, constant: pad),
            passwordField.trailingAnchor.constraint(equalTo: glassCard.trailingAnchor, constant: -pad),
            passwordField.heightAnchor.constraint(equalToConstant: rowH),

            confirmPasswordField.topAnchor.constraint(equalTo: passwordField.bottomAnchor, constant: rowGap),
            confirmPasswordField.leadingAnchor.constraint(equalTo: glassCard.leadingAnchor, constant: pad),
            confirmPasswordField.trailingAnchor.constraint(equalTo: glassCard.trailingAnchor, constant: -pad),
            confirmPasswordField.heightAnchor.constraint(equalToConstant: rowH),

            signUpButton.topAnchor.constraint(equalTo: confirmPasswordField.bottomAnchor, constant: Responsive.padding(24)),
            signUpButton.leadingAnchor.constraint(equalTo: glassCard.leadingAnchor, constant: pad),
            signUpButton.trailingAnchor.constraint(equalTo: glassCard.trailingAnchor, constant: -pad),
            signUpButton.heightAnchor.constraint(equalToConstant: rowH),

            loginSwitchStack.topAnchor.constraint(equalTo: signUpButton.bottomAnchor, constant: Responsive.padding(20)),
            loginSwitchStack.centerXAnchor.constraint(equalTo: glassCard.centerXAnchor),
            loginSwitchStack.bottomAnchor.constraint(equalTo: glassCard.bottomAnchor, constant: -Responsive.padding(28))
        ])
    }

    // MARK: - Style helper

    func styleTextField(_ textField: UITextField, placeholder: String, icon: String,
                        isSecure: Bool = false, keyboardType: UIKeyboardType = .default,
                        capitalization: UITextAutocapitalizationType = .none) {
        textField.backgroundColor = .white
        textField.layer.cornerRadius = Responsive.cornerRadius(10)
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.systemGray]
        )
        textField.isSecureTextEntry      = isSecure
        textField.textColor              = .black
        textField.autocapitalizationType = capitalization
        textField.autocorrectionType     = .no
        textField.spellCheckingType      = .no
        textField.keyboardType           = keyboardType

        let iconView             = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor       = .darkGray
        iconView.contentMode     = .scaleAspectFit
        let leftContainer        = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 50))
        iconView.frame           = CGRect(x: 12, y: 15, width: 20, height: 20)
        leftContainer.addSubview(iconView)
        textField.leftView       = leftContainer
        textField.leftViewMode   = .always
        textField.translatesAutoresizingMaskIntoConstraints = false
    }

    // MARK: - Keyboard dismiss

    func setupKeyboardDismiss() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
    }

    @objc func dismissKeyboard() { view.endEditing(true) }
}
