//
//  Jump2Detector.swift
//  VisionExample
//
//  Created on 27 January 2026.
//

import Foundation
import MLKit

class Jump2Detector {
    
    // MARK: - states
    enum JumpState {
        case notJumping
        case jumping
        case cooldown
    }
    
    /// Buffered frame data with all metrics
    private struct FrameData {
        let shoulderCenterX: CGFloat
        let hipCenterX: CGFloat
        let kneeCenterX: CGFloat
        let ankleCenterX: CGFloat
        let leftKneeAngle: CGFloat
        let rightKneeAngle: CGFloat
        let avgKneeAngle: CGFloat
        let torsoLength: CGFloat
    }
    
    // MARK: - Properties
    
    private var currentJumpState: JumpState = .notJumping
    

    private var frameBuffer: [FrameData] = []
    private let bufferSize: Int = 8
    

    private var groundBaseline: CGFloat = 0.0
    private var baselineHistory: [CGFloat] = []
    private let baselineHistorySize: Int = 30
    

    private var shoulderSmoothBuffer: [CGFloat] = []
    private var hipSmoothBuffer: [CGFloat] = []
    private var ankleSmoothBuffer: [CGFloat] = []
    private var kneeAngleSmoothBuffer: [CGFloat] = []
    private let smoothingWindow: Int = 3
    
    // Cooldown
    private var cooldownTimer: Timer?
    private let cooldownDuration: TimeInterval = 0.8
    
    // Current metrics for debugging
    private var currentThreshold: CGFloat = 0.0
    
    // Detection thresholds
    private let ankleLiftThresholdRatio: CGFloat = 0.08     // Ankles must lift 8% of torso length from baseline
    private let kneeAngleChangeTolerance: CGFloat = 15.0    // Knee angle can change max 15° (crouch-to-stand changes 30°+)
    private let upperBodyVelocityRatio: CGFloat = 0.10      // Upper body must move up 10% of torso length
    private let minConsecutiveFrames: Int = 2              // Need 2+ frames of valid jump motion
    
    // State tracking
    private var consecutiveValidFrames: Int = 0
    
    // Callbacks
    var onJumpTriggered: (() -> Void)?
    var onHeightDifferenceUpdated: ((CGFloat) -> Void)?
    var onThresholdUpdated: ((CGFloat) -> Void)?
    var onDebugInfo: ((CGFloat, CGFloat, Bool) -> Void)?
    
    // MARK: - Initialization
    
    init(thresholdMultiplier: CGFloat = 1.0) {
    }
    
    deinit {
        cooldownTimer?.invalidate()
    }
    
    // MARK: - Public Configuration Methods
    
    func setThresholdMultiplier(_ multiplier: CGFloat) {
        print("🦘 Jump2 configured")
    }
    
    func getThresholdMultiplier() -> CGFloat {
        return ankleLiftThresholdRatio
    }
    
    func getCurrentThreshold() -> CGFloat {
        return currentThreshold
    }
    
    // MARK: - Public Methods
    
