//
//  TimelineView.swift
//  voicejournal
//
//  Created on 4/29/25.
//

import SwiftUI
import CoreData

/// A view that displays journal entries in a chronological timeline
struct TimelineView: View {
    // MARK: - Environment
    
    @Environment(\.managedObjectContext) private var viewContext
    
    // MARK: - State
    
    @StateObject private var viewModel: TimelineViewModel
    @State private var showingDatePicker = false
    @State private var showingRangePicker = false
    @State private var selectedEntry: JournalEntry? = nil
    @State private var scrollToDate: Date? = nil
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext? = nil) {
        let contextToUse = context ?? PersistenceController.shared.container.viewContext
        _viewModel = StateObject(wrappedValue: TimelineViewModel(context: contextToUse))
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Timeline header
            timelineHeader
            
            // Timeline content
            if viewModel.isLoading {
                loadingView
            } else if viewModel.sortedDates.isEmpty {
                emptyStateView
            } else {
                timelineContent
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePickerView(onDateSelected: { date in
                viewModel.jumpToDate(date)
                scrollToDate = date
                showingDatePicker = false
            })
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingRangePicker) {
            DateRangePickerView(
                dateRange: $viewModel.dateRange,
                customStartDate: $viewModel.customStartDate,
                customEndDate: $viewModel.customEndDate,
                onDismiss: {
                    showingRangePicker = false
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $selectedEntry) { entry in
            JournalEntryView(journalEntry: entry)
        }
    }
    
    // MARK: - Subviews
    
    /// Timeline header with date range selection
    private var timelineHeader: some View {
        VStack(spacing: 8) {
            // Title and date range
            HStack {
                Text("Timeline")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    showingRangePicker = true
                }) {
                    HStack(spacing: 4) {
                        Text(viewModel.dateRangeTitle())
                            .font(.subheadline)
                        
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            
            // Jump to date and entry count
            HStack {
                Button(action: {
                    showingDatePicker = true
                }) {
                    Label("Jump to Date", systemImage: "calendar")
                        .font(.caption)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color(.secondarySystemBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                }
                
                Spacer()
                
                Text("\(viewModel.totalEntryCount()) entries")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            Divider()
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    /// Timeline content with entries grouped by date
    private var timelineContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16, pinnedViews: [.sectionHeaders]) {
                ForEach(viewModel.sortedDates, id: \.self) { date in
                    if let entries = viewModel.entriesByDate[date], !entries.isEmpty {
                        Section(header: dateHeader(for: date)) {
                            VStack(spacing: 12) {
                                ForEach(entries) { entry in
                                    TimelineEntryRow(entry: entry)
                                        .onTapGesture {
                                            selectedEntry = entry
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Bottom padding
                Color.clear.frame(height: 40)
            }
        }
        .onChange(of: scrollToDate) { oldValue, newValue in
            if let date = newValue {
                // Find the closest date in our sorted dates
                if !viewModel.sortedDates.isEmpty {
                    var closestDate = viewModel.sortedDates.first!
                    var smallestDifference = abs(date.timeIntervalSince(closestDate))
                    
                    for dateWithEntries in viewModel.sortedDates {
                        let difference = abs(date.timeIntervalSince(dateWithEntries))
                        if difference < smallestDifference {
                            smallestDifference = difference
                            closestDate = dateWithEntries
                        }
                    }
                    
                    // Reset the scroll target
                    scrollToDate = nil
                    
                    // In a real app, we would scroll to this date
                    // This would require a ScrollViewReader and id-based views
                    print("Would scroll to date: \(closestDate)")
                }
            }
        }
    }
    
    /// Date header for a section in the timeline
    private func dateHeader(for date: Date) -> some View {
        HStack {
            Text(viewModel.formattedDateHeader(for: date))
                .font(.headline)
                .padding(.vertical, 8)
            
            Spacer()
        }
        .padding(.horizontal)
        .background(Color(.systemBackground).opacity(0.9))
    }
    
    /// Loading view shown while fetching entries
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
            Text("Loading entries...")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.top, 16)
            Spacer()
        }
    }
    
    /// Empty state view when no entries are found
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 72))
                .foregroundColor(.secondary)
            
            Text("No Journal Entries")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("No entries found for the selected date range.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(action: {
                viewModel.setDateRange(.allTime)
            }) {
                Text("Show All Entries")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.top, 8)
            
            Spacer()
        }
    }
}

// MARK: - Timeline Entry Row

/// A row representing an entry in the timeline
struct TimelineEntryRow: View {
    let entry: JournalEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Time and duration
            HStack {
                if let date = entry.createdAt {
                    Text(date, formatter: timeFormatter)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let recording = entry.audioRecording {
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(formatDuration(recording.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if entry.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Title
            Text(entry.title ?? "Untitled Entry")
                .font(.headline)
                .lineLimit(1)
            
            // Tags
            if let tags = entry.tags as? Set<Tag>, !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Array(tags), id: \.self) { tag in
                            if let name = tag.name, let color = tag.color {
                                HStack(spacing: 4) {
                                    // Display icon if available, otherwise color circle
                                    if let iconName = tag.iconName, !iconName.isEmpty {
                                        Image(systemName: iconName)
                                            .font(.caption2)
                                            .foregroundColor(Color(hex: color))
                                    } else {
                                        Circle()
                                            .fill(Color(hex: color))
                                            .frame(width: 6, height: 6)
                                    }
                                    
                                    Text(name)
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: color).opacity(0.2))
                                .foregroundColor(Color(hex: color))
                                .cornerRadius(4)
                            }
                        }
                    }
                }
            }
            
            // Preview of transcription
            if let transcription = entry.transcription, let text = transcription.text, !text.isEmpty {
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .padding(.top, 2)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    /// Format duration in seconds to MM:SS
    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
}

// MARK: - Date Picker View

/// A view for picking a specific date to jump to
struct DatePickerView: View {
    @State private var selectedDate = Date()
    @Environment(\.dismiss) private var dismiss
    let onDateSelected: (Date) -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Select a date",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(GraphicalDatePickerStyle())
                .padding()
                
                Button(action: {
                    onDateSelected(selectedDate)
                }) {
                    Text("Jump to Date")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Jump to Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Date Range Picker View

/// A view for selecting a date range for the timeline
struct DateRangePickerView: View {
    @Binding var dateRange: DateRange
    @Binding var customStartDate: Date?
    @Binding var customEndDate: Date?
    
    @State private var tempStartDate: Date = Date()
    @State private var tempEndDate: Date = Date()
    @State private var showingCustomDatePicker = false
    
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                // Preset date ranges
                Section(header: Text("Date Range")) {
                    ForEach(DateRange.allCases.filter { $0 != .custom }) { range in
                        Button(action: {
                            dateRange = range
                            onDismiss()
                        }) {
                            HStack {
                                Text(range.displayName)
                                Spacer()
                                if dateRange == range {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                // Custom date range
                Section(header: Text("Custom Range")) {
                    Button(action: {
                        showingCustomDatePicker = true
                        
                        // Initialize with current custom dates or today
                        tempStartDate = customStartDate ?? Date()
                        tempEndDate = customEndDate != nil ? Calendar.current.date(byAdding: .day, value: -1, to: customEndDate!) ?? Date() : Date()
                    }) {
                        HStack {
                            Text("Custom Date Range")
                            Spacer()
                            if dateRange == .custom {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                    
                    if dateRange == .custom && customStartDate != nil && customEndDate != nil {
                        HStack {
                            Text("From")
                            Spacer()
                            Text(customStartDate!, formatter: dateFormatter)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("To")
                            Spacer()
                            Text(Calendar.current.date(byAdding: .day, value: -1, to: customEndDate!) ?? customEndDate!, formatter: dateFormatter)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Select Date Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCustomDatePicker) {
                CustomDateRangePickerView(
                    startDate: $tempStartDate,
                    endDate: $tempEndDate,
                    onSave: { start, end in
                        customStartDate = start
                        
                        // Add one day to end date for the predicate range
                        customEndDate = Calendar.current.date(byAdding: .day, value: 1, to: end)
                        dateRange = .custom
                        showingCustomDatePicker = false
                    },
                    onCancel: {
                        showingCustomDatePicker = false
                    }
                )
                .presentationDetents([.medium, .large])
            }
        }
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

// MARK: - Custom Date Range Picker View

/// A view for selecting a custom date range
struct CustomDateRangePickerView: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    
    let onSave: (Date, Date) -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section(header: Text("Start Date")) {
                        DatePicker(
                            "Start Date",
                            selection: $startDate,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(GraphicalDatePickerStyle())
                        .labelsHidden()
                    }
                    
                    Section(header: Text("End Date")) {
                        DatePicker(
                            "End Date",
                            selection: $endDate,
                            in: startDate...,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(GraphicalDatePickerStyle())
                        .labelsHidden()
                    }
                }
                
                HStack {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        onSave(startDate, endDate)
                    }) {
                        Text("Apply")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding()
            }
            .navigationTitle("Custom Date Range")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}


// MARK: - Preview

#Preview {
    TimelineView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
