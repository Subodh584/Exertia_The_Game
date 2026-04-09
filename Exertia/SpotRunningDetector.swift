//
//  SpotRunningDetector.swift
//  VisionExample
//
//  Created on 22 December 2025.
//

import Foundation
import MLKit

/// Detects spot running (running in place) using pose landmarks
class SpotRunningDetector {
    
    // MARK: - Types
    
    enum FootState {
        case grounded
        case lifted
    }
    
    enum Foot {
        case left
        case right
        
        var opposite: Foot {
            return self == .left ? .right : .left
        }
    }
    
    // MARK: - Properties
    
    // Foot lift detection
    private var leftFootState: FootState = .grounded
    private var rightFootState: FootState = .grounded
    private var lastLiftedFoot: Foot?
    
    // Rep counting
    private var repCount: Int = 0
    private var isWaitingForSecondFootLift: Bool = false
    
    // Thresholds
    private let minHeightThresholdRatio: CGFloat = 0.50 // 50% of hip-to-ankle distance
    private let idleThreshold: CGFloat = 0.20 // Threshold for considering feet at same level
    
    // Hip-to-ankle reference distance (computed from first valid pose)
    private var referenceDistance: CGFloat?
    private var lastReferenceUpdateTime: Date?
    private let referenceUpdateInterval: TimeInterval = 3.0 // Update every 3 seconds
    
    // Running state tracking
    private(set) var isCurrentlyRunning: Bool = false
    private var lastActivityTime: Date?
    private let activityTimeout: TimeInterval = 0.5  // Stop after 0.5s of no reps
    
    // Callbacks
    var onRunningStateChanged: ((Bool) -> Void)?
    var onRepCompleted: ((Int) -> Void)?  // Called when a rep is completed
    var onDebugInfo: ((CGFloat, CGFloat) -> Void)?  // (threshold, footDiff)
    
    // MARK: - Initialization
    
    init() {
        lastActivityTime = nil
    }
    
    // MARK: - Public Methods
    
    /// Process a pose and update running detection
    func processPose(_ pose: Pose) {
        checkActivityTimeout()
        
        // Get ankle and hip landmarks
        guard let leftAnkle = getLandmark(pose, type: .leftAnkle),
              let rightAnkle = getLandmark(pose, type: .rightAnkle),
              let leftHip = getLandmark(pose, type: .leftHip),
              let rightHip = getLandmark(pose, type: .rightHip) else {
            return
        }
        
        // Update reference distance every 3 seconds or if not set
        let now = Date()
        let shouldUpdateReference = referenceDistance == nil || 
            (lastReferenceUpdateTime == nil) ||
            (now.timeIntervalSince(lastReferenceUpdateTime!) >= referenceUpdateInterval)
        
        if shouldUpdateReference {
            // Calculate horizontal distance between hips (body width) for X-axis detection
            let hipWidth = abs(leftHip.position.x - rightHip.position.x)
            referenceDistance = hipWidth
            lastReferenceUpdateTime = now
            print("📏 Reference distance updated: \(referenceDistance ?? 0)")
        }
        
//        guard let refDistance = referenceDistance, refDistance > 0 else { return }
        
        // Use difficulty-based refDistance
        let refDistance = DifficultySettings.shared.spotRunningRefDistance
        // Calculate dynamic threshold based on leg length
        let minHeightThreshold = refDistance * minHeightThresholdRatio
        
        // Detect foot lifts
        detectFootLifts(
            leftAnkle: leftAnkle.position,
            rightAnkle: rightAnkle.position,
            minHeightThreshold: minHeightThreshold
        )
    }
    
    /// Reset the detector to initial state
    func reset() {
        leftFootState = .grounded
        rightFootState = .grounded
        lastLiftedFoot = nil
        repCount = 0
        isWaitingForSecondFootLift = false
        referenceDistance = nil
        lastReferenceUpdateTime = nil
        isCurrentlyRunning = false
        lastActivityTime = nil
        
        onRunningStateChanged?(false)
    }
    
    // MARK: - Private Methods
    
    private func getLandmark(_ pose: Pose, type: PoseLandmarkType) -> PoseLandmark? {
        let landmark = pose.landmark(ofType: type)
        // Check if landmark has reasonable confidence (inFrameLikelihood)
        if landmark.inFrameLikelihood > 0.5 {
            return landmark
        }
        return nil
    }
    
