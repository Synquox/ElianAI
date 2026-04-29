import SwiftUI
import SwiftData
import Charts

struct AnalyticsDashboardView: View {
    let folder: FolderModel
    
    private var attempts: [QuizAttempt] {
        folder.notes.flatMap { $0.quizAttempts }.sorted { $0.timestamp < $1.timestamp }
    }
    
    private var recentAttempts: [QuizAttempt] {
        Array(attempts.suffix(10))
    }
    
    private var averageScore: Double {
        guard !attempts.isEmpty else { return 0 }
        let totalPct = attempts.reduce(0.0) { sum, attempt in
            let pct = Double(attempt.score) / Double(max(1, attempt.totalQuestions))
            return sum + pct
        }
        return totalPct / Double(attempts.count)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                
                if attempts.isEmpty {
                    emptySection
                } else {
                    dataSection
                }
            }
            .padding(.vertical, 24)
        }
        .background(Color.elianBackground)
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Study Analytics")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.elianTextPrimary)
            
            Text(folder.name)
                .font(.system(size: 16))
                .foregroundStyle(Color(hex: folder.accentColorHex))
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Empty State
    
    private var emptySection: some View {
        EmptyStudyView(
            icon: "chart.line.uptrend.xyaxis",
            title: "No Data Yet",
            subtitle: "Complete quizzes in this folder to see your performance over time.",
            color: Color(hex: folder.accentColorHex)
        )
        .frame(height: 300)
    }
    
    // MARK: - Data Section
    
    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            summaryCards
            chartSection
        }
    }
    
    // MARK: - Summary Cards
    
    private var summaryCards: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Total Quizzes",
                value: "\(attempts.count)",
                icon: "checklist",
                color: .elianBlue
            )
            
            StatCard(
                title: "Average Score",
                value: "\(Int(averageScore * 100))%",
                icon: "percent",
                color: averageScore >= 0.7 ? .elianSuccess : .elianWarning
            )
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Chart
    
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Performance (Last 10)")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.elianTextSecondary)
            
            performanceChart
                .frame(height: 240)
        }
        .padding(24)
        .background(Color.elianSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.elianBorder, lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
    
    private var performanceChart: some View {
        let accentColor = Color(hex: folder.accentColorHex)
        let chartData: [(index: Int, percentage: Double)] = recentAttempts.enumerated().map { index, attempt in
            let pct = Double(attempt.score) / Double(max(1, attempt.totalQuestions)) * 100
            return (index: index + 1, percentage: pct)
        }
        
        return Chart(chartData, id: \.index) { item in
            LineMark(
                x: .value("Attempt", item.index),
                y: .value("Score %", item.percentage)
            )
            .lineStyle(StrokeStyle(lineWidth: 3))
            .foregroundStyle(accentColor)
            
            PointMark(
                x: .value("Attempt", item.index),
                y: .value("Score %", item.percentage)
            )
            .foregroundStyle(Color.elianSurface)
            .symbolSize(100)
            
            PointMark(
                x: .value("Attempt", item.index),
                y: .value("Score %", item.percentage)
            )
            .foregroundStyle(accentColor)
            .symbolSize(40)
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.elianBorder)
                AxisValueLabel {
                    if let intValue = value.as(Int.self) {
                        Text("\(intValue)%")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.elianTextTertiary)
                    }
                }
            }
        }
        .chartXAxis(.hidden)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.elianTextSecondary)
                
                Spacer()
                
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.15))
                    .clipShape(Circle())
            }
            
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.elianTextPrimary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.elianSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.elianBorder, lineWidth: 1)
        )
    }
}
