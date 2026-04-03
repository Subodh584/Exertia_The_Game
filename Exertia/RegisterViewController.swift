//
//  RegisterViewController.swift
//  Exertia
//
//  Created by Ekansh Jindal on 27/02/26.
//

import UIKit

class RegisterViewController: UIViewController {

    // MARK: - UI Components
    private let backgroundImageView = UIImageView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let glassCard = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    private let firstNameField       = UITextField()
    private let lastNameField        = UITextField()
    private let emailField           = UITextField()
    private let passwordField        = UITextField()
    private let confirmPasswordField = UITextField()
    
    private let signUpButton = UIButton()
    private let loginSwitchStack = UIStackView()
    private let alreadyHaveAccountLabel = UILabel()
    private let loginSwitchButton = UIButton()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupKeyboardDismiss()
    }

    // MARK: - ACTIONS
    
    @objc func signUpTapped() {
        let firstName = firstNameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let lastName  = lastNameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let email     = emailField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let password  = passwordField.text ?? ""

        // ── Validation ─────────────────────────────────────────────────
        guard !firstName.isEmpty else {
            showAlert(title: "First Name Required", message: "Please enter your first name.")
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
        let confirmPassword = confirmPasswordField.text ?? ""
        guard !confirmPassword.isEmpty else {
            showAlert(title: "Confirm Password Required", message: "Please confirm your password.")
            return
        }
        guard password == confirmPassword else {
            showAlert(title: "Passwords Don't Match", message: "The passwords you entered don't match. Please try again.")
            confirmPasswordField.text = ""
            confirmPasswordField.becomeFirstResponder()
            return
        }

        let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        let username = email.components(separatedBy: "@").first?.lowercased() ?? "player\(Int.random(in: 1000...9999))"

        setLoading(true, title: "Checking…")

        Task {
            defer { DispatchQueue.main.async { self.setLoading(false) } }

            do {
                // 1. Make sure this email isn't already registered
                let exists = try await SupabaseManager.shared.checkEmailExists(email)
                if exists {
                    DispatchQueue.main.async {
                        self.showAlert(title: "Email Taken",
                                       message: "An account with this email already exists. Try logging in instead.")
                    }
                    return
                }

                // 2. Ask the mail server to send an OTP (URL fetched fresh inside sendOTP)
                DispatchQueue.main.async { self.setLoading(true, title: "Sending code…") }
                try await MailServerManager.sendOTP(to: email, purpose: "register")

                print("✅ OTP sent to \(email). Navigating to verification…")

                // 3. Hand off to OTPViewController — actual Supabase signup happens AFTER verification
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
                    self.showAlert(title: "Something Went Wrong",
                                   message: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Loading state helper
    private func setLoading(_ loading: Bool, title: String = "Sign Up") {
        signUpButton.isEnabled = !loading
        signUpButton.setTitle(loading ? title : "Sign Up", for: .normal)
        signUpButton.alpha = loading ? 0.7 : 1.0
    }

    // MARK: - Alert Helper
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc func loginSwitchTapped() {
        self.dismiss(animated: true, completion: nil)
    }

    // MARK: - UI Setup
    func setupUI() {
        backgroundImageView.image = UIImage(named: "loading background")
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
        glassCard.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        glassCard.layer.cornerRadius = Responsive.cornerRadius(24)
        glassCard.layer.borderWidth = 1
        glassCard.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        glassCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(glassCard)
        
        titleLabel.text = "Create Account"
        titleLabel.font = .systemFont(ofSize: Responsive.font(28), weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(titleLabel)
        
        subtitleLabel.text = "Start your fitness journey today"
        subtitleLabel.font = .systemFont(ofSize: Responsive.font(14), weight: .medium)
        subtitleLabel.textColor = UIColor(white: 0.9, alpha: 1.0)
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(subtitleLabel)
        
        styleTextField(firstNameField,       placeholder: "First Name",           icon: "person",    capitalization: .words)
        styleTextField(lastNameField,        placeholder: "Last Name (Optional)", icon: "person",    capitalization: .words)
        styleTextField(emailField,           placeholder: "Email",                icon: "envelope",  keyboardType: .emailAddress)
        styleTextField(passwordField,        placeholder: "Password",             icon: "lock",      isSecure: true)
        styleTextField(confirmPasswordField, placeholder: "Confirm Password",     icon: "lock.fill", isSecure: true)

        glassCard.addSubview(firstNameField)
        glassCard.addSubview(lastNameField)
        glassCard.addSubview(emailField)
        glassCard.addSubview(passwordField)
        glassCard.addSubview(confirmPasswordField)
    
        signUpButton.setTitle("Sign Up", for: .normal)
        signUpButton.backgroundColor = UIColor(red: 0.0, green: 0.2, blue: 0.4, alpha: 1.0)
        signUpButton.layer.cornerRadius = Responsive.cornerRadius(12)
        signUpButton.titleLabel?.font = .systemFont(ofSize: Responsive.font(18), weight: .bold)
        signUpButton.addTarget(self, action: #selector(signUpTapped), for: .touchUpInside)
        signUpButton.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(signUpButton)
        
        loginSwitchStack.spacing = 5
        loginSwitchStack.translatesAutoresizingMaskIntoConstraints = false
        
        alreadyHaveAccountLabel.text = "Already have an account?"
        alreadyHaveAccountLabel.font = .systemFont(ofSize: Responsive.font(14), weight: .medium)
        alreadyHaveAccountLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
        
        loginSwitchButton.setTitle("Sign in", for: .normal)
        loginSwitchButton.setTitleColor(.white, for: .normal)
        loginSwitchButton.titleLabel?.font = .systemFont(ofSize: Responsive.font(16), weight: .bold)
        loginSwitchButton.addTarget(self, action: #selector(loginSwitchTapped), for: .touchUpInside)
        
        loginSwitchStack.addArrangedSubview(alreadyHaveAccountLabel)
        loginSwitchStack.addArrangedSubview(loginSwitchButton)
        glassCard.addSubview(loginSwitchStack)
        
        NSLayoutConstraint.activate([
            glassCard.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            glassCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Responsive.contentInset),
            glassCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Responsive.contentInset),
            glassCard.heightAnchor.constraint(greaterThanOrEqualToConstant: Responsive.verticalSize(645)),

            titleLabel.topAnchor.constraint(equalTo: glassCard.topAnchor, constant: Responsive.padding(40)),
            titleLabel.centerXAnchor.constraint(equalTo: glassCard.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Responsive.padding(8)),
            subtitleLabel.centerXAnchor.constraint(equalTo: glassCard.centerXAnchor),

            firstNameField.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: Responsive.padding(35)),
            firstNameField.leadingAnchor.constraint(equalTo: glassCard.leadingAnchor, constant: Responsive.padding(25)),
            firstNameField.trailingAnchor.constraint(equalTo: glassCard.trailingAnchor, constant: -Responsive.padding(25)),
            firstNameField.heightAnchor.constraint(equalToConstant: Responsive.size(50)),

            lastNameField.topAnchor.constraint(equalTo: firstNameField.bottomAnchor, constant: Responsive.padding(15)),
            lastNameField.leadingAnchor.constraint(equalTo: firstNameField.leadingAnchor),
            lastNameField.trailingAnchor.constraint(equalTo: firstNameField.trailingAnchor),
            lastNameField.heightAnchor.constraint(equalToConstant: Responsive.size(50)),

            emailField.topAnchor.constraint(equalTo: lastNameField.bottomAnchor, constant: Responsive.padding(15)),
            emailField.leadingAnchor.constraint(equalTo: firstNameField.leadingAnchor),
            emailField.trailingAnchor.constraint(equalTo: firstNameField.trailingAnchor),
            emailField.heightAnchor.constraint(equalToConstant: Responsive.size(50)),

            passwordField.topAnchor.constraint(equalTo: emailField.bottomAnchor, constant: Responsive.padding(15)),
            passwordField.leadingAnchor.constraint(equalTo: firstNameField.leadingAnchor),
            passwordField.trailingAnchor.constraint(equalTo: firstNameField.trailingAnchor),
            passwordField.heightAnchor.constraint(equalToConstant: Responsive.size(50)),

            confirmPasswordField.topAnchor.constraint(equalTo: passwordField.bottomAnchor, constant: Responsive.padding(15)),
            confirmPasswordField.leadingAnchor.constraint(equalTo: firstNameField.leadingAnchor),
            confirmPasswordField.trailingAnchor.constraint(equalTo: firstNameField.trailingAnchor),
            confirmPasswordField.heightAnchor.constraint(equalToConstant: Responsive.size(50)),

            signUpButton.topAnchor.constraint(equalTo: confirmPasswordField.bottomAnchor, constant: Responsive.padding(30)),
            signUpButton.leadingAnchor.constraint(equalTo: firstNameField.leadingAnchor),
            signUpButton.trailingAnchor.constraint(equalTo: firstNameField.trailingAnchor),
            signUpButton.heightAnchor.constraint(equalToConstant: Responsive.size(50)),

            loginSwitchStack.topAnchor.constraint(equalTo: signUpButton.bottomAnchor, constant: Responsive.padding(30)),
            loginSwitchStack.centerXAnchor.constraint(equalTo: glassCard.centerXAnchor),
            loginSwitchStack.bottomAnchor.constraint(equalTo: glassCard.bottomAnchor, constant: -Responsive.padding(30))
        ])
    }

    func styleTextField(_ textField: UITextField, placeholder: String, icon: String,
                        isSecure: Bool = false, keyboardType: UIKeyboardType = .default,
                        capitalization: UITextAutocapitalizationType = .none) {
        textField.backgroundColor = .white
        textField.layer.cornerRadius = 10
        textField.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [.foregroundColor: UIColor.systemGray])
        textField.isSecureTextEntry = isSecure
        textField.textColor = .black
        textField.autocapitalizationType = capitalization
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        textField.keyboardType = keyboardType

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = .darkGray
        iconView.contentMode = .scaleAspectFit

        let leftContainer = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 50))
        iconView.frame = CGRect(x: 12, y: 15, width: 20, height: 20)
        leftContainer.addSubview(iconView)

        textField.leftView = leftContainer
        textField.leftViewMode = .always
        textField.translatesAutoresizingMaskIntoConstraints = false
    }

    func setupKeyboardDismiss() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}