    func processPose(_ pose: Pose) {
        // Get all required landmarks
        guard let leftShoulder = getLandmark(pose, type: .leftShoulder),
              let rightShoulder = getLandmark(pose, type: .rightShoulder),
              let leftHip = getLandmark(pose, type: .leftHip),
              let rightHip = getLandmark(pose, type: .rightHip),
              let leftKnee = getLandmark(pose, type: .leftKnee),
              let rightKnee = getLandmark(pose, type: .rightKnee),
              let leftAnkle = getLandmark(pose, type: .leftAnkle),
              let rightAnkle = getLandmark(pose, type: .rightAnkle) else {
            return
        }
        
        // Calculate center positions (X = vertical in camera coords, higher X = lower position)
        let shoulderCenterX = (leftShoulder.position.x + rightShoulder.position.x) / 2.0
        let hipCenterX = (leftHip.position.x + rightHip.position.x) / 2.0
        let kneeCenterX = (leftKnee.position.x + rightKnee.position.x) / 2.0
        let ankleCenterX = (leftAnkle.position.x + rightAnkle.position.x) / 2.0
        
        // Calculate knee angles (angle at knee joint: hip-knee-ankle)
        let leftKneeAngle = calculateAngle(
            pointA: leftHip.position,
            pointB: leftKnee.position,
            pointC: leftAnkle.position
        )
        let rightKneeAngle = calculateAngle(
            pointA: rightHip.position,
            pointB: rightKnee.position,
            pointC: rightAnkle.position
        )
        let avgKneeAngle = (leftKneeAngle + rightKneeAngle) / 2.0
        
        // Apply smoothing
        let smoothedShoulderX = smoothValue(shoulderCenterX, buffer: &shoulderSmoothBuffer)
        let smoothedHipX = smoothValue(hipCenterX, buffer: &hipSmoothBuffer)
        let smoothedAnkleX = smoothValue(ankleCenterX, buffer: &ankleSmoothBuffer)
        let smoothedKneeAngle = smoothValue(avgKneeAngle, buffer: &kneeAngleSmoothBuffer)
        
        // Calculate torso length for dynamic thresholds
        let torsoLength = abs(smoothedHipX - smoothedShoulderX)
        
        // Update ground baseline (track the lowest position ankles have been)
        updateGroundBaseline(ankleX: smoothedAnkleX)
        
        // Create frame data
        let frameData = FrameData(
            shoulderCenterX: smoothedShoulderX,
            hipCenterX: smoothedHipX,
            kneeCenterX: kneeCenterX,
            ankleCenterX: smoothedAnkleX,
            leftKneeAngle: leftKneeAngle,
            rightKneeAngle: rightKneeAngle,
            avgKneeAngle: smoothedKneeAngle,
            torsoLength: torsoLength
        )
        
        // Add to buffer
        frameBuffer.append(frameData)
        if frameBuffer.count > bufferSize {
            frameBuffer.removeFirst()
        }
        
        // Need enough frames
        guard frameBuffer.count >= 4 else { return }
        
        // Get comparison frame (4 frames ago)
        let oldFrame = frameBuffer[frameBuffer.count - 4]
        let currentFrame = frameData
        
        // === METRIC 1: ANKLE LIFT FROM GROUND ===
        // In camera coords: lower X = higher position
        // groundBaseline is the highest X value (lowest position) we've seen
        // If current ankle X is significantly lower than baseline, ankles have lifted
        let ankleLiftThreshold = currentFrame.torsoLength * ankleLiftThresholdRatio
        let ankleLiftFromGround = groundBaseline - currentFrame.ankleCenterX
        let hasAnkleLift = ankleLiftFromGround > ankleLiftThreshold
        
        // === METRIC 2: KNEE ANGLE STABILITY ===
        // During crouch-to-stand: knee angle INCREASES (legs straighten) by 20-40°
        // During jump: knee angle stays relatively stable (±15°)
        let kneeAngleChange = currentFrame.avgKneeAngle - oldFrame.avgKneeAngle
        let hasStableKnees = kneeAngleChange < kneeAngleChangeTolerance
        
        // === METRIC 3: UPPER BODY MOVING UP ===
        let upperBodyVelocityThreshold = currentFrame.torsoLength * upperBodyVelocityRatio
        let shoulderVelocity = oldFrame.shoulderCenterX - currentFrame.shoulderCenterX
        let hipVelocity = oldFrame.hipCenterX - currentFrame.hipCenterX
        let upperBodyVelocity = (shoulderVelocity + hipVelocity) / 2.0
        let hasUpperBodyLift = upperBodyVelocity > upperBodyVelocityThreshold
        
        // === METRIC 4: ANKLE ALSO MOVING UP ===
        // Real jump: ankles move up with body
        // Crouch-to-stand: ankles stay mostly in place
        let ankleVelocity = oldFrame.ankleCenterX - currentFrame.ankleCenterX
        let ankleMovingUp = ankleVelocity > (upperBodyVelocityThreshold * 0.5)
        
        // Combined validation - ALL conditions must be true
        let isValidJumpFrame = hasAnkleLift && hasStableKnees && hasUpperBodyLift && ankleMovingUp
        
        // Track consecutive valid frames
        if isValidJumpFrame {
            consecutiveValidFrames += 1
        } else {
            consecutiveValidFrames = max(0, consecutiveValidFrames - 1)
        }
        
        let isValidJump = consecutiveValidFrames >= minConsecutiveFrames
        
        // Update threshold for display
        currentThreshold = ankleLiftThreshold
        onThresholdUpdated?(currentThreshold)
        onHeightDifferenceUpdated?(ankleLiftFromGround)
        onDebugInfo?(ankleLiftFromGround, ankleLiftThreshold, isValidJump)
        
        // Debug logging
        if hasUpperBodyLift {
            print("🔍 AnkleLift:\(String(format: "%.1f", ankleLiftFromGround))/\(String(format: "%.1f", ankleLiftThreshold)) KneeΔ:\(String(format: "%.1f", kneeAngleChange))° AnkleVel:\(String(format: "%.1f", ankleVelocity)) Valid:\(isValidJumpFrame) Consec:\(consecutiveValidFrames)")
        }
        
        // Detect jump
        detectJump(isValidJump: isValidJump)
    }
    
