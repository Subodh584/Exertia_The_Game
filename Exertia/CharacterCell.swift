import UIKit

class CharacterCell: UICollectionViewCell {

    @IBOutlet weak var thumbImageView: UIImageView!
    @IBOutlet weak var containerView: UIView!
    override func awakeFromNib() {
            super.awakeFromNib()
            
            // 1. Make the main cell transparent
            self.backgroundColor = .clear
            self.layer.backgroundColor = UIColor.clear.cgColor
            
            // 2. Apply rounding to the CONTAINER VIEW, not the whole cell
            containerView.layer.cornerRadius = 12
            containerView.clipsToBounds = true
            
            // 3. Ensure the image can stick out (optional, for the "pop out" effect)
            self.clipsToBounds = false
        }

    func configure(player: Player, isSelected: Bool) {
        thumbImageView.image = UIImage(named: player.thumbnailImageName)
        
        if isSelected {
            containerView.layer.borderWidth = 3
            containerView.layer.borderColor = UIColor.cyan.cgColor
            
            // --- FIX: Change .clear back to your desired purple ---
            // You can use your original semi-transparent purple:
            // Or a solid purple if you prefer:
            containerView.backgroundColor = UIColor(red: 123/255, green: 31/255, blue: 111/255, alpha: 1)
            
        } else {
            containerView.layer.borderWidth = 0
            
            // --- FIX: Change .clear back to your desired non-selected color ---
            // Use your original black/gray:
            containerView.backgroundColor = UIColor(red: 123/255, green: 31/255, blue: 111/255, alpha: 0.7)
        }
    }
    }
