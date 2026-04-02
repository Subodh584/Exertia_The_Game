//
//  TermsViewController.swift
//  Exertia
//
//  Displays Terms & Conditions natively inside the app.
//

import UIKit

class TermsViewController: UIViewController {

    // MARK: - UI
    private let backgroundImageView = UIImageView()
    private let navBar              = UIView()
    private let titleLabel          = UILabel()
    private let closeButton         = UIButton(type: .system)
    private let scrollView          = UIScrollView()
    private let contentStack        = UIStackView()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.05, green: 0.02, blue: 0.1, alpha: 1)
        setupBackground()
        setupNav()
        setupScroll()
        buildContent()
    }

    // MARK: - Background
    private func setupBackground() {
        backgroundImageView.image       = UIImage(named: "WhatsApp Image 2025-09-24 at 14.26.03")
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.alpha       = 0.4
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundImageView)
        view.sendSubviewToBack(backgroundImageView)
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    // MARK: - Nav bar
    private func setupNav() {
        navBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navBar)

        titleLabel.text          = "Terms & Conditions"
        titleLabel.font          = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor     = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        navBar.addSubview(titleLabel)

        let symCfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        closeButton.setImage(UIImage(systemName: "chevron.left", withConfiguration: symCfg), for: .normal)
        closeButton.tintColor   = .white
        closeButton.setTitle("  Back", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        navBar.addSubview(closeButton)

        // Thin separator line
        let line = UIView()
        line.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        line.translatesAutoresizingMaskIntoConstraints = false
        navBar.addSubview(line)

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navBar.heightAnchor.constraint(equalToConstant: 52),

            closeButton.leadingAnchor.constraint(equalTo: navBar.leadingAnchor, constant: 16),
            closeButton.centerYAnchor.constraint(equalTo: navBar.centerYAnchor),

            titleLabel.centerXAnchor.constraint(equalTo: navBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: navBar.centerYAnchor),

            line.leadingAnchor.constraint(equalTo: navBar.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: navBar.trailingAnchor),
            line.bottomAnchor.constraint(equalTo: navBar.bottomAnchor),
            line.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    // MARK: - Scroll view
    private func setupScroll() {
        scrollView.showsVerticalScrollIndicator = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentStack.axis      = .vertical
        contentStack.spacing   = 16
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -50),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
    }

    // MARK: - Content
    private func buildContent() {
        // Last updated label
        let dateLbl = UILabel()
        dateLbl.text      = "Last updated: April 2026"
        dateLbl.font      = .systemFont(ofSize: 12, weight: .regular)
        dateLbl.textColor = UIColor.white.withAlphaComponent(0.4)
        contentStack.addArrangedSubview(dateLbl)

        let sections: [(String, String)] = [
            (
                "1. Acceptance of Terms",
                "By downloading, installing, or using Exertia (\"the App\"), you agree to be bound by these Terms and Conditions. If you do not agree to these terms, please do not use the App.\n\nThese terms apply to all users of the App, including users who contribute content, information, or other materials."
            ),
            (
                "2. Use of the App",
                "Exertia is a fitness game designed for personal, non-commercial use. You agree to use the App only for its intended purpose.\n\nYou must not:\n• Use the App for any unlawful purpose\n• Attempt to reverse-engineer, decompile, or disassemble any part of the App\n• Use automated systems to access the App in an unauthorised manner\n• Transmit any harmful, offensive, or disruptive content through the App"
            ),
            (
                "3. User Accounts",
                "You must create an account to use certain features of the App. You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account.\n\nYou agree to provide accurate and complete information when creating your account and to update it to keep it accurate. We reserve the right to suspend or terminate accounts that violate these terms."
            ),
            (
                "4. Fitness & Health Disclaimer",
                "Exertia is a fitness game and is not a medical device or substitute for professional medical advice.\n\n• Consult your doctor before starting any new exercise programme, particularly if you have a pre-existing medical condition.\n• Stop using the App immediately if you experience pain, dizziness, shortness of breath, or any other discomfort.\n• The calorie and distance estimates provided by the App are approximate and should not be relied upon for medical or clinical decisions.\n\nWe are not liable for any injury, illness, or health issue arising from use of the App."
            ),
            (
                "5. Camera Usage",
                "The App uses your device camera solely for real-time motion tracking during gameplay. No video, images, or biometric data are recorded, stored, or transmitted.\n\nCamera access is required for gameplay. If you deny camera permission, the App's core features will not function. You may revoke camera permission at any time via your device settings."
            ),
            (
                "6. Intellectual Property",
                "All content within the App — including but not limited to graphics, characters, music, sound effects, and code — is the property of Exertia and is protected by applicable intellectual property laws.\n\nYou are granted a limited, non-exclusive, non-transferable licence to use the App for personal, non-commercial purposes. You may not copy, modify, distribute, sell, or lease any part of the App or its content."
            ),
            (
                "7. In-App Data & Privacy",
                "Your use of the App is also governed by our Privacy Policy, which is incorporated into these Terms by reference. By using the App, you consent to the data practices described in the Privacy Policy.\n\nYou can delete your account and all associated data at any time via Settings → Delete Account."
            ),
            (
                "8. Limitation of Liability",
                "To the maximum extent permitted by applicable law, Exertia and its developers shall not be liable for:\n\n• Any indirect, incidental, or consequential damages arising from your use of the App\n• Loss of data or unauthorised access to your account due to circumstances beyond our reasonable control\n• Interruptions or errors in the App's availability\n\nOur total liability to you for any claim arising from these terms shall not exceed the amount you paid for the App in the 12 months preceding the claim."
            ),
            (
                "9. Termination",
                "We reserve the right to suspend or terminate your access to the App at any time, with or without notice, if we believe you have violated these Terms and Conditions.\n\nUpon termination, your right to use the App will cease immediately. You may also terminate your account at any time by using the Delete Account feature in the App."
            ),
            (
                "10. Changes to These Terms",
                "We may update these Terms and Conditions from time to time. When we do, we will update the \"Last updated\" date at the top of this page.\n\nYour continued use of the App after any changes constitutes your acceptance of the new terms. We encourage you to review these terms periodically."
            ),
            (
                "11. Governing Law",
                "These Terms and Conditions are governed by and construed in accordance with applicable laws. Any disputes arising from these terms shall be subject to the exclusive jurisdiction of the relevant courts."
            ),
            (
                "12. Contact",
                "If you have any questions about these Terms and Conditions, please contact us at:\n\nexertia.game@gmail.com"
            )
        ]

        for (title, body) in sections {
            contentStack.addArrangedSubview(makeCard(title: title, body: body))
        }
    }

    // MARK: - Card builder
    private func makeCard(title: String, body: String) -> UIView {
        // Glass card background (blur + border)
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = 16
        blur.clipsToBounds      = true
        blur.layer.borderColor  = UIColor.white.withAlphaComponent(0.12).cgColor
        blur.layer.borderWidth  = 1
        blur.isUserInteractionEnabled = false
        card.addSubview(blur)

        // Title
        let titleLbl = UILabel()
        titleLbl.text          = title
        titleLbl.font          = .systemFont(ofSize: 13, weight: .bold)
        titleLbl.textColor     = UIColor(red: 0.0, green: 0.95, blue: 0.63, alpha: 1)
        titleLbl.textAlignment = .left
        titleLbl.numberOfLines = 0
        titleLbl.translatesAutoresizingMaskIntoConstraints = false

        // Neon dot accent
        let dot = UIView()
        dot.backgroundColor    = UIColor(red: 0.0, green: 0.95, blue: 0.63, alpha: 1)
        dot.layer.cornerRadius = 3
        dot.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 6),
            dot.heightAnchor.constraint(equalToConstant: 6)
        ])

        let titleRow = UIStackView(arrangedSubviews: [dot, titleLbl])
        titleRow.axis      = .horizontal
        titleRow.spacing   = 8
        titleRow.alignment = .center
        titleRow.translatesAutoresizingMaskIntoConstraints = false

        // Body
        let bodyLbl = UILabel()
        bodyLbl.text          = body
        bodyLbl.font          = .systemFont(ofSize: 14, weight: .regular)
        bodyLbl.textColor     = UIColor.white.withAlphaComponent(0.75)
        bodyLbl.textAlignment = .left
        bodyLbl.numberOfLines = 0
        bodyLbl.lineBreakMode = .byWordWrapping
        bodyLbl.translatesAutoresizingMaskIntoConstraints = false

        let inner = UIStackView(arrangedSubviews: [titleRow, bodyLbl])
        inner.axis    = .vertical
        inner.spacing = 10
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)

        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: card.topAnchor),
            blur.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            blur.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: card.trailingAnchor),

            inner.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16)
        ])
        return card
    }

    // MARK: - Actions
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}
