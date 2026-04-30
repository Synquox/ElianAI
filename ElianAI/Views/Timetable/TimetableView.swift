import SwiftUI
import SwiftData

struct TimetableView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var configs: [TimetableConfig]
    @Query private var periods: [TimetablePeriod]
    @Query(sort: \Subject.name) private var subjects: [Subject]
    
    @State private var showEditSubjects = false
    @State private var showConfigSheet = false
    @State private var selectedPeriod: TimetablePeriod?
    @State private var showSubjectPicker = false
    
    private var config: TimetableConfig {
        configs.first ?? TimetableConfig()
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Day headers
                headerRow
                
                Divider().background(Color.elianBorder)
                
                // Period rows
                ForEach(1...config.periodsPerDay, id: \.self) { period in
                    periodRow(period)
                    
                    if period < config.periodsPerDay {
                        Divider().background(Color.elianBorder.opacity(0.5))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(Color.elianBackground)
        .navigationTitle("Timetable")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showConfigSheet = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18))
                        .foregroundStyle(.elianTextSecondary)
                }
                
                Button {
                    showEditSubjects = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.elianBlue)
                }
            }
        }
        .sheet(isPresented: $showEditSubjects) {
            TimetableEditView()
        }
        .sheet(isPresented: $showConfigSheet) {
            timetableConfigSheet
        }
        .sheet(isPresented: $showSubjectPicker) {
            subjectPickerSheet
        }
        .onAppear {
            ensureConfigExists()
            ensurePeriodsExist()
        }
    }
    
    // MARK: - Header Row
    
    private var headerRow: some View {
        HStack(spacing: 0) {
            // Time column
            Text("Time")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.elianTextTertiary)
                .frame(width: 60)
            
            ForEach(Weekday.allCases) { day in
                Text(day.shortName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(
                        day == Weekday.today ? .elianBlue : .elianTextSecondary
                    )
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 12)
    }
    
    // MARK: - Period Row
    
    private func periodRow(_ period: Int) -> some View {
        HStack(spacing: 0) {
            // Time label
            VStack(spacing: 2) {
                Text("\(period)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.elianTextSecondary)
                Text(config.periodStartTime(period))
                    .font(.system(size: 10))
                    .foregroundStyle(.elianTextTertiary)
            }
            .frame(width: 60)
            
            ForEach(Weekday.allCases) { day in
                let timetablePeriod = findPeriod(day: day.rawValue, period: period)
                
                Button {
                    selectedPeriod = timetablePeriod
                    showSubjectPicker = true
                } label: {
                    periodCell(subject: timetablePeriod?.subject, isToday: day == Weekday.today)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func periodCell(subject: Subject?, isToday: Bool) -> some View {
        Group {
            if let subject = subject {
                VStack(spacing: 2) {
                    Image(systemName: subject.icon)
                        .font(.system(size: 12))
                    Text(subject.name)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundStyle(Color(hex: subject.colorHex))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color(hex: subject.colorHex).opacity(isToday ? 0.15 : 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isToday ? Color.elianSurfaceSecondary : Color.clear)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.elianBorder.opacity(0.3), lineWidth: 0.5)
                    )
            }
        }
        .padding(.horizontal, 2)
    }
    
    // MARK: - Subject Picker
    
    private var subjectPickerSheet: some View {
        NavigationStack {
            List {
                Button {
                    assignSubject(nil)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "xmark.circle")
                            .foregroundStyle(.elianTextTertiary)
                        Text("Remove Subject")
                            .foregroundStyle(.elianTextSecondary)
                    }
                }
                
                ForEach(subjects) { subject in
                    Button {
                        assignSubject(subject)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: subject.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(hex: subject.colorHex))
                                .frame(width: 32, height: 32)
                                .background(Color(hex: subject.colorHex).opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            Text(subject.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.elianTextPrimary)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.elianBackground)
            .navigationTitle("Assign Subject")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showSubjectPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Config Sheet
    
    private var timetableConfigSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Periods per Day")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.elianTextSecondary)
                    
                    Stepper(
                        "\(config.periodsPerDay) periods",
                        value: Binding(
                            get: { config.periodsPerDay },
                            set: { newValue in
                                config.periodsPerDay = max(4, min(12, newValue))
                                ensurePeriodsExist()
                            }
                        ),
                        in: 4...12
                    )
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.elianTextPrimary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Period Duration")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.elianTextSecondary)
                    
                    Stepper(
                        "\(config.periodDurationMinutes) min",
                        value: Binding(
                            get: { config.periodDurationMinutes },
                            set: { config.periodDurationMinutes = $0 }
                        ),
                        in: 30...90,
                        step: 5
                    )
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.elianTextPrimary)
                }
                
                Spacer()
            }
            .padding(24)
            .background(Color.elianBackground)
            .navigationTitle("Timetable Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showConfigSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Helpers
    
    private func findPeriod(day: Int, period: Int) -> TimetablePeriod? {
        periods.first { $0.dayOfWeek == day && $0.periodNumber == period }
    }
    
    private func assignSubject(_ subject: Subject?) {
        selectedPeriod?.subject = subject
        try? modelContext.save()
        showSubjectPicker = false
        HapticEngine.selection()
    }
    
    private func ensureConfigExists() {
        if configs.isEmpty {
            let newConfig = TimetableConfig()
            modelContext.insert(newConfig)
            try? modelContext.save()
        }
    }
    
    private func ensurePeriodsExist() {
        // Create missing periods for all day/period combinations
        for day in Weekday.allCases {
            for period in 1...config.periodsPerDay {
                if findPeriod(day: day.rawValue, period: period) == nil {
                    let newPeriod = TimetablePeriod(dayOfWeek: day.rawValue, periodNumber: period)
                    modelContext.insert(newPeriod)
                }
            }
        }
        try? modelContext.save()
    }
}
