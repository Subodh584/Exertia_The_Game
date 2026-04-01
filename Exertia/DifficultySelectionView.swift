//
//  DifficultySelectionView.swift
//  VisionExample
//
//  Cyberpunk-themed Difficulty Level Selection Screen
//

import SwiftUI

// MARK: - Cyberpunk Color Palette

private struct CyberColors {
    static let bgDark = Color(red: 0.02, green: 0.02, blue: 0.06)
    static let bgMid = Color(red: 0.04, green: 0.03, blue: 0.12)
    static let neonCyan = Color(red: 0.0, green: 0.95, blue: 1.0)
    static let neonMagenta = Color(red: 1.0, green: 0.0, blue: 0.6)
    static let neonGreen = Color(red: 0.0, green: 1.0, blue: 0.45)
    static let neonAmber = Color(red: 1.0, green: 0.75, blue: 0.0)
    static let neonRed = Color(red: 1.0, green: 0.15, blue: 0.25)
    static let glassWhite = Color.white.opacity(0.06)
    static let glassBorder = Color.white.opacity(0.12)
}

// MARK: - Main View

struct DifficultySelectionView: View {
    @State private var selectedDifficulty: DifficultySettings.Difficulty = .medium
    @State private var skipDemo: Bool = false
    @State private var appeared: Bool = false
    @State private var gridPulse: Bool = false
    var onDifficultySelected: ((DifficultySettings.Difficulty) -> Void)?
    var onDismiss: (() -> Void)?

    private func isLocked(_ difficulty: DifficultySettings.Difficulty) -> Bool {
        difficulty == .easy || difficulty == .hard
    }
    
    var body: some View {
        ZStack {
            // === Deep Background ===
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: CyberColors.bgDark, location: 0.0),
                    .init(color: CyberColors.bgMid, location: 0.5),
                    .init(color: Color(red: 0.03, green: 0.01, blue: 0.08), location: 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // === Subtle grid lines ===
            CyberGridOverlay(pulse: gridPulse)
                .ignoresSafeArea()
                .opacity(0.3)
            
            // === Floating glow orbs ===
            GeometryReader { geo in
                Circle()
                    .fill(CyberColors.neonCyan.opacity(0.08))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(x: -60, y: geo.size.height * 0.1)
                
                Circle()
                    .fill(CyberColors.neonMagenta.opacity(0.06))
                    .frame(width: 250, height: 250)
                    .blur(radius: 70)
                    .offset(x: geo.size.width * 0.5, y: geo.size.height * 0.6)
            }
            .ignoresSafeArea()
            
            // === Main Content ===
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 28) {
                    
                    // ── Back Button ──
                    HStack {
                        Button(action: { onDismiss?() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .bold))
                                Text("BACK")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .tracking(1)
                            }
                            .foregroundColor(CyberColors.neonCyan)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(CyberColors.neonCyan.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(CyberColors.neonCyan.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 54)
                    .opacity(appeared ? 1 : 0)

                    // ── Header ──
                    VStack(spacing: 14) {
                        // Cyberpunk icon
                        ZStack {
                            // Outer glow ring
                            Circle()
                                .stroke(
                                    AngularGradient(
                                        colors: [CyberColors.neonCyan, CyberColors.neonMagenta, CyberColors.neonCyan],
                                        center: .center
                                    ),
                                    lineWidth: 2
                                )
                                .frame(width: 72, height: 72)
                                .blur(radius: 4)
                                .opacity(0.7)
                            
                            Image(systemName: "shield.checkered")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [CyberColors.neonCyan, CyberColors.neonMagenta],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: CyberColors.neonCyan.opacity(0.6), radius: 8)
                        }
                        
                        Text("SELECT PROTOCOL")
                            .font(.system(size: 26, weight: .black, design: .monospaced))
                            .tracking(4)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [CyberColors.neonCyan, .white],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: CyberColors.neonCyan.opacity(0.5), radius: 12)
                        
                        // Decorative line
                        HStack(spacing: 8) {
                            Rectangle()
                                .fill(CyberColors.neonCyan.opacity(0.4))
                                .frame(width: 40, height: 1)
                            
                            Text("DIFFICULTY MATRIX")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .tracking(3)
                                .foregroundColor(CyberColors.neonCyan.opacity(0.5))
                            
                            Rectangle()
                                .fill(CyberColors.neonCyan.opacity(0.4))
                                .frame(width: 40, height: 1)
                        }
                    }
                    .padding(.top, 8)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : -20)
                    
