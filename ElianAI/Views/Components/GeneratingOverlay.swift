import SwiftUI

/// Animated loading overlay shown while Gemini generates study materials
struct GeneratingOverlay: View {
    let message: String
    
    @State private var rotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var currentPhase = 0
    
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
                
                // Retry status banner
                if case .waiting(let attempt, let maxAttempts, let retryAt, let taskName) = GeminiService.shared.retryStatus {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.elianWarning)
                            Text("API Rate Limited")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.elianWarning)
                        }
                        
                        Text("Retry \(attempt)/\(maxAttempts) for \(taskName)")
                            .font(.system(size: 12))
                            .foregroundStyle(.elianTextSecondary)
                        
                        Text("Retrying at \(retryAt.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(.elianTextPrimary)
                    }
                    .padding(14)
                    .background(Color.elianWarning.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
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
        }
        .task {
            // Automatically cancelled when the view disappears
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.5))
                guard !Task.isCancelled else { break }
                withAnimation(.spring(duration: 0.4)) {
                    currentPhase = (currentPhase + 1) % phases.count
                }
            }
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