    private func detectFootLifts(leftAnkle: VisionPoint, rightAnkle: VisionPoint, minHeightThreshold: CGFloat) {
        // Note: In camera coordinates, Y increases downward (0=top, 1=bottom)
        // So a LIFTED foot has a SMALLER Y value (closer to 0)
        // And a GROUNDED foot has a LARGER Y value (closer to 1)
        
        let leftFootX = leftAnkle.x   // Horizontal position of left ankle
        let rightFootX = rightAnkle.x // Horizontal position of right ankle
//        print(leftFootX, rightFootX)
        
        // Calculate HORIZONTAL foot difference (X-axis):
        // Positive value = right foot is more to the RIGHT
        // Negative value = left foot is more to the RIGHT
        let footDiff = rightFootX - leftFootX
        
        // Send debug info to UI
        onDebugInfo?(minHeightThreshold, footDiff)
        
        // Check if feet are at approximately the same horizontal level
        let xDifference = abs(footDiff)
        if xDifference < idleThreshold * (referenceDistance ?? 1.0) {
            // Both feet are at similar horizontal position
            resetFootStates()
            return
        }
        
        // Determine which foot is lifted based on HORIZONTAL position:
        // Left foot is considered "lifted" if horizontally separated enough
        let isLeftFootLifted = footDiff > minHeightThreshold
        
        // Right foot is considered "lifted" if horizontally separated enough
        let isRightFootLifted = -footDiff > minHeightThreshold
        
        // Update left foot state
        updateFootState(
            foot: .left,
            isLifted: isLeftFootLifted,
            currentState: leftFootState
        ) { newState in
            leftFootState = newState
        }
        
        // Update right foot state
        updateFootState(
            foot: .right,
            isLifted: isRightFootLifted,
            currentState: rightFootState
        ) { newState in
            rightFootState = newState
        }
    }
    
    private func updateFootState(
        foot: Foot,
        isLifted: Bool,
        currentState: FootState,
        updateHandler: (FootState) -> Void
    ) {
        if isLifted {
            if currentState == .grounded {
                // Foot just lifted
                let oppositeFoot = foot.opposite
                let isOppositeFootGrounded = (foot == .left ? rightFootState : leftFootState) == .grounded
                
                // Check for valid alternation
                if lastLiftedFoot == nil || lastLiftedFoot == oppositeFoot {
                    if isOppositeFootGrounded {
                        // Valid lift detected
                        updateHandler(.lifted)
                        handleFootLift(foot)
                    }
                }
            }
        } else {
            // Foot is grounded
            if currentState == .lifted {
                // Foot just landed
                updateHandler(.grounded)
            }
        }
    }
    
    private func handleFootLift(_ foot: Foot) {
//        print("🦶 Foot lifted: \(foot == .left ? "LEFT" : "RIGHT")")
        
        if lastLiftedFoot == nil {
            // First lift in the cycle
            lastLiftedFoot = foot
            isWaitingForSecondFootLift = true
//            print("✅ First lift - waiting for opposite foot")
        } else if lastLiftedFoot == foot.opposite && isWaitingForSecondFootLift {
            // Second lift in the cycle - complete rep!
//            print("🎉 COMPLETE REP! Both feet lifted alternately")
            completeRep()
        }
    }
    
    private func completeRep() {
        repCount += 1
//        print("🏃 Rep completed! Total reps: \(repCount)")
        
        // Mark as actively running
        lastActivityTime = Date()
        if !isCurrentlyRunning {
            isCurrentlyRunning = true
            onRunningStateChanged?(true)
        }
        
        // Notify rep completed (this triggers speed bar increase)
        onRepCompleted?(repCount)
        
        // Reset for next cycle
        isWaitingForSecondFootLift = false
        lastLiftedFoot = nil
//        print("🔄 Ready for next cycle")
    }
    
    private func resetFootStates() {
        leftFootState = .grounded
        rightFootState = .grounded
        // Note: Don't reset lastLiftedFoot here to maintain cycle continuity
    }
    
    private func checkActivityTimeout() {
        guard let lastActivity = lastActivityTime else {
            return
        }
        
        let now = Date()
        let timeSinceLastActivity = now.timeIntervalSince(lastActivity)
        
        // If no reps for activityTimeout seconds, stop running state
        if timeSinceLastActivity > activityTimeout && isCurrentlyRunning {
            isCurrentlyRunning = false
            onRunningStateChanged?(false)
//            print("⏸️ Running stopped - no activity for \(activityTimeout)s")
        }
    }
    
    // MARK: - Getters
    
    func getRepCount() -> Int {
        return repCount
    }
    
    func isRunning() -> Bool {
        return isCurrentlyRunning
    }
}