                    // ── Difficulty Cards ──
                    VStack(spacing: 16) {
                        ForEach(Array(DifficultySettings.Difficulty.allCases.enumerated()), id: \.element) { index, difficulty in
                            LiquidGlassCard(
                                difficulty: difficulty,
                                isSelected: selectedDifficulty == difficulty,
                                isLocked: isLocked(difficulty),
                                onTap: {
                                    guard !isLocked(difficulty) else { return }
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                        selectedDifficulty = difficulty
                                    }
                                }
                            )
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 30)
                            .animation(
                                .spring(response: 0.6, dampingFraction: 0.8)
                                    .delay(Double(index) * 0.12 + 0.2),
                                value: appeared
                            )
                        }
                    }
                    .padding(.horizontal, 22)
                    
                    // ── Skip Demo Toggle ──
                    HStack(spacing: 12) {
                        Image(systemName: skipDemo ? "bolt.trianglebadge.exclamationmark.fill" : "play.desktopcomputer")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(skipDemo ? CyberColors.neonAmber : .white.opacity(0.4))
                            .frame(width: 24)
                        
                        Text("SKIP CALIBRATION")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .tracking(1)
                            .foregroundColor(.white.opacity(0.75))
                        
                        Spacer()
                        
                        Toggle("", isOn: $skipDemo)
                            .toggleStyle(SwitchToggleStyle(tint: CyberColors.neonAmber))
                            .labelsHidden()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(CyberColors.glassWhite)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(.ultraThinMaterial.opacity(0.3))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(CyberColors.glassBorder, lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 22)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut.delay(0.6), value: appeared)
                    
                    // ── Launch Button ──
                    Button(action: {
                        DifficultySettings.shared.setDifficulty(selectedDifficulty)
                        DifficultySettings.shared.setSkipDemo(skipDemo)
                        onDifficultySelected?(selectedDifficulty)
                    }) {
                        HStack(spacing: 10) {
                            Text("INITIALIZE")
                                .font(.system(size: 18, weight: .black, design: .monospaced))
                                .tracking(3)
                            
                            Image(systemName: "chevron.right.2")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            ZStack {
                                // Glass base
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                accentColor(for: selectedDifficulty).opacity(0.35),
                                                accentColor(for: selectedDifficulty).opacity(0.15),
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                // Inner highlight
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [.white.opacity(0.15), .clear],
                                            startPoint: .top,
                                            endPoint: .center
                                        )
                                    )
                                
                                // Border glow
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        accentColor(for: selectedDifficulty).opacity(0.6),
                                        lineWidth: 1.5
                                    )
                            }
                        )
                        .shadow(color: accentColor(for: selectedDifficulty).opacity(0.4), radius: 16, y: 6)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 50)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut.delay(0.7), value: appeared)
                }
            }
        }
        .onAppear {
            withAnimation { appeared = true }
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                gridPulse = true
            }
        }
    }
    
    private func accentColor(for difficulty: DifficultySettings.Difficulty) -> Color {
        switch difficulty {
        case .easy: return CyberColors.neonGreen
        case .medium: return CyberColors.neonAmber
        case .hard: return CyberColors.neonRed
        }
    }
}

// MARK: - Liquid Glass Difficulty Card

struct LiquidGlassCard: View {
    let difficulty: DifficultySettings.Difficulty
    let isSelected: Bool
    var isLocked: Bool = false
    let onTap: () -> Void
    
    private var accent: Color {
        switch difficulty {
        case .easy: return CyberColors.neonGreen
        case .medium: return CyberColors.neonAmber
        case .hard: return CyberColors.neonRed
        }
    }
    
    private var iconName: String {
        switch difficulty {
        case .easy: return "waveform.path"
        case .medium: return "waveform.path.ecg"
        case .hard: return "bolt.heart.fill"
        }
    }
    
    private var tierLabel: String {
        switch difficulty {
        case .easy: return "TIER 1"
        case .medium: return "TIER 2"
        case .hard: return "TIER 3"
        }
    }
    
