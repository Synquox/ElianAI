import SwiftUI

struct FlashcardView: View {
    let note: NoteModel
    
    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var dragOffset: CGSize = .zero
    @State private var showCompletionView = false
    @State private var sessionCards: [Flashcard] = []
    
    @State private var ttsService = TTSService()
    
    private var allCards: [Flashcard] {
        note.flashcards.sorted { $0.createdAt < $1.createdAt }
    }
    
    var body: some View {
        if allCards.isEmpty {
            EmptyStudyView(
                icon: "rectangle.on.rectangle.fill",
                title: "No Flashcards",
                subtitle: "Flashcards will appear after generating study materials.",
                color: .elianGreen
            )
        } else if showCompletionView {
            completionView
        } else if sessionCards.isEmpty {
            // Session just started or all cards reviewed
            VStack(spacing: 20) {
                Text("🎓")
                    .font(.system(size: 64))
                Text("All caught up!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.elianTextPrimary)
                Text("No cards are due for review right now.")
                    .font(.system(size: 16))
                    .foregroundStyle(.elianTextSecondary)
                Button {
                    resetDeck(fullReset: true)
                } label: {
                    Text("🔄 Start Full Review")
                        .elianOutlineButton(color: .elianGreen)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.elianBackground)
            .onAppear { loadSessionCards() }
        } else {
            cardDeckView
                .onAppear { loadSessionCards() }
        }
    }
    
    private func loadSessionCards() {
        guard sessionCards.isEmpty else { return }
        let due = allCards.filter { $0.nextReviewDate <= Date() }
        if due.isEmpty {
            sessionCards = allCards
        } else {
            sessionCards = due
        }
        currentIndex = 0
    }
    
    // MARK: - Card Deck View
    
    private var cardDeckView: some View {
        VStack(spacing: 24) {
            // Progress
            HStack {
                Text("Card \(currentIndex + 1) of \(sessionCards.count)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.elianGreen)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.elianSuccess)
                    Text("\(allCards.filter { $0.isKnown }.count) Known")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.elianTextSecondary)
                }
            }
            .padding(.horizontal, 24)
            
            // Card
            ZStack {
                // Background card (next card peek)
                if currentIndex + 1 < sessionCards.count {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.elianSurfaceSecondary)
                        .frame(maxWidth: 520, maxHeight: 360)
                        .offset(y: 8)
                        .scaleEffect(0.96)
                        .opacity(0.5)
                }
                
                // Main card
                flashcardContent
                    .frame(maxWidth: 540, maxHeight: 380)
                    .offset(dragOffset)
                    .rotationEffect(.degrees(Double(dragOffset.width / 30)))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation
                            }
                            .onEnded { value in
                                handleSwipe(value)
                            }
                    )
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.5, bounce: 0.2)) {
                            isFlipped.toggle()
                        }
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Controls
            if !isFlipped {
                Button {
                    withAnimation(.spring(duration: 0.5, bounce: 0.2)) {
                        isFlipped.toggle()
                    }
                } label: {
                    Text("Show Answer")
                        .elianButton(color: .elianBlue)
                }
                .padding(.bottom, 20)
            } else {
                HStack(spacing: 8) {
                    GradeButton(label: "Again", color: .elianError) { gradeCard(0) }
                    GradeButton(label: "Hard", color: .elianOrange) { gradeCard(1) }
                    GradeButton(label: "Good", color: .elianGreen) { gradeCard(2) }
                    GradeButton(label: "Easy", color: .elianBlue) { gradeCard(3) }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
        .padding(.top, 16)
        .background(Color.elianBackground)
        .onDisappear {
            ttsService.stop()
        }
    }
    
    // MARK: - Flashcard Content
    
    private var flashcardContent: some View {
        ZStack {
            // Front
            cardFace(
                text: sessionCards[currentIndex].front,
                label: "QUESTION",
                color: .elianGreen,
                icon: "questionmark.circle.fill"
            )
            .opacity(isFlipped ? 0 : 1)
            .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            
            // Back
            cardFace(
                text: sessionCards[currentIndex].back,
                label: "ANSWER",
                color: .elianBlue,
                icon: "lightbulb.fill"
            )
            .opacity(isFlipped ? 1 : 0)
            .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
        }
    }
    
    private func cardFace(text: String, label: String, color: Color, icon: String) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                
                Spacer()
                
                Button {
                    ttsService.togglePlayPause(text: text)
                } label: {
                    Image(systemName: ttsService.isSpeaking ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 20))
                }
            }
            .foregroundStyle(color)
            
            Spacer()
            
            Text(text)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.elianTextPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            
            Spacer()
            
            Text("Tap to flip")
                .font(.system(size: 12))
                .foregroundStyle(.elianTextTertiary)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color.elianSurface, color.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.1), radius: 20, y: 10)
    }
    
    // MARK: - Completion View
    
    private var completionView: some View {
        VStack(spacing: 20) {
            Text("🎓")
                .font(.system(size: 64))
            
            Text("Deck Complete!")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.elianTextPrimary)
            
            Text("\(allCards.filter { $0.isKnown }.count)/\(allCards.count) cards marked as known")
                .font(.system(size: 16))
                .foregroundStyle(.elianTextSecondary)
            
            HStack(spacing: 16) {
                Button {
                    resetDeck(fullReset: false)
                } label: {
                    Text("📝 Review Unknown")
                        .elianOutlineButton(color: .elianOrange)
                }
                
                Button {
                    resetDeck(fullReset: true)
                } label: {
                    Text("🔄 Full Reset")
                        .elianOutlineButton(color: .elianGreen)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.elianBackground)
    }
    
    // MARK: - Actions
    
    private func gradeCard(_ grade: Int) {
        guard currentIndex < sessionCards.count else { return }
        sessionCards[currentIndex].applySM2(grade: grade)
        HapticEngine.selection()
        
        // Swipe animation for visual feedback
        advanceCard(direction: grade >= 2 ? .right : .left)
    }
    
    private func handleSwipe(_ gesture: DragGesture.Value) {
        let threshold: CGFloat = 100
        
        if gesture.translation.width > threshold {
            // Swipe right = Good (2)
            gradeCard(2)
        } else if gesture.translation.width < -threshold {
            // Swipe left = Again (0)
            gradeCard(0)
        } else {
            withAnimation(.spring(duration: 0.3)) {
                dragOffset = .zero
            }
        }
    }
    
    private enum SwipeDirection { case left, right }
    
    private func advanceCard(direction: SwipeDirection) {
        let targetX: CGFloat = direction == .right ? 500 : -500
        
        withAnimation(.easeOut(duration: 0.3)) {
            dragOffset = CGSize(width: targetX, height: 0)
        }
        
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            dragOffset = .zero
            isFlipped = false
            
            if currentIndex < sessionCards.count - 1 {
                currentIndex += 1
            } else {
                withAnimation(.spring(duration: 0.4)) {
                    showCompletionView = true
                }
            }
        }
    }
    
    private func resetDeck(fullReset: Bool) {
        if fullReset {
            for card in allCards {
                card.nextReviewDate = .now
                card.repetitions = 0
                card.interval = 0
                card.easeFactor = 2.5
            }
        }
        
        withAnimation(.spring(duration: 0.3)) {
            // Reload session cards
            sessionCards = fullReset
                ? allCards
                : allCards.filter { !$0.isKnown }
            currentIndex = 0
            isFlipped = false
            showCompletionView = false
        }
    }
}
    
// MARK: - Components

struct GradeButton: View {
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(color.opacity(0.15))
                .foregroundStyle(color)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Swipe Hint

struct SwipeHint: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 22))
            Text(text)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(color.opacity(0.6))
    }
}
