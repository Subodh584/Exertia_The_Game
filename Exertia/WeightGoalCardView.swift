import UIKit

class WeightGoalCardView: UIView {
    
    @IBOutlet weak var progressView: UIView!
    @IBOutlet weak var progressWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var trackView: UIView!
    @IBOutlet weak var thumbCircleView: UIView!
    
    // MARK: - Configuration
    func configure(start: Double, current: Double, target: Double) {
        // 1. Calculate Math
        let totalToLose = start - target
        let lostSoFar = start - current
        
        var progressRatio: CGFloat = 0.0
        
        if totalToLose > 0 {
            progressRatio = CGFloat(lostSoFar / totalToLose)
        }
        
        // 2. Update Text Labels (COMMENTED OUT UNTIL YOU ADD THEM)
        /*
        if let startLabel = startWeightLabel { startLabel.text = "\(Int(start)) Kgs" }
        if let targetLabel = targetWeightLabel { targetLabel.text = "\(Int(target)) Kgs" }
        if let toolTip = tooltipLabel { toolTip.text = "\(current)" }
        */
        
        // 3. Update Bar
        self.setProgress(to: progressRatio)
    }

    // MARK: - Progress Logic
    func setProgress(to value: CGFloat) {
        // 1. Clamp value between 0.0 and 1.0
        let clampedValue = min(max(value, 0), 1)
        
        // 2. Check connections
        guard let pView = progressView, let tView = trackView else { return }

        // 3. Remove the OLD constraint (if it exists)
        if let existing = progressWidthConstraint {
            pView.removeConstraint(existing)
            existing.isActive = false
        }
        
        // 4. Create the NEW constraint
        let newConstraint = pView.widthAnchor.constraint(
            equalTo: tView.widthAnchor,
            multiplier: clampedValue
        )
        newConstraint.isActive = true
        
        // 5. Store it for next time
        self.progressWidthConstraint = newConstraint
        
        // 6. Force Layout Update IMMEDIATELY (No Animation)
        self.setNeedsLayout()
        self.layoutIfNeeded()
    }
    
    // MARK: - Gradient Styling
    override func layoutSubviews() {
            super.layoutSubviews()
            
            // 1. Setup Gradient (Existing Code)
            if progressView.layer.sublayers?.first is CAGradientLayer == false {
                let gradient = CAGradientLayer()
                gradient.colors = [
                    UIColor(hex: "#FFEFBE").cgColor,
                    UIColor(hex: "#FFA6DF").cgColor,
                    UIColor(hex: "#FF81EF").cgColor,
                    UIColor(hex: "#FF5CFF").cgColor
                ]
                gradient.locations = [0.0, 0.47, 0.74, 0.97]
                gradient.startPoint = CGPoint(x: 0.0, y: 0.5)
                gradient.endPoint = CGPoint(x: 1.0, y: 0.5)
                progressView.layer.insertSublayer(gradient, at: 0)
            }
            if let gradient = progressView.layer.sublayers?.first as? CAGradientLayer {
                gradient.frame = progressView.bounds
                gradient.cornerRadius = progressView.layer.cornerRadius
            }
            
            // 2. Make Thumb Circular
            if let thumb = thumbCircleView {
                thumb.layer.cornerRadius = thumb.frame.width / 2
                thumb.layer.masksToBounds = true
                thumb.layer.borderWidth = 4
                thumb.layer.borderColor = UIColor(hex: "#FFEFBE").cgColor
            }
            
            // --- 3. MANUAL POSITIONING (The Fix) ---
            // We force the thumb to sit exactly at the end of the pink bar
        if let thumb = thumbCircleView, let pView = progressView, let tView = trackView {
                    
                    // 1. Find the point at the end of the pink bar
                    // (This point is currently relative to the Gray Track)
                    let endPointInTrack = CGPoint(x: pView.frame.maxX, y: pView.frame.midY)
                    
                    // 2. Convert that point to the "Card" coordinates
                    // This adds the position of the Gray Track automatically!
                    let convertedPoint = tView.convert(endPointInTrack, to: self)
                    
                    // 3. Move the thumb to that calculated spot
                    thumb.center = convertedPoint
                }
        }
}
