//
//  CountdownOverlayView.swift
//  Exertia
//
//  Aesthetic 3-2-1-GO countdown shown after the player resumes a paused game.
//

import SwiftUI
import UIKit

struct CountdownOverlayView: View {
    var onComplete: () -> Void

    // Countdown sequence: numbers, then a final "GO!" beat.
    private let beats: [String] = ["3", "2", "1", "GO!"]
    private let beatDuration: Double = 0.85

    @State private var index: Int = 0
    @State private var scale: CGFloat = 1.45
    @State private var opacity: Double = 0.0
    @State private var ringProgress: CGFloat = 1.0
    @State private var rotate: Double = 0

    private let neonCyan    = Color(red: 0.0,  green: 0.95, blue: 1.0)
    private let neonMagenta = Color(red: 1.0,  green: 0.20, blue: 0.85)
    private let neonGreen   = Color(red: 0.0,  green: 1.0,  blue: 0.45)

    private var isFinalBeat: Bool { index == beats.count - 1 }
    private var glowColor: Color { isFinalBeat ? neonGreen : neonCyan }
    private var accentColor: Color { isFinalBeat ? neonGreen : neonMagenta }
    private var currentText: String { beats[min(index, beats.count - 1)] }
    private var fontSize: CGFloat { isFinalBeat ? 140 : 200 }

    var body: some View {
        ZStack {
            // Dimmed backdrop — slightly transparent so the game peeks through.
            Color.black.opacity(0.55).ignoresSafeArea()

            // Soft radial glow behind the number.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [glowColor.opacity(0.35), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 220
                    )
                )
                .frame(width: 440, height: 440)
                .blur(radius: 20)
                .opacity(opacity)

            // Animated draining ring.
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 4)
                    .frame(width: 260, height: 260)

                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(
                        LinearGradient(
                            colors: [glowColor, accentColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 260, height: 260)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: glowColor.opacity(0.9), radius: 12)
            }

            // Rotating accent dashes — subtle motion.
            Circle()
                .trim(from: 0.0, to: 0.04)
                .stroke(accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: 300, height: 300)
                .rotationEffect(.degrees(rotate))
                .shadow(color: accentColor.opacity(0.8), radius: 8)
                .opacity(opacity * 0.9)

            Circle()
                .trim(from: 0.5, to: 0.54)
                .stroke(glowColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: 300, height: 300)
                .rotationEffect(.degrees(rotate))
                .shadow(color: glowColor.opacity(0.8), radius: 8)
                .opacity(opacity * 0.9)

            // The number / GO!
            Text(currentText)
                .font(.custom("Audiowide-Regular", size: fontSize))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, glowColor],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: glowColor.opacity(0.9), radius: 18)
                .shadow(color: accentColor.opacity(0.6), radius: 28)
                .scaleEffect(scale)
                .opacity(opacity)
                .accessibilityLabel(Text(currentText))
        }
        .onAppear {
            startContinuousRotation()
            runBeat()
        }
    }

    private func startContinuousRotation() {
        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
            rotate = 360
        }
    }

    private func runBeat() {
        // Reset for the new beat.
        scale = 1.55
        opacity = 0.0
        ringProgress = 1.0

        // Snap in — bouncy spring.
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
            scale = 1.0
            opacity = 1.0
        }

        // Drain the ring over the beat duration.
        withAnimation(.linear(duration: beatDuration).delay(0.05)) {
            ringProgress = 0.0
        }

        // Fade out near the end so the next beat snaps in cleanly.
        withAnimation(.easeIn(duration: 0.22).delay(beatDuration - 0.18)) {
            opacity = 0.0
            scale = isFinalBeat ? 1.8 : 0.85
        }

        // Light haptic per beat for tactile feedback.
        let generator = UIImpactFeedbackGenerator(style: isFinalBeat ? .heavy : .medium)
        generator.impactOccurred()

        // Schedule next beat or finish.
        DispatchQueue.main.asyncAfter(deadline: .now() + beatDuration) {
            if index < beats.count - 1 {
                index += 1
                runBeat()
            } else {
                onComplete()
            }
        }
    }
}

#Preview {
    CountdownOverlayView(onComplete: {})
        .background(Color.black)
}
