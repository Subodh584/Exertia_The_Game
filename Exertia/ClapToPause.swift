//
//  ClapToJumpDetector.swift
//  VisionExample
//
//  Created on 23 December 2025.
//

import Foundation
import MLKit

/// Detects clap-to-jump gesture by analyzing wrist proximity above nose level
class ClapToPause{
    
    // MARK: - Types
    
    enum ClapState {
        case notClapping
        case clapping
        case cooldown
    }
    
    // MARK: - Properties
    
    // Clap detection
    private var currentClapState: ClapState = .notClapping
    private var clapDistanceThreshold: CGFloat = 30.0 // Distance in points
    
    // Cooldown management
    private var cooldownTimer: Timer?
    private let cooldownDuration: TimeInterval = 1.0 // 1 second
    
    // Callbacks
    var onClapDetected: (() -> Void)?
    var onWristDistanceUpdated: ((CGFloat) -> Void)? // Real-time distance feedback
    var onDebugInfo: ((CGFloat, Bool) -> Void)? // (distance, isAboveNose)
    
    // MARK: - Initialization
    
    init(clapDistanceThreshold: CGFloat = 30.0) {
        self.clapDistanceThreshold = clapDistanceThreshold
    }
    
    deinit {
        cooldownTimer?.invalidate()
    }
    
    // MARK: - Public Configuration Methods
    
    /// Adjust the clap detection distance threshold
    /// - Parameter threshold: Distance threshold in points. Default is 30.0
    func setClapDistanceThreshold(_ threshold: CGFloat) {
        self.clapDistanceThreshold = max(0.0, threshold)
        print("👏 Clap distance threshold set to: \(self.clapDistanceThreshold)")
    }
    
    /// Get current clap distance threshold value
    func getClapDistanceThreshold() -> CGFloat {
        return clapDistanceThreshold
    }
    
    // MARK: - Public Methods
    
    /// Process a pose and detect clap-to-jump gesture
    func processPose(_ pose: Pose) {
        // Get required landmarks
        guard let nose = getLandmark(pose, type: .nose),
              let leftWrist = getLandmark(pose, type: .leftWrist),
              let rightWrist = getLandmark(pose, type: .rightWrist) else {
            return
        }
        
        // Calculate distance between wrists (Euclidean distance)
        let wristDistance = calculateDistance(
            from: leftWrist.position,
            to: rightWrist.position
        )
        
        // Send real-time distance update
        onWristDistanceUpdated?(wristDistance)
        
        // Calculate average X position of wrists (X is vertical axis)
        let wristsAverageX = (leftWrist.position.x + rightWrist.position.x) / 2.0
        let noseX = nose.position.x
        
        // Check if wrists are above nose
        // In camera coordinates, LOWER X values = HIGHER position (above)
        let isAboveNose = wristsAverageX < noseX
        
        // Send debug info
        onDebugInfo?(wristDistance, isAboveNose)
        
        // Detect clap based on current state
        detectClap(distance: wristDistance, isAboveNose: isAboveNose)
    }
    
    /// Reset the detector to initial state
    func reset() {
        currentClapState = .notClapping
        cooldownTimer?.invalidate()
        cooldownTimer = nil
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
    
    private func calculateDistance(from point1: VisionPoint, to point2: VisionPoint) -> CGFloat {
        let deltaX = point1.x - point2.x
        let deltaY = point1.y - point2.y
        return sqrt(deltaX * deltaX + deltaY * deltaY)
    }
    
    private func detectClap(distance: CGFloat, isAboveNose: Bool) {
        switch currentClapState {
        case .notClapping:
            // Check for clap: hands close together AND above nose
            if distance < clapDistanceThreshold && isAboveNose {
                // Valid clap detected!
                triggerClapPause()
                currentClapState = .cooldown
                startCooldown()
                print("CLAP detected! Pause triggered. Distance: \(String(format: "%.3f", distance))")
            }
            
        case .clapping:
            // This state is not used in current implementation
            // but kept for potential future state machine refinements
            break
            
        case .cooldown:
            // Ignore all clap checks during cooldown
            // Prevents multiple jump triggers from same clap
            break
        }
    }
    
    private func triggerClapPause() {
        // Trigger pause callback
        onClapDetected?()
    }
    
    private func startCooldown() {
        // Invalidate any existing timer
        cooldownTimer?.invalidate()
        
        // Start new cooldown timer
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: cooldownDuration, repeats: false) { [weak self] _ in
            self?.endCooldown()
        }
    }
    
    private func endCooldown() {
        currentClapState = .notClapping
        print("Cooldown ended - Ready for next clap")
    }
}
