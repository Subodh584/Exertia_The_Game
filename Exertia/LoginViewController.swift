import UIKit

class LoginViewController: UIViewController {

    // MARK: - UI Components
    private let backgroundImageView = UIImageView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let glassCard = UIView()
    private let logoImageView = UIImageView()
    private let titleLabel = UILabel()
    private let emailField = UITextField() // Keeping this variable name so constraints don't break
    private let passwordField = UITextField()
    private let signInButton = UIButton()
    private let forgotButton = UIButton()
    private let registerLabel = UILabel()
    private let registerButton = UIButton()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupKeyboardDismiss()
    }

    // MARK: - ACTIONS
    
    @objc func signInTapped() {
            // We use emailField.text here, but treat it as the username!
            guard let username = emailField.text, !username.isEmpty else {
                print("⚠️ Please enter your username")
                return
            }

            print("🔍 Searching Django for user: \(username)...")

            Task {
                do {
                    // 1. Ask APIManager to find the user
                    if let foundUser = try await APIManager.shared.loginUser(username: username) {
                        
                        print("✅ LOGIN SUCCESS! Found user ID: \(foundUser.id)")
                        
                        // 2. Save their ID to the phone
                        UserDefaults.standard.set(foundUser.id, forKey: "djangoUserID")
                        
                        // 3. Mark them as online
                        try? await APIManager.shared.setUserOnline(userId: foundUser.id)
                        
                        // 4. Send them directly to the Home screen
                        DispatchQueue.main.async {
                            let sb = UIStoryboard(name: "Main", bundle: nil)
                            // Make sure the ID below matches your storyboard perfectly
                            if let homeVC = sb.instantiateViewController(withIdentifier: "HomeViewController") as? UIViewController {
                                homeVC.modalPresentationStyle = .fullScreen
                                homeVC.modalTransitionStyle = .crossDissolve
                                self.present(homeVC, animated: true)
                            } else {
                                print("❌ ERROR: Could not find 'HomeViewController' in Main.storyboard")
                            }
                        }
                        
                    } else {
                        print("❌ LOGIN FAILED: Username not found in database.")
                    }
                } catch {
                    print("❌ API ERROR: \(error.localizedDescription)")
                }
            }
        }
    
    @objc func registerTapped() {
            print("📲 Navigating to Register Screen...")
            DispatchQueue.main.async {
                let registerVC = RegisterViewController()
                // Presenting it full screen
                registerVC.modalPresentationStyle = .fullScreen
                registerVC.modalTransitionStyle = .coverVertical
                self.present(registerVC, animated: true, completion: nil)
            }
        }
    
    func navigateToHome() {
        DispatchQueue.main.async {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let homeVC = storyboard.instantiateViewController(withIdentifier: "HomeViewController") as? UIViewController {
                homeVC.modalPresentationStyle = .fullScreen
                homeVC.modalTransitionStyle = .crossDissolve
                self.present(homeVC, animated: true, completion: nil)
                print("✅ NAVIGATION SUCCESS")
            } else {
                print("❌ ERROR: Could not find 'HomeViewController' in Main.storyboard")
            }
        }
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
        
        logoImageView.image = UIImage(named: "ExertiaHomePageTitle")
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(logoImageView)
        
        titleLabel.text = "Login"
        titleLabel.font = .systemFont(ofSize: 26, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(titleLabel)
        
        // 🔥 CHANGED THIS LINE: Now it visually asks for a Username
        styleTextField(emailField, placeholder: "Username", icon: "person")
        styleTextField(passwordField, placeholder: "Password", icon: "lock", isSecure: true)
        
        glassCard.addSubview(emailField)
        glassCard.addSubview(passwordField)
    
        forgotButton.setTitle("Forgot Password?", for: .normal)
        forgotButton.setTitleColor(.white, for: .normal)
        forgotButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        forgotButton.contentHorizontalAlignment = .right
        forgotButton.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(forgotButton)
        
        signInButton.setTitle("Sign in", for: .normal)
        signInButton.backgroundColor = UIColor(red: 0.0, green: 0.2, blue: 0.4, alpha: 1.0)
        signInButton.layer.cornerRadius = 12
        signInButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        signInButton.addTarget(self, action: #selector(signInTapped), for: .touchUpInside)
        signInButton.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(signInButton)
        
        let orLabel = UILabel()
        orLabel.text = "or continue with"
        orLabel.font = .systemFont(ofSize: 14, weight: .medium)
        orLabel.textColor = UIColor(white: 0.9, alpha: 1.0)
        orLabel.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(orLabel)
        
        let socialStack = UIStackView()
        socialStack.spacing = 25
        socialStack.translatesAutoresizingMaskIntoConstraints = false
        
        let appleBtn = createSocialButton(iconName: "apple.logo", isSystem: true)
        let googleBtn = createSocialButton(iconName: "google logo", isSystem: false)
        
        socialStack.addArrangedSubview(appleBtn)
        socialStack.addArrangedSubview(googleBtn)
        glassCard.addSubview(socialStack)
        
        let registerStack = UIStackView()
        registerStack.spacing = 5
        registerStack.translatesAutoresizingMaskIntoConstraints = false
        
        registerLabel.text = "Don't have an account yet?"
        registerLabel.font = .systemFont(ofSize: 14, weight: .medium)
        registerLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
        
        registerButton.setTitle("Register for free", for: .normal)
        registerButton.setTitleColor(.white, for: .normal)
        registerButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        registerButton.addTarget(self, action: #selector(registerTapped), for: .touchUpInside)
        
        registerStack.addArrangedSubview(registerLabel)
        registerStack.addArrangedSubview(registerButton)
        glassCard.addSubview(registerStack)
        
        NSLayoutConstraint.activate([
            glassCard.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            glassCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            glassCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            glassCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 640),
            logoImageView.topAnchor.constraint(equalTo: glassCard.topAnchor, constant: 30),
            logoImageView.centerXAnchor.constraint(equalTo: glassCard.centerXAnchor),
            logoImageView.heightAnchor.constraint(equalToConstant: 140),
            logoImageView.widthAnchor.constraint(equalToConstant: 350),
            
            titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: glassCard.leadingAnchor, constant: 25),
            
            emailField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            emailField.leadingAnchor.constraint(equalTo: glassCard.leadingAnchor, constant: 25),
            emailField.trailingAnchor.constraint(equalTo: glassCard.trailingAnchor, constant: -25),
            emailField.heightAnchor.constraint(equalToConstant: 50),
            
            passwordField.topAnchor.constraint(equalTo: emailField.bottomAnchor, constant: 15),
            passwordField.leadingAnchor.constraint(equalTo: emailField.leadingAnchor),
            passwordField.trailingAnchor.constraint(equalTo: emailField.trailingAnchor),
            passwordField.heightAnchor.constraint(equalToConstant: 50),
            
            forgotButton.topAnchor.constraint(equalTo: passwordField.bottomAnchor, constant: 12),
            forgotButton.trailingAnchor.constraint(equalTo: passwordField.trailingAnchor),
            
            signInButton.topAnchor.constraint(equalTo: forgotButton.bottomAnchor, constant: 25),
            signInButton.leadingAnchor.constraint(equalTo: emailField.leadingAnchor),
            signInButton.trailingAnchor.constraint(equalTo: emailField.trailingAnchor),
            signInButton.heightAnchor.constraint(equalToConstant: 50),
            
            orLabel.topAnchor.constraint(equalTo: signInButton.bottomAnchor, constant: 30),
            orLabel.centerXAnchor.constraint(equalTo: glassCard.centerXAnchor),
            
            socialStack.topAnchor.constraint(equalTo: orLabel.bottomAnchor, constant: 20),
            socialStack.centerXAnchor.constraint(equalTo: glassCard.centerXAnchor),
            
            registerStack.topAnchor.constraint(equalTo: socialStack.bottomAnchor, constant: 40),
            registerStack.centerXAnchor.constraint(equalTo: glassCard.centerXAnchor),
            registerStack.bottomAnchor.constraint(equalTo: glassCard.bottomAnchor, constant: -30)
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

    func createSocialButton(iconName: String, isSystem: Bool = false) -> UIButton {
        let btn = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = .white
        config.cornerStyle = .fixed
        config.background.cornerRadius = 12

        let targetSize = CGSize(width: 24, height: 24)
        var originalImage: UIImage?
        
        if isSystem {
            originalImage = UIImage(systemName: iconName)
            config.baseForegroundColor = .black
        } else {
            originalImage = UIImage(named: iconName)?.withRenderingMode(.alwaysOriginal)
        }

        if let image = originalImage {
            config.image = resizeImage(image: image, targetSize: targetSize)
        }
        
        config.imagePlacement = .all
        btn.configuration = config

        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.widthAnchor.constraint(equalToConstant: 140).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return btn
    }

    func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    func setupKeyboardDismiss() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}
