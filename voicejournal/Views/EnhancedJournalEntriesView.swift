//
//  EnhancedJournalEntriesView.swift
//  voicejournal
//
//  Created on 4/28/25.
//

import SwiftUI
import CoreData

/// A view that displays journal entries with enhanced UI and organization
struct EnhancedJournalEntriesView: View {
    // MARK: - Environment
    
    @Environment(\.managedObjectContext) private var viewContext
    
    // MARK: - State
    
    @State private var searchText = ""
    @State private var showingFilterOptions = false
    @State private var showingSortOptions = false
    @State private var selectedFilterTags: Set<String> = [] // Tags to include
    @State private var excludedFilterTags: Set<String> = [] // Tags to exclude
    @State private var sortOption: SortOption = .dateNewest
    @State private var showingNewEntrySheet = false
    @State private var selectedEntryForEdit: JournalEntry? = nil
    
    // MARK: - Fetch Request
    
    @FetchRequest private var entries: FetchedResults<JournalEntry>
    
    // MARK: - Initialization
    
    init() {
        // Create the fetch request before initializing _entries
        let request = JournalEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \JournalEntry.createdAt, ascending: false)]
        _entries = FetchRequest(fetchRequest: request)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                // Main content
                VStack(spacing: 0) {
                    // Search bar
                    searchBar
                    
                    // Filter chips
                    filterChipsView
                    
                    // Entries list
                    if entries.isEmpty {
                        emptyStateView
                    } else {
                        entriesList
                    }
                }
                
                // FAB for new entry
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        newEntryButton
                    }
                    .padding()
                }
            }
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showingFilterOptions = true
                        }) {
                            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                        }
                        
                        Menu {
                            Button(action: {
                                setSortOption(.dateNewest)
                            }) {
                                Label("Newest First", systemImage: sortOption == .dateNewest ? "checkmark" : "")
                            }
                            
                            Button(action: {
                                setSortOption(.dateOldest)
                            }) {
                                Label("Oldest First", systemImage: sortOption == .dateOldest ? "checkmark" : "")
                            }
                            
                            Button(action: {
                                setSortOption(.titleAZ)
                            }) {
                                Label("Title (A-Z)", systemImage: sortOption == .titleAZ ? "checkmark" : "")
                            }
                            
                            Button(action: {
                                setSortOption(.titleZA)
                            }) {
                                Label("Title (Z-A)", systemImage: sortOption == .titleZA ? "checkmark" : "")
                            }
                            
                            Button(action: {
                                setSortOption(.duration)
                            }) {
                                Label("Duration", systemImage: sortOption == .duration ? "checkmark" : "")
                            }
                        } label: {
                            Label("Sort", systemImage: "arrow.up.arrow.down")
                        }
                        
                        Divider()
                        
                        Button(action: {
                            showingNewEntrySheet = true
                        }) {
                            Label("New Entry", systemImage: "plus")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingFilterOptions) {
                // Pass bindings to both tag sets
                FilterOptionsView(
                    selectedTags: $selectedFilterTags,
                    excludedTags: $excludedFilterTags,
                    onDismiss: {
                        showingFilterOptions = false
                        updateFetchRequest()
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingNewEntrySheet) {
                EntryCreationView(isPresented: $showingNewEntrySheet)
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(item: $selectedEntryForEdit) { entry in
                JournalEntryEditView(journalEntry: entry)
                    .environment(\.managedObjectContext, viewContext)
            }
            .onChange(of: searchText) { oldValue, newValue in
                updateFetchRequest()
            }
            .onAppear {
                updateFetchRequest()
            }
            
            // Placeholder for when no entry is selected
            Text("Select an entry")
                .font(.title2)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Subviews
    
    /// Search bar for filtering entries
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search entries", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    /// Filter chips view
    private var filterChipsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Display chips for each included tag
                ForEach(selectedFilterTags.sorted(), id: \.self) { tag in
                    FilterChip(
                        label: "Include: \(tag)",
                        systemImage: "tag.fill",
                        isSelected: true,
                        action: {
                            selectedFilterTags.remove(tag)
                            updateFetchRequest()
                        }
                    )
                }
                
                // Display chips for each excluded tag
                ForEach(excludedFilterTags.sorted(), id: \.self) { tag in
                    FilterChip(
                        label: "Exclude: \(tag)",
                        systemImage: "tag.slash",
                        isSelected: true,
                        action: {
                            excludedFilterTags.remove(tag)
                            updateFetchRequest()
                        }
                    )
                }
                
                if sortOption != .dateNewest {
                    FilterChip(
                        label: "Sort: \(sortOption.displayName)",
                        systemImage: "arrow.up.arrow.down",
                        isSelected: true,
                        action: {
                            setSortOption(.dateNewest)
                        }
                    )
                }
                
                if !searchText.isEmpty {
                    FilterChip(
                        label: "Search: \(searchText)",
                        systemImage: "magnifyingglass",
                        isSelected: true,
                        action: {
                            searchText = ""
                        }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .opacity(hasActiveFilters ? 1 : 0)
        .frame(height: hasActiveFilters ? nil : 0)
    }
    
    /// List of journal entries
    private var entriesList: some View {
        List {
            ForEach(groupedEntries.keys.sorted(by: >), id: \.self) { dateKey in
                Section(header: Text(sectionTitle(for: dateKey))) {
                    ForEach(groupedEntries[dateKey] ?? []) { entry in
                        NavigationLink {
                            JournalEntryView(journalEntry: entry)
                        } label: {
                            EnhancedJournalEntryRow(entry: entry)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteEntry(entry)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                toggleLock(entry)
                            } label: {
                                Label(
                                    entry.isLocked ? "Unlock" : "Lock",
                                    systemImage: entry.isLocked ? "lock.open" : "lock"
                                )
                            }
                            .tint(.blue)
                        }
                        .contextMenu {
                            Button {
                                selectedEntryForEdit = entry
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            
                            Button {
                                toggleLock(entry)
                            } label: {
                                Label(
                                    entry.isLocked ? "Unlock" : "Lock",
                                    systemImage: entry.isLocked ? "lock.open" : "lock"
                                )
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                deleteEntry(entry)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    /// Empty state view when no entries are available
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 72))
                .foregroundColor(.secondary)
            
            Text(emptyStateMessage)
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            if hasActiveFilters {
                Button("Clear Filters") {
                    searchText = ""
                    selectedFilterTags = [] // Clear included tags
                    excludedFilterTags = [] // Clear excluded tags
                    setSortOption(.dateNewest)
                    // updateFetchRequest() will be called by setSortOption
                }
                .buttonStyle(.bordered)
            } else {
                Button("Create First Entry") {
                    showingNewEntrySheet = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    /// New entry floating action button
    private var newEntryButton: some View {
        Button(action: {
            showingNewEntrySheet = true
        }) {
            Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.blue)
                .clipShape(Circle())
                .shadow(radius: 4)
        }
        .accessibilityLabel("New Journal Entry")
    }
    
    // MARK: - Helper Views
    
    /// A chip view for displaying active filters
    struct FilterChip: View {
        let label: String
        let systemImage: String
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.caption)
                
                Text(label)
                    .font(.caption)
                
                Image(systemName: "xmark")
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue.opacity(0.2) : Color(.systemGray5))
            .foregroundColor(isSelected ? .blue : .primary)
            .cornerRadius(16)
            .onTapGesture {
                action()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Check if any filters are active
    private var hasActiveFilters: Bool {
        !searchText.isEmpty || !selectedFilterTags.isEmpty || !excludedFilterTags.isEmpty || sortOption != .dateNewest
    }
    
    /// Message to display when no entries are found
    private var emptyStateMessage: String {
        if hasActiveFilters {
            return "No entries match your current filters"
        } else {
            return "No journal entries yet\nStart by creating your first entry"
        }
    }
    
    /// Group entries by date section
    private var groupedEntries: [String: [JournalEntry]] {
        var result = [String: [JournalEntry]]()
        
        for entry in entries {
            guard let date = entry.createdAt else { continue }
            
            let dateKey = dateSection(for: date)
            if result[dateKey] == nil {
                result[dateKey] = [entry]
            } else {
                result[dateKey]?.append(entry)
            }
        }
        
        return result
    }
    
    // MARK: - Methods
    
    /// Create a fetch request based on search, filter, and sort options
    private func createFetchRequest(searchText: String, filterTags: Set<String>, excludedTags: Set<String>, sortOption: SortOption) -> NSFetchRequest<JournalEntry> {
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        
        // Build predicates
        var predicates = [NSPredicate]()
        
        if !searchText.isEmpty {
            let searchPredicate = NSPredicate(
                format: "title CONTAINS[cd] %@ OR transcription.text CONTAINS[cd] %@",
                searchText, searchText
            )
            predicates.append(searchPredicate)
        }
        
        // Predicate for included tags
        if !filterTags.isEmpty {
            let tagPredicate = NSPredicate(format: "ANY tags.name IN %@", filterTags)
            predicates.append(tagPredicate)
        }
        
        // Predicate for excluded tags
        if !excludedTags.isEmpty {
            let excludePredicate = NSPredicate(format: "NONE tags.name IN %@", excludedTags)
            predicates.append(excludePredicate)
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        // Set sort descriptors
        request.sortDescriptors = sortOption.sortDescriptors
        
        return request
    }
    
    /// Update the fetch request based on current filters and sort options
    private func updateFetchRequest() {
        entries.nsPredicate = createFetchRequest(
            searchText: searchText,
            filterTags: selectedFilterTags,
            excludedTags: excludedFilterTags,
            sortOption: sortOption
        ).predicate
        
        entries.nsSortDescriptors = sortOption.sortDescriptors
    }
    
    /// Set the sort option and update the fetch request
    private func setSortOption(_ option: SortOption) {
        sortOption = option
        updateFetchRequest()
    }
    
    /// Delete a journal entry
    private func deleteEntry(_ entry: JournalEntry) {
        withAnimation {
            viewContext.delete(entry)
            
            do {
                try viewContext.save()
            } catch {
                print("Error deleting entry: \(error.localizedDescription)")
            }
        }
    }
    
    /// Toggle the lock state of an entry
    private func toggleLock(_ entry: JournalEntry) {
        if entry.isLocked {
            entry.unlock()
        } else {
            entry.lock()
        }
    }
    
    /// Get the date section key for a given date
    private func dateSection(for date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "today"
        } else if calendar.isDateInYesterday(date) {
            return "yesterday"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            return "thisWeek"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .month) {
            return "thisMonth"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM"
            return dateFormatter.string(from: date)
        }
    }
    
    /// Get a human-readable section title for a date key
    private func sectionTitle(for dateKey: String) -> String {
        switch dateKey {
        case "today":
            return "Today"
        case "yesterday":
            return "Yesterday"
        case "thisWeek":
            return "This Week"
        case "thisMonth":
            return "This Month"
        default:
            // Format as Month Year
            let components = dateKey.split(separator: "-")
            if components.count == 2,
               let year = Int(components[0]),
               let month = Int(components[1]) {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMMM yyyy"
                
                var dateComponents = DateComponents()
                dateComponents.year = year
                dateComponents.month = month
                
                if let date = Calendar.current.date(from: dateComponents) {
                    return dateFormatter.string(from: date)
                }
            }
            return dateKey
        }
    }
}

// MARK: - Sort Option

/// Options for sorting journal entries
enum SortOption: String, CaseIterable {
    case dateNewest
    case dateOldest
    case titleAZ
    case titleZA
    case duration
    
    var displayName: String {
        switch self {
        case .dateNewest: return "Newest First"
        case .dateOldest: return "Oldest First"
        case .titleAZ: return "Title (A-Z)"
        case .titleZA: return "Title (Z-A)"
        case .duration: return "Duration"
        }
    }
    
    var sortDescriptors: [NSSortDescriptor] {
        switch self {
        case .dateNewest:
            return [NSSortDescriptor(keyPath: \JournalEntry.createdAt, ascending: false)]
        case .dateOldest:
            return [NSSortDescriptor(keyPath: \JournalEntry.createdAt, ascending: true)]
        case .titleAZ:
            return [
                NSSortDescriptor(keyPath: \JournalEntry.title, ascending: true),
                NSSortDescriptor(keyPath: \JournalEntry.createdAt, ascending: false)
            ]
        case .titleZA:
            return [
                NSSortDescriptor(keyPath: \JournalEntry.title, ascending: false),
                NSSortDescriptor(keyPath: \JournalEntry.createdAt, ascending: false)
            ]
        case .duration:
            return [
                NSSortDescriptor(keyPath: \JournalEntry.audioRecording?.duration, ascending: false),
                NSSortDescriptor(keyPath: \JournalEntry.createdAt, ascending: false)
            ]
        }
    }
}

// MARK: - Filter Options View

/// A view for selecting filter options
struct FilterOptionsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var selectedTags: Set<String> // Tags to include
    @Binding var excludedTags: Set<String> // Tags to exclude
    let onDismiss: () -> Void
    
    @FetchRequest(
        entity: Tag.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
    ) private var tags: FetchedResults<Tag>
    
    @State private var filterMode: FilterMode = .include
    
    enum FilterMode {
        case include
        case exclude
    }
    
    var body: some View {
        NavigationView {
            List {
                // Filter mode picker
                Section {
                    Picker("Filter Mode", selection: $filterMode) {
                        Text("Include Tags").tag(FilterMode.include)
                        Text("Exclude Tags").tag(FilterMode.exclude)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                // Include tags section
                if filterMode == .include {
                    Section(header: Text("Include Entries With These Tags")) {
                        // Button to clear all tag selections
                        Button {
                            selectedTags.removeAll()
                        } label: {
                            HStack {
                                Text("Clear Selection")
                                Spacer()
                                if selectedTags.isEmpty {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(selectedTags.isEmpty ? .blue : .primary)
                        
                        // List each tag for inclusion
                        ForEach(tags, id: \.self) { tag in
                            if let name = tag.name {
                                Button {
                                    // Toggle membership in the include set
                                    if selectedTags.contains(name) {
                                        selectedTags.remove(name)
                                    } else {
                                        selectedTags.insert(name)
                                    }
                                } label: {
                                    tagRow(tag: tag, isSelected: selectedTags.contains(name ?? ""))
                                }
                                .foregroundColor(.primary)
                            }
                        }
                    }
                }
                
                // Exclude tags section
                if filterMode == .exclude {
                    Section(header: Text("Exclude Entries With These Tags")) {
                        // Button to clear all excluded tags
                        Button {
                            excludedTags.removeAll()
                        } label: {
                            HStack {
                                Text("Clear Exclusions")
                                Spacer()
                                if excludedTags.isEmpty {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(excludedTags.isEmpty ? .blue : .primary)
                        
                        // List each tag for exclusion
                        ForEach(tags, id: \.self) { tag in
                            if let name = tag.name {
                                Button {
                                    // Toggle membership in the exclude set
                                    if excludedTags.contains(name) {
                                        excludedTags.remove(name)
                                    } else {
                                        excludedTags.insert(name)
                                    }
                                } label: {
                                    tagRow(tag: tag, isSelected: excludedTags.contains(name ?? ""))
                                }
                                .foregroundColor(.primary)
                            }
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Filter Entries")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
    
    // Helper function to create consistent tag rows
    private func tagRow(tag: Tag, isSelected: Bool) -> some View {
        HStack {
            // Display icon if available, otherwise color circle
            if let iconName = tag.iconName, !iconName.isEmpty {
                Image(systemName: iconName)
                    .font(.caption)
                    .foregroundColor(Color(hex: tag.color ?? "#007AFF"))
            } else if let color = tag.color {
                Circle()
                    .fill(Color(hex: color))
                    .frame(width: 12, height: 12)
            }
            
            Text(tag.name ?? "")
            Spacer()
            
            // Show checkmark if selected
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            }
        }
    }
}

// MARK: - Enhanced Journal Entry Row

/// An enhanced row view for a journal entry in the list
struct EnhancedJournalEntryRow: View {
    let entry: JournalEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title and lock status
            HStack {
                Text(entry.title ?? "Untitled Entry")
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                if entry.isLocked {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            
            // Date and duration
            HStack(spacing: 12) {
                if let date = entry.createdAt {
                    Label {
                        Text(date, formatter: itemFormatter)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemName: "calendar")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                if let recording = entry.audioRecording {
                    Label {
                        Text(formatDuration(recording.duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemName: "waveform")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            
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
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
    
    /// Format duration in seconds to MM:SS
    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}


// MARK: - Formatters

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

// MARK: - Preview

#Preview {
    EnhancedJournalEntriesView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
