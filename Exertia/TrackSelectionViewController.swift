import UIKit
import AVFoundation

class TrackSelectionViewController: UIViewController {
    @IBOutlet weak var trackTitleName: UILabel!
    @IBOutlet weak var portalBaseView: UIImageView!
    @IBOutlet weak var videoContainerView: UIView!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var profileButton: UIButton!
    @IBOutlet weak var prevTrackTapped: UIButton!
    @IBOutlet weak var nextTrackTapped: UIButton!
    @IBOutlet weak var startButton: UIButton!
    
    var player: AVPlayer?
    var playerLayer: AVPlayerLayer?
    
    struct Track {
        let title: String
        let videoName: String
        let duration: String
        let calories: String
    }
    
    let tracks: [Track] = [
        Track(title: "Earth's Twin", videoName: "planet_green", duration: "25 Min", calories: "150 Kcal"),
        Track(title: "Mars Colony", videoName: "mars_colony", duration: "30 Min", calories: "210 Kcal"),
        Track(title: "Destroyer", videoName: "destroyer_planet", duration: "45 Min", calories: "350 Kcal")
    ]
    
    var currentIndex: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupDesign()
        updateUI()
        setupPortalAnimation()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        startButton.layer.cornerRadius = startButton.frame.height / 2
        profileButton.layer.cornerRadius = profileButton.frame.height / 2
        profileButton.clipsToBounds = true
    }
    
    func setupDesign() {
        videoContainerView.layer.cornerRadius = 20
        videoContainerView.clipsToBounds = false
        videoContainerView.layer.shadowColor = UIColor(red: 0.7, green: 0.3, blue: 1.0, alpha: 1.0).cgColor
        videoContainerView.layer.shadowOpacity = 0.7
        videoContainerView.layer.shadowOffset = .zero
        videoContainerView.layer.shadowRadius = 30
        portalBaseView.transform = CGAffineTransform(scaleX: 6.0, y: 4.0)
        portalBaseView.contentMode = .scaleAspectFit
        portalBaseView.isUserInteractionEnabled = false
        trackTitleName.font = UIFont(name: "Audiowide-Regular", size: 28)
        startButton.backgroundColor = UIColor(red: 0.63, green: 0.31, blue: 0.94, alpha: 0.6)
        startButton.layer.shadowColor = UIColor(red: 0.8, green: 0.5, blue: 1.0, alpha: 1.0).cgColor
        startButton.layer.shadowOpacity = 0.8
        startButton.layer.shadowRadius = 20
        startButton.layer.shadowOffset = .zero
        startButton.layer.borderWidth = 1.5
        startButton.layer.borderColor = UIColor(red: 0.9, green: 0.8, blue: 1.0, alpha: 0.4).cgColor
        startButton.setTitleColor(UIColor(red: 1.0, green: 0.9, blue: 0.8, alpha: 1.0), for: .normal)
        startButton.titleLabel?.font = UIFont(name: "Audiowide-Regular", size: 24) ?? .boldSystemFont(ofSize: 24)
    }
    
    func setupPortalAnimation() {
        var frameArray: [UIImage] = []
        for i in 1...60 {
            let imageName = String(format: "portal_anim%04d", i)
            if let image = UIImage(named: imageName) { frameArray.append(image) }
        }
        if !frameArray.isEmpty {
            portalBaseView.animationImages = frameArray
            portalBaseView.animationDuration = 5.0
            portalBaseView.startAnimating()
        }
    }
    
    func updateUI() {
        let track = tracks[currentIndex]
        trackTitleName.text = track.title
        playVideo(named: track.videoName)
    }
    
    func playVideo(named videoName: String) {
        guard let path = Bundle.main.path(forResource: videoName, ofType: "mp4") else { return }
        player?.pause()
        playerLayer?.removeFromSuperlayer()
        player = AVPlayer(url: URL(fileURLWithPath: path))
        playerLayer = AVPlayerLayer(player: player)
        
        videoContainerView.layoutIfNeeded()
        playerLayer?.frame = videoContainerView.bounds
        playerLayer?.videoGravity = .resizeAspectFill
        playerLayer?.cornerRadius = 20
        playerLayer?.masksToBounds = true
        
        videoContainerView.layer.addSublayer(playerLayer!)
        player?.play()
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem, queue: .main) { _ in
            self.player?.seek(to: .zero)
            self.player?.play()
        }
    }
    
    @IBAction func prevTrackAction(_ sender: UIButton) {
        if currentIndex > 0 { currentIndex -= 1; updateUI() }
    }
    
    @IBAction func nextTrackAction(_ sender: UIButton) {
        if currentIndex < tracks.count - 1 { currentIndex += 1; updateUI() }
    }
    @IBAction func backButtonTapped(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    @IBAction func profileButtonTapped(_ sender: UIButton) {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let profileVC = storyboard.instantiateViewController(withIdentifier: "ProfileViewController")
            profileVC.modalPresentationStyle = .fullScreen
            profileVC.modalTransitionStyle = .coverVertical
            self.present(profileVC, animated: true, completion: nil)
        }
    @IBAction func startButtonTapped(_ sender: UIButton) {
        // Store selected track so the game session can record it
        let trackIds = ["track_001", "track_002", "track_003"]
        let displayNames = ["Earth's Twin", "Mars Colony", "Destroyer"]
        DifficultySettings.shared.setSelectedTrack(
            id: trackIds[currentIndex],
            displayName: displayNames[currentIndex]
        )

        let difficultyVC = DifficultySelectionViewController()
        let navController = UINavigationController(rootViewController: difficultyVC)
        navController.setNavigationBarHidden(true, animated: false)
        navController.modalPresentationStyle = .fullScreen

        difficultyVC.onDifficultySelected = { [weak navController] in
            let cameraVC = CameraViewController()
            navController?.pushViewController(cameraVC, animated: true)
        }

        self.present(navController, animated: true, completion: nil)
    }
}
