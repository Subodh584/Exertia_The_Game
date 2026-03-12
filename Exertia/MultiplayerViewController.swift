import UIKit

// 1. Define Friend Struct globally here
struct Friend {
    var name: String
    var avatarImageName: String
    var isOnline: Bool
}

class MultiplayerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    // MARK: - Outlets
    @IBOutlet weak var friendsTableView: UITableView!
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var idTextField: UITextField!
    @IBOutlet weak var addFriendPopupView: UIView!
    @IBOutlet weak var blurView: UIVisualEffectView!
    
    // MARK: - Programmatic Tab Bar
    private let tabBarContainer = UIView()
    private let tabBarStackView = UIStackView()
    private let indicatorView = UIView()
    private var tabIcons: [UIImageView] = []
    private var tabLabels: [UILabel] = []
    private var tabWrappers: [UIView] = []
    private let currentTabIndex = 1 // Multiplayer is Index 1
    
    // MARK: - Data
    var onlineFriends: [Friend] = []
    var offlineFriends: [Friend] = []
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupData()
        
        // Setup UI
        friendsTableView.dataSource = self
        friendsTableView.delegate = self
        friendsTableView.backgroundColor = .clear
        friendsTableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 90, right: 0)
        
        stylePopup()
        styleTextField(usernameTextField)
        styleTextField(idTextField)
        
        // Setup Tab Bar
        setupGlassTabBarDesign()
        setupCustomTabs()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tabBarContainer.layoutIfNeeded()
        if tabWrappers.indices.contains(currentTabIndex) {
            moveIndicator(to: tabWrappers[currentTabIndex], animated: false)
        }
    }
    
    // MARK: - Data Setup
    func setupData() {
        // Start with empty arrays, will be populated by API
        onlineFriends = []
        offlineFriends = []
        fetchFriendsFromAPI()
    }
    
    func fetchFriendsFromAPI() {
        guard let userId = UserDefaults.standard.string(forKey: "djangoUserID") else {
            print("⚠️ No Django User ID found. Showing empty friends list.")
            return
        }
        
        Task {
            do {
                // 1. Fetch accepted friendships for this user
                let friendships = try await APIManager.shared.getUserFriends(userId: userId)
                
                var loadedFriends: [Friend] = []
                let avatarImages = ["FriendPFP1", "FriendPFP2", "FriendPFP3", "FriendPFP4", "FriendPFP5"]
                
                for (index, friendship) in friendships.enumerated() {
                    // Determine who is the friend (the other person)
                    let friendId = (friendship.requester == userId) ? friendship.receiver : friendship.requester
                    let friendUsername = (friendship.requester == userId) ? friendship.receiverUsername : friendship.requesterUsername
                    
                    // Fetch the friend's user details to get online status
                    do {
                        let friendUser = try await APIManager.shared.getUser(userId: friendId)
                        let avatarImg = avatarImages[index % avatarImages.count]
                        
                        loadedFriends.append(Friend(
                            name: friendUser.displayName ?? friendUser.username,
                            avatarImageName: avatarImg,
                            isOnline: friendUser.isOnline ?? false
                        ))
                    } catch {
                        // If we can't fetch details, use username only
                        let avatarImg = avatarImages[index % avatarImages.count]
                        loadedFriends.append(Friend(
                            name: friendUsername,
                            avatarImageName: avatarImg,
                            isOnline: false
                        ))
                    }
                }
                
                DispatchQueue.main.async {
                    self.onlineFriends = loadedFriends.filter { $0.isOnline }
                    self.offlineFriends = loadedFriends.filter { !$0.isOnline }
                    self.friendsTableView.reloadData()
                    print("✅ Friends list hydrated from API! Online: \(self.onlineFriends.count), Offline: \(self.offlineFriends.count)")
                }
            } catch {
                print("❌ Failed to fetch friends: \(error)")
            }
        }
    }
    
    // MARK: - Tab Bar Logic
    func setupGlassTabBarDesign() {
        view.addSubview(tabBarContainer)
        tabBarContainer.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            tabBarContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -5),
            tabBarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            tabBarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            tabBarContainer.heightAnchor.constraint(equalToConstant: 70)
        ])
        
        tabBarContainer.backgroundColor = .clear
        let blurEffect = UIBlurEffect(style: .systemThinMaterialDark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = 35
        blurView.clipsToBounds = true
        blurView.isUserInteractionEnabled = false
        tabBarContainer.insertSubview(blurView, at: 0)
        
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: tabBarContainer.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: tabBarContainer.bottomAnchor),
            blurView.leadingAnchor.constraint(equalTo: tabBarContainer.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: tabBarContainer.trailingAnchor)
        ])
        
        tabBarContainer.layer.cornerRadius = 35
        tabBarContainer.layer.borderWidth = 1.0
        tabBarContainer.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        
        indicatorView.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        indicatorView.layer.cornerRadius = 30
        indicatorView.layer.cornerCurve = .continuous
        tabBarContainer.insertSubview(indicatorView, at: 1)
        
        view.bringSubviewToFront(tabBarContainer)
    }
    
    func setupCustomTabs() {
        tabBarStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        tabIcons.removeAll(); tabLabels.removeAll(); tabWrappers.removeAll()
        tabBarStackView.distribution = .fillEqually
        tabBarStackView.translatesAutoresizingMaskIntoConstraints = false
        tabBarContainer.addSubview(tabBarStackView)
        
        NSLayoutConstraint.activate([
            tabBarStackView.topAnchor.constraint(equalTo: tabBarContainer.topAnchor),
            tabBarStackView.bottomAnchor.constraint(equalTo: tabBarContainer.bottomAnchor),
            tabBarStackView.leadingAnchor.constraint(equalTo: tabBarContainer.leadingAnchor, constant: 10),
            tabBarStackView.trailingAnchor.constraint(equalTo: tabBarContainer.trailingAnchor, constant: -10)
        ])
        
        let items = [("home2", "Home"), ("multiplayer2", "Multiplayer"), ("customize2", "Customize"), ("statistics2", "Statistics")]
        
        for (index, (iconName, title)) in items.enumerated() {
            let containerStack = UIStackView()
            containerStack.axis = .vertical
            containerStack.alignment = .center
            containerStack.spacing = 2
            containerStack.isUserInteractionEnabled = false
            
            let iconImageView = UIImageView(image: UIImage(named: iconName))
            iconImageView.contentMode = .scaleAspectFit
            iconImageView.translatesAutoresizingMaskIntoConstraints = false
            iconImageView.widthAnchor.constraint(equalToConstant: 44).isActive = true
            iconImageView.heightAnchor.constraint(equalToConstant: 34).isActive = true
            
            let label = UILabel()
            label.text = title
            label.font = UIFont.systemFont(ofSize: 10, weight: .semibold)
            label.textColor = .lightGray
            label.textAlignment = .center
            
            tabIcons.append(iconImageView)
            tabLabels.append(label)
            containerStack.addArrangedSubview(iconImageView)
            containerStack.addArrangedSubview(label)
            
            let button = UIButton()
            button.tag = index
            button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            button.translatesAutoresizingMaskIntoConstraints = false
            
            let wrapperView = UIView()
            wrapperView.translatesAutoresizingMaskIntoConstraints = false
            wrapperView.addSubview(containerStack)
            wrapperView.addSubview(button)
            tabWrappers.append(wrapperView)
            
            containerStack.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                containerStack.centerXAnchor.constraint(equalTo: wrapperView.centerXAnchor),
                containerStack.centerYAnchor.constraint(equalTo: wrapperView.centerYAnchor),
                button.topAnchor.constraint(equalTo: wrapperView.topAnchor),
                button.bottomAnchor.constraint(equalTo: wrapperView.bottomAnchor),
                button.leadingAnchor.constraint(equalTo: wrapperView.leadingAnchor),
                button.trailingAnchor.constraint(equalTo: wrapperView.trailingAnchor)
            ])
            tabBarStackView.addArrangedSubview(wrapperView)
        }
        updateTabState(selectedIndex: currentTabIndex)
    }
    
    @objc func tabTapped(_ sender: UIButton) {
            let index = sender.tag
            moveIndicator(to: tabWrappers[index], animated: true)
            
            switch index {
            case 0: // Home (Smart Unwind)
                var candidate = self.presentingViewController
                while candidate != nil {
                    if candidate is HomeViewController {
                        candidate?.dismiss(animated: true, completion: nil)
                        return
                    }
                    candidate = candidate?.presentingViewController
                }
                self.dismiss(animated: true, completion: nil)
                
            case 1: // Multiplayer (Current Page)
                break // Do nothing
                
            case 2: // Customize
                let sb = UIStoryboard(name: "Main", bundle: nil)
                if let vc = sb.instantiateViewController(withIdentifier: "CharacterSelectionViewController") as? CharacterSelectionViewController {
                    vc.modalPresentationStyle = .fullScreen
                    vc.modalTransitionStyle = .crossDissolve
                    self.present(vc, animated: true)
                }
                
            case 3: // Statistics
                let sb = UIStoryboard(name: "Main", bundle: nil)
                if let vc = sb.instantiateViewController(withIdentifier: "StatisticsViewController") as? StatisticsViewController {
                    vc.modalPresentationStyle = .fullScreen
                    vc.modalTransitionStyle = .crossDissolve
                    self.present(vc, animated: true)
                }
                
            default: break
            }
        }
    
    func moveIndicator(to targetView: UIView, animated: Bool) {
        let targetFrame = targetView.convert(targetView.bounds, to: tabBarContainer)
        let paddedFrame = targetFrame.insetBy(dx: 4, dy: 4)
        
        UIView.animate(withDuration: animated ? 0.4 : 0.0, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
            self.indicatorView.frame = paddedFrame
        }, completion: nil)
        
        for (i, icon) in tabIcons.enumerated() {
            let isSelected = (tabWrappers[i] == targetView)
            UIView.animate(withDuration: 0.3) {
                icon.alpha = isSelected ? 1.0 : 0.5
                self.tabLabels[i].textColor = isSelected ? .white : .lightGray
                self.tabLabels[i].alpha = isSelected ? 1.0 : 0.5
            }
        }
    }
    
    func updateTabState(selectedIndex: Int) {
        if tabWrappers.indices.contains(selectedIndex) {
            moveIndicator(to: tabWrappers[selectedIndex], animated: false)
        }
    }
    
    // MARK: - Actions
    @IBAction func addFriendButtonTapped(_ sender: Any) {
        blurView.isHidden = false
        addFriendPopupView.isHidden = false
    }
    
    @IBAction func closeAddFriendTapped(_ sender: Any) {
        blurView.isHidden = true
        addFriendPopupView.isHidden = true
    }
    
    @IBAction func backButtonTapped(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func multiplayerBackButtonTapped(_ sender: Any) {
        self.dismiss(animated: true)
    }
    
    // MARK: - Styles
    func stylePopup() {
        addFriendPopupView.layer.cornerRadius = 23
        addFriendPopupView.layer.masksToBounds = true
        addFriendPopupView.layer.borderWidth = 2
        addFriendPopupView.layer.borderColor = UIColor(red: 1.0, green: 0.937, blue: 0.745, alpha: 1.0).cgColor
    }
    
    func styleTextField(_ textField: UITextField) {
        textField.backgroundColor = UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)
        textField.layer.cornerRadius = textField.frame.height / 2
        textField.layer.masksToBounds = true
        textField.layer.borderWidth = 2
        textField.layer.borderColor = UIColor.white.cgColor
        
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 15, height: textField.frame.height))
        textField.leftView = paddingView
        textField.leftViewMode = .always
        
        textField.attributedPlaceholder = NSAttributedString(
            string: textField.placeholder ?? "",
            attributes: [NSAttributedString.Key.foregroundColor: UIColor.gray.withAlphaComponent(0.6)]
        )
    }
    
    // MARK: - Table View
    func numberOfSections(in tableView: UITableView) -> Int { return 2 }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "Online Friends" : "Offline Friends"
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerView = view as? UITableViewHeaderFooterView {
            headerView.textLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
            headerView.textLabel?.textColor = UIColor(red: 1.0, green: 0.937, blue: 0.745, alpha: 1.0)
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? onlineFriends.count : offlineFriends.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FriendCell", for: indexPath) as! FriendTableViewCell
        let friend = indexPath.section == 0 ? onlineFriends[indexPath.row] : offlineFriends[indexPath.row]
        
        cell.nameLabel.text = friend.name
        cell.avatarImageView.image = UIImage(named: friend.avatarImageName)
        cell.statusIndicatorView.isHidden = (indexPath.section != 0)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { return 96 }
}
