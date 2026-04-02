//
//  PauseMenuView.swift
//  Exertia
//
//  Pause overlay, session summary and supporting views for the in-game pause menu.
//

import SwiftUI

// MARK: - Session Summary Data

struct SessionSummaryData {
    let trackName: String
    let durationSeconds: Int
    let caloriesBurned: Int
    let completionStatus: String
    let characterName: String
    let avgSpeedMpMin: Double?     // metres per minute
    let totalJumps: Int
    let totalCrouches: Int
    let totalLeftLeans: Int
    let totalRightLeans: Int
    let distanceMeters: Double
    let totalSteps: Int

    var durationFormatted: String {
        let m = durationSeconds / 60
        let s = durationSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    var avgSpeedFormatted: String {
        guard let sp = avgSpeedMpMin else { return "N/A" }
        return String(format: "%.1f m/min", sp)
    }

    var distanceKmFormatted: String {
        String(format: "%.2f km", distanceMeters / 1000.0)
    }
}

// MARK: - Shared colour palette (mirrors DifficultySelectionView)

private struct PC {                           // PauseColors
    static let bgDark      = Color(red: 0.02, green: 0.02, blue: 0.06)
    static let bgMid       = Color(red: 0.04, green: 0.02, blue: 0.10)
    static let neonCyan    = Color(red: 0.0,  green: 0.95, blue: 1.0)
    static let neonAmber   = Color(red: 1.0,  green: 0.75, blue: 0.0)
    static let neonGreen   = Color(red: 0.0,  green: 1.0,  blue: 0.45)
    static let neonRed     = Color(red: 1.0,  green: 0.15, blue: 0.25)
    static let glass       = Color.white.opacity(0.05)
    static let border      = Color.white.opacity(0.10)
}

// MARK: - Pause Menu View

struct PauseMenuView: View {
    let currentCalories: Int
    let targetCalories: Int
    let currentDistanceKm: Double
    let targetDistanceKm: Double
    var onResume: () -> Void
    var onExitConfirmed: () -> Void

    @State private var showExitConfirm = false

    private var calorieProgress: Double {
        guard targetCalories > 0 else { return 0 }
        return min(1.0, Double(currentCalories) / Double(targetCalories))
    }

    private var distanceProgress: Double {
        guard targetDistanceKm > 0 else { return 0 }
        return min(1.0, currentDistanceKm / targetDistanceKm)
    }

    var body: some View {
        ZStack {
            // ── Frosted dark backdrop ──
            Color.black.opacity(0.82).ignoresSafeArea()

            // ── Ambient glow orbs ──
            GeometryReader { geo in
                Circle()
                    .fill(PC.neonCyan.opacity(0.07))
                    .frame(width: 260, height: 260)
                    .blur(radius: 70)
                    .offset(x: -50, y: geo.size.height * 0.12)
                Circle()
                    .fill(PC.neonAmber.opacity(0.05))
                    .frame(width: 200, height: 200)
                    .blur(radius: 55)
                    .offset(x: geo.size.width * 0.65, y: geo.size.height * 0.68)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── PAUSED header ──
                VStack(spacing: 10) {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 46, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(colors: [PC.neonCyan, PC.neonCyan.opacity(0.55)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .shadow(color: PC.neonCyan.opacity(0.55), radius: 14)

                    Text("PAUSED")
                        .font(.system(size: 34, weight: .black, design: .monospaced))
                        .tracking(6)
                        .foregroundStyle(
                            LinearGradient(colors: [PC.neonCyan, .white],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .shadow(color: PC.neonCyan.opacity(0.4), radius: 10)

                    HStack(spacing: 8) {
                        Rectangle().fill(PC.neonCyan.opacity(0.35)).frame(width: 30, height: 1)
                        Text("SESSION IN PROGRESS")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .tracking(3)
                            .foregroundColor(PC.neonCyan.opacity(0.45))
                        Rectangle().fill(PC.neonCyan.opacity(0.35)).frame(width: 30, height: 1)
                    }
                }
                .padding(.top, 64)

                Spacer().frame(height: 30)

                // ── Progress bars ──
                VStack(spacing: 14) {
                    PauseProgressBar(
                        icon: "flame.fill",
                        label: "CALORIES GOAL",
                        valueText: "\(currentCalories) / \(targetCalories) kcal",
                        progress: calorieProgress,
                        color: PC.neonAmber
                    )
                    PauseProgressBar(
                        icon: "figure.run",
                        label: "DISTANCE GOAL",
                        valueText: String(format: "%.2f / %.1f km",
                                          currentDistanceKm, targetDistanceKm),
                        progress: distanceProgress,
                        color: PC.neonCyan
                    )
                }
                .padding(.horizontal, 26)

                Spacer().frame(height: 28)

                // ── Clap to resume pill ──
                HStack(spacing: 10) {
                    Text("👏")
                        .font(.system(size: 20))
                    Text("CLAP TO RESUME")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.55))
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 26)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(PC.glass)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(PC.border, lineWidth: 1))
                )

                Spacer().frame(height: 30)

                // ── Action buttons ──
                HStack(spacing: 14) {

                    // Exit
                    Button(action: { showExitConfirm = true }) {
                        Label {
                            Text("EXIT")
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .tracking(2)
                        } icon: {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(PC.neonRed)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(PC.neonRed.opacity(0.10))
                                .overlay(RoundedRectangle(cornerRadius: 14)
                                    .stroke(PC.neonRed.opacity(0.45), lineWidth: 1.5))
                        )
                    }

                    // Resume
                    Button(action: onResume) {
                        Label {
                            Text("RESUME")
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .tracking(2)
                        } icon: {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(LinearGradient(
                                        colors: [PC.neonGreen.opacity(0.28), PC.neonGreen.opacity(0.10)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(PC.neonGreen.opacity(0.55), lineWidth: 1.5)
                            }
                        )
                        .shadow(color: PC.neonGreen.opacity(0.3), radius: 12, y: 4)
                    }
                }
                .padding(.horizontal, 26)

                Spacer().frame(height: 60)
            }
        }
        .alert("Exit Session?", isPresented: $showExitConfirm) {
            Button("Yes, Exit", role: .destructive) { onExitConfirmed() }
            Button("No, Continue", role: .cancel) {}
        } message: {
            Text("Your progress will be saved and this session will end.")
        }
    }
}

// MARK: - Pause Progress Bar

struct PauseProgressBar: View {
    let icon: String
    let label: String
    let valueText: String
    let progress: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(color.opacity(0.85))
                Spacer()
                Text(valueText)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.65))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 9)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(LinearGradient(
                            colors: [color, color.opacity(0.55)],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(progress), height: 9)
                        .shadow(color: color.opacity(0.45), radius: 5)
                    // Percentage badge at the right of fill
                    if progress > 0.08 {
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.9))
                            .offset(x: geo.size.width * CGFloat(progress) - 28, y: 0)
                    }
                }
            }
            .frame(height: 9)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(PC.glass)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(PC.border, lineWidth: 1))
        )
    }
}

