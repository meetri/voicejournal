//
//  CalendarView.swift
//  voicejournal
//
//  Created on 4/29/25.
//

import SwiftUI
import CoreData
// Import the shared JournalEntryRow component

/// A view that displays a calendar with journal entries
struct CalendarView: View {
    // MARK: - Environment
    
    @Environment(\.managedObjectContext) private var viewContext
    
    // MARK: - State
    
    @StateObject private var viewModel: CalendarViewModel
    @State private var selectedEntry: JournalEntry? = nil
    @State private var showingEntryCreation = false
    @State private var selectedEntryToDelete: JournalEntry? = nil
    @State private var showDeleteConfirmation = false
    @State private var selectedEntryToToggleLock: JournalEntry? = nil
    @State private var showLockConfirmation = false
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext? = nil) {
        let contextToUse = context ?? PersistenceController.shared.container.viewContext
        _viewModel = StateObject(wrappedValue: CalendarViewModel(context: contextToUse))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
            VStack(spacing: 0) {
                // Calendar header
                calendarHeader
                
                // Calendar content based on zoom level
                switch viewModel.zoomLevel {
                case .year:
                    YearCalendarView(viewModel: viewModel)
                case .month:
                    MonthCalendarView(viewModel: viewModel)
                case .week:
                    WeekCalendarView(
                        viewModel: viewModel,
                        selectedEntryToDelete: $selectedEntryToDelete,
                        showDeleteConfirmation: $showDeleteConfirmation,
                        selectedEntryToToggleLock: $selectedEntryToToggleLock,
                        showLockConfirmation: $showLockConfirmation
                    )
                }
            }
            
            // Floating Action Button for creating new recordings
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        showingEntryCreation = true
                    }) {
                        Image(systemName: "mic.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding([.bottom, .trailing], 20)
                    .accessibilityLabel("New Recording")
                }
            }
        }
        .sheet(item: $selectedEntry) { entry in
            JournalEntryView(journalEntry: entry)
        }
        .sheet(isPresented: $showingEntryCreation) {
            EntryCreationView(isPresented: $showingEntryCreation)
                .environment(\.managedObjectContext, viewContext)
        }
        .alert("Delete Entry", isPresented: $showDeleteConfirmation, actions: {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let entryToDelete = selectedEntryToDelete {
                    viewModel.deleteEntry(entryToDelete)
                    selectedEntryToDelete = nil
                }
            }
        }, message: {
            Text("Are you sure you want to delete this journal entry? This action cannot be undone.")
        })
        .alert("Lock Entry", isPresented: $showLockConfirmation, actions: {
            Button("Cancel", role: .cancel) {}
            Button(selectedEntryToToggleLock?.isLocked == true ? "Unlock" : "Lock") {
                if let entryToToggle = selectedEntryToToggleLock {
                    viewModel.toggleEntryLock(entryToToggle)
                    selectedEntryToToggleLock = nil
                }
            }
        }, message: {
            Text(selectedEntryToToggleLock?.isLocked == true ? 
                "Unlock this entry? Anyone with access to the app will be able to view it." : 
                "Lock this entry? It will require authentication to view.")
        })
        }
    }
    
    // MARK: - Subviews
    
    /// Calendar header with navigation controls and zoom level selection
    private var calendarHeader: some View {
        VStack(spacing: 8) {
            // Title and navigation buttons
            HStack {
                Button(action: {
                    viewModel.moveToPrevious()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text(viewModel.displayTitle())
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    viewModel.moveToNext()
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal)
            
            // Zoom level picker
            Picker("Zoom Level", selection: $viewModel.zoomLevel) {
                Text("Year").tag(CalendarZoomLevel.year)
                Text("Month").tag(CalendarZoomLevel.month)
                Text("Week").tag(CalendarZoomLevel.week)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            // Today button
            Button(action: {
                viewModel.moveToToday()
            }) {
                Text("Today")
                    .font(.subheadline)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
            .padding(.vertical, 4)
            
            // Weekday header for month and week views
            if viewModel.zoomLevel != .year {
                weekdayHeader
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    /// Weekday header for month and week views
    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Calendar.current.shortWeekdaySymbols.indices, id: \.self) { index in
                let adjustedIndex = (index + Calendar.current.firstWeekday - 1) % 7
                Text(Calendar.current.shortWeekdaySymbols[adjustedIndex])
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

// MARK: - Year Calendar View

/// A view that displays a year calendar
struct YearCalendarView: View {
    @ObservedObject var viewModel: CalendarViewModel
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 16) {
                ForEach(viewModel.monthsInYear(), id: \.self) { date in
                    MonthCell(date: date, viewModel: viewModel)
                }
            }
            .padding()
        }
    }
    
    /// A cell representing a month in the year view
    struct MonthCell: View {
        let date: Date
        @ObservedObject var viewModel: CalendarViewModel
        
        var body: some View {
            VStack(spacing: 4) {
                // Month name
                Text(date, formatter: monthFormatter)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // Mini month grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
                    // Generate mini day cells for the month
                    ForEach(daysInMonth(), id: \.self) { day in
                        Circle()
                            .fill(dayColor(for: day))
                            .frame(width: 6, height: 6)
                    }
                }
                .frame(height: 60)
                .padding(.horizontal, 4)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemBackground))
            )
            .onTapGesture {
                viewModel.displayDate = date
                viewModel.setZoomLevel(.month)
            }
        }
        
        /// Get the days in this month for the mini grid
        private func daysInMonth() -> [Date] {
            guard let monthInterval = Calendar.current.dateInterval(of: .month, for: date) else { return [] }
            
            let startDate = monthInterval.start
            let endDate = monthInterval.end
            
            var days: [Date] = []
            var currentDate = startDate
            
            // Find the first day of the week containing the start date
            let firstWeekday = Calendar.current.firstWeekday
            let weekdayOfStartDate = Calendar.current.component(.weekday, from: startDate)
            let daysToSubtract = (weekdayOfStartDate - firstWeekday + 7) % 7
            
            if daysToSubtract > 0 {
                currentDate = Calendar.current.date(byAdding: .day, value: -daysToSubtract, to: startDate) ?? startDate
            }
            
            // Add dates until we've gone past the end of the month
            // and completed the last week
            while currentDate < endDate || Calendar.current.component(.weekday, from: currentDate) != firstWeekday {
                days.append(currentDate)
                currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            
            return days
        }
        
        /// Determine the color for a day cell in the mini grid
        private func dayColor(for date: Date) -> Color {
            if !Calendar.current.isDate(date, equalTo: self.date, toGranularity: .month) {
                return Color.clear
            }
            
            if viewModel.hasEntries(on: date) {
                return Color.blue
            }
            
            return Color(.tertiarySystemFill)
        }
        
        private let monthFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            return formatter
        }()
    }
}

// MARK: - Month Calendar View

/// A view that displays a month calendar
struct MonthCalendarView: View {
    @ObservedObject var viewModel: CalendarViewModel
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(viewModel.daysInMonth(), id: \.self) { date in
                    DayCell(date: date, viewModel: viewModel)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
//        .onAppear {
//            // Ensure today's date is selected by default
//            if Calendar.current.isDateInToday(viewModel.selectedDate) == false {
//                viewModel.moveToToday()
//            }
//        }
    }
    
    /// A cell representing a day in the month view
    struct DayCell: View {
        let date: Date
        @ObservedObject var viewModel: CalendarViewModel
        
        var body: some View {
            VStack(spacing: 2) {
                // Day number
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.subheadline)
                    .fontWeight(viewModel.isToday(date) ? .bold : .regular)
                    .foregroundColor(textColor())
                
                // Entry indicators
                if viewModel.hasEntries(on: date) {
                    entryIndicators
                } else {
                    Spacer()
                        .frame(height: 16)
                }
            }
            .frame(width: 50, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(cellBackgroundColor())
            )
            .opacity(viewModel.isInCurrentMonth(date) ? 1.0 : 0.4)
            .onTapGesture {
                viewModel.selectDate(date)
                viewModel.setZoomLevel(.week)
            }
        }
        
        /// Entry indicators showing tags
        private var entryIndicators: some View {
            let tagInfo = viewModel.tagInfo(for: date)
            let entryCount = viewModel.entryCount(for: date)
            
            return VStack(spacing: 2) {
                // Tag indicators (up to 3)
                HStack(spacing: 2) {
                    ForEach(Array(tagInfo.prefix(3))) { tag in
                        if let iconName = tag.iconName, !iconName.isEmpty {
                            Image(systemName: iconName)
                                .font(.system(size: 8))
                                .foregroundColor(Color(hex: tag.color))
                        } else {
                            Circle()
                                .fill(Color(hex: tag.color))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
                
                // Entry count if more than 3 tags or entries
                if tagInfo.count > 3 || entryCount > 3 {
                    Text("\(entryCount)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
        }
        
        /// Determine the text color for the day number
        private func textColor() -> Color {
            if viewModel.isToday(date) {
                return .white
            } else if viewModel.isSelected(date) {
                return .blue
            } else {
                return .primary
            }
        }
        
        /// Determine the background color for the cell
        private func cellBackgroundColor() -> Color {
            if viewModel.isToday(date) {
                return .blue
            } else if viewModel.isSelected(date) {
                return Color.purple.opacity(0.3)
            } else {
                return Color.clear
            }
        }
    }
}

// MARK: - Week Calendar View

/// A view that displays a week calendar
struct WeekCalendarView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Binding var selectedEntryToDelete: JournalEntry?
    @Binding var showDeleteConfirmation: Bool
    @Binding var selectedEntryToToggleLock: JournalEntry?
    @Binding var showLockConfirmation: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Week days
            HStack(spacing: 0) {
                ForEach(viewModel.daysInWeek(), id: \.self) { date in
                    WeekDayCell(date: date, viewModel: viewModel)
                }
            }
            .padding(.horizontal, 8)
            
            // Entries for selected day
            let entries = viewModel.entries(for: viewModel.selectedDate)
            if !entries.isEmpty {
                List {
                    ForEach(entries) { entry in
                        NavigationLink(destination: JournalEntryView(journalEntry: entry)) {
                            JournalEntryRow(entry: entry, onToggleLock: { toggledEntry in
                                selectedEntryToToggleLock = toggledEntry
                                showLockConfirmation = true
                            })
                        }
                        .swipeActions(edge: .trailing) {
                            // Only show delete action for unlocked entries
                            if !entry.isLocked {
                                Button(role: .destructive) {
                                    selectedEntryToDelete = entry
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                selectedEntryToToggleLock = entry
                                showLockConfirmation = true
                            } label: {
                                Label(entry.isLocked ? "Unlock" : "Lock", 
                                      systemImage: entry.isLocked ? "lock.open" : "lock")
                            }
                            .tint(entry.isLocked ? .green : .blue)
                        }
                    }
                }
                .listStyle(PlainListStyle())
            } else {
                VStack {
                    Spacer()
                    Text("No entries for this day")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            }
        }
//        .onAppear {
//            // Ensure today's date is selected by default
//            if Calendar.current.isDateInToday(viewModel.selectedDate) == false {
//                viewModel.moveToToday()
//            }
//        }
    }
    
    /// A cell representing a day in the week view
    struct WeekDayCell: View {
        let date: Date
        @ObservedObject var viewModel: CalendarViewModel
        
        var body: some View {
            VStack(spacing: 4) {
                // Weekday
                Text(date, formatter: weekdayFormatter)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Day number
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.title3)
                    .fontWeight(viewModel.isToday(date) ? .bold : .regular)
                    .foregroundColor(textColor())
                
                // Month if first day of month
                if Calendar.current.component(.day, from: date) == 1 {
                    Text(date, formatter: monthFormatter)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Entry indicators
                if viewModel.hasEntries(on: date) {
                    entryIndicators
                } else {
                    Spacer()
                        .frame(height: 16)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(cellBackgroundColor())
            )
            .onTapGesture {
                viewModel.selectDate(date)
            }
        }
        
        /// Entry indicators showing tags
        private var entryIndicators: some View {
            let tagInfo = viewModel.tagInfo(for: date)
            let entryCount = viewModel.entryCount(for: date)
            
            return VStack(spacing: 2) {
                // Tag indicators (up to 3)
                HStack(spacing: 2) {
                    ForEach(Array(tagInfo.prefix(3))) { tag in
                        if let iconName = tag.iconName, !iconName.isEmpty {
                            Image(systemName: iconName)
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: tag.color))
                        } else {
                            Circle()
                                .fill(Color(hex: tag.color))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                
                // Entry count if more than 3 tags or entries
                if tagInfo.count > 3 || entryCount > 3 {
                    Text("\(entryCount)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        
        /// Determine the text color for the day number
        private func textColor() -> Color {
            if viewModel.isToday(date) {
                return .white
            } else if viewModel.isSelected(date) {
                return .blue
            } else {
                return .primary
            }
        }
        
        /// Determine the background color for the cell
        private func cellBackgroundColor() -> Color {
            if viewModel.isToday(date) {
                return .blue
            } else if viewModel.isSelected(date) {
                return Color.purple.opacity(0.3)
            } else {
                return Color.clear
            }
        }
        
        private let weekdayFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return formatter
        }()
        
        private let monthFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            return formatter
        }()
    }
}

// MARK: - Preview

#Preview {
    CalendarView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

// Preview for WeekCalendarView
struct WeekCalendarView_Previews: PreviewProvider {
    static var previews: some View {
        @State var selectedEntryToDelete: JournalEntry? = nil
        @State var showDeleteConfirmation = false
        @State var selectedEntryToToggleLock: JournalEntry? = nil
        @State var showLockConfirmation = false
        
        return WeekCalendarView(
            viewModel: CalendarViewModel(context: PersistenceController.preview.container.viewContext),
            selectedEntryToDelete: .constant(nil),
            showDeleteConfirmation: .constant(false),
            selectedEntryToToggleLock: .constant(nil),
            showLockConfirmation: .constant(false)
        )
    }
}
