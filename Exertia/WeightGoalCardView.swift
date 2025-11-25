
import UIKit

class WeightGoalCardView: UIView {
    
    @IBOutlet weak var progressView: UIView!
    @IBOutlet weak var progressWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var trackView: UIView!
    
    
    func setProgress(to value: CGFloat) {
            
            // 1. Safety Check: Just check if the critical views exist
            guard let existingConstraint = progressWidthConstraint,
                  let pView = progressView,
                  let tView = trackView else {
                print("Error: Missing connections. Ensure Pink View, Grey Track, and Constraint are connected.")
                return
            }

            // 2. Limit the value between 0.0 and 1.0
            let clampedValue = min(max(value, 0), 1)

            // 3. Deactivate the old constraint
            existingConstraint.isActive = false

            // 4. Create the NEW constraint directly using the views we know exist
            let newConstraint = pView.widthAnchor.constraint(
                equalTo: tView.widthAnchor,
                multiplier: clampedValue
            )

            // 5. Activate it and save it back
            newConstraint.isActive = true
            self.progressWidthConstraint = newConstraint

            // 6. Animate
            UIView.animate(withDuration: 1.0, delay: 0, options: .curveEaseOut) {
                self.layoutIfNeeded()
            }
        }
        

        override func layoutSubviews() {
            super.layoutSubviews()
            if progressView.layer.sublayers?.first is CAGradientLayer == false {
                        let gradient = CAGradientLayer()
                        gradient.colors = [
                            UIColor(red: 1.0, green: 0.9, blue: 0.6, alpha: 1.0).cgColor, // Pale Yellow
                            UIColor.systemPink.cgColor                                    // Pink
                        ]
                        gradient.startPoint = CGPoint(x: 0.0, y: 0.5) // Left
                        gradient.endPoint = CGPoint(x: 1.0, y: 0.5)   // Right
                        progressView.layer.insertSublayer(gradient, at: 0)
                    }
            if let gradient = progressView.layer.sublayers?.first as? CAGradientLayer {
                        gradient.frame = progressView.bounds
                        gradient.cornerRadius = progressView.layer.cornerRadius
                    }
                }
    }

