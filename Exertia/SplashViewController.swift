import UIKit
import Lottie
import SceneKit

class SplashViewController: UIViewController {

    private let backgroundImageView = UIImageView()
    private let logoImageView = UIImageView()
    private let loadingLabel = UILabel()
    private var animationView: LottieAnimationView?

    /// Tracks whether both conditions are met before navigating:
    /// 1. Minimum splash time elapsed   2. Character preload finished
    private var animationTimerDone = false
    private var preloadDone = false
    private var hasNavigated = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()

        // Listen for preload completion
        NotificationCenter.default.addObserver(
            self, selector: #selector(onPreloadReady),
            name: .characterPreviewReady, object: nil
        )

        // Start preloading the 3D character model
        AssetLoader.shared.preloadCharacterPreview()

        // Safety timeout: if preload takes longer than 8 seconds, navigate anyway
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) { [weak self] in
            guard let self = self, !self.hasNavigated else { return }
            print("⚠️ Character preload timed out — navigating anyway")
            self.preloadDone = true
            self.navigateIfReady()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AudioManager.shared.playAppMusic()
        animateOpeningSequence()
    }

    @objc private func onPreloadReady() {
        preloadDone = true
        navigateIfReady()
    }

    /// Only navigates when both the minimum animation time AND preload are done.
    private func navigateIfReady() {
        guard animationTimerDone, preloadDone, !hasNavigated else { return }
        hasNavigated = true
        checkAuthAndNavigate()
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


        loadingLabel.text = "Outrun the universe."
        loadingLabel.font = .systemFont(ofSize: Responsive.font(16), weight: .medium)

        loadingLabel.textColor = UIColor(white: 0.9, alpha: 1.0)
        loadingLabel.alpha = 0
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingLabel)

        let config = LottieConfiguration(renderingEngine: .coreAnimation)
        animationView = .init(dotLottieName: "rocket_animation", configuration: config)

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
                animationView.widthAnchor.constraint(equalToConstant: Responsive.size(120)),
                animationView.heightAnchor.constraint(equalToConstant: Responsive.size(120))
            ])
        }
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: Responsive.size(350)),
            logoImageView.heightAnchor.constraint(equalToConstant: Responsive.size(140)),
            loadingLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Responsive.padding(60)),
            loadingLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    func animateOpeningSequence() {
        UIView.animate(withDuration: 1.5, animations: {
            self.logoImageView.alpha = 1.0
            self.logoImageView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }) { _ in
            UIView.animate(withDuration: 0.8, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
                self.logoImageView.transform = CGAffineTransform(translationX: 0, y: -Responsive.verticalSize(180))
                self.backgroundImageView.alpha = 1.0
                self.loadingLabel.alpha = 1.0
                self.animationView?.alpha = 1.0
            }) { _ in
                self.animationView?.play()
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.animationTimerDone = true
                    self.navigateIfReady()
                }
            }
        }
    }

    func checkAuthAndNavigate() {
        // No Supabase session → must log in
        guard SupabaseManager.shared.hasSession else {
            print("🔐 No Supabase session — going to login")
            goToLogin()
            return
        }

        Task {
            do {
                if let user = try await SupabaseManager.shared.restoreSession() {
                    UserDefaults.standard.set(user.id, forKey: "supabaseUserID")
                    print("✅ Session restored, user: \(user.username ?? "unknown") — going home")
                    DispatchQueue.main.async { self.goToHome() }
                } else {
                    print("🔐 Could not restore session — going to login")
                    DispatchQueue.main.async {
                        UserDefaults.standard.removeObject(forKey: "supabaseUserID")
                        self.goToLogin()
                    }
                }
            } catch {
                // Network error — session might still be valid, go home
                print("⚠️ Session restore error: \(error) — proceeding to home")
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
