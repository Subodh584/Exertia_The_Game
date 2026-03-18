//
//  Copyright (c) 2018 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import AVFoundation
import CoreVideo
import MLImage
import MLKit
import SwiftUI

@objc(CameraViewController)
class CameraViewController: UIViewController {
  
  // MARK: - Demo Stage Enum
  
  enum DemoStage {
    case initialWait           // Wait 3 seconds, show "Detecting player..."
    case playerDetection       // Detect if player is in frame
    case playerDetectedMessage // Show "User Detected" for 2 seconds
    case countdown             // Show "Ready for the demo?" -> 3 -> 2 -> 1
    case jumpTest              // 3 jumps
    case crouchTest            // 3 crouches
    case leanTest              // 5 random lean directions
    case spotRunningTest       // 10 reps
    case completed             // All tests done, show Play button
    case gamePlaying           // Game is active, process all detectors
  }
  
  // MARK: - Properties
  
  private var currentDetector: Detector = .pose
  private var isUsingFrontCamera = true
  private var previewLayer: AVCaptureVideoPreviewLayer!
  private lazy var captureSession = AVCaptureSession()
  private lazy var sessionQueue = DispatchQueue(label: Constant.sessionQueueLabel)
  private var lastFrame: CMSampleBuffer?
  
  // Demo state
  private var currentStage: DemoStage = .initialWait
  private var isPlayerDetected: Bool = false
  private var stageTimer: Timer?
  
  // Test counters
  private var jumpCount: Int = 0
  private var crouchCount: Int = 0
  private var leanCount: Int = 0
  private var spotRunningReps: Int = 0
  
  // Lean test specific
  private var leanDirections: [LeanDetector.LeanDirection] = []
  private var currentLeanTarget: LeanDetector.LeanDirection = .neutral
  private var isWaitingForCorrectLean: Bool = false
  
  // Crouch test specific
  private var isCrouching: Bool = false
  private var crouchCounted: Bool = false

  // MARK: - UI Elements
  
  private lazy var previewOverlayView: UIImageView = {
    precondition(isViewLoaded)
    let previewOverlayView = UIImageView(frame: .zero)
    previewOverlayView.contentMode = UIView.ContentMode.scaleAspectFill
    previewOverlayView.translatesAutoresizingMaskIntoConstraints = false
    return previewOverlayView
  }()

  private lazy var annotationOverlayView: UIView = {
    precondition(isViewLoaded)
    let annotationOverlayView = UIView(frame: .zero)
    annotationOverlayView.translatesAutoresizingMaskIntoConstraints = false
    return annotationOverlayView
  }()
  
