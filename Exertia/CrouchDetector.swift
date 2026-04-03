//
//  CrouchDetector.swift
//  VisionExample
//
//  Created on 23 December 2025.
//

import Foundation
import MLKit

/// Detects crouching by measuring the vertical distance between hip and toe landmarks.
/// Works reliably when the user faces the camera directly (front-facing view).
class CrouchDetector {

    // MARK: - Types

    enum CrouchState {
        case notCrouching
        case crouching
    }

    // MARK: - Properties

    // Crouch detection
    private var currentCrouchState: CrouchState = .notCrouching
    private var crouchThreshold: CGFloat = 180.0 // pixels — vertical distance between hip and toe

    // Distance smoothing (moving average)
    private var leftDistanceHistory: [CGFloat] = []
    private var rightDistanceHistory: [CGFloat] = []
    private let smoothingFrames: Int = 5 // Average over 5 frames

    // Callbacks
    var onCrouchStateChanged: ((CrouchState) -> Void)?
    var onDistancesUpdated: ((CGFloat, CGFloat) -> Void)? // (leftHipToToe, rightHipToToe)

    // MARK: - Initialization

    init(crouchThreshold: CGFloat = 180.0) {
        self.crouchThreshold = crouchThreshold
    }

    // MARK: - Public Configuration Methods

    /// Adjust the crouch detection threshold
    /// - Parameter threshold: Vertical pixel distance between hip and toe. Default is 180.0
    func setCrouchThreshold(_ threshold: CGFloat) {
        self.crouchThreshold = max(0.0, threshold)
        print("🦵 Crouch threshold set to: \(self.crouchThreshold)px")
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
              let leftToe = getLandmark(pose, type: .leftToe),
              let rightHip = getLandmark(pose, type: .rightHip),
              let rightToe = getLandmark(pose, type: .rightToe) else {
            return
        }

        // Calculate vertical distance between hip and toe for each side
        let leftDistance = calculateHipToToeDistance(hip: leftHip.position, toe: leftToe.position)
        let rightDistance = calculateHipToToeDistance(hip: rightHip.position, toe: rightToe.position)

        // Apply smoothing
        let smoothedLeft = smoothValue(leftDistance, history: &leftDistanceHistory)
        let smoothedRight = smoothValue(rightDistance, history: &rightDistanceHistory)

        // Send real-time distance updates
        onDistancesUpdated?(smoothedLeft, smoothedRight)

        // Detect crouch based on both hip-to-toe distances
        detectCrouch(leftDistance: smoothedLeft, rightDistance: smoothedRight)
    }

    /// Reset the detector to initial state
    func reset() {
        currentCrouchState = .notCrouching
        leftDistanceHistory.removeAll()
        rightDistanceHistory.removeAll()
    }

    // MARK: - Private Methods

    private func getLandmark(_ pose: Pose, type: PoseLandmarkType) -> PoseLandmark? {
        let landmark = pose.landmark(ofType: type)
        if landmark.inFrameLikelihood > 0.5 {
            return landmark
        }
        return nil
    }

    /// Returns the vertical pixel distance between hip and toe.
    /// When standing, hips are far above toes (large value).
    /// When crouching, hips drop toward toe level (smaller value).
    private func calculateHipToToeDistance(hip: VisionPoint, toe: VisionPoint) -> CGFloat {
        return abs(hip.y - toe.y)
    }

    private func smoothValue(_ value: CGFloat, history: inout [CGFloat]) -> CGFloat {
        history.append(value)
        if history.count > smoothingFrames {
            history.removeFirst()
        }
        let sum = history.reduce(0.0, +)
        return sum / CGFloat(history.count)
    }

    private func detectCrouch(leftDistance: CGFloat, rightDistance: CGFloat) {
        let newState: CrouchState

        // Use difficulty-based threshold (pixel distance)
        let threshold = DifficultySettings.shared.crouchThreshold

        // Crouch detected when BOTH hips are close enough to their respective toes
        if leftDistance < threshold && rightDistance < threshold {
            newState = .crouching
        } else {
            newState = .notCrouching
        }

        // Trigger callback when state changes
        if newState != currentCrouchState {
            currentCrouchState = newState
            onCrouchStateChanged?(newState)

            switch newState {
            case .crouching:
                print("🔽 CROUCHING detected! Left: \(String(format: "%.1f", leftDistance))px Right: \(String(format: "%.1f", rightDistance))px")
            case .notCrouching:
                print("🔼 Standing up - Crouch ended")
            }
        }
    }
}
