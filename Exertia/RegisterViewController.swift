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
    
    private let firstNameField = UITextField()
    private let lastNameField = UITextField()
    private let emailField = UITextField()
    private let passwordField = UITextField()
    
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
        guard let email = emailField.text, !email.isEmpty,
              let password = passwordField.text, !password.isEmpty,
              let firstName = firstNameField.text, !firstName.isEmpty else {
            print("⚠️ Please fill in all required fields")
            return
        }
        
        let lastName = lastNameField.text ?? ""
        let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        let username = email.components(separatedBy: "@").first ?? "player\(Int.random(in: 1000...9999))"

        print("🚀 Sending new user to Django Backend on Render...")

        Task {
            do {
                let newUser = try await APIManager.shared.createUser(
                    username: username,
                    displayName: fullName
                )
                
                // SAVE ID LOCALLY
                UserDefaults.standard.set(newUser.id, forKey: "djangoUserID")
                
                print("✅ REAL DATA INSERTED IN DJANGO! User ID: \(newUser.id)")

                DispatchQueue.main.async {
                    let otpVC = OTPViewController()
                    otpVC.modalPresentationStyle = .fullScreen
                    otpVC.modalTransitionStyle = .crossDissolve
                    self.present(otpVC, animated: true)
                }
                
            } catch {
                print("❌ DJANGO INSERT FAILED: \(error)")
            }
        }
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
        glassCard.layer.cornerRadius = 24
        glassCard.layer.borderWidth = 1
        glassCard.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        glassCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(glassCard)
        
        titleLabel.text = "Create Account"
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(titleLabel)
        
        subtitleLabel.text = "Start your fitness journey today"
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        subtitleLabel.textColor = UIColor(white: 0.9, alpha: 1.0)
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(subtitleLabel)
        
        styleTextField(firstNameField, placeholder: "First Name", icon: "person")
        styleTextField(lastNameField, placeholder: "Last Name (Optional)", icon: "person")
        styleTextField(emailField, placeholder: "Email", icon: "envelope")
        styleTextField(passwordField, placeholder: "Password", icon: "lock", isSecure: true)
        
        glassCard.addSubview(firstNameField)
        glassCard.addSubview(lastNameField)
        glassCard.addSubview(emailField)
        glassCard.addSubview(passwordField)
    
        signUpButton.setTitle("Sign Up", for: .normal)
        signUpButton.backgroundColor = UIColor(red: 0.0, green: 0.2, blue: 0.4, alpha: 1.0)
        signUpButton.layer.cornerRadius = 12
        signUpButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        signUpButton.addTarget(self, action: #selector(signUpTapped), for: .touchUpInside)
        signUpButton.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(signUpButton)
        
        loginSwitchStack.spacing = 5
        loginSwitchStack.translatesAutoresizingMaskIntoConstraints = false
        
        alreadyHaveAccountLabel.text = "Already have an account?"
        alreadyHaveAccountLabel.font = .systemFont(ofSize: 14, weight: .medium)
        alreadyHaveAccountLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
        
        loginSwitchButton.setTitle("Sign in", for: .normal)
        loginSwitchButton.setTitleColor(.white, for: .normal)
        loginSwitchButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        loginSwitchButton.addTarget(self, action: #selector(loginSwitchTapped), for: .touchUpInside)
        
        loginSwitchStack.addArrangedSubview(alreadyHaveAccountLabel)
        loginSwitchStack.addArrangedSubview(loginSwitchButton)
        glassCard.addSubview(loginSwitchStack)
        
        NSLayoutConstraint.activate([
            glassCard.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            glassCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            glassCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            glassCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 580),
            
            titleLabel.topAnchor.constraint(equalTo: glassCard.topAnchor, constant: 40),
            titleLabel.centerXAnchor.constraint(equalTo: glassCard.centerXAnchor),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.centerXAnchor.constraint(equalTo: glassCard.centerXAnchor),
            
            firstNameField.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 35),
            firstNameField.leadingAnchor.constraint(equalTo: glassCard.leadingAnchor, constant: 25),
            firstNameField.trailingAnchor.constraint(equalTo: glassCard.trailingAnchor, constant: -25),
            firstNameField.heightAnchor.constraint(equalToConstant: 50),
            
            lastNameField.topAnchor.constraint(equalTo: firstNameField.bottomAnchor, constant: 15),
            lastNameField.leadingAnchor.constraint(equalTo: firstNameField.leadingAnchor),
            lastNameField.trailingAnchor.constraint(equalTo: firstNameField.trailingAnchor),
            lastNameField.heightAnchor.constraint(equalToConstant: 50),
            
            emailField.topAnchor.constraint(equalTo: lastNameField.bottomAnchor, constant: 15),
            emailField.leadingAnchor.constraint(equalTo: firstNameField.leadingAnchor),
            emailField.trailingAnchor.constraint(equalTo: firstNameField.trailingAnchor),
            emailField.heightAnchor.constraint(equalToConstant: 50),
            
            passwordField.topAnchor.constraint(equalTo: emailField.bottomAnchor, constant: 15),
            passwordField.leadingAnchor.constraint(equalTo: firstNameField.leadingAnchor),
            passwordField.trailingAnchor.constraint(equalTo: firstNameField.trailingAnchor),
            passwordField.heightAnchor.constraint(equalToConstant: 50),
            
            signUpButton.topAnchor.constraint(equalTo: passwordField.bottomAnchor, constant: 30),
            signUpButton.leadingAnchor.constraint(equalTo: firstNameField.leadingAnchor),
            signUpButton.trailingAnchor.constraint(equalTo: firstNameField.trailingAnchor),
            signUpButton.heightAnchor.constraint(equalToConstant: 50),
            
            loginSwitchStack.topAnchor.constraint(equalTo: signUpButton.bottomAnchor, constant: 30),
            loginSwitchStack.centerXAnchor.constraint(equalTo: glassCard.centerXAnchor),
            loginSwitchStack.bottomAnchor.constraint(equalTo: glassCard.bottomAnchor, constant: -30)
        ])
    }

    func styleTextField(_ textField: UITextField, placeholder: String, icon: String, isSecure: Bool = false) {
        textField.backgroundColor = .white
        textField.layer.cornerRadius = 10
        textField.placeholder = placeholder
        textField.isSecureTextEntry = isSecure
        textField.textColor = .black
        
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
