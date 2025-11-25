import UIKit

//tells the main screen to update
protocol CustomToggleControlDelegate: AnyObject {
    func toggleControl(_ control: CustomToggleControl, didSelectCalBurn isCalBurnSelected: Bool)
}

class CustomToggleControl: UIView {

    // MARK: - IBOutlets
    @IBOutlet weak var sliderView: UIView!
    @IBOutlet weak var calBurnButton: UIButton!
    @IBOutlet weak var runtimeButton: UIButton!
    @IBOutlet weak var sliderLeadingConstraint: NSLayoutConstraint!
    
    weak var delegate: CustomToggleControlDelegate?
    private var didSetup = false

    override func awakeFromNib() {
        super.awakeFromNib()
      
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if !didSetup {
            setupUI()
            didSetup = true
        }
    
        self.layer.cornerRadius = self.bounds.height / 2
        sliderView.layer.cornerRadius = sliderView.bounds.height / 2
    }

    private func setupUI() {
    

        self.clipsToBounds = true
    
        calBurnButton.isSelected = true
        runtimeButton.isSelected = false
        
        let padding: CGFloat = 4.0
        sliderLeadingConstraint.constant = padding
        
        updateButtonColors(selectedButton: calBurnButton)
     

    }
    
    // MARK: - Actions
    @IBAction func toggleTapped(_ sender: UIButton) {
        guard !sender.isSelected else { return }
        
        calBurnButton.isSelected = (sender == calBurnButton)
        runtimeButton.isSelected = (sender == runtimeButton)
        
        let padding: CGFloat = 4.0
       
        let sliderWidth = (self.bounds.width / 2) - (padding * 2) // e.g., (200/2) - (4*2) = 92
        
        if sender == runtimeButton {
          
            sliderLeadingConstraint.constant = self.bounds.width / 2
        } else {
            sliderLeadingConstraint.constant = padding
        }
        
        // Animate the constraint change
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut]) {
            self.layoutIfNeeded()
            self.updateButtonColors(selectedButton: sender)
            self.delegate?.toggleControl(self, didSelectCalBurn: self.calBurnButton.isSelected)
                    
        }
    }

    // MARK: - Helper Methods
    private func updateButtonColors(selectedButton: UIButton) {
        let selectedTextColor = UIColor(red: 0.9, green: 0.9, blue: 0.7, alpha: 1.0)
        let unselectedTextColor = UIColor.white.withAlphaComponent(0.6)
        calBurnButton.setTitleColor(calBurnButton.isSelected ? selectedTextColor : unselectedTextColor, for: .normal)
        runtimeButton.setTitleColor(runtimeButton.isSelected ? selectedTextColor : unselectedTextColor, for: .normal)
    }
}