  // Main instruction label (center of screen)
  private lazy var instructionLabel: UILabel = {
    precondition(isViewLoaded)
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = ""
    label.font = UIFont.monospacedSystemFont(ofSize: 28, weight: .bold)
    label.textColor = UIColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 1.0) // neon cyan
    label.backgroundColor = UIColor(red: 0.02, green: 0.02, blue: 0.06, alpha: 0.85)
    label.textAlignment = .center
    label.layer.cornerRadius = 16
    label.layer.borderWidth = 1.0
    label.layer.borderColor = UIColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 0.3).cgColor
    label.clipsToBounds = true
    label.numberOfLines = 0
    return label
  }()
  
  // Counter label (below instruction)
  private lazy var counterLabel: UILabel = {
    precondition(isViewLoaded)
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = ""
    label.font = UIFont.monospacedDigitSystemFont(ofSize: 44, weight: .bold)
    label.textColor = UIColor(red: 1.0, green: 0.75, blue: 0.0, alpha: 1.0) // neon amber
    label.backgroundColor = UIColor(red: 0.02, green: 0.02, blue: 0.06, alpha: 0.8)
    label.textAlignment = .center
    label.layer.cornerRadius = 14
    label.layer.borderWidth = 1.0
    label.layer.borderColor = UIColor(red: 1.0, green: 0.75, blue: 0.0, alpha: 0.25).cgColor
    label.clipsToBounds = true
    return label
  }()
  
  // Feedback label (for "Great!", "Oops!!", etc.)
  private lazy var feedbackLabel: UILabel = {
    precondition(isViewLoaded)
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = ""
    label.font = UIFont.monospacedSystemFont(ofSize: 26, weight: .bold)
    label.textColor = UIColor(red: 0.0, green: 1.0, blue: 0.45, alpha: 1.0) // neon green
    label.backgroundColor = UIColor(red: 0.02, green: 0.02, blue: 0.06, alpha: 0.85)
    label.textAlignment = .center
    label.layer.cornerRadius = 14
    label.layer.borderWidth = 1.0
    label.layer.borderColor = UIColor(red: 0.0, green: 1.0, blue: 0.45, alpha: 0.3).cgColor
    label.clipsToBounds = true
    label.isHidden = true
    return label
  }()
  
  // Stage title label (top of screen)
  private lazy var stageTitleLabel: UILabel = {
    precondition(isViewLoaded)
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = ""
    label.font = UIFont.monospacedSystemFont(ofSize: 16, weight: .bold)
    label.textColor = UIColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 1.0)
    label.backgroundColor = UIColor(red: 0.02, green: 0.02, blue: 0.08, alpha: 0.9)
    label.textAlignment = .center
    label.layer.cornerRadius = 12
    label.layer.borderWidth = 1.0
    label.layer.borderColor = UIColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 0.35).cgColor
    label.clipsToBounds = true
    return label
  }()
  
  // Play button (shown after all tests complete)
  private lazy var playButton: UIButton = {
    precondition(isViewLoaded)
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setTitle("  INITIALIZE  ▸▸  ", for: .normal)
    button.titleLabel?.font = UIFont.monospacedSystemFont(ofSize: 22, weight: .bold)
    button.setTitleColor(.white, for: .normal)
    button.backgroundColor = UIColor(red: 0.0, green: 0.35, blue: 0.15, alpha: 0.9)
    button.layer.cornerRadius = 16
    button.layer.borderWidth = 1.5
    button.layer.borderColor = UIColor(red: 0.0, green: 1.0, blue: 0.45, alpha: 0.6).cgColor
    button.contentEdgeInsets = UIEdgeInsets(top: 16, left: 44, bottom: 16, right: 44)
    button.addTarget(self, action: #selector(playButtonTapped), for: .touchUpInside)
    button.isHidden = true
    return button
  }()
  
  // MARK: - Detectors
  
  private var poseDetector: PoseDetector? = nil
  private var jump2Detector: Jump2Detector? = nil
  private var crouchDetector: CrouchDetector? = nil
  private var leanDetector: LeanDetector? = nil
  private var runningDetector: SpotRunningDetector? = nil
  
  // SceneKit game view controller (new Exertia game)
  var exertiaGameVC: ExertiaGameViewController?
  
  private var lastDetector: Detector?

  // MARK: - Views

  private var cameraView: UIView!

  // MARK: - UIViewController Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()

    cameraView = UIView(frame: view.bounds)
    cameraView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(cameraView)

    previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    setUpPreviewOverlayView()
    setUpAnnotationOverlayView()
    setUpDemoUI()
    setUpCaptureSessionOutput()
    setUpCaptureSessionInput()
    
    // Initialize detectors
    initializeDetectors()
    
    // Initialize pose detector
    let options = PoseDetectorOptions()
    self.poseDetector = PoseDetector.poseDetector(options: options)
    self.lastDetector = .pose
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setNavigationBarHidden(true, animated: animated)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    startSession()
    
    // Check if demo should be skipped
    if DifficultySettings.shared.skipDemo {
      skipDemoAndStartGame()
    } else {
      // Start the demo flow
      startDemoFlow()
    }
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    stopSession()
    stageTimer?.invalidate()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    previewLayer.frame = cameraView.frame
  }

  // MARK: - Demo Flow
  
  private func skipDemoAndStartGame() {
    // Hide all demo UI
    stageTitleLabel.isHidden = true
    instructionLabel.isHidden = true
    counterLabel.isHidden = true
    feedbackLabel.isHidden = true
    playButton.isHidden = true
    
    // Short delay to let the camera initialize, then start game
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
      self?.playButtonTapped(self as Any)
    }
  }
  
  private func startDemoFlow() {
    currentStage = .initialWait
    isPlayerDetected = false  // Reset player detection state
    updateUIForCurrentStage()
    
    // Wait 3 seconds then start detecting player
    stageTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
      DispatchQueue.main.async {
        self?.currentStage = .playerDetection
        self?.updateUIForCurrentStage()
      }
    }
  }
  
  private func updateUIForCurrentStage() {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      
      switch self.currentStage {
      case .initialWait:
        self.stageTitleLabel.text = "  ◆ CALIBRATION MODE ◆  "
        self.stageTitleLabel.textColor = UIColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 1.0)
        self.stageTitleLabel.layer.borderColor = UIColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 0.35).cgColor
        self.instructionLabel.text = "  SCANNING FOR USER...  "
        self.counterLabel.isHidden = true
        self.feedbackLabel.isHidden = true
        self.playButton.isHidden = true
        
      case .playerDetection:
        self.instructionLabel.text = self.isPlayerDetected ? "  ◈ USER DETECTED  " : "  ◇ NO SIGNAL  "
        self.instructionLabel.textColor = self.isPlayerDetected
          ? UIColor(red: 0.0, green: 1.0, blue: 0.45, alpha: 1.0)
          : UIColor(red: 1.0, green: 0.15, blue: 0.25, alpha: 1.0)
        
      case .playerDetectedMessage:
        self.instructionLabel.text = "  ◈ USER LOCKED  "
        self.instructionLabel.textColor = UIColor(red: 0.0, green: 1.0, blue: 0.45, alpha: 1.0)
        
      case .countdown:
        self.instructionLabel.textColor = UIColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 1.0)
        
      case .jumpTest:
        self.stageTitleLabel.text = "  ▲ JUMP PROTOCOL  "
        self.stageTitleLabel.textColor = UIColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 1.0)
        self.stageTitleLabel.backgroundColor = UIColor(red: 0.02, green: 0.02, blue: 0.08, alpha: 0.9)
        self.stageTitleLabel.layer.borderColor = UIColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 0.35).cgColor
        self.instructionLabel.text = "  EXECUTE 3 JUMPS  "
        self.instructionLabel.textColor = UIColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 1.0)
        self.counterLabel.text = "\(self.jumpCount)/3"
        self.counterLabel.isHidden = false
        self.feedbackLabel.isHidden = true
        
      case .crouchTest:
        self.stageTitleLabel.text = "  ▼ CROUCH PROTOCOL  "
        self.stageTitleLabel.textColor = UIColor(red: 1.0, green: 0.75, blue: 0.0, alpha: 1.0)
        self.stageTitleLabel.backgroundColor = UIColor(red: 0.02, green: 0.02, blue: 0.08, alpha: 0.9)
        self.stageTitleLabel.layer.borderColor = UIColor(red: 1.0, green: 0.75, blue: 0.0, alpha: 0.35).cgColor
        self.instructionLabel.text = "  EXECUTE 3 CROUCHES  "
        self.instructionLabel.textColor = UIColor(red: 1.0, green: 0.75, blue: 0.0, alpha: 1.0)
        self.counterLabel.text = "\(self.crouchCount)/3"
        self.counterLabel.isHidden = false
        self.feedbackLabel.isHidden = true
        
      case .leanTest:
        self.stageTitleLabel.text = "  ◁▷ LEAN PROTOCOL  "
        self.stageTitleLabel.textColor = UIColor(red: 1.0, green: 0.0, blue: 0.6, alpha: 1.0)
        self.stageTitleLabel.backgroundColor = UIColor(red: 0.02, green: 0.02, blue: 0.08, alpha: 0.9)
        self.stageTitleLabel.layer.borderColor = UIColor(red: 1.0, green: 0.0, blue: 0.6, alpha: 0.35).cgColor
        self.updateLeanTestUI()
        self.counterLabel.text = "\(self.leanCount)/5"
        self.counterLabel.isHidden = false
        
      case .spotRunningTest:
        self.stageTitleLabel.text = "  ⫸ SPRINT PROTOCOL  "
        self.stageTitleLabel.textColor = UIColor(red: 0.0, green: 1.0, blue: 0.45, alpha: 1.0)
        self.stageTitleLabel.backgroundColor = UIColor(red: 0.02, green: 0.02, blue: 0.08, alpha: 0.9)
        self.stageTitleLabel.layer.borderColor = UIColor(red: 0.0, green: 1.0, blue: 0.45, alpha: 0.35).cgColor
        self.instructionLabel.text = "  RUN IN PLACE\n10 REPS  "
        self.instructionLabel.textColor = UIColor(red: 0.0, green: 1.0, blue: 0.45, alpha: 1.0)
        self.counterLabel.text = "\(self.spotRunningReps)/10"
        self.counterLabel.isHidden = false
        self.feedbackLabel.isHidden = true
        
      case .completed:
        self.stageTitleLabel.text = "  ◈ CALIBRATION COMPLETE ◈  "
        self.stageTitleLabel.textColor = UIColor(red: 0.0, green: 1.0, blue: 0.45, alpha: 1.0)
        self.stageTitleLabel.backgroundColor = UIColor(red: 0.02, green: 0.02, blue: 0.08, alpha: 0.9)
        self.stageTitleLabel.layer.borderColor = UIColor(red: 0.0, green: 1.0, blue: 0.45, alpha: 0.35).cgColor
        self.instructionLabel.text = "  SYSTEMS READY  "
        self.instructionLabel.textColor = UIColor(red: 0.0, green: 1.0, blue: 0.45, alpha: 1.0)
        self.counterLabel.isHidden = true
        self.feedbackLabel.isHidden = true
        self.playButton.isHidden = false
        
      case .gamePlaying:
        // UI is hidden during game, nothing to update
        break
      }
    }
  }
  
  private func updateLeanTestUI() {
    if currentLeanTarget == .left {
      instructionLabel.text = "  ◁  LEAN LEFT  "
      instructionLabel.textColor = UIColor(red: 1.0, green: 0.75, blue: 0.0, alpha: 1.0)
    } else if currentLeanTarget == .right {
      instructionLabel.text = "  LEAN RIGHT  ▷  "
      instructionLabel.textColor = UIColor(red: 1.0, green: 0.0, blue: 0.6, alpha: 1.0)
    }
  }
  
  private func showFeedback(_ text: String, color: UIColor, duration: TimeInterval = 1.0) {
    DispatchQueue.main.async { [weak self] in
      self?.feedbackLabel.text = "  \(text)  "
      self?.feedbackLabel.textColor = color
      self?.feedbackLabel.layer.borderColor = color.withAlphaComponent(0.3).cgColor
      self?.feedbackLabel.isHidden = false
      
      DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
        self?.feedbackLabel.isHidden = true
      }
    }
  }
  
  private func showGreatAndProceed(to nextStage: DemoStage) {
    showFeedback("◈ COMPLETE", color: UIColor(red: 0.0, green: 1.0, blue: 0.45, alpha: 1.0), duration: 1.5)
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
      self?.currentStage = nextStage
      self?.updateUIForCurrentStage()
      
      // Setup for lean test
      if nextStage == .leanTest {
        self?.setupLeanTest()
      }
    }
  }
  
  private func setupLeanTest() {
    // Generate 5 random lean directions
    leanDirections = (0..<5).map { _ in
      Bool.random() ? LeanDetector.LeanDirection.left : LeanDetector.LeanDirection.right
    }
    leanCount = 0
    currentLeanTarget = leanDirections[0]
    isWaitingForCorrectLean = true
    updateLeanTestUI()
  }
  
  private func runCountdown() {
    let countdownSequence = ["INITIATING CALIBRATION", "3", "2", "1", "EXECUTE"]
    runCountdownStep(sequence: countdownSequence, index: 0)
  }
  
  private func runCountdownStep(sequence: [String], index: Int) {
    guard index < sequence.count else {
      // Countdown finished, start jump test
      DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        self.currentStage = .jumpTest
        self.instructionLabel.font = UIFont.monospacedSystemFont(ofSize: 28, weight: .bold)  // Reset font
        self.updateUIForCurrentStage()
      }
      return
    }
    
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.instructionLabel.text = "  \(sequence[index])  "
      if index >= 1 && index <= 3 {
        self.instructionLabel.font = UIFont.monospacedSystemFont(ofSize: 64, weight: .bold)
      } else {
        self.instructionLabel.font = UIFont.monospacedSystemFont(ofSize: 28, weight: .bold)
      }
    }
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
      self?.runCountdownStep(sequence: sequence, index: index + 1)
    }
  }

  // MARK: - Detector Callbacks
  
  private func initializeDetectors() {
    // Jump2 Detector
    jump2Detector = Jump2Detector(thresholdMultiplier: 1.0)
    jump2Detector?.onJumpTriggered = { [weak self] in
      self?.handleJumpDetected()
    }
    
    // Crouch Detector
    crouchDetector = CrouchDetector()
    crouchDetector?.onCrouchStateChanged = { [weak self] state in
      self?.handleCrouchStateChanged(state)
    }
    
    // Lean Detector
    leanDetector = LeanDetector()
    leanDetector?.onLeanDetected = { [weak self] direction in
      self?.handleLeanDetected(direction)
    }
    
    // Running Detector
    runningDetector = SpotRunningDetector()
    runningDetector?.onRepCompleted = { [weak self] repCount in
      self?.handleSpotRunningRep(repCount)
    }
  }
  
  private func handleJumpDetected() {
    guard currentStage == .jumpTest else { return }
    
    jumpCount += 1
    
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      
      self.counterLabel.text = "\(self.jumpCount)/3"
      self.showFeedback("▲ JUMP LOGGED", color: UIColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 1.0), duration: 0.5)
      
      // Animate counter
      UIView.animate(withDuration: 0.1, animations: {
        self.counterLabel.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
      }) { _ in
        UIView.animate(withDuration: 0.1) {
          self.counterLabel.transform = .identity
        }
      }
      
      if self.jumpCount >= 3 {
        self.showGreatAndProceed(to: .crouchTest)
      }
    }
  }
  
  private func handleCrouchStateChanged(_ state: CrouchDetector.CrouchState) {
    guard currentStage == .crouchTest else { return }
    
    if state == .crouching && !crouchCounted {
      // User started crouching
      isCrouching = true
    } else if state == .notCrouching && isCrouching && !crouchCounted {
      // User stood up after crouching - count as one crouch
      crouchCount += 1
      crouchCounted = true
      isCrouching = false
      
      DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        
        self.counterLabel.text = "\(self.crouchCount)/3"
        self.showFeedback("▼ CROUCH LOGGED", color: UIColor(red: 1.0, green: 0.75, blue: 0.0, alpha: 1.0), duration: 0.5)
        
        // Animate counter
        UIView.animate(withDuration: 0.1, animations: {
          self.counterLabel.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        }) { _ in
          UIView.animate(withDuration: 0.1) {
            self.counterLabel.transform = .identity
          }
        }
        
        if self.crouchCount >= 3 {
          self.showGreatAndProceed(to: .leanTest)
        }
      }
      
      // Reset for next crouch
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        self?.crouchCounted = false
      }
    }
  }
  
  private func handleLeanDetected(_ direction: LeanDetector.LeanDirection) {
    guard currentStage == .leanTest && isWaitingForCorrectLean else { return }
    guard direction != .neutral else { return }
    
    if direction == currentLeanTarget {
      // Correct lean!
      leanCount += 1
      isWaitingForCorrectLean = false
      
      DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        
        self.counterLabel.text = "\(self.leanCount)/5"
        let arrow = direction == .left ? "◁" : "▷"
        self.showFeedback("\(arrow) CORRECT", color: UIColor(red: 0.0, green: 1.0, blue: 0.45, alpha: 1.0), duration: 0.5)
        
        // Animate counter
        UIView.animate(withDuration: 0.1, animations: {
          self.counterLabel.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        }) { _ in
          UIView.animate(withDuration: 0.1) {
            self.counterLabel.transform = .identity
          }
        }
        
        if self.leanCount >= 5 {
          // All leans done
          self.showGreatAndProceed(to: .spotRunningTest)
        } else {
          // Next lean direction
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            self.currentLeanTarget = self.leanDirections[self.leanCount]
            self.isWaitingForCorrectLean = true
            self.updateLeanTestUI()
          }
        }
      }
    } else {
      // Wrong direction
      DispatchQueue.main.async { [weak self] in
        self?.showFeedback("WRONG DIRECTION", color: UIColor(red: 1.0, green: 0.15, blue: 0.25, alpha: 1.0), duration: 1.0)
      }
    }
  }
  
  private func handleSpotRunningRep(_ repCount: Int) {
    guard currentStage == .spotRunningTest else { return }
    
    spotRunningReps = repCount
    
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      
      self.counterLabel.text = "\(min(self.spotRunningReps, 10))/10"
      
      // Animate counter
      UIView.animate(withDuration: 0.1, animations: {
        self.counterLabel.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
      }) { _ in
        UIView.animate(withDuration: 0.1) {
          self.counterLabel.transform = .identity
        }
      }
      
      if self.spotRunningReps >= 10 {
        self.showGreatAndProceed(to: .completed)
      }
    }
  }

  // MARK: - Play Button Action
  
  @objc func playButtonTapped(_ sender: Any) {
    // Set stage to game playing so detectors process poses
    currentStage = .gamePlaying
    
    // Hide demo UI
    previewOverlayView.isHidden = true
    annotationOverlayView.isHidden = true
    stageTitleLabel.isHidden = true
    instructionLabel.isHidden = true
    counterLabel.isHidden = true
    feedbackLabel.isHidden = true
    playButton.isHidden = true
    
    cameraView.backgroundColor = .black
    
    // Create and present the SceneKit game view controller
    let exertiaVC = ExertiaGameViewController()
    self.exertiaGameVC = exertiaVC
    
    // Connect ML detectors directly to the SceneKit game
    connectDetectorsToExertiaGame(exertiaVC)
    
    // Present game view controller
    exertiaVC.modalPresentationStyle = .overFullScreen
    exertiaVC.modalTransitionStyle = .crossDissolve
    
    present(exertiaVC, animated: true)
  }
  
  /// Connect ML detectors directly to ExertiaGameViewController
  private func connectDetectorsToExertiaGame(_ gameVC: ExertiaGameViewController) {
    // Connect spot running state to forward movement
    runningDetector?.onRunningStateChanged = { [weak gameVC] isRunning in
      DispatchQueue.main.async {
        if isRunning {
          gameVC?.startMoveForward()
        } else {
          gameVC?.stopMoveForward()
        }
      }
    }
    
    // Connect running reps directly to speed bar (20% per rep)
    runningDetector?.onRepCompleted = { [weak gameVC] _ in
      DispatchQueue.main.async {
        gameVC?.onRunningRepCompleted()
      }
    }
    
    // Connect lean to lane switching
    leanDetector?.onLeanDetected = { [weak gameVC] direction in
      DispatchQueue.main.async {
        switch direction {
        case .left:
          gameVC?.movePlayerLeft()
        case .right:
          gameVC?.movePlayerRight()
        case .neutral:
          break
        }
      }
    }
    
    // Connect crouch to dive/slide
    crouchDetector?.onCrouchStateChanged = { [weak gameVC] state in
      DispatchQueue.main.async {
        switch state {
        case .crouching:
          gameVC?.playerDive()
        case .notCrouching:
          // No action needed when standing back up
          break
        }
      }
    }
    
    // Connect jump to jump action
    jump2Detector?.onJumpTriggered = { [weak gameVC] in
      DispatchQueue.main.async {
        gameVC?.playerJump()
      }
    }
  }
  

  // MARK: - Pose Detection

  private func detectPose(in image: MLImage, width: CGFloat, height: CGFloat) {
    if let poseDetector = self.poseDetector {
      var poses: [Pose] = []
      var detectionError: Error?
      do {
        poses = try poseDetector.results(in: image)
      } catch let error {
        detectionError = error
      }
      weak var weakSelf = self
      DispatchQueue.main.sync {
        guard let strongSelf = weakSelf else { return }
        strongSelf.updatePreviewOverlayViewWithLastFrame()
        
        if detectionError != nil {
          return
        }
        
        // Update player detection status
        let wasDetected = strongSelf.isPlayerDetected
        strongSelf.isPlayerDetected = !poses.isEmpty
        
        // Handle player detection stage
        if strongSelf.currentStage == .playerDetection {
          strongSelf.updateUIForCurrentStage()
          
          // If player is detected (either just now or already was)
          if strongSelf.isPlayerDetected {
            strongSelf.currentStage = .playerDetectedMessage
            strongSelf.updateUIForCurrentStage()
            
            // Wait 2 seconds, then start countdown
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
              guard let self = self, self.currentStage == .playerDetectedMessage else { return }
              self.currentStage = .countdown
              self.runCountdown()
            }
          }
        }
        
        // Handle player lost during playerDetectedMessage stage
        if strongSelf.currentStage == .playerDetectedMessage && !strongSelf.isPlayerDetected {
          // Player left, go back to detection
          strongSelf.currentStage = .playerDetection
          strongSelf.updateUIForCurrentStage()
        }
        
        guard !poses.isEmpty else { return }

        // Process pose with detectors
        poses.forEach { pose in
          // Process for jump detection (during jump test OR game)
          if strongSelf.currentStage == .jumpTest || strongSelf.currentStage == .gamePlaying {
            strongSelf.jump2Detector?.processPose(pose)
          }
          
          // Process for crouch detection (during crouch test OR game)
          if strongSelf.currentStage == .crouchTest || strongSelf.currentStage == .gamePlaying {
            strongSelf.crouchDetector?.processPose(pose)
          }
          
          // Process for lean detection (during lean test OR game)
          if strongSelf.currentStage == .leanTest || strongSelf.currentStage == .gamePlaying {
            strongSelf.leanDetector?.processPose(pose)
          }
          
          // Process for spot running detection (during running test OR game)
          if strongSelf.currentStage == .spotRunningTest || strongSelf.currentStage == .gamePlaying {
            strongSelf.runningDetector?.processPose(pose)
          }
          
          // Always draw skeleton overlay
          let poseOverlayView = UIUtilities.createPoseOverlayView(
            forPose: pose,
            inViewWithBounds: strongSelf.annotationOverlayView.bounds,
            lineWidth: Constant.lineWidth,
            dotRadius: Constant.smallDotRadius,
            positionTransformationClosure: { (position) -> CGPoint in
              return strongSelf.normalizedPoint(
                fromVisionPoint: position, width: width, height: height)
            }
          )
          strongSelf.annotationOverlayView.addSubview(poseOverlayView)
        }
      }
    }
  }

  // MARK: - UI Setup

  private func setUpPreviewOverlayView() {
    cameraView.addSubview(previewOverlayView)
    NSLayoutConstraint.activate([
      previewOverlayView.centerXAnchor.constraint(equalTo: cameraView.centerXAnchor),
      previewOverlayView.centerYAnchor.constraint(equalTo: cameraView.centerYAnchor),
      previewOverlayView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor),
      previewOverlayView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor),
    ])
  }

  private func setUpAnnotationOverlayView() {
    cameraView.addSubview(annotationOverlayView)
    NSLayoutConstraint.activate([
      annotationOverlayView.topAnchor.constraint(equalTo: cameraView.topAnchor),
      annotationOverlayView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor),
      annotationOverlayView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor),
      annotationOverlayView.bottomAnchor.constraint(equalTo: cameraView.bottomAnchor),
    ])
  }
  
  private func setUpDemoUI() {
    // Stage title label (top)
    cameraView.addSubview(stageTitleLabel)
    NSLayoutConstraint.activate([
      stageTitleLabel.topAnchor.constraint(equalTo: cameraView.safeAreaLayoutGuide.topAnchor, constant: 20),
      stageTitleLabel.centerXAnchor.constraint(equalTo: cameraView.centerXAnchor),
      stageTitleLabel.heightAnchor.constraint(equalToConstant: 50),
    ])
    
    // Instruction label (center)
    cameraView.addSubview(instructionLabel)
    NSLayoutConstraint.activate([
      instructionLabel.centerXAnchor.constraint(equalTo: cameraView.centerXAnchor),
      instructionLabel.centerYAnchor.constraint(equalTo: cameraView.centerYAnchor, constant: -50),
      instructionLabel.widthAnchor.constraint(lessThanOrEqualTo: cameraView.widthAnchor, constant: -40),
      instructionLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),
    ])
    
    // Counter label (below instruction)
    cameraView.addSubview(counterLabel)
    NSLayoutConstraint.activate([
      counterLabel.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 20),
      counterLabel.centerXAnchor.constraint(equalTo: cameraView.centerXAnchor),
      counterLabel.widthAnchor.constraint(equalToConstant: 150),
      counterLabel.heightAnchor.constraint(equalToConstant: 70),
    ])
    
    // Feedback label (above instruction)
    cameraView.addSubview(feedbackLabel)
    NSLayoutConstraint.activate([
      feedbackLabel.bottomAnchor.constraint(equalTo: instructionLabel.topAnchor, constant: -20),
      feedbackLabel.centerXAnchor.constraint(equalTo: cameraView.centerXAnchor),
      feedbackLabel.heightAnchor.constraint(equalToConstant: 60),
    ])
    
    // Play button (bottom)
    cameraView.addSubview(playButton)
    NSLayoutConstraint.activate([
      playButton.bottomAnchor.constraint(equalTo: cameraView.safeAreaLayoutGuide.bottomAnchor, constant: -40),
      playButton.centerXAnchor.constraint(equalTo: cameraView.centerXAnchor),
    ])
  }

  // MARK: - Capture Session

  private func setUpCaptureSessionOutput() {
    weak var weakSelf = self
    sessionQueue.async {
      guard let strongSelf = weakSelf else { return }
      strongSelf.captureSession.beginConfiguration()
      strongSelf.captureSession.sessionPreset = AVCaptureSession.Preset.medium

      let output = AVCaptureVideoDataOutput()
      output.videoSettings = [
        (kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA
      ]
      output.alwaysDiscardsLateVideoFrames = true
      let outputQueue = DispatchQueue(label: Constant.videoDataOutputQueueLabel)
      output.setSampleBufferDelegate(strongSelf, queue: outputQueue)
      guard strongSelf.captureSession.canAddOutput(output) else {
        print("Failed to add capture session output.")
        return
      }
      strongSelf.captureSession.addOutput(output)
      strongSelf.captureSession.commitConfiguration()
    }
  }

  private func setUpCaptureSessionInput() {
    weak var weakSelf = self
    sessionQueue.async {
      guard let strongSelf = weakSelf else { return }
      let cameraPosition: AVCaptureDevice.Position = strongSelf.isUsingFrontCamera ? .front : .back
      guard let device = strongSelf.captureDevice(forPosition: cameraPosition) else {
        print("Failed to get capture device for camera position: \(cameraPosition)")
        return
      }
      do {
        strongSelf.captureSession.beginConfiguration()
        let currentInputs = strongSelf.captureSession.inputs
        for input in currentInputs {
          strongSelf.captureSession.removeInput(input)
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard strongSelf.captureSession.canAddInput(input) else {
          print("Failed to add capture session input.")
          return
        }
        strongSelf.captureSession.addInput(input)
        strongSelf.captureSession.commitConfiguration()
      } catch {
        print("Failed to create capture device input: \(error.localizedDescription)")
      }
    }
  }

  private func startSession() {
    weak var weakSelf = self
    sessionQueue.async {
      weakSelf?.captureSession.startRunning()
    }
  }

  private func stopSession() {
    weak var weakSelf = self
    sessionQueue.async {
      weakSelf?.captureSession.stopRunning()
    }
  }

  private func captureDevice(forPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
    let discoverySession = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.builtInWideAngleCamera],
      mediaType: .video,
      position: .unspecified
    )
    return discoverySession.devices.first { $0.position == position }
  }

  private func removeDetectionAnnotations() {
    for annotationView in annotationOverlayView.subviews {
      annotationView.removeFromSuperview()
    }
  }

  private func updatePreviewOverlayViewWithLastFrame() {
    guard let lastFrame = lastFrame,
      let imageBuffer = CMSampleBufferGetImageBuffer(lastFrame)
    else {
      return
    }
    self.updatePreviewOverlayViewWithImageBuffer(imageBuffer)
    self.removeDetectionAnnotations()
  }

  private func updatePreviewOverlayViewWithImageBuffer(_ imageBuffer: CVImageBuffer?) {
    guard let imageBuffer = imageBuffer else { return }
    let orientation: UIImage.Orientation = isUsingFrontCamera ? .leftMirrored : .right
    let image = UIUtilities.createUIImage(from: imageBuffer, orientation: orientation)
    previewOverlayView.image = image
  }

  private func normalizedPoint(
    fromVisionPoint point: VisionPoint,
    width: CGFloat,
    height: CGFloat
  ) -> CGPoint {
    let cgPoint = CGPoint(x: point.x, y: point.y)
    var normalizedPoint = CGPoint(x: cgPoint.x / width, y: cgPoint.y / height)
    normalizedPoint = previewLayer.layerPointConverted(fromCaptureDevicePoint: normalizedPoint)
    return normalizedPoint
  }

  private func resetManagedLifecycleDetectors(activeDetector: Detector) {
    if activeDetector == self.lastDetector {
      return
    }
    switch self.lastDetector {
    case .pose, .poseAccurate:
      self.poseDetector = nil
    default:
      break
    }
    switch activeDetector {
    case .pose, .poseAccurate:
      let options = activeDetector == .pose ? PoseDetectorOptions() : AccuratePoseDetectorOptions()
      self.poseDetector = PoseDetector.poseDetector(options: options)
    default:
      break
    }
    self.lastDetector = activeDetector
  }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {

  func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      print("Failed to get image buffer from sample buffer.")
      return
    }
    
    let activeDetector = self.currentDetector
    resetManagedLifecycleDetectors(activeDetector: activeDetector)

    lastFrame = sampleBuffer
    let visionImage = VisionImage(buffer: sampleBuffer)
    let orientation = UIUtilities.imageOrientation(
      fromDevicePosition: isUsingFrontCamera ? .front : .back
    )
    visionImage.orientation = orientation

    guard let inputImage = MLImage(sampleBuffer: sampleBuffer) else {
      print("Failed to create MLImage from sample buffer.")
      return
    }
    inputImage.orientation = orientation

    let imageWidth = CGFloat(CVPixelBufferGetWidth(imageBuffer))
    let imageHeight = CGFloat(CVPixelBufferGetHeight(imageBuffer))

    switch activeDetector {
    case .pose, .poseAccurate:
      detectPose(in: inputImage, width: imageWidth, height: imageHeight)
    }
  }
}

// MARK: - Constants

public enum Detector: String {
  case pose = "Pose Detection"
  case poseAccurate = "Pose Detection, accurate"
}

private enum Constant {
  static let videoDataOutputQueueLabel = "com.google.mlkit.visiondetector.VideoDataOutputQueue"
  static let sessionQueueLabel = "com.google.mlkit.visiondetector.SessionQueue"
  static let smallDotRadius: CGFloat = 4.0
  static let lineWidth: CGFloat = 3.0
}
