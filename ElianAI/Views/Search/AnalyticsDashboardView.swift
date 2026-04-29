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
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Study Analytics")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.elianTextPrimary)
                    
                    Text(folder.name)
                        .font(.system(size: 16))
                        .foregroundStyle(Color(hex: folder.accentColorHex))
                }
                .padding(.horizontal, 24)
                
                if attempts.isEmpty {
                    EmptyStudyView(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "No Data Yet",
                        subtitle: "Complete quizzes in this folder to see your performance over time.",
                        color: Color(hex: folder.accentColorHex)
                    )
                    .frame(height: 300)
                } else {
                    // Summary Cards
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
                    
                    // Chart
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Recent Performance (Last 10)")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.elianTextSecondary)
                        
                        Chart {
                            ForEach(Array(recentAttempts.enumerated()), id: \.offset) { index, attempt in
                                let percentage = Double(attempt.score) / Double(max(1, attempt.totalQuestions)) * 100
                                
                                LineMark(
                                    x: .value("Attempt", index + 1),
                                    y: .value("Score %", percentage)
                                )
                                .lineStyle(StrokeStyle(lineWidth: 3))
                                .foregroundStyle(Color(hex: folder.accentColorHex))
                                
                                PointMark(
                                    x: .value("Attempt", index + 1),
                                    y: .value("Score %", percentage)
                                )
                                .foregroundStyle(.elianSurface)
                                .symbolSize(100)
                                
                                PointMark(
                                    x: .value("Attempt", index + 1),
                                    y: .value("Score %", percentage)
                                )
                                .foregroundStyle(Color(hex: folder.accentColorHex))
                                .symbolSize(40)
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(.elianBorder)
                                AxisValueLabel {
                                    if let intValue = value.as(Int.self) {
                                        Text("\(intValue)%")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.elianTextTertiary)
                                    }
                                }
                            }
                        }
                        .chartXAxis(.hidden)
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
            }
            .padding(.vertical, 24)
        }
        .background(Color.elianBackground)
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
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
