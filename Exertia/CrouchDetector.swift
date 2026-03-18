//
//  CrouchDetector.swift
//  VisionExample
//
//  Created on 23 December 2025.
//

import Foundation
import MLKit

/// Detects crouching by analyzing knee bend angles
class CrouchDetector {
    
    // MARK: - Types
    
    enum CrouchState {
        case notCrouching
        case crouching
    }
    
    // MARK: - Properties
    
    // Crouch detection
    private var currentCrouchState: CrouchState = .notCrouching
    private var crouchThreshold: CGFloat = 135.0 // degrees
    
    // Angle smoothing (moving average)
    private var leftKneeAngleHistory: [CGFloat] = []
    private var rightKneeAngleHistory: [CGFloat] = []
    private let smoothingFrames: Int = 5 // Average over 5 frames
    
    // Callbacks
    var onCrouchStateChanged: ((CrouchState) -> Void)?
    var onKneeAnglesUpdated: ((CGFloat, CGFloat) -> Void)? // (leftKneeAngle, rightKneeAngle)
    
    // MARK: - Initialization
    
    init(crouchThreshold: CGFloat = 135.0) {
        self.crouchThreshold = crouchThreshold
    }
    
    // MARK: - Public Configuration Methods
    
    /// Adjust the crouch detection threshold
    /// - Parameter threshold: Knee angle in degrees. Default is 135.0
    func setCrouchThreshold(_ threshold: CGFloat) {
        self.crouchThreshold = max(0.0, min(180.0, threshold))
        print("🦵 Crouch threshold set to: \(self.crouchThreshold)°")
    }
    
    /// Get current crouch threshold value
    func getCrouchThreshold() -> CGFloat {
        return crouchThreshold
    }
    
    // MARK: - Public Methods
    
    /// Process a pose and detect crouching motion
    func processPose(_ pose: Pose) {
        // Get required landmarks for both legs
        guard let leftHip = getLandmark(pose, type: .leftHip),
              let leftKnee = getLandmark(pose, type: .leftKnee),
              let leftAnkle = getLandmark(pose, type: .leftAnkle),
              let rightHip = getLandmark(pose, type: .rightHip),
              let rightKnee = getLandmark(pose, type: .rightKnee),
              let rightAnkle = getLandmark(pose, type: .rightAnkle) else {
            return
        }
        
        // Calculate left knee angle
        let leftKneeAngle = calculateKneeAngle(
            hip: leftHip.position,
            knee: leftKnee.position,
            ankle: leftAnkle.position
        )
        
        // Calculate right knee angle
        let rightKneeAngle = calculateKneeAngle(
            hip: rightHip.position,
            knee: rightKnee.position,
            ankle: rightAnkle.position
        )
        
        // Apply smoothing
        let smoothedLeftKneeAngle = smoothAngle(leftKneeAngle, history: &leftKneeAngleHistory)
        let smoothedRightKneeAngle = smoothAngle(rightKneeAngle, history: &rightKneeAngleHistory)
        
        // Send real-time angle updates
        onKneeAnglesUpdated?(smoothedLeftKneeAngle, smoothedRightKneeAngle)
        
        // Detect crouch based on both knee angles
        detectCrouch(leftKneeAngle: smoothedLeftKneeAngle, rightKneeAngle: smoothedRightKneeAngle)
    }
    
    /// Reset the detector to initial state
    func reset() {
        currentCrouchState = .notCrouching
        leftKneeAngleHistory.removeAll()
        rightKneeAngleHistory.removeAll()
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
    
    private func calculateKneeAngle(hip: VisionPoint, knee: VisionPoint, ankle: VisionPoint) -> CGFloat {
        // Calculate vectors from knee to hip and knee to ankle
        // Vector1: knee → hip
        let vector1X = hip.x - knee.x
        let vector1Y = hip.y - knee.y
        
        // Vector2: knee → ankle
        let vector2X = ankle.x - knee.x
        let vector2Y = ankle.y - knee.y
        
        // Calculate dot product
        let dotProduct = vector1X * vector2X + vector1Y * vector2Y
        
        // Calculate magnitudes
        let magnitude1 = sqrt(vector1X * vector1X + vector1Y * vector1Y)
        let magnitude2 = sqrt(vector2X * vector2X + vector2Y * vector2Y)
        
        // Avoid division by zero
        guard magnitude1 > 0 && magnitude2 > 0 else {
            return 180.0 // Return straight leg angle if calculation fails
        }
        
        // Calculate cosine of angle
        let cosAngle = dotProduct / (magnitude1 * magnitude2)
        
        // Clamp to valid range for acos [-1, 1]
        let clampedCosAngle = max(-1.0, min(1.0, cosAngle))
        
        // Calculate angle in radians
        let angleRadians = acos(clampedCosAngle)
        
        // Convert to degrees
        let angleDegrees = angleRadians * 180.0 / .pi
        
        return angleDegrees
    }
    
    private func smoothAngle(_ angle: CGFloat, history: inout [CGFloat]) -> CGFloat {
        // Add current angle to history
        history.append(angle)
        
        // Keep only last N frames
        if history.count > smoothingFrames {
            history.removeFirst()
        }
        
        // Calculate average
        let sum = history.reduce(0.0, +)
        return sum / CGFloat(history.count)
    }
    
    private func detectCrouch(leftKneeAngle: CGFloat, rightKneeAngle: CGFloat) {
        let newState: CrouchState
        
        // Use difficulty-based threshold
        let threshold = DifficultySettings.shared.crouchThreshold
        
        // Crouch detected only when BOTH knees are bent below threshold
        if leftKneeAngle < threshold && rightKneeAngle < threshold {
            newState = .crouching
        } else {
            // Either knee is above threshold - not crouching
            newState = .notCrouching
        }
        
        // Trigger callback when state changes
        if newState != currentCrouchState {
            currentCrouchState = newState
            onCrouchStateChanged?(newState)
            
            switch newState {
            case .crouching:
                print("🔽 CROUCHING detected! Left: \(String(format: "%.1f", leftKneeAngle))° Right: \(String(format: "%.1f", rightKneeAngle))°")
            case .notCrouching:
                print("🔼 Standing up - Crouch ended")
            }
        }
    }
}
