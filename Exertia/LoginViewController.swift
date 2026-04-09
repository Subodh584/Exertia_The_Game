import UIKit
import AuthenticationServices
import Supabase

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
    private var googleBtn: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupKeyboardDismiss()
    }

    // MARK: - ACTIONS

    @objc func signInTapped() {
        let username = emailField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let password = passwordField.text ?? ""

        // ── Field validation ──────────────────────────────────────────
        guard !username.isEmpty else {
            showAlert(title: "Username Required",
                      message: "Please enter your username to continue.")
            shakeField(emailField)
            return
        }
        guard !password.isEmpty else {
            showAlert(title: "Password Required",
                      message: "Please enter your password to continue.")
            shakeField(passwordField)
            return
        }

        // ── Show loading state ─────────────────────────────────────────
        setSignInLoading(true)
        print("🔐 Attempting login for: \(username)…")

        Task {
            defer { DispatchQueue.main.async { self.setSignInLoading(false) } }

            do {
                // 1. Look up the user's email from their username
                guard let foundUser = try await SupabaseManager.shared.findUserByUsername(username) else {
                    throw LoginError.userNotFound
                }
                guard let email = foundUser.email, !email.isEmpty else {
                    throw LoginError.userNotFound
                }

                // 2. Sign in with Supabase Auth using email + password
                let user = try await SupabaseManager.shared.signIn(email: email, password: password)

                print("✅ LOGIN SUCCESS! User ID: \(user.id)")
                UserDefaults.standard.set(user.id, forKey: "supabaseUserID")
                await SupabaseManager.shared.setUserOnline()

                DispatchQueue.main.async {
                    let sb = UIStoryboard(name: "Main", bundle: nil)
                    let homeVC = sb.instantiateViewController(withIdentifier: "HomeViewController")
                    homeVC.modalPresentationStyle = .fullScreen
                    homeVC.modalTransitionStyle = .crossDissolve
                    self.present(homeVC, animated: true)
                }

            } catch LoginError.invalidCredentials {
                print("❌ LOGIN FAILED: Wrong password.")
                DispatchQueue.main.async {
                    self.showAlert(title: "Incorrect Password",
                                   message: "The password you entered is wrong. Please try again.")
                    self.shakeField(self.passwordField)
                    self.passwordField.text = ""
                }
            } catch LoginError.userNotFound {
                print("❌ LOGIN FAILED: Username not found.")
                DispatchQueue.main.async {
                    self.showAlert(title: "User Not Found",
                                   message: "No account with that username exists. Please check the spelling or register.")
                    self.shakeField(self.emailField)
                }
            } catch LoginError.networkError {
                print("❌ LOGIN FAILED: Network error.")
                DispatchQueue.main.async {
                    self.showAlert(title: "Connection Error",
                                   message: "Could not reach the server. Please check your internet connection and try again.")
                }
            } catch {
                print("❌ LOGIN FAILED: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.showAlert(title: "Login Failed",
                                   message: "Something went wrong. Please try again.")
                }
            }
        }
    }

    // MARK: - Alert Helper
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Shake Animation (iOS-style wrong-field feedback)
    private func shakeField(_ field: UITextField) {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = 0.5
        animation.values = [-10, 10, -8, 8, -5, 5, -2, 2, 0]
        field.layer.add(animation, forKey: "shake")
    }

    // MARK: - Loading State
    private func setSignInLoading(_ loading: Bool) {
        signInButton.isEnabled = !loading
        signInButton.setTitle(loading ? "Signing in…" : "Sign in", for: .normal)
        signInButton.alpha = loading ? 0.7 : 1.0
    }
    
    @objc private func toggleLoginPasswordVisibility(_ sender: UIButton) {
        passwordField.isSecureTextEntry.toggle()
        let icon = passwordField.isSecureTextEntry ? "eye.slash" : "eye"
        sender.setImage(UIImage(systemName: icon), for: .normal)
    }

    @objc func forgotPasswordTapped() {
        let forgotVC = ForgotPasswordViewController()
        forgotVC.modalPresentationStyle = .fullScreen
        forgotVC.modalTransitionStyle   = .crossDissolve
        present(forgotVC, animated: true)
    }

    @objc func registerTapped() {
        print("📲 Navigating to Register Screen...")
        DispatchQueue.main.async {
            let registerVC = RegisterViewController()
            registerVC.modalPresentationStyle = .fullScreen
            registerVC.modalTransitionStyle = .coverVertical
            self.present(registerVC, animated: true, completion: nil)
        }
    }

    // MARK: - OAuth Actions

    @objc func googleSignInTapped() {
        handleOAuthSignIn(provider: .google)
    }

    private func handleOAuthSignIn(provider: Auth.Provider) {
        googleBtn.isEnabled = false

        Task {
            defer {
                DispatchQueue.main.async {
                    self.googleBtn.isEnabled = true
                }
            }

            do {
                try await SupabaseManager.shared.signInWithOAuth(provider: provider)

                guard let authUser = SupabaseManager.shared.client.auth.currentUser else {
                    throw NSError(domain: "OAuth", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "No user after sign-in"])
                }

                let userId = authUser.id.uuidString
                UserDefaults.standard.set(userId, forKey: "supabaseUserID")
                await SupabaseManager.shared.setUserOnline()

                print("✅ OAuth sign-in success! User: \(userId)")

                // Check if user needs to complete their profile
                let profileComplete = try await SupabaseManager.shared.isProfileComplete(userId: userId)

                if !profileComplete {
                    // First-time OAuth user — create a minimal row, then go to onboarding
                    let email = authUser.email ?? ""
                    let displayName: String? = {
                        if case let .string(name) = authUser.userMetadata["full_name"] { return name }
                        return nil
                    }()

                    // Only create row if it doesn't exist at all
                    let users: [AppUser] = try await SupabaseManager.shared.client.from("users")
                        .select().eq("id", value: userId).execute().value
                    if users.isEmpty {
                        try await SupabaseManager.shared.createOAuthUserRow(
                            userId: userId, email: email, displayName: displayName)
                    }

                    DispatchQueue.main.async {
                        let onboardingVC = OnboardingProfileViewController()
                        onboardingVC.isOAuthUser = true
                        onboardingVC.modalPresentationStyle = .fullScreen
                        onboardingVC.modalTransitionStyle = .crossDissolve
                        self.present(onboardingVC, animated: true)
                    }
                } else {
                    // Returning OAuth user — go straight to home
                    DispatchQueue.main.async {
                        self.navigateToHome()
                    }
                }

            } catch let error as ASWebAuthenticationSessionError
                        where error.code == .canceledLogin {
                print("ℹ️ User cancelled OAuth sign-in")
            } catch {
                print("❌ OAuth sign-in failed: \(error)")
                DispatchQueue.main.async {
                    self.showAlert(title: "Sign-In Failed",
                                   message: "Could not complete sign-in. Please try again.")
                }
            }
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
        glassCard.layer.cornerRadius = Responsive.cornerRadius(24)
        glassCard.layer.borderWidth = 1
        glassCard.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        glassCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(glassCard)
        
        logoImageView.image = UIImage(named: "ExertiaHomePageTitle")
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(logoImageView)
        
        titleLabel.text = "Login"
        titleLabel.font = .systemFont(ofSize: Responsive.font(26), weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(titleLabel)
        
        // 🔥 CHANGED THIS LINE: Now it visually asks for a Username
        styleTextField(emailField, placeholder: "Username", icon: "person")
        styleTextField(passwordField, placeholder: "Password", icon: "lock", isSecure: true)

        // Eye toggle for password
        let eyeBtn = UIButton(type: .custom)
        eyeBtn.setImage(UIImage(systemName: "eye.slash"), for: .normal)
        eyeBtn.tintColor = .darkGray
        eyeBtn.frame = CGRect(x: 0, y: 0, width: 44, height: 50)
        eyeBtn.contentEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 12)
        eyeBtn.addTarget(self, action: #selector(toggleLoginPasswordVisibility(_:)), for: .touchUpInside)
        passwordField.rightView     = eyeBtn
        passwordField.rightViewMode = .always

        glassCard.addSubview(emailField)
        glassCard.addSubview(passwordField)
    
        forgotButton.setTitle("Forgot Password?", for: .normal)
        forgotButton.setTitleColor(.white, for: .normal)
        forgotButton.titleLabel?.font = .systemFont(ofSize: Responsive.font(14), weight: .medium)
        forgotButton.contentHorizontalAlignment = .right
        forgotButton.addTarget(self, action: #selector(forgotPasswordTapped), for: .touchUpInside)
        forgotButton.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(forgotButton)
        
        signInButton.setTitle("Sign in", for: .normal)
        signInButton.backgroundColor = UIColor(red: 0.0, green: 0.2, blue: 0.4, alpha: 1.0)
        signInButton.layer.cornerRadius = Responsive.cornerRadius(12)
        signInButton.titleLabel?.font = .systemFont(ofSize: Responsive.font(18), weight: .bold)
        signInButton.addTarget(self, action: #selector(signInTapped), for: .touchUpInside)
        signInButton.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(signInButton)
        
        let orLabel = UILabel()
        orLabel.text = "or continue with"
        orLabel.font = .systemFont(ofSize: Responsive.font(14), weight: .medium)
        orLabel.textColor = UIColor(white: 0.9, alpha: 1.0)
        orLabel.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(orLabel)
        
        let socialStack = UIStackView()
        socialStack.spacing = Responsive.padding(25)
        socialStack.translatesAutoresizingMaskIntoConstraints = false
        
        googleBtn = createSocialButton(iconName: "google logo", isSystem: false)
        googleBtn.addTarget(self, action: #selector(googleSignInTapped), for: .touchUpInside)

        socialStack.addArrangedSubview(googleBtn)
        glassCard.addSubview(socialStack)
        
        let registerStack = UIStackView()
        registerStack.spacing = 5
        registerStack.translatesAutoresizingMaskIntoConstraints = false
        
        registerLabel.text = "Don't have an account yet?"
        registerLabel.font = .systemFont(ofSize: Responsive.font(14), weight: .medium)
        registerLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
        
        registerButton.setTitle("Register for free", for: .normal)
        registerButton.setTitleColor(.white, for: .normal)
        registerButton.titleLabel?.font = .systemFont(ofSize: Responsive.font(16), weight: .bold)
        registerButton.addTarget(self, action: #selector(registerTapped), for: .touchUpInside)
        
        registerStack.addArrangedSubview(registerLabel)
        registerStack.addArrangedSubview(registerButton)
        glassCard.addSubview(registerStack)
        
        NSLayoutConstraint.activate([
            glassCard.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            glassCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Responsive.contentInset),
            glassCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Responsive.contentInset),
            glassCard.heightAnchor.constraint(greaterThanOrEqualToConstant: Responsive.verticalSize(640)),
            logoImageView.topAnchor.constraint(equalTo: glassCard.topAnchor, constant: Responsive.padding(30)),
            logoImageView.centerXAnchor.constraint(equalTo: glassCard.centerXAnchor),
            logoImageView.heightAnchor.constraint(equalToConstant: Responsive.size(140)),
            logoImageView.widthAnchor.constraint(equalToConstant: Responsive.size(350)),

            titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: Responsive.padding(10)),
            titleLabel.leadingAnchor.constraint(equalTo: glassCard.leadingAnchor, constant: Responsive.padding(25)),

            emailField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Responsive.padding(20)),
            emailField.leadingAnchor.constraint(equalTo: glassCard.leadingAnchor, constant: Responsive.padding(25)),
            emailField.trailingAnchor.constraint(equalTo: glassCard.trailingAnchor, constant: -Responsive.padding(25)),
            emailField.heightAnchor.constraint(equalToConstant: Responsive.size(50)),

            passwordField.topAnchor.constraint(equalTo: emailField.bottomAnchor, constant: Responsive.padding(15)),
            passwordField.leadingAnchor.constraint(equalTo: emailField.leadingAnchor),
            passwordField.trailingAnchor.constraint(equalTo: emailField.trailingAnchor),
            passwordField.heightAnchor.constraint(equalToConstant: Responsive.size(50)),

            forgotButton.topAnchor.constraint(equalTo: passwordField.bottomAnchor, constant: Responsive.padding(12)),
            forgotButton.trailingAnchor.constraint(equalTo: passwordField.trailingAnchor),

            signInButton.topAnchor.constraint(equalTo: forgotButton.bottomAnchor, constant: Responsive.padding(25)),
            signInButton.leadingAnchor.constraint(equalTo: emailField.leadingAnchor),
            signInButton.trailingAnchor.constraint(equalTo: emailField.trailingAnchor),
            signInButton.heightAnchor.constraint(equalToConstant: Responsive.size(50)),

            orLabel.topAnchor.constraint(equalTo: signInButton.bottomAnchor, constant: Responsive.padding(30)),
            orLabel.centerXAnchor.constraint(equalTo: glassCard.centerXAnchor),

            socialStack.topAnchor.constraint(equalTo: orLabel.bottomAnchor, constant: Responsive.padding(20)),
            socialStack.centerXAnchor.constraint(equalTo: glassCard.centerXAnchor),

            registerStack.topAnchor.constraint(equalTo: socialStack.bottomAnchor, constant: Responsive.padding(40)),
            registerStack.centerXAnchor.constraint(equalTo: glassCard.centerXAnchor),
            registerStack.bottomAnchor.constraint(equalTo: glassCard.bottomAnchor, constant: -Responsive.padding(30))
        ])
    }

    func styleTextField(_ textField: UITextField, placeholder: String, icon: String, isSecure: Bool = false) {
        textField.backgroundColor = .white
        textField.layer.cornerRadius = Responsive.cornerRadius(10)
        textField.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [.foregroundColor: UIColor.systemGray])
        textField.isSecureTextEntry = isSecure
        textField.textColor = .black
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no

        let iconSize = Responsive.size(20)
        let containerWidth = Responsive.size(40)
        let containerHeight = Responsive.size(50)
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = .darkGray
        iconView.contentMode = .scaleAspectFit

        let leftContainer = UIView(frame: CGRect(x: 0, y: 0, width: containerWidth, height: containerHeight))
        iconView.frame = CGRect(x: Responsive.padding(12), y: (containerHeight - iconSize) / 2, width: iconSize, height: iconSize)
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
        config.background.cornerRadius = Responsive.cornerRadius(12)

        let iconDim = Responsive.size(24)
        let targetSize = CGSize(width: iconDim, height: iconDim)
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
        btn.widthAnchor.constraint(equalToConstant: Responsive.size(140)).isActive = true
        btn.heightAnchor.constraint(equalToConstant: Responsive.size(50)).isActive = true
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
