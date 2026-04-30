import SwiftUI
import SwiftData

struct FlashcardView: View {
    let note: NoteModel
    
    @Environment(\.modelContext) private var modelContext
    @Environment(GeminiService.self) private var geminiService
    
    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var dragOffset: CGSize = .zero
    @State private var showCompletionView = false
    @State private var sessionCards: [Flashcard] = []
    
    @State private var ttsService = TTSService()
    
    // Card generation
    @State private var showGenerateSheet = false
    @State private var selectedCardCount = 20
    @State private var specialInstructions = ""
    @State private var isGenerating = false
    @State private var generationError: String?
    
    private let cardCountOptions = [10, 20, 30, 50]
    
    private var allCards: [Flashcard] {
        note.flashcards.sorted { $0.createdAt < $1.createdAt }
    }
    
    var body: some View {
        if allCards.isEmpty {
            VStack(spacing: 20) {
                EmptyStudyView(
                    icon: "rectangle.on.rectangle.fill",
                    title: "No Flashcards",
                    subtitle: "Generate flashcards to start studying.",
                    color: .elianGreen
                )
                generateButton
            }
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
                HStack(spacing: 12) {
                    Button {
                        resetDeck(fullReset: true)
                    } label: {
                        Text("🔄 Start Full Review")
                            .elianOutlineButton(color: .elianGreen)
                    }
                    generateButton
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
    
    // MARK: - Generate Cards
    
    private var generateButton: some View {
        Button {
            showGenerateSheet = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                Text("Generate Cards")
            }
            .elianButton(color: .elianPurple)
        }
        .sheet(isPresented: $showGenerateSheet) {
            generateCardsSheet
        }
    }
    
    private var generateCardsSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Card Count
                VStack(alignment: .leading, spacing: 8) {
                    Text("Number of Cards")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.elianTextSecondary)
                    
                    HStack(spacing: 10) {
                        ForEach(cardCountOptions, id: \.self) { count in
                            Button {
                                withAnimation(.spring(duration: 0.2)) {
                                    selectedCardCount = count
                                }
                            } label: {
                                Text("\(count)")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(
                                        selectedCardCount == count ? .white : .elianTextPrimary
                                    )
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        selectedCardCount == count
                                            ? Color.elianPurple
                                            : Color.elianSurfaceSecondary
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // Special Instructions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Special Instructions (Optional)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.elianTextSecondary)
                    
                    TextField("e.g. Focus on key dates, formulas only...", text: $specialInstructions, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .padding(14)
                        .lineLimit(3...6)
                        .background(Color.elianSurfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Error
                if let error = generationError {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(error)
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.elianError)
                }
                
                Spacer()
            }
            .padding(24)
            .background(Color.elianBackground)
            .navigationTitle("Generate Flashcards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showGenerateSheet = false
                        generationError = nil
                    }
                    .disabled(isGenerating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        generateCards()
                    } label: {
                        if isGenerating {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text("Generate")
                        }
                    }
                    .disabled(isGenerating)
                }
            }
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled(isGenerating)
    }
    
    // MARK: - Generate Cards Action
    
    private func generateCards() {
        isGenerating = true
        generationError = nil
        
        Task {
            do {
                let flashcardDTOs = try await geminiService.generateFlashcards(
                    from: note.rawContent,
                    count: selectedCardCount,
                    instructions: specialInstructions
                )
                
                await MainActor.run {
                    // Delete old cards
                    for card in note.flashcards {
                        modelContext.delete(card)
                    }
                    
                    // Insert new cards
                    for dto in flashcardDTOs {
                        let card = Flashcard(front: dto.front, back: dto.back)
                        card.note = note
                        modelContext.insert(card)
                    }
                    
                    try? modelContext.save()
                    isGenerating = false
                    showGenerateSheet = false
                    specialInstructions = ""
                    
                    // Reload session
                    sessionCards = []
                    showCompletionView = false
                    loadSessionCards()
                    
                    HapticEngine.notification(.success)
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    generationError = error.localizedDescription
                    HapticEngine.notification(.error)
                }
            }
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
                // 3-grade system: Didn't Know / Partially / Knew It
                HStack(spacing: 8) {
                    GradeButton(label: "❌ Didn't Know", color: .elianError) { gradeCard(0) }
                    GradeButton(label: "🤔 Partially", color: .elianOrange) { gradeCard(2) }
                    GradeButton(label: "✅ Knew It", color: .elianGreen) { gradeCard(3) }
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
            
            Text("Tap to flip • Swipe to grade")
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
                
                generateButton
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
            // Swipe right = Knew It (3)
            gradeCard(3)
        } else if gesture.translation.width < -threshold {
            // Swipe left = Didn't Know (0)
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
