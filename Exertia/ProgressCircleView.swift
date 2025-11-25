import UIKit

@IBDesignable
class ProgressCircleView: UIView {

    @IBInspectable var ringWidth: CGFloat = 10.0 {
        didSet { setNeedsDisplay() }
    }
    @IBInspectable var backgroundRingColor: UIColor = UIColor.darkGray.withAlphaComponent(0.8) {
        didSet { setNeedsDisplay() }
    }
    @IBInspectable var progressRingColor: UIColor = .magenta { // Default to magenta
        didSet { setNeedsDisplay() }
    }
    @IBInspectable var progressValue: CGFloat = 0.75 { // 0.0 to 1.0
        didSet { setNeedsDisplay() }
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - ringWidth / 2

        // Background Ring (full circle)
        let backgroundPath = UIBezierPath(arcCenter: center,
                                         radius: radius,
                                         startAngle: -CGFloat.pi / 2, // Start at top
                                         endAngle: CGFloat.pi * 2 - CGFloat.pi / 2, // Full circle from top
                                         clockwise: true)
        backgroundPath.lineWidth = ringWidth
        backgroundRingColor.setStroke()
        backgroundPath.stroke()

        // Progress Ring
        let startAngle = -CGFloat.pi / 2 // Start at the top
        let endAngle = startAngle + (CGFloat.pi * 2 * progressValue)
        
        let progressPath = UIBezierPath(arcCenter: center,
                                        radius: radius,
                                        startAngle: startAngle,
                                        endAngle: endAngle,
                                        clockwise: true)
        progressPath.lineWidth = ringWidth
        progressRingColor.setStroke()
        progressPath.stroke()
    }
}
