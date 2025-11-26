import UIKit

class WeightGoalCardView: UIView {
    
    @IBOutlet weak var progressView: UIView!
    @IBOutlet weak var progressWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var trackView: UIView!
    @IBOutlet weak var thumbCircleView: UIView!
    
    @IBOutlet weak var tooltipView: UIView!  // The yellow box
        @IBOutlet weak var tooltipLabel: UILabel! // The text inside
    
    private let triangleView = UIView()
    
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
        
        if let toolTip = tooltipLabel {
                    toolTip.text = "\(current)"
                }
                
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
            
            // 1. Gradient Setup (Keep existing code)
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
            
            // 2. Thumb Styling
            if let thumb = thumbCircleView {
                thumb.layer.cornerRadius = thumb.frame.width / 2
                thumb.layer.masksToBounds = true
                thumb.layer.borderWidth = 4
                thumb.layer.borderColor = UIColor(hex: "#FFEFBE").cgColor
            }
            
            // --- 3. MANUAL POSITIONING (Thumb & Tooltip) ---
            if let thumb = thumbCircleView, let pView = progressView, let tView = trackView {
                
                // A. Calculate Thumb Position
                let endPointInTrack = CGPoint(x: pView.frame.maxX, y: pView.frame.midY)
                let thumbCenter = tView.convert(endPointInTrack, to: self)
                
                // Move Thumb
                thumb.center = thumbCenter
                
                // B. Calculate Tooltip Position
                // B. Calculate Tooltip Position
                            if let tooltip = tooltipView {
                                // Style the tooltip box
                                tooltip.backgroundColor = UIColor(hex: "#FFEFBE")
                                tooltip.layer.cornerRadius = 6
                                tooltip.layer.masksToBounds = true
                                
                                // --- NEW: SIZE & POSITION LOGIC ---
                                let tooltipWidth: CGFloat = 40
                                let tooltipHeight: CGFloat = 22
                                let padding: CGFloat = 8
                                
                                // Calculate Y to be above thumb
                                let tooltipY = thumb.frame.minY - (tooltipHeight / 2) - padding
                                
                                // Set the frame manually (forces size and position)
                                tooltip.bounds = CGRect(x: 0, y: 0, width: tooltipWidth, height: tooltipHeight)
                                tooltip.center = CGPoint(x: thumbCenter.x, y: tooltipY)
                            }
                
            }
        if let thumb = thumbCircleView, let tooltip = tooltipView {
                    
                    // 1. Add to screen if needed
                    if triangleView.superview == nil {
                        self.addSubview(triangleView)
                        triangleView.backgroundColor = .clear
                    }
                    
                    // 2. Define Size
                    let triWidth: CGFloat = 10
                    let triHeight: CGFloat = 8
                    
                    // 3. Draw the Triangle Shape
                    // We draw an upside-down triangle (V shape) to point down at the thumb
                    let path = UIBezierPath()
                    path.move(to: CGPoint(x: 0, y: 0))           // Top Left
                    path.addLine(to: CGPoint(x: triWidth, y: 0)) // Top Right
                    path.addLine(to: CGPoint(x: triWidth/2, y: triHeight)) // Bottom Point
                    path.close()
                    
                    let shapeLayer = CAShapeLayer()
                    shapeLayer.path = path.cgPath
                    shapeLayer.fillColor = UIColor(hex: "#FFEFBE").cgColor // Same yellow as tooltip
                    
                    // Reset layer to avoid drawing it 100 times
                    triangleView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
                    triangleView.layer.addSublayer(shapeLayer)
                    
                    // 4. Position it
                    // X: Center of the thumb
                    // Y: Right below the tooltip box
                    triangleView.frame = CGRect(x: 0, y: 0, width: triWidth, height: triHeight)
                    triangleView.center = CGPoint(x: thumb.center.x, y: tooltip.frame.maxY + (triHeight / 2))
                }
        }
}
