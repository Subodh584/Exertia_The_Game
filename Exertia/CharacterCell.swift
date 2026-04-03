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

    func configure(player: Player, isSelected: Bool, isLocked: Bool = false, characterIndex: Int = 0) {
        // Always clean up previous state first
        containerView.subviews.filter { $0 is UIVisualEffectView }.forEach { $0.removeFromSuperview() }
        containerView.subviews.filter { $0.tag == 902 }.forEach { $0.removeFromSuperview() }
        containerView.layer.sublayers?.filter { $0 is CAGradientLayer && $0 !== glossLayer }.forEach { $0.removeFromSuperlayer() }
        glossLayer.removeFromSuperlayer()

        if isLocked {
            thumbImageView.isHidden = true

            // Deep space gradient background
            let gradientLayer = CAGradientLayer()
            gradientLayer.colors = [
                UIColor(red: 0.04, green: 0.06, blue: 0.14, alpha: 1).cgColor,
                UIColor(red: 0.08, green: 0.12, blue: 0.22, alpha: 1).cgColor,
                UIColor(red: 0.05, green: 0.08, blue: 0.16, alpha: 1).cgColor
            ]
            gradientLayer.locations = [0.0, 0.5, 1.0]
            gradientLayer.startPoint = CGPoint(x: 0, y: 0)
            gradientLayer.endPoint = CGPoint(x: 1, y: 1)
            gradientLayer.frame = containerView.bounds
            gradientLayer.cornerRadius = 20
            containerView.layer.insertSublayer(gradientLayer, at: 0)
            containerView.backgroundColor = .clear

            // Frosted glass overlay
            let frostedBlur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
            frostedBlur.frame = containerView.bounds
            frostedBlur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            frostedBlur.alpha = 0.5
            containerView.addSubview(frostedBlur)

            // Character thumbnail (dimmed) behind the lock
            let charImageName = "char\(characterIndex + 1)"
            let charThumb = UIImageView()
            charThumb.tag = 902
            charThumb.image = UIImage(named: charImageName)
            charThumb.contentMode = .scaleAspectFit
            charThumb.alpha = 0.8
            charThumb.clipsToBounds = true
            charThumb.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(charThumb)
            NSLayoutConstraint.activate([
                charThumb.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                charThumb.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                charThumb.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 0.75),
                charThumb.heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 0.75)
            ])

            // Lock icon with a subtle glowing halo
            let teal = UIColor(red: 0.0, green: 0.85, blue: 0.85, alpha: 1)
            let lockCfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
            let lockImg = UIImageView(image: UIImage(systemName: "lock.fill", withConfiguration: lockCfg))
            lockImg.tag = 902
            lockImg.tintColor = teal
            lockImg.contentMode = .scaleAspectFit
            lockImg.translatesAutoresizingMaskIntoConstraints = false
            // Glow halo behind lock
            lockImg.layer.shadowColor = teal.cgColor
            lockImg.layer.shadowRadius = 8
            lockImg.layer.shadowOpacity = 0.7
            lockImg.layer.shadowOffset = .zero
            containerView.addSubview(lockImg)
            NSLayoutConstraint.activate([
                lockImg.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                lockImg.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                lockImg.widthAnchor.constraint(equalToConstant: 18),
                lockImg.heightAnchor.constraint(equalToConstant: 18)
            ])

            // Teal sci-fi border glow
            containerView.layer.borderWidth = 1.0
            containerView.layer.borderColor = UIColor.cyan.withAlphaComponent(0.2).cgColor
            self.layer.shadowColor   = UIColor.cyan.cgColor
            self.layer.shadowRadius  = 6
            self.layer.shadowOpacity = 0.15

        } else {
            // Character is visible
            thumbImageView.isHidden = false
            thumbImageView.image = UIImage(named: "nobg")
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