// MARK: - Session Summary View

struct SessionSummaryView: View {
    let summary: SessionSummaryData
    var onGoHome: () -> Void

    private var statusColor: Color {
        summary.completionStatus.lowercased() == "completed" ? PC.neonGreen : PC.neonAmber
    }
    private var statusIcon: String {
        summary.completionStatus.lowercased() == "completed" ? "checkmark.seal.fill" : "xmark.seal.fill"
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(colors: [PC.bgDark, PC.bgMid], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            // Glow orbs
            GeometryReader { geo in
                Circle()
                    .fill(PC.neonCyan.opacity(0.05))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(x: -60, y: geo.size.height * 0.12)
                Circle()
                    .fill(statusColor.opacity(0.04))
                    .frame(width: 250, height: 250)
                    .blur(radius: 70)
                    .offset(x: geo.size.width * 0.55, y: geo.size.height * 0.72)
            }
            .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 22) {

                    // ── Header ──
                    VStack(spacing: 10) {
                        Image(systemName: statusIcon)
                            .font(.system(size: 52))
                            .foregroundStyle(
                                LinearGradient(colors: [statusColor, statusColor.opacity(0.55)],
                                               startPoint: .top, endPoint: .bottom)
                            )
                            .shadow(color: statusColor.opacity(0.55), radius: 18)

                        Text("SESSION ENDED")
                            .font(.system(size: 26, weight: .black, design: .monospaced))
                            .tracking(4)
                            .foregroundStyle(
                                LinearGradient(colors: [PC.neonCyan, .white],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .shadow(color: PC.neonCyan.opacity(0.4), radius: 8)

                        HStack(spacing: 8) {
                            Rectangle().fill(PC.neonCyan.opacity(0.35)).frame(width: 28, height: 1)
                            Text("PERFORMANCE REPORT")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .tracking(3)
                                .foregroundColor(PC.neonCyan.opacity(0.45))
                            Rectangle().fill(PC.neonCyan.opacity(0.35)).frame(width: 28, height: 1)
                        }
                    }
                    .padding(.top, 60)

                    // ── Stats ──
                    VStack(spacing: 9) {
                        SummaryStatRow(icon: "map.fill",         label: "TRACK",        value: summary.trackName,             color: PC.neonCyan)
                        SummaryStatRow(icon: "clock.fill",       label: "DURATION",     value: summary.durationFormatted,     color: PC.neonAmber)
                        SummaryStatRow(icon: "flame.fill",       label: "CALORIES",     value: "\(summary.caloriesBurned) kcal", color: PC.neonAmber)
                        SummaryStatRow(icon: "figure.run",       label: "DISTANCE",     value: summary.distanceKmFormatted,   color: PC.neonCyan)
                        SummaryStatRow(icon: "speedometer",      label: "AVG SPEED",    value: summary.avgSpeedFormatted,     color: PC.neonGreen)
                        SummaryStatRow(icon: "person.fill",      label: "CHARACTER",    value: summary.characterName.uppercased(), color: PC.neonCyan)
                        SummaryStatRow(icon: "checkmark.seal",   label: "STATUS",       value: summary.completionStatus.uppercased(), color: statusColor)

                        // Divider
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 1)
                            .padding(.vertical, 3)
                            .padding(.horizontal, 4)

                        SummaryStatRow(icon: "figure.walk",      label: "STEPS",        value: "\(summary.totalSteps)",       color: PC.neonGreen)
                        SummaryStatRow(icon: "arrow.up",         label: "JUMPS",        value: "\(summary.totalJumps)",       color: PC.neonCyan)
                        SummaryStatRow(icon: "arrow.down",       label: "CROUCHES",     value: "\(summary.totalCrouches)",    color: PC.neonAmber)
                        SummaryStatRow(icon: "arrow.left",       label: "LEFT LEANS",   value: "\(summary.totalLeftLeans)",   color: PC.neonGreen)
                        SummaryStatRow(icon: "arrow.right",      label: "RIGHT LEANS",  value: "\(summary.totalRightLeans)",  color: PC.neonRed)
                    }
                    .padding(.horizontal, 22)

                    // ── Go Home button ──
                    Button(action: onGoHome) {
                        HStack(spacing: 12) {
                            Image(systemName: "house.fill")
                                .font(.system(size: 17, weight: .bold))
                            Text("GO HOME")
                                .font(.system(size: 18, weight: .black, design: .monospaced))
                                .tracking(3)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(LinearGradient(
                                        colors: [PC.neonCyan.opacity(0.28), PC.neonCyan.opacity(0.10)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(LinearGradient(colors: [.white.opacity(0.12), .clear],
                                                         startPoint: .top, endPoint: .center))
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(PC.neonCyan.opacity(0.55), lineWidth: 1.5)
                            }
                        )
                        .shadow(color: PC.neonCyan.opacity(0.3), radius: 16, y: 6)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 52)
                }
            }
        }
    }
}

// MARK: - Summary Stat Row

struct SummaryStatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.5)
                .foregroundColor(.white.opacity(0.40))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.88))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(PC.glass)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(PC.border, lineWidth: 1))
        )
    }
}

