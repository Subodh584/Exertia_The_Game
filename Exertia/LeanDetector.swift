//
//  LeanDetector.swift
//  VisionExample
//
//  Created on 23 December 2025.
//

import Foundation
import MLKit

/// Detects left and right body lean by analyzing torso angle
class LeanDetector {
    
    // MARK: - Types
    
    enum LeanDirection {
        case neutral
        case left
        case right
    }
    
    // MARK: - Properties
    
    // Lean detection
    private var currentLeanDirection: LeanDirection = .neutral
    private var leanThreshold: CGFloat = 20.0 // degrees
    
    // Angle smoothing (moving average)
    private var angleHistory: [CGFloat] = []
    private let smoothingFrames: Int = 5 // Average over 5 frames
    
    // Callbacks
    var onLeanDetected: ((LeanDirection) -> Void)?
    var onAngleUpdated: ((CGFloat) -> Void)? // Real-time angle display
    
    // MARK: - Initialization
    
    init(leanThreshold: CGFloat = 20.0) {
        self.leanThreshold = leanThreshold
    }
    
    // MARK: - Public Configuration Methods
    
    /// Adjust the lean detection threshold (angle from vertical)
    /// - Parameter threshold: Angle in degrees. Default is 20.0
    func setLeanThreshold(_ threshold: CGFloat) {
        self.leanThreshold = max(0.0, min(90.0, threshold))
        print("📐 Lean threshold set to: \(self.leanThreshold)°")
    }
    
    /// Get current lean threshold value
    func getLeanThreshold() -> CGFloat {
        return leanThreshold
    }
    
    // MARK: - Public Methods
    
    /// Process a pose and detect leaning motion
    func processPose(_ pose: Pose) {
        // Get shoulder landmarks
        guard let leftShoulder = getLandmark(pose, type: .leftShoulder),
              let rightShoulder = getLandmark(pose, type: .rightShoulder),
              let leftHip = getLandmark(pose, type: .leftHip),
              let rightHip = getLandmark(pose, type: .rightHip) else {
            return
        }
        
        // Calculate center points
        // Y-axis is horizontal (left/right)
        let shoulderCenterY = (leftShoulder.position.y + rightShoulder.position.y) / 2.0
        // X-axis is vertical (up/down)
        let shoulderCenterX = (leftShoulder.position.x + rightShoulder.position.x) / 2.0
        
        let hipCenterY = (leftHip.position.y + rightHip.position.y) / 2.0
        let hipCenterX = (leftHip.position.x + rightHip.position.x) / 2.0
        
        // Calculate angle from vertical
        // Vector from hip to shoulder
        let deltaY = shoulderCenterY - hipCenterY  // Horizontal displacement
        let deltaX = shoulderCenterX - hipCenterX  // Vertical displacement
        
        // Calculate angle using atan2
        // We want angle from vertical, so we swap the parameters
        // atan2(horizontal, vertical) gives us angle from vertical axis
        let angleRadians = atan2(deltaY, deltaX)
        
        // Convert to degrees
        var angleDegrees = angleRadians * 180.0 / .pi
        
        // Adjust so that:
        // - Leaning right (shoulder moves right, Y increases) = positive angle
        // - Leaning left (shoulder moves left, Y decreases) = negative angle
        // - Standing straight = 0°
        // Since atan2(y,x) gives angle from X-axis, we need to subtract 90° to get angle from vertical
        angleDegrees = angleDegrees - 90.0
        
        // Normalize angle to -180 to 180 range
        if angleDegrees > 180.0 {
            angleDegrees -= 360.0
        } else if angleDegrees < -180.0 {
            angleDegrees += 360.0
        }
        
        // Apply smoothing
        let smoothedAngle = smoothAngle(angleDegrees)
        
        // Send real-time angle update
        onAngleUpdated?(smoothedAngle)
        
        // Detect lean based on threshold
        detectLean(angle: smoothedAngle)
    }
    
    /// Reset the detector to initial state
    func reset() {
        currentLeanDirection = .neutral
        angleHistory.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func getLandmark(_ pose: Pose, type: PoseLandmarkType) -> PoseLandmark? {
        let landmark = pose.landmark(ofType: type)
        // Check if landmark has reasonable confidence
        if landmark.inFrameLikelihood > 0.5 {
            return landmark
        }
        return nil
    }
    
    private func smoothAngle(_ angle: CGFloat) -> CGFloat {
        // Add current angle to history
        angleHistory.append(angle)
        
        // Keep only last N frames
        if angleHistory.count > smoothingFrames {
            angleHistory.removeFirst()
        }
        
        // Calculate average
        let sum = angleHistory.reduce(0.0, +)
        return sum / CGFloat(angleHistory.count)
    }
    
    private func detectLean(angle: CGFloat) {
        let newDirection: LeanDirection
        
        // Use difficulty-based thresholds
        let rightThreshold = DifficultySettings.shared.leanRightThreshold
        let leftThreshold = DifficultySettings.shared.leanLeftThreshold
        
        if angle < rightThreshold {
            // Leaning right
            newDirection = .right
        } else if angle > leftThreshold {
            // Leaning left
            newDirection = .left
        } else {
            // Neutral zone (-threshold to +threshold)
            newDirection = .neutral
        }
        
        // Only trigger callback when direction changes
        if newDirection != currentLeanDirection && newDirection != .neutral {
            currentLeanDirection = newDirection
            onLeanDetected?(newDirection)
            
            switch newDirection {
            case .left:
//                print("⬅️ LEAN LEFT detected! Angle: \(String(format: "%.1f", angle))°")
                break
            case .right:
//                print("➡️ LEAN RIGHT detected! Angle: \(String(format: "%.1f", angle))°")
                break
            case .neutral:
                break
            }
        }
        
        // Update current direction for next comparison
        if newDirection == .neutral {
            currentLeanDirection = .neutral
        }
    }
}
