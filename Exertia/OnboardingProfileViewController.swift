//
//  OnboardingProfileViewController.swift
//  Exertia
//
//  Created on 03/03/26.
//

import UIKit

class OnboardingProfileViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, UITextFieldDelegate {

    // MARK: - Public flag — OAuth users need username too
    var isOAuthUser: Bool = false

    // MARK: - UI Components
    private let backgroundImageView  = UIImageView()
    private let scrollView           = UIScrollView()
    private let contentView          = UIView()

    private let glassCard      = UIView()
    private let titleLabel     = UILabel()
    private let subtitleLabel  = UILabel()

    // Username (OAuth only)
    private let usernameField          = UITextField()
    private let usernameStatusLabel    = UILabel()
    private let usernameCheckIndicator = UIActivityIndicatorView(style: .medium)
    private var usernameDebounce: Timer?
    private var usernameValidated = false

    // Goal fields
    private let targetCaloriesField  = UITextField()
    private let currentWeightField   = UITextField()
    private let targetWeightField    = UITextField()
    private let targetDistanceField  = UITextField()

    // Picker views for weight and distance
    private let currentWeightPicker  = UIPickerView()
    private let targetWeightPicker   = UIPickerView()
    private let targetDistancePicker = UIPickerView()

    // Picker data
    private let wholeWeightRange  = Array(20...250)   // kg whole part
    private let decimalRange      = Array(0...9)       // .0 - .9
    private let wholeDistRange    = Array(0...100)     // km whole part

    private let saveButton        = UIButton()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    // Track which picker field is active
    private enum PickerField { case currentWeight, targetWeight, distance }
    private var activePickerField: PickerField?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupKeyboardDismiss()
        setupPickers()

        if isOAuthUser {
            usernameField.addTarget(self, action: #selector(usernameTextChanged), for: .editingChanged)
        }
    }

    // MARK: - Picker setup

    private func setupPickers() {
        [currentWeightPicker, targetWeightPicker, targetDistancePicker].forEach {
            $0.delegate   = self
            $0.dataSource = self
        }

        currentWeightField.inputView = currentWeightPicker
        targetWeightField.inputView  = targetWeightPicker
        targetDistanceField.inputView = targetDistancePicker

        // Toolbars with Done button
        [currentWeightField, targetWeightField, targetDistanceField].forEach { field in
            let toolbar = UIToolbar()
            toolbar.sizeToFit()
            let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            let done = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(pickerDoneTapped))
            toolbar.setItems([flex, done], animated: false)
            field.inputAccessoryView = toolbar
        }

