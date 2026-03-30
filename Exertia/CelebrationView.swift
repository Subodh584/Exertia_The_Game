import UIKit

/// A full-screen confetti + streak celebration overlay.
/// Call `CelebrationView.show(on:streak:)` to trigger.
final class CelebrationView: UIView {

    // MARK: - Public API

    /// Shows a daily target celebration animation.
    static func show(on viewController: UIViewController, streak: Int) {
        let celebration = CelebrationView(frame: viewController.view.bounds, streak: streak)
        celebration.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        viewController.view.addSubview(celebration)
        celebration.startAnimation()
    }

    /// Shows a badge earned celebration animation.
    static func showBadge(on viewController: UIViewController, badgeName: String) {
        let celebration = CelebrationView(frame: viewController.view.bounds, streak: 0,
                                          mode: .badge, badgeName: badgeName)
        celebration.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        viewController.view.addSubview(celebration)
        celebration.startAnimation()
    }

    /// Shows a streak milestone celebration (7, 14, 30, 50, 100 days).
    static func showMilestone(on viewController: UIViewController, streak: Int) {
        let celebration = CelebrationView(frame: viewController.view.bounds, streak: streak,
                                          mode: .milestone)
        celebration.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        viewController.view.addSubview(celebration)
        celebration.startAnimation()
    }

    // MARK: - Private

    enum Mode { case dailyTarget, badge, milestone }

    private let streakCount: Int
    private let mode: Mode
    private let badgeName: String
    private let containerView = UIView()
    private let emojiLabel = UILabel()
    private let streakIconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let streakLabel = UILabel()
    private let streakRow = UIStackView()

    private init(frame: CGRect, streak: Int, mode: Mode = .dailyTarget, badgeName: String = "") {
        self.streakCount = streak
        self.mode = mode
        self.badgeName = badgeName
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.6)
        alpha = 0
        setupContent()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupContent() {
        // Center card
        containerView.backgroundColor = UIColor(red: 20/255, green: 10/255, blue: 40/255, alpha: 0.95)
        containerView.layer.cornerRadius = 24
        containerView.layer.borderColor = UIColor.neonPink.withAlphaComponent(0.5).cgColor
        containerView.layer.borderWidth = 2
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        containerView.alpha = 0
        addSubview(containerView)

        // Configure based on mode
        switch mode {
        case .dailyTarget:
            emojiLabel.text = "🏅"
            titleLabel.text = "Daily Target Complete!"
            subtitleLabel.text = "You crushed both your calorie & distance goals"
            if streakCount > 0 {
                streakLabel.text = "\(streakCount) Day Streak!"
            } else {
                streakLabel.text = "Streak started!"
            }
        case .badge:
            emojiLabel.text = "🏆"
            titleLabel.text = "Badge Unlocked!"
            subtitleLabel.text = badgeName
            streakLabel.text = "⭐ Keep going for more!"
        case .milestone:
            let milestoneEmoji: String
            switch streakCount {
            case 100...: milestoneEmoji = "💎"
            case 50...:  milestoneEmoji = "👑"
            case 30...:  milestoneEmoji = "🌟"
            case 14...:  milestoneEmoji = "⚡"
            default:     milestoneEmoji = "🔥"
            }
            emojiLabel.text = milestoneEmoji
            titleLabel.text = "\(streakCount) Day Streak!"
            subtitleLabel.text = "Incredible dedication!"
            streakLabel.text = "🏅 Milestone reached!"
        }

        emojiLabel.font = .systemFont(ofSize: 64)
        emojiLabel.textAlignment = .center
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = .gray
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        streakLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        streakLabel.textColor = UIColor(red: 1, green: 0.86, blue: 0.24, alpha: 1)
        streakLabel.textAlignment = .center
        streakLabel.translatesAutoresizingMaskIntoConstraints = false

        streakIconView.image = UIImage(named: "fire")
        streakIconView.contentMode = .scaleAspectFit
        streakIconView.translatesAutoresizingMaskIntoConstraints = false
        streakIconView.widthAnchor.constraint(equalToConstant: 28).isActive = true
        streakIconView.heightAnchor.constraint(equalToConstant: 28).isActive = true
        streakIconView.isHidden = mode == .badge

        streakRow.axis = .horizontal
        streakRow.alignment = .center
        streakRow.spacing = 10
        streakRow.translatesAutoresizingMaskIntoConstraints = false
        streakRow.addArrangedSubview(streakIconView)
        streakRow.addArrangedSubview(streakLabel)

        containerView.addSubview(emojiLabel)
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        containerView.addSubview(streakRow)

        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 300),

            emojiLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 28),
            emojiLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            titleLabel.topAnchor.constraint(equalTo: emojiLabel.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),

            streakRow.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
            streakRow.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            streakRow.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -28)
        ])

        // Close button (X) at top-right of card
        let closeBtn = UIButton(type: .system)
        closeBtn.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeBtn.tintColor = UIColor.white.withAlphaComponent(0.6)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        containerView.addSubview(closeBtn)

        NSLayoutConstraint.activate([
            closeBtn.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            closeBtn.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            closeBtn.widthAnchor.constraint(equalToConstant: 28),
            closeBtn.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    // MARK: - Confetti Emitter

    private func addConfetti() {
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: -20)
        emitter.emitterSize = CGSize(width: bounds.width, height: 1)
        emitter.emitterShape = .line
        emitter.renderMode = .additive

        let colors: [UIColor] = [
            .neonPink,
            UIColor(red: 1, green: 0.86, blue: 0.24, alpha: 1),  // gold
            .cyan,
            .white,
            UIColor(red: 0.6, green: 0.4, blue: 1, alpha: 1)     // purple
        ]
        let shapes = ["circle", "star.fill", "sparkle"]

        var cells: [CAEmitterCell] = []
        for color in colors {
            for shape in shapes {
                let cell = CAEmitterCell()
                cell.birthRate = 6
                cell.lifetime = 4.0
                cell.velocity = 180
                cell.velocityRange = 80
                cell.emissionLongitude = .pi
                cell.emissionRange = .pi / 4
                cell.spin = 3
                cell.spinRange = 6
                cell.scale = 0.06
                cell.scaleRange = 0.03
                cell.alphaSpeed = -0.3

                if let img = UIImage(systemName: shape)?.withTintColor(color, renderingMode: .alwaysOriginal) {
                    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12))
                    let rendered = renderer.image { ctx in
                        img.draw(in: CGRect(origin: .zero, size: CGSize(width: 12, height: 12)))
                    }
                    cell.contents = rendered.cgImage
                }
                cells.append(cell)
            }
        }

        emitter.emitterCells = cells
        layer.addSublayer(emitter)

        // Stop emitting after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            emitter.birthRate = 0
        }
    }

    // MARK: - Animation

    private func startAnimation() {
        // Haptic
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        // Fade in background
        UIView.animate(withDuration: 0.3) {
            self.alpha = 1
        }

        // Pop in card with spring
        UIView.animate(withDuration: 0.5, delay: 0.1, usingSpringWithDamping: 0.65,
                       initialSpringVelocity: 0.8, options: [], animations: {
            self.containerView.transform = .identity
            self.containerView.alpha = 1
        })

        // Add confetti
        addConfetti()

        // Pulse the emoji
        UIView.animate(withDuration: 0.4, delay: 0.6, options: [.autoreverse, .repeat], animations: {
            self.emojiLabel.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        })

        // No auto-dismiss — user must tap the X button
    }

    @objc private func dismissTapped() {
        dismissAnimation()
    }

    private func dismissAnimation() {
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0
            self.containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            self.removeFromSuperview()
        }
    }
}
