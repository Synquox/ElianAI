import SwiftUI

struct QuizView: View {
    let note: NoteModel
    
    @Environment(\.modelContext) private var modelContext
    @State private var currentIndex = 0
    @State private var selectedAnswer: Int?
    @State private var hasSubmitted = false
    @State private var showResults = false
    @State private var score = 0
    
    private var questions: [QuizQuestion] {
        note.quizQuestions.sorted { $0.createdAt < $1.createdAt }
    }
    
    var body: some View {
        if questions.isEmpty {
            EmptyStudyView(
                icon: "questionmark.circle.fill",
                title: "No Quiz Questions",
                subtitle: "Quiz questions will appear after generating study materials.",
                color: .elianPurple
            )
        } else if showResults {
            resultsView
        } else {
            questionView
        }
    }
    
    // MARK: - Question View
    
    private var questionView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Progress bar
                VStack(spacing: 8) {
                    HStack {
                        Text("Question \(currentIndex + 1) of \(questions.count)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.elianPurple)
                        
                        Spacer()
                        
                        Text("Score: \(score)/\(currentIndex)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.elianTextSecondary)
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.elianSurfaceTertiary)
                                .frame(height: 6)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.elianPurple)
                                .frame(
                                    width: geo.size.width * CGFloat(currentIndex) / CGFloat(questions.count),
                                    height: 6
                                )
                                .animation(.spring(duration: 0.4), value: currentIndex)
                        }
                    }
                    .frame(height: 6)
                }
                
                let question = questions[currentIndex]
                
                // Question text
                Text(question.questionText)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.elianTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color.elianSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Options
                VStack(spacing: 12) {
                    ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                        Button {
                            if !hasSubmitted {
                                withAnimation(.spring(duration: 0.2)) {
                                    selectedAnswer = index
                                }
                            }
                        } label: {
                            HStack(spacing: 14) {
                                // Letter badge
                                Text(["A", "B", "C", "D"][index])
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(optionLetterColor(index: index, question: question))
                                    .frame(width: 36, height: 36)
                                    .background(optionBadgeBackground(index: index, question: question))
                                    .clipShape(Circle())
                                
                                Text(option)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.elianTextPrimary)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                                
                                if hasSubmitted && index == question.correctAnswerIndex {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.elianSuccess)
                                        .transition(.scale.combined(with: .opacity))
                                }
                                
                                if hasSubmitted && selectedAnswer == index && index != question.correctAnswerIndex {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.elianError)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding(16)
                            .background(optionBackground(index: index, question: question))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(optionBorderColor(index: index, question: question), lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Explanation (shown after submit)
                if hasSubmitted {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(.elianWarning)
                            Text("Explanation")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.elianWarning)
                        }
                        
                        Text(question.explanation)
                            .font(.system(size: 15))
                            .foregroundStyle(.elianTextSecondary)
                    }
                    .padding(16)
                    .background(Color.elianWarning.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.elianWarning.opacity(0.2), lineWidth: 1)
                    )
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                
                // Action buttons
                HStack(spacing: 16) {
                    if hasSubmitted {
                        Button {
                            nextQuestion()
                        } label: {
                            Text(currentIndex < questions.count - 1 ? "Next Question →" : "See Results 🎉")
                                .elianButton(color: .elianPurple, fullWidth: true)
                        }
                    } else {
                        Button {
                            submitAnswer()
                        } label: {
                            Text("Submit Answer")
                                .elianButton(color: .elianPurple, fullWidth: true)
                        }
                        .disabled(selectedAnswer == nil)
                        .opacity(selectedAnswer == nil ? 0.5 : 1)
                    }
                }
            }
            .padding(24)
        }
        .background(Color.elianBackground)
    }
    
    // MARK: - Results View
    
    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text(scoreEmoji)
                        .font(.system(size: 64))
                    
                    Text("Quiz Complete!")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.elianTextPrimary)
                    
                    Text("You scored \(score) out of \(questions.count)")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.elianTextSecondary)
                    
                    // Score percentage ring
                    ZStack {
                        Circle()
                            .stroke(Color.elianSurfaceTertiary, lineWidth: 12)
                            .frame(width: 120, height: 120)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(score) / CGFloat(questions.count))
                            .stroke(
                                scoreColor,
                                style: StrokeStyle(lineWidth: 12, lineCap: .round)
                            )
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(Int(Double(score) / Double(questions.count) * 100))%")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(scoreColor)
                    }
                    .padding(.vertical, 16)
                }
                
                Button {
                    resetQuiz()
                } label: {
                    Text("🔄 Retake Quiz")
                        .elianOutlineButton(color: .elianPurple)
                }
            }
            .padding(40)
        }
        .background(Color.elianBackground)
    }
    
    // MARK: - Helpers
    
    private func submitAnswer() {
        guard let answer = selectedAnswer else { return }
        
        withAnimation(.spring(duration: 0.3)) {
            hasSubmitted = true
        }
        
        let question = questions[currentIndex]
        question.userAnswerIndex = answer
        if answer == question.correctAnswerIndex {
            score += 1
        }
    }
    
    private func nextQuestion() {
        if currentIndex < questions.count - 1 {
            withAnimation(.spring(duration: 0.3)) {
                currentIndex += 1
                selectedAnswer = nil
                hasSubmitted = false
            }
        } else {
            // Save attempt
            let attempt = QuizAttempt(score: score, totalQuestions: questions.count)
            attempt.note = note
            modelContext.insert(attempt)
            try? modelContext.save()
            
            withAnimation(.spring(duration: 0.4)) {
                showResults = true
            }
        }
    }
    
    private func resetQuiz() {
        withAnimation(.spring(duration: 0.3)) {
            currentIndex = 0
            selectedAnswer = nil
            hasSubmitted = false
            showResults = false
            score = 0
            for q in questions { q.userAnswerIndex = nil }
        }
    }
    
    private var scoreEmoji: String {
        let pct = Double(score) / Double(max(questions.count, 1))
        if pct >= 0.9 { return "🏆" }
        if pct >= 0.7 { return "🎉" }
        if pct >= 0.5 { return "👍" }
        return "📚"
    }
    
    private var scoreColor: Color {
        let pct = Double(score) / Double(max(questions.count, 1))
        if pct >= 0.7 { return .elianSuccess }
        if pct >= 0.5 { return .elianWarning }
        return .elianError
    }
    
    // MARK: - Option Styling
    
    private func optionLetterColor(index: Int, question: QuizQuestion) -> Color {
        if !hasSubmitted && selectedAnswer == index { return .white }
        if hasSubmitted && index == question.correctAnswerIndex { return .white }
        if hasSubmitted && selectedAnswer == index { return .white }
        return .elianTextSecondary
    }
    
    private func optionBadgeBackground(index: Int, question: QuizQuestion) -> Color {
        if !hasSubmitted && selectedAnswer == index { return .elianPurple }
        if hasSubmitted && index == question.correctAnswerIndex { return .elianSuccess }
        if hasSubmitted && selectedAnswer == index { return .elianError }
        return .elianSurfaceTertiary
    }
    
    private func optionBackground(index: Int, question: QuizQuestion) -> Color {
        if hasSubmitted && index == question.correctAnswerIndex {
            return .elianSuccess.opacity(0.08)
        }
        if hasSubmitted && selectedAnswer == index && index != question.correctAnswerIndex {
            return .elianError.opacity(0.08)
        }
        if selectedAnswer == index { return .elianPurple.opacity(0.08) }
        return .elianSurface
    }
    
    private func optionBorderColor(index: Int, question: QuizQuestion) -> Color {
        if hasSubmitted && index == question.correctAnswerIndex {
            return .elianSuccess.opacity(0.4)
        }
        if hasSubmitted && selectedAnswer == index && index != question.correctAnswerIndex {
            return .elianError.opacity(0.4)
        }
        if selectedAnswer == index { return .elianPurple.opacity(0.5) }
        return .elianBorder
    }
}

// MARK: - Empty Study View

struct EmptyStudyView: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(color.opacity(0.5))
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.elianTextSecondary)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(.elianTextTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.elianBackground)
    }
}
