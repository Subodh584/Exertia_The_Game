import SwiftUI

struct HighScorePopupView: View {
    let metricName: String
    let newValue: String
    let oldValue: String
    let unit: String
    var onContinue: () -> Void
    
    @State private var animateEntrance = false
    @State private var animateGlow = false
    
    // Core Colors
    let neonCyan = Color(red: 0.0, green: 0.95, blue: 1.0)
    let neonAmber = Color(red: 1.0, green: 0.75, blue: 0.0)
    let bgDark = Color(red: 0.02, green: 0.02, blue: 0.06)
    
    var body: some View {
        ZStack {
            // Dark Frosted Background
            Color.black.opacity(0.85).ignoresSafeArea()
            
            // Pulsing Glow Orbs
            GeometryReader { geo in
                Circle()
                    .fill(neonAmber.opacity(0.15))
                    .frame(width: 350, height: 350)
                    .blur(radius: 80)
                    .offset(x: geo.size.width * 0.5 - 175, y: geo.size.height * 0.2)
                    .scaleEffect(animateGlow ? 1.2 : 0.8)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animateGlow)
                
                Circle()
                    .fill(neonCyan.opacity(0.1))
                    .frame(width: 300, height: 300)
                    .blur(radius: 70)
                    .offset(x: geo.size.width * 0.5 - 150, y: geo.size.height * 0.6)
                    .scaleEffect(animateGlow ? 1.1 : 0.9)
                    .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(0.5), value: animateGlow)
            }
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Header Icon
                Image(systemName: "crown.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(
                        LinearGradient(colors: [neonAmber, neonAmber.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: neonAmber.opacity(0.6), radius: animateGlow ? 25 : 10)
                    .scaleEffect(animateEntrance ? 1.0 : 0.4)
                    .opacity(animateEntrance ? 1.0 : 0.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.5, blendDuration: 0), value: animateEntrance)
                
                // Title
                VStack(spacing: 8) {
                    Text("NEW RECORD!")
                        .font(.system(size: 40, weight: .black, design: .monospaced))
                        .foregroundStyle(
                            LinearGradient(colors: [neonAmber, Color.white], startPoint: .leading, endPoint: .trailing)
                        )
                        .shadow(color: neonAmber.opacity(0.5), radius: 10)
                        .tracking(4)
                    
                    Text("\(metricName) BEST BEATEN")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(neonCyan)
                        .tracking(3)
                }
                .scaleEffect(animateEntrance ? 1.0 : 0.8)
                .opacity(animateEntrance ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.5).delay(0.2), value: animateEntrance)
                
                // Score Cards
                HStack(spacing: 20) {
                    // Old Score
                    VStack(spacing: 8) {
                        Text("PREVIOUS")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(1)
                        Text(oldValue)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                        Text(unit)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .frame(width: 110, height: 100)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    
                    // Arrow
                    Image(systemName: "arrow.right")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(neonAmber.opacity(0.7))
                    
                    // New Score
                    VStack(spacing: 8) {
                        Text("NEW BEST")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(neonAmber)
                            .tracking(1)
                        Text(newValue)
                            .font(.system(size: 32, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                            .shadow(color: neonAmber.opacity(0.4), radius: 8)
                        Text(unit)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(neonAmber.opacity(0.6))
                    }
                    .frame(width: 130, height: 120)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 16).fill(neonAmber.opacity(0.15))
                            RoundedRectangle(cornerRadius: 16).stroke(neonAmber.opacity(0.6), lineWidth: 1.5)
                        }
                    )
                    .shadow(color: neonAmber.opacity(0.2), radius: 15)
                }
                .padding(.top, 10)
                .offset(y: animateEntrance ? 0 : 30)
                .opacity(animateEntrance ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.5).delay(0.4), value: animateEntrance)
                
                Spacer().frame(height: 40)
                
                // Continue Button
                Button(action: onContinue) {
                    HStack(spacing: 8) {
                        Text("CONTINUE")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .tracking(2)
                        Image(systemName: "chevron.right.2")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(bgDark)
                    .frame(width: 240, height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(LinearGradient(colors: [neonAmber, Color(red: 1.0, green: 0.85, blue: 0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .shadow(color: neonAmber.opacity(0.4), radius: 12, y: 5)
                }
                .opacity(animateEntrance ? 1.0 : 0.0)
                .animation(.easeIn(duration: 0.3).delay(0.8), value: animateEntrance)
            }
        }
        .onAppear {
            animateEntrance = true
            animateGlow = true
        }
    }
}
