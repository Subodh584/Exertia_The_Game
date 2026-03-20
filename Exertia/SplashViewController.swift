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
        // Step 1: Check if we have stored tokens at all
        guard TokenManager.shared.hasTokens,
              TokenManager.shared.accessToken != nil else {
            print("🔐 No stored tokens — going to login")
            goToLogin()
            return
        }

        Task {
            do {
                // Step 2: Try GET /auth/me/ with the stored access token
                let user = try await APIManager.shared.getMe()
                // 200 → user is still logged in
                print("✅ /auth/me/ succeeded — user: \(user.username)")
                // Ensure djangoUserID is stored
                UserDefaults.standard.set(user.id, forKey: "djangoUserID")
                DispatchQueue.main.async { self.goToHome() }
            } catch {
                // Step 3: Access token expired (401) — makeRequest already tried refresh internally
                // If makeRequest's auto-refresh succeeded, it would have returned the user above.
                // If we're here, both access AND refresh failed.
                print("❌ Auth check failed: \(error) — going to login")
                DispatchQueue.main.async {
                    TokenManager.shared.clear()
                    self.goToLogin()
                }
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
