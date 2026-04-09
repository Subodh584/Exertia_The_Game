//
//  CreditsViewController.swift
//  Exertia
//
//  Displays the team credits for the app.
//

import UIKit

class CreditsViewController: UIViewController {

    // MARK: - UI
    private let backgroundImageView = UIImageView()
    private let navBar              = UIView()
    private let titleLabel          = UILabel()
    private let closeButton         = UIButton(type: .system)
    private let scrollView          = UIScrollView()
    private let contentStack        = UIStackView()

    // MARK: - Data
    private struct Credit {
        let name: String
        let role: String
        let icon: String  // SF Symbol
    }

    private let credits: [Credit] = [
        Credit(name: "Ekansh Jindal", role: "Developer", icon: "laptopcomputer"),
        Credit(name: "Satakshi Srivastava", role: "Developer", icon: "laptopcomputer"),
        Credit(name: "Subodh Kumar", role: "Developer", icon: "laptopcomputer"),
    ]

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

        titleLabel.text          = "Credits"
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
            line.heightAnchor.constraint(equalToConstant: 0.5)
        ])
    }

    // MARK: - Scroll
    private func setupScroll() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)

        contentStack.axis    = .vertical
        contentStack.spacing = 0
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 30),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -40),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -48)
        ])
    }

    // MARK: - Content
    private func buildContent() {

        // App icon + name header
        let headerStack = UIStackView()
        headerStack.axis = .vertical
        headerStack.alignment = .center
        headerStack.spacing = 12

        let appIcon = UIImageView(image: UIImage(named: "ExertiaHomePageTitle"))
        appIcon.contentMode = .scaleAspectFit
        appIcon.translatesAutoresizingMaskIntoConstraints = false
        appIcon.heightAnchor.constraint(equalToConstant: 60).isActive = true

        let versionLabel = UILabel()
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        versionLabel.text = "Version \(version) (\(build))"
        versionLabel.font = .systemFont(ofSize: 13, weight: .medium)
        versionLabel.textColor = UIColor.white.withAlphaComponent(0.5)

        headerStack.addArrangedSubview(appIcon)
        headerStack.addArrangedSubview(versionLabel)
        contentStack.addArrangedSubview(headerStack)
        contentStack.setCustomSpacing(36, after: headerStack)

        // "Built by" section header
        let sectionLabel = UILabel()
        sectionLabel.text = "BUILT BY"
        sectionLabel.font = .systemFont(ofSize: 12, weight: .bold)
        sectionLabel.textColor = UIColor(red: 0.0, green: 0.95, blue: 0.63, alpha: 1)
        sectionLabel.letterSpacing(1.5)
        contentStack.addArrangedSubview(sectionLabel)
        contentStack.setCustomSpacing(16, after: sectionLabel)

        // Team card
        let teamCard = makeGlassCard()
        let teamStack = UIStackView()
        teamStack.axis = .vertical
        teamStack.spacing = 0
        teamStack.translatesAutoresizingMaskIntoConstraints = false
        teamCard.addSubview(teamStack)
        NSLayoutConstraint.activate([
            teamStack.topAnchor.constraint(equalTo: teamCard.topAnchor, constant: 8),
            teamStack.bottomAnchor.constraint(equalTo: teamCard.bottomAnchor, constant: -8),
            teamStack.leadingAnchor.constraint(equalTo: teamCard.leadingAnchor, constant: 20),
            teamStack.trailingAnchor.constraint(equalTo: teamCard.trailingAnchor, constant: -20)
        ])

        for (i, credit) in credits.enumerated() {
            let row = makeCreditRow(credit: credit)
            teamStack.addArrangedSubview(row)
            if i < credits.count - 1 {
                let sep = UIView()
                sep.backgroundColor = UIColor.white.withAlphaComponent(0.08)
                sep.translatesAutoresizingMaskIntoConstraints = false
                sep.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
                teamStack.addArrangedSubview(sep)
            }
        }

        contentStack.addArrangedSubview(teamCard)
        contentStack.setCustomSpacing(30, after: teamCard)

        // Contact section
        let contactLabel = UILabel()
        contactLabel.text = "CONTACT"
        contactLabel.font = .systemFont(ofSize: 12, weight: .bold)
        contactLabel.textColor = UIColor(red: 0.0, green: 0.95, blue: 0.63, alpha: 1)
        contactLabel.letterSpacing(1.5)
        contentStack.addArrangedSubview(contactLabel)
        contentStack.setCustomSpacing(16, after: contactLabel)

        let contactCard = makeGlassCard()
        let emailRow = makeContactRow(
            icon: "envelope.fill",
            text: "exertia.game@gmail.com"
        )
        emailRow.translatesAutoresizingMaskIntoConstraints = false
        contactCard.addSubview(emailRow)
        NSLayoutConstraint.activate([
            emailRow.topAnchor.constraint(equalTo: contactCard.topAnchor, constant: 16),
            emailRow.bottomAnchor.constraint(equalTo: contactCard.bottomAnchor, constant: -16),
            emailRow.leadingAnchor.constraint(equalTo: contactCard.leadingAnchor, constant: 20),
            emailRow.trailingAnchor.constraint(equalTo: contactCard.trailingAnchor, constant: -20)
        ])
        contentStack.addArrangedSubview(contactCard)
        contentStack.addArrangedSubview(contactCard)
    }

    // MARK: - Helpers

    private func makeCreditRow(credit: Credit) -> UIView {
        let symCfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let iconView = UIImageView(image: UIImage(systemName: credit.icon, withConfiguration: symCfg))
        iconView.tintColor = UIColor(red: 0.6, green: 0.4, blue: 1.0, alpha: 1)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 28).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 28).isActive = true
        iconView.contentMode = .scaleAspectFit

        let nameLabel = UILabel()
        nameLabel.text = credit.name
        nameLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        nameLabel.textColor = .white

        let roleLabel = UILabel()
        roleLabel.text = credit.role
        roleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        roleLabel.textColor = UIColor.white.withAlphaComponent(0.5)

        let textStack = UIStackView(arrangedSubviews: [nameLabel, roleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        let row = UIStackView(arrangedSubviews: [iconView, textStack])
        row.axis = .horizontal
        row.spacing = 14
        row.alignment = .center
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 14, left: 0, bottom: 14, right: 0)
        return row
    }

    private func makeContactRow(icon: String, text: String) -> UIView {
        let symCfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: symCfg))
        iconView.tintColor = UIColor(red: 0.0, green: 0.95, blue: 0.63, alpha: 1)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 22).isActive = true

        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.8)

        let row = UIStackView(arrangedSubviews: [iconView, label])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        return row
    }

    private func makeGlassCard() -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        card.layer.cornerRadius = 16
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        return card
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}

// MARK: - Letter Spacing Helper
private extension UILabel {
    func letterSpacing(_ spacing: CGFloat) {
        guard let text = self.text else { return }
        let attr = NSMutableAttributedString(string: text)
        attr.addAttribute(.kern, value: spacing, range: NSRange(location: 0, length: text.count))
        self.attributedText = attr
    }
}