        // Set sensible defaults
        currentWeightPicker.selectRow(50, inComponent: 0, animated: false)  // 70 kg
        currentWeightPicker.selectRow(0,  inComponent: 1, animated: false)
        targetWeightPicker.selectRow(45,  inComponent: 0, animated: false)  // 65 kg
        targetWeightPicker.selectRow(0,   inComponent: 1, animated: false)
        targetDistancePicker.selectRow(5, inComponent: 0, animated: false)  // 5 km
        targetDistancePicker.selectRow(0, inComponent: 1, animated: false)
    }

    @objc private func pickerDoneTapped() {
        view.endEditing(true)
    }

    // MARK: - UIPickerViewDataSource

    func numberOfComponents(in pickerView: UIPickerView) -> Int { 2 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if component == 0 {
            if pickerView === targetDistancePicker { return wholeDistRange.count }
            return wholeWeightRange.count
        }
        return decimalRange.count
    }

    // MARK: - UIPickerViewDelegate

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if component == 0 {
            if pickerView === targetDistancePicker { return "\(wholeDistRange[row])" }
            return "\(wholeWeightRange[row])"
        }
        return ".\(decimalRange[row])"
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let wholeIdx   = pickerView.selectedRow(inComponent: 0)
        let decIdx     = pickerView.selectedRow(inComponent: 1)

        if pickerView === currentWeightPicker {
            let val = Double(wholeWeightRange[wholeIdx]) + Double(decimalRange[decIdx]) / 10.0
            currentWeightField.text = String(format: "%.1f", val)
        } else if pickerView === targetWeightPicker {
            let val = Double(wholeWeightRange[wholeIdx]) + Double(decimalRange[decIdx]) / 10.0
            targetWeightField.text = String(format: "%.1f", val)
        } else if pickerView === targetDistancePicker {
            let val = Double(wholeDistRange[wholeIdx]) + Double(decimalRange[decIdx]) / 10.0
            targetDistanceField.text = String(format: "%.1f", val)
        }
    }

    // MARK: - UITextFieldDelegate (number-only for calories)

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if textField === targetCaloriesField {
            let allowed = CharacterSet.decimalDigits
            return string.unicodeScalars.allSatisfy { allowed.contains($0) } || string.isEmpty
        }
        return true
    }

    // MARK: - Username live validation (OAuth)

    @objc private func usernameTextChanged() {
        let raw       = usernameField.text ?? ""
        let corrected = String(raw.lowercased().filter { !$0.isWhitespace })
        if raw != corrected { usernameField.text = corrected }

        usernameDebounce?.invalidate()
        usernameValidated = false

        let text = corrected
        guard text.count >= 3 else {
            if text.isEmpty { clearUsernameStatus() }
            else            { setUsernameStatus("Min. 3 chars", color: .systemOrange) }
            usernameCheckIndicator.stopAnimating()
            return
        }

        clearUsernameStatus()
        usernameDebounce = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
            self?.performUsernameCheck(text)
        }
    }

    private func performUsernameCheck(_ username: String) {
        usernameCheckIndicator.startAnimating()
        usernameStatusLabel.isHidden = true

        Task {
            do {
                let taken = try await SupabaseManager.shared.checkUsernameExists(username)
                DispatchQueue.main.async {
                    self.usernameCheckIndicator.stopAnimating()
                    if taken {
                        self.setUsernameStatus("Already taken", color: .systemRed)
                        self.usernameValidated = false
                    } else {
                        self.setUsernameStatus("Available", color: .systemGreen)
                        self.usernameValidated = true
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.usernameCheckIndicator.stopAnimating()
                    self.setUsernameStatus("Check failed", color: .systemOrange)
                    self.usernameValidated = false
                }
            }
        }
    }

    private func setUsernameStatus(_ text: String, color: UIColor) {
        usernameStatusLabel.isHidden        = false
        usernameStatusLabel.text            = text
        usernameStatusLabel.textColor       = .white
        usernameStatusLabel.backgroundColor = color.withAlphaComponent(0.85)
        UIView.animate(withDuration: 0.25) {
            self.usernameField.layer.borderColor = color.withAlphaComponent(0.8).cgColor
            self.usernameField.layer.borderWidth = 1.5
        }
    }

    private func clearUsernameStatus() {
        usernameStatusLabel.isHidden        = true
        usernameStatusLabel.text            = nil
        usernameStatusLabel.backgroundColor = .clear
        UIView.animate(withDuration: 0.25) {
            self.usernameField.layer.borderWidth = 0
        }
    }

    // MARK: - Save Action

    @objc func saveTapped() {
        // Username validation for OAuth users
        if isOAuthUser {
            let uname = usernameField.text ?? ""
            guard uname.count >= 3, usernameValidated else {
                showAlert(title: "Username Required", message: "Please choose an available username (min 3 characters).")
                return
            }
        }

        guard let calText = targetCaloriesField.text, let calories = Int(calText), calories > 0 else {
            showAlert(title: "Invalid Calories", message: "Please enter a valid calorie target.")
            return
        }

        guard let distText = targetDistanceField.text, let distance = Double(distText), distance > 0 else {
            showAlert(title: "Invalid Distance", message: "Please enter a valid daily distance target (km).")
            return
        }

        guard let userId = UserDefaults.standard.string(forKey: "supabaseUserID") else {
            showAlert(title: "Error", message: "User session not found. Please register again.")
            return
        }

        saveButton.isEnabled = false
        saveButton.setTitle("", for: .normal)
        activityIndicator.startAnimating()

        print("💾 Saving onboarding targets for user \(userId)…")

        Task {
            do {
                var data: [String: AnyEncodable] = [
                    "daily_target_calories": AnyEncodable(calories),
                    "daily_target_distance": AnyEncodable(distance)
                ]

                // Optional weight fields
                if let cwText = currentWeightField.text, let cw = Double(cwText), cw > 0 {
                    data["current_weight"] = AnyEncodable(cw)
                }
                if let twText = targetWeightField.text, let tw = Double(twText), tw > 0 {
                    data["target_weight"] = AnyEncodable(tw)
                }

                // Username for OAuth
                if isOAuthUser, let uname = usernameField.text, !uname.isEmpty {
                    data["username"] = AnyEncodable(uname)
                }

                let updatedUser = try await SupabaseManager.shared.updateUser(userId: userId, data: data)
                print("✅ Targets saved! Calories: \(updatedUser.daily_target_calories ?? 0), Distance: \(updatedUser.daily_target_distance ?? 0) km")

                DispatchQueue.main.async {
                    self.navigateToHome()
                }
            } catch {
                print("❌ Failed to save targets: \(error)")
                DispatchQueue.main.async {
                    self.saveButton.isEnabled = true
                    self.saveButton.setTitle("Save & Continue", for: .normal)
                    self.activityIndicator.stopAnimating()
                    self.showAlert(title: "Update Failed", message: "Could not save your targets. Please try again.")
                }
            }
        }
    }

    func navigateToHome() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let homeVC = storyboard.instantiateViewController(withIdentifier: "HomeViewController")
        homeVC.modalPresentationStyle = .fullScreen
        homeVC.modalTransitionStyle   = .crossDissolve
        self.present(homeVC, animated: true)
    }

    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - UI Setup

    func setupUI() {
        backgroundImageView.image       = UIImage(named: "loading background")
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
        glassCard.backgroundColor    = UIColor.white.withAlphaComponent(0.15)
        glassCard.layer.cornerRadius = Responsive.cornerRadius(24)
        glassCard.layer.borderWidth  = 1
        glassCard.layer.borderColor  = UIColor.white.withAlphaComponent(0.3).cgColor
        glassCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(glassCard)

        // Title
        titleLabel.text          = "Set Your Profile"
        titleLabel.font          = .systemFont(ofSize: Responsive.font(28), weight: .bold)
        titleLabel.textColor     = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(titleLabel)

        // Subtitle
        subtitleLabel.text          = "These targets will drive your in-game progress"
        subtitleLabel.font          = .systemFont(ofSize: Responsive.font(14), weight: .medium)
        subtitleLabel.textColor     = UIColor(white: 0.9, alpha: 1.0)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(subtitleLabel)

        let pad: CGFloat  = 25
        let rowH: CGFloat = Responsive.size(50)
        let rowGap: CGFloat = 12
        let halfGap: CGFloat = 8

        // ── Username (OAuth only) ──
        if isOAuthUser {
            styleTextField(usernameField, placeholder: "Username", icon: "at")

            let usernameContainer = UIView(frame: CGRect(x: 0, y: 0, width: 130, height: 50))
            usernameCheckIndicator.color = .darkGray
            usernameCheckIndicator.hidesWhenStopped = true
            usernameCheckIndicator.frame = CGRect(x: 105, y: 15, width: 20, height: 20)
            usernameContainer.addSubview(usernameCheckIndicator)

            usernameStatusLabel.font            = .systemFont(ofSize: 11, weight: .semibold)
            usernameStatusLabel.textAlignment   = .center
            usernameStatusLabel.layer.cornerRadius = 8
            usernameStatusLabel.clipsToBounds   = true
            usernameStatusLabel.frame           = CGRect(x: 5, y: 13, width: 112, height: 24)
            usernameStatusLabel.isHidden        = true
            usernameContainer.addSubview(usernameStatusLabel)

            usernameField.rightView     = usernameContainer
            usernameField.rightViewMode = .always
            glassCard.addSubview(usernameField)
        }

        // ── Calories ──
        styleTextField(targetCaloriesField, placeholder: "Daily Calorie Target (e.g. 500)", icon: "flame")
        targetCaloriesField.keyboardType = .numberPad
        targetCaloriesField.delegate     = self
        glassCard.addSubview(targetCaloriesField)

        // ── Weight row (side by side) ──
        styleTextField(currentWeightField, placeholder: "Current Weight (kg)", icon: "scalemass")
        currentWeightField.tintColor = .clear // hide cursor for picker
        glassCard.addSubview(currentWeightField)

        styleTextField(targetWeightField, placeholder: "Target Weight (kg)", icon: "target")
        targetWeightField.tintColor = .clear
        glassCard.addSubview(targetWeightField)

        // ── Distance ──
        styleTextField(targetDistanceField, placeholder: "Daily Distance (km)", icon: "figure.run")
        targetDistanceField.tintColor = .clear
        glassCard.addSubview(targetDistanceField)

        // Save Button
        saveButton.setTitle("Save & Continue", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.backgroundColor    = UIColor(red: 0.0, green: 0.2, blue: 0.4, alpha: 1.0)
        saveButton.layer.cornerRadius = Responsive.cornerRadius(12)
        saveButton.titleLabel?.font   = .systemFont(ofSize: Responsive.font(18), weight: .bold)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(saveButton)

        // Activity indicator centred on button
        activityIndicator.color = .white
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        saveButton.addSubview(activityIndicator)

        // ── Constraints ──
        var constraints: [NSLayoutConstraint] = [
            glassCard.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            glassCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            glassCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            titleLabel.topAnchor.constraint(equalTo: glassCard.topAnchor, constant: 36),
            titleLabel.centerXAnchor.constraint(equalTo: glassCard.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: glassCard.leadingAnchor, constant: pad),
            subtitleLabel.trailingAnchor.constraint(equalTo: glassCard.trailingAnchor, constant: -pad),
        ]

        // Anchor chain: what the first field pins to
        var topAnchorView: UIView = subtitleLabel
        var topConstant: CGFloat  = 28

        if isOAuthUser {
            constraints += [
                usernameField.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 28),
                usernameField.leadingAnchor.constraint(equalTo: glassCard.leadingAnchor, constant: pad),
                usernameField.trailingAnchor.constraint(equalTo: glassCard.trailingAnchor, constant: -pad),
                usernameField.heightAnchor.constraint(equalToConstant: rowH),
            ]
            topAnchorView = usernameField
            topConstant = rowGap
        }

        constraints += [
            // Calories
            targetCaloriesField.topAnchor.constraint(equalTo: topAnchorView.bottomAnchor, constant: topConstant),
            targetCaloriesField.leadingAnchor.constraint(equalTo: glassCard.leadingAnchor, constant: pad),
            targetCaloriesField.trailingAnchor.constraint(equalTo: glassCard.trailingAnchor, constant: -pad),
            targetCaloriesField.heightAnchor.constraint(equalToConstant: rowH),

            // Weight row — side by side
            currentWeightField.topAnchor.constraint(equalTo: targetCaloriesField.bottomAnchor, constant: rowGap),
            currentWeightField.leadingAnchor.constraint(equalTo: glassCard.leadingAnchor, constant: pad),
            currentWeightField.trailingAnchor.constraint(equalTo: glassCard.centerXAnchor, constant: -(halfGap / 2)),
            currentWeightField.heightAnchor.constraint(equalToConstant: rowH),

            targetWeightField.topAnchor.constraint(equalTo: currentWeightField.topAnchor),
            targetWeightField.leadingAnchor.constraint(equalTo: glassCard.centerXAnchor, constant: halfGap / 2),
            targetWeightField.trailingAnchor.constraint(equalTo: glassCard.trailingAnchor, constant: -pad),
            targetWeightField.heightAnchor.constraint(equalToConstant: rowH),

            // Distance
            targetDistanceField.topAnchor.constraint(equalTo: currentWeightField.bottomAnchor, constant: rowGap),
            targetDistanceField.leadingAnchor.constraint(equalTo: glassCard.leadingAnchor, constant: pad),
            targetDistanceField.trailingAnchor.constraint(equalTo: glassCard.trailingAnchor, constant: -pad),
            targetDistanceField.heightAnchor.constraint(equalToConstant: rowH),

            // Save
            saveButton.topAnchor.constraint(equalTo: targetDistanceField.bottomAnchor, constant: 28),
            saveButton.leadingAnchor.constraint(equalTo: glassCard.leadingAnchor, constant: pad),
            saveButton.trailingAnchor.constraint(equalTo: glassCard.trailingAnchor, constant: -pad),
            saveButton.heightAnchor.constraint(equalToConstant: rowH),
            saveButton.bottomAnchor.constraint(equalTo: glassCard.bottomAnchor, constant: -36),

            activityIndicator.centerXAnchor.constraint(equalTo: saveButton.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: saveButton.centerYAnchor)
        ]

        NSLayoutConstraint.activate(constraints)
    }

    // MARK: - Helpers

    func styleTextField(_ textField: UITextField, placeholder: String, icon: String) {
        textField.backgroundColor = .white
        textField.layer.cornerRadius = Responsive.cornerRadius(10)
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.systemGray]
        )
        textField.textColor              = .black
        textField.autocapitalizationType = .none
        textField.autocorrectionType     = .no

        let iconView         = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor   = .darkGray
        iconView.contentMode = .scaleAspectFit

        let leftContainer = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 50))
        iconView.frame    = CGRect(x: 12, y: 15, width: 20, height: 20)
        leftContainer.addSubview(iconView)

        textField.leftView     = leftContainer
        textField.leftViewMode = .always
        textField.translatesAutoresizingMaskIntoConstraints = false
    }

    // MARK: - Keyboard dismiss

    func setupKeyboardDismiss() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
    }

    @objc func dismissKeyboard() { view.endEditing(true) }
}
