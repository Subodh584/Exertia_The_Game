import UIKit

class OTPViewController: UIViewController, UITextFieldDelegate {

    // MARK: - UI Components
    private let backgroundImageView = UIImageView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let glassCard = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    // An array to hold our 4 individual OTP boxes
    private let otpFields: [UITextField] = (0..<4).map { _ in UITextField() }
    private let otpStackView = UIStackView()
    
    private let verifyButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupKeyboardDismiss()
    }

    // MARK: - Actions
    @objc func verifyTapped() {
        print("✅ DEMO OTP Verified. Navigating to profile setup...")
        
        DispatchQueue.main.async {
            let onboardingVC = OnboardingProfileViewController()
            onboardingVC.modalPresentationStyle = .fullScreen
            onboardingVC.modalTransitionStyle = .crossDissolve
            self.present(onboardingVC, animated: true)
        }
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
        glassCard.layer.cornerRadius = Responsive.cornerRadius(24)
        glassCard.layer.borderWidth = 1
        glassCard.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        glassCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(glassCard)
        
        titleLabel.text = "Verification"
        titleLabel.font = .systemFont(ofSize: Responsive.font(28), weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(titleLabel)
        
        subtitleLabel.text = "Enter the 4-digit code sent to your email."
        subtitleLabel.font = .systemFont(ofSize: Responsive.font(14), weight: .medium)
        subtitleLabel.textColor = UIColor(white: 0.9, alpha: 1.0)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(subtitleLabel)
        
        otpStackView.axis = .horizontal
        otpStackView.spacing = Responsive.padding(15)
        otpStackView.distribution = .fillEqually
        otpStackView.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(otpStackView)
        
        for field in otpFields {
            field.backgroundColor = .white
            field.layer.cornerRadius = Responsive.cornerRadius(14)
            field.textColor = .black
            field.font = .systemFont(ofSize: Responsive.font(28), weight: .bold)
            field.textAlignment = .center
            field.keyboardType = .numberPad
            field.delegate = self
            
            field.layer.shadowColor = UIColor.black.cgColor
            field.layer.shadowOpacity = 0.1
            field.layer.shadowOffset = CGSize(width: 0, height: 2)
            field.layer.shadowRadius = 4
            
            otpStackView.addArrangedSubview(field)
            field.heightAnchor.constraint(equalTo: field.widthAnchor).isActive = true
        }
        
        verifyButton.setTitle("Verify & Continue", for: .normal)
        verifyButton.backgroundColor = UIColor(red: 0.0, green: 0.2, blue: 0.4, alpha: 1.0)
        verifyButton.setTitleColor(.white, for: .normal)
        verifyButton.layer.cornerRadius = Responsive.cornerRadius(27.5)
        verifyButton.titleLabel?.font = .systemFont(ofSize: Responsive.font(18), weight: .bold)
        verifyButton.addTarget(self, action: #selector(verifyTapped), for: .touchUpInside)
        verifyButton.translatesAutoresizingMaskIntoConstraints = false
        glassCard.addSubview(verifyButton)
        
        NSLayoutConstraint.activate([
            glassCard.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            glassCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            glassCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            glassCard.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 40),
            glassCard.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -40),
            
            titleLabel.topAnchor.constraint(equalTo: glassCard.topAnchor, constant: Responsive.padding(40)),
            titleLabel.leadingAnchor.constraint(equalTo: glassCard.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: glassCard.trailingAnchor, constant: -20),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: glassCard.leadingAnchor, constant: 25),
            subtitleLabel.trailingAnchor.constraint(equalTo: glassCard.trailingAnchor, constant: -25),
            
            otpStackView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 40),
            otpStackView.centerXAnchor.constraint(equalTo: glassCard.centerXAnchor),
            otpStackView.widthAnchor.constraint(equalToConstant: Responsive.size(260)),
            
            verifyButton.topAnchor.constraint(equalTo: otpStackView.bottomAnchor, constant: Responsive.padding(45)),
            verifyButton.leadingAnchor.constraint(equalTo: glassCard.leadingAnchor, constant: 25),
            verifyButton.trailingAnchor.constraint(equalTo: glassCard.trailingAnchor, constant: -25),
            verifyButton.heightAnchor.constraint(equalToConstant: Responsive.size(55)),
            verifyButton.bottomAnchor.constraint(equalTo: glassCard.bottomAnchor, constant: -40)
        ])
    }

    // MARK: - Text Field Logic
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let index = otpFields.firstIndex(of: textField) else { return false }
        
        if string.isEmpty {
            textField.text = ""
            if index > 0 {
                otpFields[index - 1].becomeFirstResponder()
            }
            return false
        }
        
        if string.count == 1 {
            textField.text = string
            if index < otpFields.count - 1 {
                otpFields[index + 1].becomeFirstResponder()
            } else {
                textField.resignFirstResponder()
            }
            return false
        }
        
        return false
    }

    func setupKeyboardDismiss() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}
