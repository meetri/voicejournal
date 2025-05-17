//
//  TimelineView.swift
//  voicejournal
//
//  Created on 4/29/25.
//

import SwiftUI
import CoreData
// Import the shared JournalEntryRow component

/// A view that displays journal entries in a chronological timeline
struct TimelineView: View {
    // MARK: - Environment
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.themeManager) var themeManager
    
    // MARK: - State
    
    @StateObject private var viewModel: TimelineViewModel
    @State private var showingDatePicker = false
    @State private var showingRangePicker = false
    @State private var selectedEntry: JournalEntry? = nil
    @State private var scrollToDate: Date? = nil
    @State private var showingEntryCreation = false
    @State private var selectedEntryToDelete: JournalEntry? = nil
    @State private var showDeleteConfirmation = false
    @State private var showLockConfirmation = false
    @State private var selectedEntryToToggleLock: JournalEntry? = nil
    @State private var searchText: String = ""
    @State private var showingTagFilter = false
    @State private var showingSortOptions = false
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext? = nil) {
        let contextToUse = context ?? PersistenceController.shared.container.viewContext
        _viewModel = StateObject(wrappedValue: TimelineViewModel(context: contextToUse))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient background for the entire view
                themeManager.theme.background
                    .ignoresSafeArea()
                
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
                                .background(
                                    LinearGradient(
                                        colors: [
                                            themeManager.theme.primary,
                                            themeManager.theme.primary.opacity(0.8)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(Circle())
                                .shadow(color: themeManager.theme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .padding([.bottom, .trailing], 20)
                        .accessibilityLabel("New Recording")
                    }
                }
            }
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
        .sheet(isPresented: $showingDatePicker) {
            DatePickerView(onDateSelected: { date in
                viewModel.jumpToDate(date)
                scrollToDate = date
                showingDatePicker = false
            })
            .presentationDetents([.medium, .large])
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
        // Removed sheet presentation in favor of NavigationLink
        .sheet(isPresented: $showingEntryCreation) {
            EntryCreationView(isPresented: $showingEntryCreation)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingTagFilter) {
            TagFilterView(
                selectedTags: $viewModel.selectedTags,
                filterMode: $viewModel.tagFilterMode
            )
            .environment(\.managedObjectContext, viewContext)
        }
    }
    
    // MARK: - Subviews
    
    /// Timeline header with date range selection
    private var timelineHeader: some View {
        VStack(spacing: 12) {
            headerTopRow
            searchAndFilterControls
        }
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .fill(themeManager.theme.surface.opacity(0.05))
                )
        )
    }
    
    private var headerTopRow: some View {
        HStack {
            Text("Timeline")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.theme.text)
            
            Spacer()
            
            dateRangeButton
        }
        .padding(.horizontal)
    }
    
    private var dateRangeButton: some View {
        Button(action: {
            showingRangePicker = true
        }) {
            HStack(spacing: 4) {
                Text(viewModel.dateRangeTitle())
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
            )
            .foregroundColor(themeManager.theme.primary)
            .overlay(
                Capsule()
                    .stroke(themeManager.theme.primary.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    private var searchAndFilterControls: some View {
        HStack(spacing: 8) {
            searchBar
            tagFilterButton
            sortMenu
        }
        .padding(.horizontal)
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(themeManager.theme.textSecondary)
            
            TextField("Search entries...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(themeManager.theme.text)
                .onChange(of: searchText) { _, newValue in
                    viewModel.searchText = newValue
                }
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    viewModel.searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(themeManager.theme.textSecondary)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(themeManager.theme.surface.opacity(0.5), lineWidth: 1)
        )
    }
    
    private var tagFilterButton: some View {
        Button(action: {
            showingTagFilter = true
        }) {
            HStack(spacing: 4) {
                Image(systemName: "tag")
                Text(viewModel.selectedTags.isEmpty ? "Tags" : "\(viewModel.selectedTags.count)")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                viewModel.selectedTags.isEmpty 
                    ? AnyView(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.ultraThinMaterial)
                      )
                    : AnyView(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(themeManager.theme.primary.opacity(0.1))
                      )
            )
            .foregroundColor(viewModel.selectedTags.isEmpty ? themeManager.theme.text : themeManager.theme.primary)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(viewModel.selectedTags.isEmpty ? themeManager.theme.surface.opacity(0.5) : themeManager.theme.primary.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    private var sortMenu: some View {
        Menu {
            ForEach(SortOrder.allCases) { order in
                Button(action: {
                    print("🔄 Sort order selected: \(order.rawValue)")
                    viewModel.applySortOrder(order)
                }) {
                    HStack {
                        Text(order.rawValue)
                        if viewModel.sortOrder == order {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                Text("Sort")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
            )
            .foregroundColor(themeManager.theme.text)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(themeManager.theme.surface.opacity(0.5), lineWidth: 1)
            )
        }
    }
    
    /// Timeline content with entries in a flat list
    private var timelineContent: some View {
        List {
            ForEach(viewModel.sortedDates, id: \.self) { date in
                if let entries = viewModel.entriesByDate[date], !entries.isEmpty {
                    // Display all entries without section headers
                    ForEach(entries) { entry in
                        NavigationLink(destination: JournalEntryView(journalEntry: entry)) {
                            ModernJournalEntryRow(entry: entry, onToggleLock: { toggledEntry in
                                selectedEntryToToggleLock = toggledEntry
                                showLockConfirmation = true
                            })
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
                }
            }
        }
        .listStyle(PlainListStyle())
        .scrollContentBackground(.hidden)
        .background(themeManager.theme.background)
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
                .progressViewStyle(CircularProgressViewStyle(tint: themeManager.theme.primary))
                .scaleEffect(1.5)
            Text("Loading entries...")
                .font(.headline)
                .foregroundColor(themeManager.theme.textSecondary)
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
                .foregroundColor(themeManager.theme.accent.opacity(0.7))
            
            Text("No Journal Entries")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.theme.text)
            
            if !viewModel.searchText.isEmpty {
                Text("No entries match your search for \"\(viewModel.searchText)\".")
                    .font(.body)
                    .foregroundColor(themeManager.theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Button(action: {
                    searchText = ""
                    viewModel.searchText = ""
                }) {
                    Text("Clear Search")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(themeManager.theme.primary)
                        )
                        .foregroundColor(.white)
                }
            } else if !viewModel.selectedTags.isEmpty {
                Text("No entries match the selected tag filters.")
                    .font(.body)
                    .foregroundColor(themeManager.theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Button(action: {
                    viewModel.selectedTags.removeAll()
                }) {
                    Text("Clear Tag Filters")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(themeManager.theme.primary)
                        )
                        .foregroundColor(.white)
                }
            } else {
                Text("No entries found for the selected date range.")
                    .font(.body)
                    .foregroundColor(themeManager.theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Button(action: {
                    viewModel.setDateRange(.allTime)
                }) {
                    Text("Show All Entries")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(themeManager.theme.primary)
                        )
                        .foregroundColor(.white)
                }
            }
            // .padding(.top, 8)
            
            Spacer()
        }
    }
}


// MARK: - Date Picker View

/// A view for picking a specific date to jump to
struct DatePickerView: View {
    @State private var selectedDate = Date()
    @Environment(\.dismiss) private var dismiss
    let onDateSelected: (Date) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                DatePicker(
                    "Select a date",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(GraphicalDatePickerStyle())
                .padding()
                
                Spacer().frame(height: 10)
                
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
                .padding(.bottom, 20)
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
