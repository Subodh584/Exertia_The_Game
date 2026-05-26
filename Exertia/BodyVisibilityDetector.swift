//
//  BodyVisibilityDetector.swift
//  Exertia
//
//  Watches pose landmarks during gameplay using a safe-zone frame inside
//  the camera image. Each body part (head, left/right arm, torso, left/right
//  leg) is evaluated independently, so we can tell the player exactly which
//  side / part is going off-screen.
//

import Foundation
import MLKit

final class BodyVisibilityDetector {

    // MARK: - Body Parts

    enum BodyPart: String, CaseIterable {
        case head
        case leftArm
        case rightArm
        case torso
        case leftLeg
        case rightLeg

        var displayName: String {
            switch self {
            case .head:     return "HEAD"
            case .leftArm:  return "LEFT ARM"
            case .rightArm: return "RIGHT ARM"
            case .torso:    return "TORSO"
            case .leftLeg:  return "LEFT LEG"
            case .rightLeg: return "RIGHT LEG"
            }
        }

        var landmarks: [PoseLandmarkType] {
            switch self {
            case .head:
                return [.nose, .leftEye, .rightEye, .leftEar, .rightEar]
            case .leftArm:
                return [.leftShoulder, .leftElbow, .leftWrist]
            case .rightArm:
                return [.rightShoulder, .rightElbow, .rightWrist]
            case .torso:
                return [.leftShoulder, .rightShoulder, .leftHip, .rightHip]
            case .leftLeg:
                return [.leftHip, .leftKnee, .leftAnkle]
            case .rightLeg:
                return [.rightHip, .rightKnee, .rightAnkle]
            }
        }
    }

    // MARK: - State

    struct VisibilityState: Equatable {
        /// Body parts that are at least partially out of the safe frame.
        let outOfFrame: Set<BodyPart>
        /// True when even the torso + head are gone — the player is effectively
        /// not in the camera view at all.
        let isFullyAbsent: Bool

        var isFullyVisible: Bool { outOfFrame.isEmpty && !isFullyAbsent }

        static let fullyVisible = VisibilityState(outOfFrame: [], isFullyAbsent: false)
        static let fullyAbsent  = VisibilityState(outOfFrame: Set(BodyPart.allCases),
                                                  isFullyAbsent: true)
    }

    var onStateChanged: ((VisibilityState) -> Void)?

    // MARK: - Tunables

    /// Fraction of width/height kept as a safe-zone margin on every edge.
    private let safeMarginFraction: CGFloat = 0.04
    /// Below this likelihood we treat a landmark as "not in frame" regardless of position.
    private let likelihoodFloor: Float = 0.25
    /// A body part is "out of frame" once this fraction of its landmarks is out.
    private let outOfFrameMajority: Double = 0.55
    /// Show a new warning state only after the signal is stable for this long.
    private let showDebounce: TimeInterval = 0.5
    /// Recover (warning goes away) faster than it appears — feels more responsive.
    private let hideDebounce: TimeInterval = 0.3
    /// If no pose at all is seen for this long, we declare the player absent.
    private let noPoseTimeout: TimeInterval = 1.0
    /// Per-landmark rolling history length for temporal smoothing.
    private let smoothingWindow: Int = 5
    /// Majority threshold within the smoothing window for a landmark to be "out".
    private let smoothingMajority: Int = 3

    // MARK: - Internal

    private(set) var currentState: VisibilityState = .fullyVisible
    private var pendingState: VisibilityState = .fullyVisible
    private var pendingSince: Date = Date()
    private var lastPoseTime: Date = Date()
    /// Recent out-of-frame booleans per landmark (rolling window).
    private var landmarkHistory: [PoseLandmarkType: [Bool]] = [:]

    // MARK: - Public API

    func processPose(_ pose: Pose, imageWidth: CGFloat, imageHeight: CGFloat) {
        lastPoseTime = Date()
        guard imageWidth > 0, imageHeight > 0 else { return }

        let marginX = imageWidth  * safeMarginFraction
        let marginY = imageHeight * safeMarginFraction
        let minX = marginX
        let maxX = imageWidth  - marginX
        let minY = marginY
        let maxY = imageHeight - marginY

        var outParts: Set<BodyPart> = []
        for part in BodyPart.allCases {
            let landmarks = part.landmarks
            guard !landmarks.isEmpty else { continue }

            var outCount = 0
            for type in landmarks {
                let lm = pose.landmark(ofType: type)
                let rawOut = isOutOfFrame(landmark: lm,
                                          minX: minX, maxX: maxX,
                                          minY: minY, maxY: maxY)
                if smoothedIsOut(type: type, currentlyOut: rawOut) {
                    outCount += 1
                }
            }

            let ratio = Double(outCount) / Double(landmarks.count)
            if ratio >= outOfFrameMajority {
                outParts.insert(part)
            }
        }

        let isAbsent = outParts.contains(.torso) && outParts.contains(.head)
        let newState = VisibilityState(outOfFrame: outParts, isFullyAbsent: isAbsent)
        updateState(newState)
    }

    /// Call when no pose was detected at all this frame.
    func processNoPose() {
        if Date().timeIntervalSince(lastPoseTime) >= noPoseTimeout {
            updateState(.fullyAbsent)
        }
    }

    func reset() {
        currentState = .fullyVisible
        pendingState = .fullyVisible
        pendingSince = Date()
        lastPoseTime = Date()
        landmarkHistory.removeAll()
    }

    /// Rolling-majority vote per landmark: smooths MLKit's noisy per-frame likelihoods.
    private func smoothedIsOut(type: PoseLandmarkType, currentlyOut: Bool) -> Bool {
        var history = landmarkHistory[type] ?? []
        history.append(currentlyOut)
        if history.count > smoothingWindow { history.removeFirst(history.count - smoothingWindow) }
        landmarkHistory[type] = history
        let outVotes = history.filter { $0 }.count
        return outVotes >= smoothingMajority
    }

    // MARK: - Private

    private func isOutOfFrame(landmark: PoseLandmark,
                              minX: CGFloat, maxX: CGFloat,
                              minY: CGFloat, maxY: CGFloat) -> Bool {
        // Model thinks this joint isn't really in the frame.
        if landmark.inFrameLikelihood < likelihoodFloor {
            return true
        }
        // Or its computed position lies outside the safe zone.
        let x = CGFloat(landmark.position.x)
        let y = CGFloat(landmark.position.y)
        return x < minX || x > maxX || y < minY || y > maxY
    }

    private func updateState(_ newState: VisibilityState) {
        if newState == currentState {
            pendingState = newState
            return
        }

        if newState != pendingState {
            pendingState = newState
            pendingSince = Date()
            return
        }

        // Recovering (fewer parts out, or back to fully visible) uses the
        // shorter debounce so the warning vanishes quickly when the player
        // corrects their position.
        let isRecovery = newState.outOfFrame.count < currentState.outOfFrame.count
            || (currentState.isFullyAbsent && !newState.isFullyAbsent)
        let needed = isRecovery ? hideDebounce : showDebounce

        if Date().timeIntervalSince(pendingSince) >= needed {
            currentState = newState
            onStateChanged?(newState)
        }
    }
}
