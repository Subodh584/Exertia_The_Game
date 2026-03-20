//
//  OnboardingProfileViewController.swift
//  Exertia
//
//  Created on 03/03/26.
//

import UIKit

class OnboardingProfileViewController: UIViewController {

    // MARK: - UI Components
    private let backgroundImageView = UIImageView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let glassCard = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    private let usernameField = UITextField()
    private let targetCaloriesField = UITextField()
    private let targetMinutesField = UITextField()

    private let saveButton = UIButton()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupKeyboardDismiss()
    }

    // MARK: - Save Action
    @objc func saveTapped() {
        guard let username = usernameField.text, !username.isEmpty else {
            showAlert(title: "Missing Username", message: "Please enter a username.")
            return
        }

        guard let calText = targetCaloriesField.text, let calories = Int(calText), calories > 0 else {
            showAlert(title: "Invalid Calories", message: "Please enter a valid calorie target.")
            return
        }

        guard let minText = targetMinutesField.text, let distance = Double(minText), distance > 0 else {
            showAlert(title: "Invalid Distance", message: "Please enter a valid daily distance target (km).")
            return
        }

        guard let userId = UserDefaults.standard.string(forKey: "djangoUserID") else {
            showAlert(title: "Error", message: "User session not found. Please register again.")
            return
        }

        // Disable button & show spinner
        saveButton.isEnabled = false
        saveButton.setTitle("", for: .normal)
        activityIndicator.startAnimating()

        print("💾 Saving onboarding profile for user \(userId)...")

        Task {
            do {
                let payload: [String: Any] = [
                    "username": username,
                    "daily_target_calories": calories,
                    "daily_target_distance": distance
                ]

                let updatedUser = try await APIManager.shared.updateUser(userId: userId, payload: payload)
                print("✅ Profile updated! Username: \(updatedUser.username), Calories: \(updatedUser.dailyTargetCalories ?? 0), Distance: \(updatedUser.dailyTargetDistance ?? 0) km")

                DispatchQueue.main.async {
                    self.navigateToHome()
                }
            } catch {
                print("❌ Failed to update profile: \(error)")
                DispatchQueue.main.async {
                    self.saveButton.isEnabled = true
                    self.saveButton.setTitle("Save & Continue", for: .normal)
                    self.activityIndicator.stopAnimating()
                    self.showAlert(title: "Update Failed", message: "Could not save your profile. Please try again.")
                }
            }
        }
    }

    func navigateToHome() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let homeVC = storyboard.instantiateViewController(withIdentifier: "HomeViewController")
        homeVC.modalPresentationStyle = .fullScreen
        homeVC.modalTransitionStyle = .crossDissolve
        self.present(homeVC, animated: true)
    }

    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - UI Setup
    func setupUI() {
        backgroundImageView.image = UIImage(named: "loading background")
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundImageView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        setupGlassCard()

        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            contentView.heightAnchor.constraint(greaterThanOrEqualTo: view.heightAnchor)
        ])
    }

    func setupGlassCard() {
        glassCard.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        glassCard.layer.cornerRadius = 24
        glassCard.layer.borderWidth = 1
        glassCard.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        glassCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(glassCard)

        // Title
        titleLabel.text = "Set Up Your Profile"
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(titleLabel)

        // Subtitle
        subtitleLabel.text = "Choose a username and set your daily fitness goals"
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        subtitleLabel.textColor = UIColor(white: 0.9, alpha: 1.0)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(subtitleLabel)

        // Fields
        styleTextField(usernameField, placeholder: "Username", icon: "at")
        styleTextField(targetCaloriesField, placeholder: "Daily Target Calories (e.g. 500)", icon: "flame")
        targetCaloriesField.keyboardType = .numberPad
        styleTextField(targetMinutesField, placeholder: "Daily Target Minutes (e.g. 45)", icon: "clock")
        targetMinutesField.keyboardType = .numberPad

        glassCard.addSubview(usernameField)
        glassCard.addSubview(targetCaloriesField)
        glassCard.addSubview(targetMinutesField)

        // Save Button
        saveButton.setTitle("Save & Continue", for: .normal)
        saveButton.backgroundColor = UIColor(red: 0.0, green: 0.2, blue: 0.4, alpha: 1.0)
        saveButton.layer.cornerRadius = 12
        saveButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(saveButton)

        // Activity indicator centered on button
        activityIndicator.color = .white
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        saveButton.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            glassCard.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            glassCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            glassCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            titleLabel.topAnchor.constraint(equalTo: glassCard.topAnchor, constant: 40),
            titleLabel.centerXAnchor.constraint(equalTo: glassCard.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: glassCard.leadingAnchor, constant: 25),
            subtitleLabel.trailingAnchor.constraint(equalTo: glassCard.trailingAnchor, constant: -25),

            usernameField.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 35),
            usernameField.leadingAnchor.constraint(equalTo: glassCard.leadingAnchor, constant: 25),
            usernameField.trailingAnchor.constraint(equalTo: glassCard.trailingAnchor, constant: -25),
            usernameField.heightAnchor.constraint(equalToConstant: 50),

            targetCaloriesField.topAnchor.constraint(equalTo: usernameField.bottomAnchor, constant: 15),
            targetCaloriesField.leadingAnchor.constraint(equalTo: usernameField.leadingAnchor),
            targetCaloriesField.trailingAnchor.constraint(equalTo: usernameField.trailingAnchor),
            targetCaloriesField.heightAnchor.constraint(equalToConstant: 50),

            targetMinutesField.topAnchor.constraint(equalTo: targetCaloriesField.bottomAnchor, constant: 15),
            targetMinutesField.leadingAnchor.constraint(equalTo: usernameField.leadingAnchor),
            targetMinutesField.trailingAnchor.constraint(equalTo: usernameField.trailingAnchor),
            targetMinutesField.heightAnchor.constraint(equalToConstant: 50),

            saveButton.topAnchor.constraint(equalTo: targetMinutesField.bottomAnchor, constant: 35),
            saveButton.leadingAnchor.constraint(equalTo: usernameField.leadingAnchor),
            saveButton.trailingAnchor.constraint(equalTo: usernameField.trailingAnchor),
            saveButton.heightAnchor.constraint(equalToConstant: 50),
            saveButton.bottomAnchor.constraint(equalTo: glassCard.bottomAnchor, constant: -40),

            activityIndicator.centerXAnchor.constraint(equalTo: saveButton.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: saveButton.centerYAnchor)
        ])
    }

    // MARK: - Helpers
    func styleTextField(_ textField: UITextField, placeholder: String, icon: String) {
        textField.backgroundColor = .white
        textField.layer.cornerRadius = 10
        textField.placeholder = placeholder
        textField.textColor = .black
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = .darkGray
        iconView.contentMode = .scaleAspectFit

        let leftContainer = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 50))
        iconView.frame = CGRect(x: 12, y: 15, width: 20, height: 20)
        leftContainer.addSubview(iconView)

        textField.leftView = leftContainer
        textField.leftViewMode = .always
        textField.translatesAutoresizingMaskIntoConstraints = false
    }

    func setupKeyboardDismiss() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}
