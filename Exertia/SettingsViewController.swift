import UIKit

class SettingsViewController: UIViewController {

    private let backgroundImageView = UIImageView()
    private let headerView = UIView()
    private let backButton = UIButton()
    private let titleLabel = UILabel()
    
    private let logoutButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backButton.layer.cornerRadius = backButton.frame.height / 2
    }

    func setupUI() {
        // Match Background
        view.backgroundColor = UIColor(red: 0.05, green: 0.02, blue: 0.1, alpha: 1.0)
        backgroundImageView.image = UIImage(named: "WhatsApp Image 2025-09-24 at 14.26.03")
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.alpha = 0.4
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundImageView)
        view.sendSubviewToBack(backgroundImageView)
        
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        setupHeader()
        
        // Setup Logout Button
        logoutButton.setTitle("Log Out", for: .normal)
        logoutButton.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        logoutButton.setTitleColor(.white, for: .normal)
        logoutButton.layer.cornerRadius = 16
        logoutButton.layer.borderWidth = 1
        logoutButton.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        logoutButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        logoutButton.translatesAutoresizingMaskIntoConstraints = false
        logoutButton.addTarget(self, action: #selector(logoutTapped), for: .touchUpInside)
        
        // Setup Delete Button
        deleteButton.setTitle("Delete Account", for: .normal)
        deleteButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.8)
        deleteButton.setTitleColor(.white, for: .normal)
        deleteButton.layer.cornerRadius = 16
        deleteButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        
        let stack = UIStackView(arrangedSubviews: [logoutButton, deleteButton])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            logoutButton.heightAnchor.constraint(equalToConstant: 55),
            deleteButton.heightAnchor.constraint(equalToConstant: 55)
        ])
    }
    
    func setupHeader() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)
        
        // Glass Back Button
        backButton.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        backButton.layer.borderWidth = 1
        backButton.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
        backButton.setImage(UIImage(systemName: "chevron.left", withConfiguration: config), for: .normal)
        backButton.tintColor = .white
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        
        // Title
        titleLabel.text = "Settings"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        headerView.addSubview(backButton)
        headerView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 60),
            
            backButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            backButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),
            
            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
        ])
    }

    // MARK: - Actions
    
    @objc func backTapped() {
        dismiss(animated: true, completion: nil)
    }

    @objc func logoutTapped() {
            print("🚪 Logging out...")
            
            // 1. Set user offline in Django before logging out
            if let userId = UserDefaults.standard.string(forKey: "djangoUserID") {
                Task {
                    try? await APIManager.shared.setUserOffline(userId: userId)
                }
            }
            
            // 2. Delete the Django User ID from the phone's memory
            UserDefaults.standard.removeObject(forKey: "djangoUserID")
            print("✅ Cleared local user data.")
            
            // 3. Go back to the Login Screen
            DispatchQueue.main.async {
                self.navigateToLogin()
            }
        }
        
        @objc func deleteTapped() {
            let alert = UIAlertController(title: "Delete Account?", message: "This cannot be undone and will erase all data.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
                print("🗑️ Deleting account...")
                
                Task {
                    // Set user offline in Django
                    if let userId = UserDefaults.standard.string(forKey: "djangoUserID") {
                        try? await APIManager.shared.setUserOffline(userId: userId)
                    }
                    
                    // Try to delete from Supabase
                    try? await SupabaseManager.shared.deleteAccount()
                    
                    // Clear local data
                    UserDefaults.standard.removeObject(forKey: "djangoUserID")
                    
                    // Go back to the login screen
                    self.navigateToLogin()
                }
            }))
            present(alert, animated: true)
        }
    
    func navigateToLogin() {
        DispatchQueue.main.async {
            let sb = UIStoryboard(name: "Main", bundle: nil)
            if let loginVC = sb.instantiateViewController(withIdentifier: "LoginViewController") as? LoginViewController {
                loginVC.modalPresentationStyle = .fullScreen
                self.present(loginVC, animated: true)
            }
        }
    }
}