    private var subtitle: String {
        switch difficulty {
        case .easy: return "LOW INTENSITY"
        case .medium: return "BALANCED MODE"
        case .hard: return "MAX EXERTION"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {

                // ── Icon container ──
                ZStack {
                    // Glow behind icon
                    Circle()
                        .fill(accent.opacity(isLocked ? 0.03 : (isSelected ? 0.25 : 0.08)))
                        .frame(width: 52, height: 52)
                        .blur(radius: isSelected ? 8 : 4)

                    Circle()
                        .fill(CyberColors.glassWhite)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .stroke(
                                    accent.opacity(isLocked ? 0.08 : (isSelected ? 0.7 : 0.2)),
                                    lineWidth: 1.5
                                )
                        )

                    Image(systemName: isLocked ? "lock.fill" : iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isLocked ? .white.opacity(0.2) : (isSelected ? accent : .white.opacity(0.5)))
                        .shadow(color: isSelected && !isLocked ? accent.opacity(0.6) : .clear, radius: 6)
                }
                
                // ── Text content ──
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(difficulty.rawValue.uppercased())
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(isLocked ? .white.opacity(0.3) : (isSelected ? .white : .white.opacity(0.7)))

                        if isLocked {
                            // COMING SOON badge
                            HStack(spacing: 4) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 7, weight: .bold))
                                Text("COMING SOON")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .tracking(0.5)
                            }
                            .foregroundColor(Color.white.opacity(0.5))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                                    )
                            )
                        } else {
                            Text(tierLabel)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(1)
                                .foregroundColor(accent.opacity(0.8))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(accent.opacity(0.12))
                                        .overlay(
                                            Capsule().stroke(accent.opacity(0.25), lineWidth: 0.5)
                                        )
                                )
                        }
                    }

                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(1.5)
                        .foregroundColor(isLocked ? .white.opacity(0.2) : .white.opacity(0.35))
                }

                Spacer()

                // ── Selection indicator / Lock icon ──
                ZStack {
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.25))
                    } else {
                        Circle()
                            .stroke(accent.opacity(isSelected ? 0.8 : 0.2), lineWidth: 1.5)
                            .frame(width: 24, height: 24)

                        if isSelected {
                            Circle()
                                .fill(accent)
                                .frame(width: 12, height: 12)
                                .shadow(color: accent.opacity(0.8), radius: 6)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                ZStack {
                    // Frosted glass base
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isSelected ? 0.1 : 0.04),
                                    Color.white.opacity(isSelected ? 0.04 : 0.02),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Top highlight (liquid glass refraction)
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(isSelected ? 0.12 : 0.06), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                    
                    // Accent glow at bottom when selected
                    if isSelected {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(
                                LinearGradient(
                                    colors: [.clear, accent.opacity(0.08)],
                                    startPoint: .center,
                                    endPoint: .bottom
                                )
                            )
                    }
                    
                    // Border
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            LinearGradient(
                                colors: isSelected
                                    ? [accent.opacity(0.6), accent.opacity(0.2)]
                                    : [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isSelected ? 1.5 : 1
                        )
                }
            )
            .shadow(color: isSelected && !isLocked ? accent.opacity(0.2) : .clear, radius: 20, y: 8)
            .scaleEffect(isSelected && !isLocked ? 1.02 : 1.0)
            .opacity(isLocked ? 0.55 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLocked)
    }
}

// MARK: - Cyberpunk Grid Overlay

struct CyberGridOverlay: View {
    var pulse: Bool
    
    var body: some View {
        Canvas { context, size in
            // Horizontal lines
            let hSpacing: CGFloat = 40
            var y: CGFloat = 0
            while y < size.height {
                let path = Path { p in
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(path, with: .color(CyberColors.neonCyan.opacity(0.06)), lineWidth: 0.5)
                y += hSpacing
            }
            
            // Vertical lines
            let vSpacing: CGFloat = 40
            var x: CGFloat = 0
            while x < size.width {
                let path = Path { p in
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: size.height))
                }
                context.stroke(path, with: .color(CyberColors.neonCyan.opacity(0.04)), lineWidth: 0.5)
                x += vSpacing
            }
        }
        .opacity(pulse ? 0.8 : 0.4)
    }
}

// MARK: - UIKit Hosting Controller

class DifficultySelectionViewController: UIViewController {
    
    var onDifficultySelected: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Hide navigation bar
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        // Create SwiftUI view
        var difficultyView = DifficultySelectionView { [weak self] difficulty in
            print("✅ Difficulty selected: \(difficulty.rawValue)")
            self?.onDifficultySelected?()
        }
        difficultyView.onDismiss = { [weak self] in
            // Walk up the presenter chain to find and dismiss back to HomeViewController
            guard let self = self else { return }
            var candidate = self.presentingViewController
            while let current = candidate {
                if current is HomeViewController {
                    current.dismiss(animated: true)
                    return
                }
                candidate = current.presentingViewController
            }
            // Fallback: dismiss just this nav controller
            self.navigationController?.dismiss(animated: true)
        }
        
        // Host SwiftUI view in UIKit
        let hostingController = UIHostingController(rootView: difficultyView)
        hostingController.view.backgroundColor = .clear
        
        // Add as child view controller
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        hostingController.didMove(toParent: self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override var prefersStatusBarHidden: Bool { true }
}

// MARK: - Preview

#Preview {
    DifficultySelectionView()
}
