import SwiftUI

/// Animated loading overlay shown while Gemini generates study materials
struct GeneratingOverlay: View {
    let message: String
    
    @State private var rotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var currentPhase = 0
    @State private var phaseTimer: Timer?
    
    private let phases = [
        ("📝", "Analyzing your content..."),
        ("🧠", "Generating rich notes..."),
        ("❓", "Creating quiz questions..."),
        ("🃏", "Building flashcards..."),
        ("✨", "Polishing everything...")
    ]
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 28) {
                // Animated icon
                ZStack {
                    // Outer spinning ring
                    Circle()
                        .strokeBorder(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    .elianBlue, .elianPurple, .elianGreen,
                                    .elianOrange, .elianBlue
                                ]),
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(rotation))
                    
                    // Inner pulsing circle
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.elianBlue.opacity(0.2), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 40
                            )
                        )
                        .frame(width: 80, height: 80)
                        .scaleEffect(pulseScale)
                    
                    // Phase emoji
                    Text(phases[currentPhase].0)
                        .font(.system(size: 36))
                }
                
                VStack(spacing: 8) {
                    Text(phases[currentPhase].1)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.elianTextPrimary)
                        .animation(.easeInOut, value: currentPhase)
                    
                    Text(message)
                        .font(.system(size: 14))
                        .foregroundStyle(.elianTextTertiary)
                }
                
                // Phase dots
                HStack(spacing: 8) {
                    ForEach(0..<phases.count, id: \.self) { index in
                        Circle()
                            .fill(index <= currentPhase ? Color.elianBlue : Color.elianSurfaceTertiary)
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == currentPhase ? 1.3 : 1.0)
                    }
                }
            }
            .padding(40)
            .background(Color.elianSurface)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.elianBorder, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.5), radius: 40)
        }
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
            }
            // Cycle through phases
            phaseTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
                withAnimation(.spring(duration: 0.4)) {
                    currentPhase = (currentPhase + 1) % phases.count
                }
            }
        }
        .onDisappear {
            phaseTimer?.invalidate()
            phaseTimer = nil
        }
    }
}

/// Haptic feedback helper
enum HapticEngine {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
    
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}