    func reset() {
        currentJumpState = .notJumping
        frameBuffer.removeAll()
        baselineHistory.removeAll()
        groundBaseline = 0.0
        shoulderSmoothBuffer.removeAll()
        hipSmoothBuffer.removeAll()
        ankleSmoothBuffer.removeAll()
        kneeAngleSmoothBuffer.removeAll()
        consecutiveValidFrames = 0
        cooldownTimer?.invalidate()
        cooldownTimer = nil
        currentThreshold = 0.0
    }
    
    // MARK: - Private Methods
    
    private func getLandmark(_ pose: Pose, type: PoseLandmarkType) -> PoseLandmark? {
        let landmark = pose.landmark(ofType: type)
        if landmark.inFrameLikelihood > 0.5 {
            return landmark
        }
        return nil
    }
    
    /// Calculate angle at point B (in degrees)
    private func calculateAngle(pointA: VisionPoint, pointB: VisionPoint, pointC: VisionPoint) -> CGFloat {
        let vectorBA = CGPoint(x: pointA.x - pointB.x, y: pointA.y - pointB.y)
        let vectorBC = CGPoint(x: pointC.x - pointB.x, y: pointC.y - pointB.y)
        
        let dotProduct = vectorBA.x * vectorBC.x + vectorBA.y * vectorBC.y
        let magnitudeBA = sqrt(vectorBA.x * vectorBA.x + vectorBA.y * vectorBA.y)
        let magnitudeBC = sqrt(vectorBC.x * vectorBC.x + vectorBC.y * vectorBC.y)
        
        guard magnitudeBA > 0 && magnitudeBC > 0 else { return 180.0 }
        
        let cosAngle = dotProduct / (magnitudeBA * magnitudeBC)
        let clampedCos = max(-1.0, min(1.0, cosAngle))
        let angleRadians = acos(clampedCos)
        
        return angleRadians * 180.0 / .pi
    }
    
    /// Update ground baseline (adaptive ground level tracking)
    private func updateGroundBaseline(ankleX: CGFloat) {
        baselineHistory.append(ankleX)
        if baselineHistory.count > baselineHistorySize {
            baselineHistory.removeFirst()
        }
        
        // Ground baseline is the 90th percentile of ankle positions (highest X = lowest position)
        // This ignores outliers from actual jumps
        guard baselineHistory.count >= 5 else {
            groundBaseline = ankleX
            return
        }
        
        let sortedHistory = baselineHistory.sorted()
        let percentileIndex = Int(Double(sortedHistory.count) * 0.90)
        groundBaseline = sortedHistory[min(percentileIndex, sortedHistory.count - 1)]
    }
    
    /// Apply moving average smoothing
    private func smoothValue(_ value: CGFloat, buffer: inout [CGFloat]) -> CGFloat {
        buffer.append(value)
        if buffer.count > smoothingWindow {
            buffer.removeFirst()
        }
        return buffer.reduce(0, +) / CGFloat(buffer.count)
    }
    
    private func detectJump(isValidJump: Bool) {
        switch currentJumpState {
        case .notJumping:
            if isValidJump {
                currentJumpState = .jumping
                triggerJump()
            }
            
        case .jumping:
            currentJumpState = .cooldown
            consecutiveValidFrames = 0
            startCooldown()
            
        case .cooldown:
            break
        }
    }
    
    private func triggerJump() {
        print("🦘 JUMP2 DETECTED! Ankles lifted from ground with stable knee angles")
        onJumpTriggered?()
    }
    
    private func startCooldown() {
        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: cooldownDuration, repeats: false) { [weak self] _ in
            self?.endCooldown()
        }
    }
    
    private func endCooldown() {
        currentJumpState = .notJumping
        consecutiveValidFrames = 0
        print("🦘 Jump2 cooldown ended")
    }
}
