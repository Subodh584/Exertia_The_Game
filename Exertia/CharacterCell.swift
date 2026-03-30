import UIKit

class CharacterCell: UICollectionViewCell {

    @IBOutlet weak var thumbImageView: UIImageView!
    @IBOutlet weak var containerView: UIView!
    
    private let glossLayer = CAGradientLayer()
    
    override func awakeFromNib() {
        super.awakeFromNib()

        self.backgroundColor = .clear
        containerView.backgroundColor = .clear

        containerView.layer.cornerRadius = 20
        containerView.layer.cornerCurve = .continuous
        containerView.clipsToBounds = true
        
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOffset = CGSize(width: 0, height: 4)
        self.layer.shadowRadius = 6
        self.layer.shadowOpacity = 0.3
        self.clipsToBounds = false

        setupGlossLayer()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        glossLayer.frame = containerView.bounds

        if let blurView = containerView.subviews.first(where: { $0 is UIVisualEffectView }) {
            blurView.frame = containerView.bounds
        }
    }
    
    private func setupGlossLayer() {
        glossLayer.colors = [
            UIColor.white.withAlphaComponent(0.15).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor
        ]
        glossLayer.startPoint = CGPoint(x: 0, y: 0)
        glossLayer.endPoint = CGPoint(x: 1, y: 1)
        glossLayer.cornerRadius = 20
        glossLayer.cornerCurve = .continuous
    }

    func configure(player: Player, isSelected: Bool, isLocked: Bool = false) {
        // Always clean up previous state first
        containerView.subviews.filter { $0 is UIVisualEffectView }.forEach { $0.removeFromSuperview() }
        containerView.subviews.filter { $0.tag == 902 }.forEach { $0.removeFromSuperview() }
        glossLayer.removeFromSuperlayer()

        if isLocked {
            // Character is completely hidden — just a solid dark cell
            thumbImageView.isHidden = true
            containerView.backgroundColor = UIColor(red: 0.09, green: 0.09, blue: 0.12, alpha: 1)

            // Lock icon — golden colour matching the character name label ("GLITCH" yellow)
            let gold = UIColor(red: 0.96, green: 0.83, blue: 0.38, alpha: 1)
            let cfg  = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
            let lockImg = UIImageView(image: UIImage(systemName: "lock.fill", withConfiguration: cfg))
            lockImg.tag = 902
            lockImg.tintColor = gold
            lockImg.contentMode = .scaleAspectFit
            lockImg.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(lockImg)
            NSLayoutConstraint.activate([
                lockImg.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                lockImg.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                lockImg.widthAnchor.constraint(equalToConstant: 28),
                lockImg.heightAnchor.constraint(equalToConstant: 28)
            ])

            containerView.layer.borderWidth = 1.0
            containerView.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
            self.layer.shadowColor   = UIColor.black.cgColor
            self.layer.shadowRadius  = 4
            self.layer.shadowOpacity = 0.2

        } else {
            // Character is visible
            thumbImageView.isHidden = false
            thumbImageView.image = UIImage(named: "CharacterAssetThumbnail")
            containerView.backgroundColor = .clear

            let blurStyle: UIBlurEffect.Style = isSelected ? .systemMaterialLight : .systemUltraThinMaterialDark
            let blurView = UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
            blurView.frame = containerView.bounds
            blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            containerView.insertSubview(blurView, at: 0)
            containerView.layer.insertSublayer(glossLayer, at: 1)

            if isSelected {
                containerView.layer.borderWidth = 2
                containerView.layer.borderColor = UIColor.cyan.cgColor
                self.layer.shadowColor   = UIColor.cyan.cgColor
                self.layer.shadowRadius  = 10
                self.layer.shadowOpacity = 0.6
                animateSelection()
            } else {
                containerView.layer.borderWidth = 1.0
                containerView.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
                self.layer.shadowColor   = UIColor.black.cgColor
                self.layer.shadowRadius  = 5
                self.layer.shadowOpacity = 0.3
            }
        }
    }

    func animateSelection() {
        UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseIn, animations: {
            self.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        }) { _ in
            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
                self.transform = CGAffineTransform.identity
            }, completion: nil)
        }
    }
}