// MARK: - All Targets Met Popup

struct AllTargetsMetPopupView: View {
    var onContinue: () -> Void
    var onExit: () -> Void

    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(0.78).ignoresSafeArea()

            VStack(spacing: 20) {

                // Trophy icon with glow
                ZStack {
                    Circle()
                        .fill(Color.yellow.opacity(0.12))
                        .frame(width: 90, height: 90)
                        .blur(radius: 18)
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 52, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(colors: [.yellow, Color(red: 1, green: 0.55, blue: 0)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .shadow(color: .yellow.opacity(0.6), radius: 16)
                }

                // Title
                VStack(spacing: 6) {
                    Text("SESSION TARGETS")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(
                            LinearGradient(colors: [PC.neonCyan, .white],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .shadow(color: PC.neonCyan.opacity(0.4), radius: 6)

                    Text("COMPLETED!")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .tracking(3)
                        .foregroundColor(PC.neonGreen)
                        .shadow(color: PC.neonGreen.opacity(0.5), radius: 6)
                }

                // Subtitle
                Text("You've hit all your goals.\nKeep going or finish here!")
                    .font(.system(size: 13, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.55))
                    .lineSpacing(4)

                // Clap hint
                HStack(spacing: 8) {
                    Image(systemName: "hands.clap.fill")
                        .font(.system(size: 12))
                    Text("CLAP TO CONTINUE")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(2)
                }
                .foregroundColor(PC.neonCyan.opacity(0.55))
                .padding(.vertical, 6)
                .padding(.horizontal, 16)
                .background(
                    Capsule()
                        .stroke(PC.neonCyan.opacity(0.2), lineWidth: 1)
                )

                // Buttons
                HStack(spacing: 12) {
                    Button(action: onExit) {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                            Text("EXIT")
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .tracking(2)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(PC.neonRed.opacity(0.15))
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(PC.neonRed.opacity(0.55), lineWidth: 1.5)
                            }
                        )
                    }

                    Button(action: onContinue) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14))
                            Text("CONTINUE")
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .tracking(2)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(PC.neonGreen.opacity(0.15))
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(PC.neonGreen.opacity(0.55), lineWidth: 1.5)
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 36)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 26)
                        .fill(LinearGradient(colors: [PC.bgDark, PC.bgMid],
                                             startPoint: .top, endPoint: .bottom))
                    RoundedRectangle(cornerRadius: 26)
                        .fill(LinearGradient(colors: [Color.white.opacity(0.07), .clear],
                                             startPoint: .top, endPoint: .center))
                    RoundedRectangle(cornerRadius: 26)
                        .stroke(PC.neonGreen.opacity(0.30), lineWidth: 1.5)
                }
            )
            .shadow(color: PC.neonGreen.opacity(0.18), radius: 32, y: 8)
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let navigateToHome = Notification.Name("com.exertia.navigateToHome")
}
