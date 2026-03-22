import UIKit
import Lottie

class SplashViewController: UIViewController {

    private let backgroundImageView = UIImageView()
    private let logoImageView = UIImageView()
    private let loadingLabel = UILabel()
    private var animationView: LottieAnimationView?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateOpeningSequence()
    }

    func setupUI() {
        view.backgroundColor = .black

        backgroundImageView.image = UIImage(named: "loading background")
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.alpha = 0
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundImageView)

        logoImageView.image = UIImage(named: "ExertiaHomePageTitle")
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.alpha = 0
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logoImageView)

        loadingLabel.text = "Burn calories while defeating villains"
        loadingLabel.font = .systemFont(ofSize: 16, weight: .medium)
        loadingLabel.textColor = UIColor(white: 0.9, alpha: 1.0)
        loadingLabel.alpha = 0
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingLabel)

        animationView = LottieAnimationView(name: "space_loader")

        if let animationView = animationView {
            animationView.contentMode = .scaleAspectFit
            animationView.loopMode = .loop
            animationView.animationSpeed = 1.0
            animationView.alpha = 0
            animationView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(animationView)
            NSLayoutConstraint.activate([
                animationView.bottomAnchor.constraint(equalTo: loadingLabel.topAnchor, constant: -10),
                animationView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                animationView.widthAnchor.constraint(equalToConstant: 120),
                animationView.heightAnchor.constraint(equalToConstant: 120)
            ])
        }
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 350),
            logoImageView.heightAnchor.constraint(equalToConstant: 140),
            loadingLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60),
            loadingLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    func animateOpeningSequence() {
        UIView.animate(withDuration: 1.5, animations: {
            self.logoImageView.alpha = 1.0
            self.logoImageView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }) { _ in
            UIView.animate(withDuration: 0.8, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
                self.logoImageView.transform = CGAffineTransform(translationX: 0, y: -180)
                self.backgroundImageView.alpha = 1.0
                self.loadingLabel.alpha = 1.0
                self.animationView?.alpha = 1.0
            }) { _ in
                self.animationView?.play()
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.checkAuthAndNavigate()
                }
            }
        }
    }

    func checkAuthAndNavigate() {
        // Migrate tokens stored in UserDefaults (old format) to Keychain
        TokenManager.shared.migrateFromUserDefaultsIfNeeded()

        // No refresh token at all → must log in
        guard TokenManager.shared.hasTokens else {
            print("🔐 No stored refresh token — going to login")
            goToLogin()
            return
        }

        Task {
            let result = await APIManager.shared.refreshTokenResult()

            switch result {
            case .success:
                // Token refreshed — fetch latest user profile and go home
                if let userId = UserDefaults.standard.string(forKey: "djangoUserID") {
                    if let user = try? await APIManager.shared.getUser(userId: userId) {
                        UserDefaults.standard.set(user.id, forKey: "djangoUserID")
                        print("✅ Token refreshed, user: \(user.username) — going home")
                    }
                }
                DispatchQueue.main.async { self.goToHome() }

            case .expired:
                // Token is definitively invalid (401/403) — must log in again
                print("🔐 Refresh token expired — must log in again")
                DispatchQueue.main.async {
                    TokenManager.shared.clear()
                    UserDefaults.standard.removeObject(forKey: "djangoUserID")
                    self.goToLogin()
                }

            case .serverError:
                // Server unreachable / cold-starting — tokens are likely still valid.
                // Go home; individual screens will retry API calls on 401 automatically.
                print("⚠️ Server unreachable during refresh — proceeding to home (tokens kept)")
                DispatchQueue.main.async { self.goToHome() }
            }
        }
    }

    func goToLogin() {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        if let loginVC = sb.instantiateViewController(withIdentifier: "LoginViewController") as? LoginViewController {
            loginVC.modalPresentationStyle = .fullScreen
            loginVC.modalTransitionStyle = .crossDissolve
            self.present(loginVC, animated: true)
        }
    }

    func goToHome() {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        if let homeVC = sb.instantiateViewController(withIdentifier: "HomeViewController") as? HomeViewController {
            homeVC.modalPresentationStyle = .fullScreen
            homeVC.modalTransitionStyle = .crossDissolve
            self.present(homeVC, animated: true)
        }
    }
}
