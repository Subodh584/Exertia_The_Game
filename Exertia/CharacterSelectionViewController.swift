import UIKit

class CharacterSelectionViewController: UIViewController {

    // MARK: - Outlets
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var mainCharacterImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    
    // MARK: - Data
    // We reference the static data we created earlier
    let players = GameData.players
    
    // Tracks which player is currently active
    var selectedIndex: Int = 0
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        backgroundImageView.addBlurEffect(style: .dark, alpha: 0.25)
        
        setupCollectionView()
        
        // Load the initial player (Index 0)
        updateMainDisplay(index: 0)
    }
    
    // MARK: - Setup
    func setupCollectionView() {
        collectionView.delegate = self
        collectionView.dataSource = self
        
        // REGISTER THE XIB FILE
        // This tells the Collection View to look for "CharacterCell.xib"
        let nib = UINib(nibName: "CharacterCell", bundle: nil)
        collectionView.register(nib, forCellWithReuseIdentifier: "CharacterCellID")
        
        // Optional: clear background so the main screen background shows through
        collectionView.backgroundColor = .clear
    }
    
    // MARK: - Update UI Logic
    func updateMainDisplay(index: Int) {
        let player = players[index]
        
        // 1. Text Updates
        nameLabel.text = player.name.uppercased()
        descriptionLabel.text = player.description
        
        // 2. Animate Character Swap (Cross Dissolve)
        UIView.transition(with: mainCharacterImageView, duration: 0.3, options: .transitionCrossDissolve, animations: {
            self.mainCharacterImageView.image = UIImage(named: player.fullBodyImageName)
        }, completion: nil)
        
        // 3. Animate Background Swap (Slower transition for depth effect)
        UIView.transition(with: backgroundImageView, duration: 0.5, options: .transitionCrossDissolve, animations: {
            self.backgroundImageView.image = UIImage(named: player.backgroundImageName)
        }, completion: nil)
    }
}

// MARK: - Collection View DataSource & Delegate
// MARK: - Collection View DataSource & Delegate
extension CharacterSelectionViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    // ---------------------------------------------------------
    // MARK: - MASTER SETTINGS (CHANGE THESE NUMBERS)
    // ---------------------------------------------------------
    // 1. How much space do you want between the cells?
    private var spacingBetweenCells: CGFloat { return 15}
    
    // 2. How much empty space do you want around the edges? (Top, Left, Bottom, Right)
    private var edgeInsetPadding: CGFloat { return 20 }
    
    // 3. Grid Dimensions
    private var cellsPerRow: CGFloat { return 3 }
    private var rowsPerScreen: CGFloat { return 2 }
    // ---------------------------------------------------------

    
    // MARK: - DataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 6
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CharacterCellID", for: indexPath) as? CharacterCell else {
            return UICollectionViewCell()
        }
        
        let player = players[indexPath.row]
        let isSelected = (indexPath.row == selectedIndex)
        cell.configure(player: player, isSelected: isSelected)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedIndex = indexPath.row
        updateMainDisplay(index: selectedIndex)
        collectionView.reloadData()
    }

    // MARK: - Layout (The Math)
    
    // 1. Calculate Cell Size
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        // --- Calculate Width ---
        let totalHorizontalPadding = (edgeInsetPadding * 2) // Left + Right padding
        let totalGapSpace = (cellsPerRow - 1) * spacingBetweenCells // Space between columns
        
        let availableWidth = collectionView.bounds.width - totalHorizontalPadding - totalGapSpace
        let width = availableWidth / cellsPerRow
        
        // --- Calculate Height ---
        let totalVerticalPadding = (edgeInsetPadding * 2) // Top + Bottom padding
        let totalLineSpace = (rowsPerScreen - 1) * spacingBetweenCells // Space between rows
        
        let availableHeight = collectionView.bounds.height - totalVerticalPadding - totalLineSpace
        let height = availableHeight / rowsPerScreen
        
        return CGSize(width: width, height: height)
    }
    
    // 2. Set Outer Margins (The "Frame" around the cells)
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: edgeInsetPadding, left: edgeInsetPadding, bottom: edgeInsetPadding, right: edgeInsetPadding)
    }
    
    // 3. Set Horizontal Spacing (Between Columns)
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return spacingBetweenCells
    }
    
    // 4. Set Vertical Spacing (Between Rows)
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return spacingBetweenCells
    }
}

extension UIImageView {
    func addBlurEffect(style: UIBlurEffect.Style = .regular, alpha: CGFloat = 1.0) {
        // 1. Remove any existing blur first
        removeBlurEffect()

        // 2. Create the blur view
        let blurEffect = UIBlurEffect(style: style)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        
        blurEffectView.frame = self.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // 3. SET THE INTENSITY (Alpha)
        // 1.0 = Full Blur, 0.0 = No Blur
        blurEffectView.alpha = alpha
        
        self.addSubview(blurEffectView)
    }
    
    func removeBlurEffect() {
        for subview in self.subviews {
            if subview is UIVisualEffectView {
                subview.removeFromSuperview()
            }
        }
    }
}
