//
//  TimelineViewModel.swift
//  voicejournal
//
//  Created on 4/29/25.
//

import Foundation
import CoreData
import Combine
import SwiftUI
import NotificationCenter

/// View model for the timeline view that manages chronological entry data
class TimelineViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// The currently selected date range
    @Published var dateRange: DateRange = .allTime
    
    /// The start date for custom date range
    @Published var customStartDate: Date?
    
    /// The end date for custom date range
    @Published var customEndDate: Date?
    
    /// Dictionary mapping dates to journal entries, sorted chronologically
    @Published var entriesByDate: [Date: [JournalEntry]] = [:]
    
    /// All dates with entries, sorted chronologically
    @Published var sortedDates: [Date] = []
    
    /// Flag indicating if data is currently loading
    @Published var isLoading: Bool = false
    
    /// Text to search for in journal entries
    @Published var searchText: String = ""
    
    /// Tags selected for filtering
    @Published var selectedTags: Set<Tag> = []
    
    /// Mode for tag filtering
    @Published var tagFilterMode: TagFilterMode = .any
    
    /// Current sort order for entries
    @Published var sortOrder: SortOrder = .newestFirst
    
    /// Computed property to determine if any filtering is active
    var isFilteringActive: Bool {
        return !searchText.isEmpty || !selectedTags.isEmpty
    }
    
    // MARK: - Private Properties
    
    private var viewContext: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()
    private let calendar = Calendar.current
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
        
        // Set up publishers to refresh data when date range changes
        Publishers.CombineLatest3($dateRange, $customStartDate, $customEndDate)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] (range, start, end) in
                self?.fetchEntriesForDateRange()
            }
            .store(in: &cancellables)
        
        // Set up publishers for search, tags, and sort order
        Publishers.CombineLatest3($searchText, $selectedTags, $tagFilterMode)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] (_, _, _) in
                self?.fetchEntriesForDateRange()
            }
            .store(in: &cancellables)
        
        // Monitor sort order changes - removed .dropFirst() to ensure initial sort is applied
        $sortOrder
            .sink { [weak self] newSortOrder in
                self?.fetchEntriesForDateRange()
            }
            .store(in: &cancellables)
        
        // Register for Core Data change notifications
        registerForCoreDataNotifications()
        
        // Initial data fetch
        fetchEntriesForDateRange()
    }
    
    deinit {
        // Unregister from notifications when this view model is deallocated
        unregisterForCoreDataNotifications()
    }
    
    // MARK: - Public Methods
    
    /// Toggle the lock state of a journal entry
    func toggleEntryLock(_ entry: JournalEntry) {
        if entry.isLocked {
            entry.unlock()
        } else {
            entry.lock()
        }
        
        // Refresh the UI
        objectWillChange.send()
    }
    
    /// Delete a journal entry
    func deleteEntry(_ entry: JournalEntry) {
        // Don't allow deletion of locked entries
        guard !entry.isLocked, let context = entry.managedObjectContext else { return }
        
        // Delete the entry
        context.delete(entry)
        
        // Save changes
        do {
            try context.save()
            
            // Refresh the data
            fetchEntriesForDateRange()
        } catch {
            // Error handling without debug logs
        }
    }
    
    /// Set the date range for the timeline
    func setDateRange(_ range: DateRange) {
        dateRange = range
        
        // Reset custom dates if not using custom range
        if range != .custom {
            customStartDate = nil
            customEndDate = nil
        }
    }
    
    /// Set a custom date range
    func setCustomDateRange(start: Date, end: Date) {
        customStartDate = calendar.startOfDay(for: start)
        customEndDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end))
        dateRange = .custom
    }
    
    /// Get the formatted title for the current date range
    func dateRangeTitle() -> String {
        switch dateRange {
        case .today:
            return "Today"
        case .yesterday:
            return "Yesterday"
        case .last7Days:
            return "Last 7 Days"
        case .last30Days:
            return "Last 30 Days"
        case .thisMonth:
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMMM yyyy"
            return dateFormatter.string(from: Date())
        case .custom:
            if let start = customStartDate, let end = customEndDate {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMM d, yyyy"
                let endDateForDisplay = calendar.date(byAdding: .day, value: -1, to: end) ?? end
                return "\(dateFormatter.string(from: start)) - \(dateFormatter.string(from: endDateForDisplay))"
            }
            return "Custom Range"
        case .allTime:
            return "All Entries"
        }
    }
    
    /// Get the total number of entries in the current date range
    func totalEntryCount() -> Int {
        var count = 0
        for (_, entries) in entriesByDate {
            count += entries.count
        }
        return count
    }
    
    /// Get the formatted date string for a date section header
    func formattedDateHeader(for date: Date) -> String {
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let dateFormatter = DateFormatter()
            
            // If this year, don't show the year
            if calendar.component(.year, from: date) == calendar.component(.year, from: Date()) {
                dateFormatter.dateFormat = "EEEE, MMMM d"
            } else {
                dateFormatter.dateFormat = "EEEE, MMMM d, yyyy"
            }
            
            return dateFormatter.string(from: date)
        }
    }
    
    /// Apply a new sort order and immediately fetch entries
    func applySortOrder(_ order: SortOrder) {
        // Update the sort order property
        sortOrder = order
        
        // Force immediate fetch with the new sort order
        fetchEntriesForDateRange()
    }
    
    // MARK: - Core Data Notification Methods
    
    /// Register for Core Data change notifications
    private func registerForCoreDataNotifications() {
        // Register for NSManagedObjectContextDidSave notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(managedObjectContextDidSave),
            name: NSNotification.Name.NSManagedObjectContextDidSave,
            object: nil
        )
    }
    
    /// Unregister from Core Data change notifications
    private func unregisterForCoreDataNotifications() {
        // Remove observer for NSManagedObjectContextDidSave notifications
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name.NSManagedObjectContextDidSave,
            object: nil
        )
    }
    
    /// Handle NSManagedObjectContextDidSave notifications
    @objc private func managedObjectContextDidSave(_ notification: Notification) {
        // Check if the notification is from our view context or a parent context
        guard let context = notification.object as? NSManagedObjectContext else {
            return
        }
        
        // Only process notifications from our view context or its parent
        if context == viewContext || context == viewContext.parent {
            // Check if the changes include JournalEntry objects
            let insertedObjects = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
            let updatedObjects = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []
            let deletedObjects = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? []
            
            let hasJournalEntryChanges = insertedObjects.contains(where: { $0 is JournalEntry }) ||
                                         updatedObjects.contains(where: { $0 is JournalEntry }) ||
                                         deletedObjects.contains(where: { $0 is JournalEntry })
            
            if hasJournalEntryChanges {
                // Refresh the timeline data on the main thread
                DispatchQueue.main.async { [weak self] in
                    self?.fetchEntriesForDateRange()
                }
            }
        }
    }
    
    /// Jump to a specific date in the timeline
    func jumpToDate(_ date: Date) {
        // Find the closest date in our sorted dates
        let targetDate = calendar.startOfDay(for: date)
        
        // If we have no dates, fetch for this specific date
        if sortedDates.isEmpty {
            fetchEntriesForDate(targetDate)
            return
        }
        
        // Find the closest date we have entries for
        var closestDate = sortedDates.first!
        var smallestDifference = abs(targetDate.timeIntervalSince(closestDate))
        
        for dateWithEntries in sortedDates {
            let difference = abs(targetDate.timeIntervalSince(dateWithEntries))
            if difference < smallestDifference {
                smallestDifference = difference
                closestDate = dateWithEntries
            }
        }
        
        // If the closest date is more than 7 days away, fetch for the target date
        if smallestDifference > 7 * 24 * 60 * 60 {
            fetchEntriesForDate(targetDate)
        }
        
        // The UI will need to scroll to the closest date
        // This will be handled by the view using this view model
    }
    
    // MARK: - Private Methods
    
    /// Fetch entries for the current date range
    private func fetchEntriesForDateRange() {
        isLoading = true
        
        let (startDate, endDate) = calculateDateRange()
        
        fetchEntries(from: startDate, to: endDate)
    }
    
    /// Fetch entries for a specific date
    private func fetchEntriesForDate(_ date: Date) {
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        
        fetchEntries(from: startDate, to: endDate)
    }
    
    /// Calculate the start and end dates based on the current date range
    private func calculateDateRange() -> (Date, Date) {
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        
        switch dateRange {
        case .today:
            let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
            return (startOfToday, endOfToday)
            
        case .yesterday:
            let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
            return (startOfYesterday, startOfToday)
            
        case .last7Days:
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: startOfToday)!
            let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
            return (sevenDaysAgo, endOfToday)
            
        case .last30Days:
            let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: startOfToday)!
            let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
            return (thirtyDaysAgo, endOfToday)
            
        case .thisMonth:
            guard let monthInterval = calendar.dateInterval(of: .month, for: now) else {
                return (startOfToday, calendar.date(byAdding: .day, value: 1, to: startOfToday)!)
            }
            return (monthInterval.start, monthInterval.end)
            
        case .custom:
            if let start = customStartDate, let end = customEndDate {
                return (start, end)
            }
            return (startOfToday, calendar.date(byAdding: .day, value: 1, to: startOfToday)!)
            
        case .allTime:
            // For all time, we'll use a very early date and a future date
            let distantPast = Date(timeIntervalSince1970: 0) // January 1, 1970
            let distantFuture = Date(timeIntervalSinceNow: 365 * 10 * 24 * 60 * 60) // 10 years from now
            return (distantPast, distantFuture)
        }
    }
    
    /// Fetch entries between two dates
    private func fetchEntries(from startDate: Date, to endDate: Date) {
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        request.predicate = buildPredicate(from: startDate, to: endDate)
        request.sortDescriptors = getSortDescriptors()
        
        do {
            let fetchedEntries = try viewContext.fetch(request)
            processEntries(fetchedEntries)
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }
    
    /// Build a predicate that combines date range, search text, and tag filters
    private func buildPredicate(from startDate: Date, to endDate: Date) -> NSPredicate {
        var predicates: [NSPredicate] = [
            NSPredicate(format: "createdAt >= %@ AND createdAt < %@", startDate as NSDate, endDate as NSDate)
        ]
        
        // Add search predicate if needed
        if !searchText.isEmpty {
            predicates.append(NSPredicate(format: "title CONTAINS[cd] %@ OR transcription.text CONTAINS[cd] %@", searchText, searchText))
        }
        
        // Add tag filter predicate if needed
        if !selectedTags.isEmpty {
            switch tagFilterMode {
            case .all:
                // Entries must have ALL selected tags
                for tag in selectedTags {
                    predicates.append(NSPredicate(format: "ANY tags == %@", tag))
                }
            case .any:
                // Entries must have ANY selected tag
                predicates.append(NSPredicate(format: "ANY tags IN %@", selectedTags))
            case .exclude:
                // Entries must NOT have selected tags
                predicates.append(NSPredicate(format: "NONE tags IN %@", selectedTags))
            }
        }
        
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
    
    /// Get sort descriptors based on the current sort order
    private func getSortDescriptors() -> [NSSortDescriptor] {
        var descriptors: [NSSortDescriptor]
        
        switch sortOrder {
        case .newestFirst:
            descriptors = [NSSortDescriptor(keyPath: \JournalEntry.createdAt, ascending: false)]
        case .oldestFirst:
            descriptors = [NSSortDescriptor(keyPath: \JournalEntry.createdAt, ascending: true)]
        case .durationLongest:
            descriptors = [
                NSSortDescriptor(keyPath: \JournalEntry.audioRecording?.duration, ascending: false),
                NSSortDescriptor(keyPath: \JournalEntry.createdAt, ascending: false)
            ]
        case .durationShortest:
            descriptors = [
                NSSortDescriptor(keyPath: \JournalEntry.audioRecording?.duration, ascending: true),
                NSSortDescriptor(keyPath: \JournalEntry.createdAt, ascending: false)
            ]
        case .titleAZ:
            descriptors = [
                NSSortDescriptor(keyPath: \JournalEntry.title, ascending: true),
                NSSortDescriptor(keyPath: \JournalEntry.createdAt, ascending: false)
            ]
        case .titleZA:
            descriptors = [
                NSSortDescriptor(keyPath: \JournalEntry.title, ascending: false),
                NSSortDescriptor(keyPath: \JournalEntry.createdAt, ascending: false)
            ]
        }
        
        return descriptors
    }
    
    /// Process fetched entries to organize by date
    private func processEntries(_ entries: [JournalEntry]) {
        var newEntriesByDate: [Date: [JournalEntry]] = [:]
        var newSortedDates: [Date] = []
        
        // Use a single date key for all entries to avoid grouping by day
        let globalDateKey = Date.distantPast
        newSortedDates = [globalDateKey]
        
        // Sort all entries according to the selected sort order
        // Note: Entries should already be sorted by Core Data, but we sort again to ensure consistency
        var sortedEntries: [JournalEntry] = []
        
        // Apply the same sorting logic as in getSortDescriptors() for consistency
        switch sortOrder {
        case .newestFirst:
            sortedEntries = entries.sorted(by: { 
                ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast)
            })
        case .oldestFirst:
            sortedEntries = entries.sorted(by: { 
                ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast)
            })
        case .durationLongest:
            sortedEntries = entries.sorted(by: { 
                let duration1 = $0.audioRecording?.duration ?? 0
                let duration2 = $1.audioRecording?.duration ?? 0
                if duration1 == duration2 {
                    // Secondary sort by date if durations are equal
                    return ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast)
                }
                return duration1 > duration2
            })
        case .durationShortest:
            sortedEntries = entries.sorted(by: { 
                let duration1 = $0.audioRecording?.duration ?? 0
                let duration2 = $1.audioRecording?.duration ?? 0
                if duration1 == duration2 {
                    // Secondary sort by date if durations are equal
                    return ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast)
                }
                return duration1 < duration2
            })
        case .titleAZ:
            sortedEntries = entries.sorted(by: { 
                let title1 = $0.title ?? ""
                let title2 = $1.title ?? ""
                if title1 == title2 {
                    // Secondary sort by date if titles are equal
                    return ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast)
                }
                return title1 < title2
            })
        case .titleZA:
            sortedEntries = entries.sorted(by: { 
                let title1 = $0.title ?? ""
                let title2 = $1.title ?? ""
                if title1 == title2 {
                    // Secondary sort by date if titles are equal
                    return ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast)
                }
                return title1 > title2
            })
        }
        
        newEntriesByDate[globalDateKey] = sortedEntries
        
        DispatchQueue.main.async {
            self.entriesByDate = newEntriesByDate
            self.sortedDates = newSortedDates
            self.isLoading = false
        }
    }
}

// MARK: - Supporting Types

/// Date range options for the timeline
enum DateRange: String, CaseIterable, Identifiable {
    case today
    case yesterday
    case last7Days
    case last30Days
    case thisMonth
    case custom
    case allTime
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .last7Days: return "Last 7 Days"
        case .last30Days: return "Last 30 Days"
        case .thisMonth: return "This Month"
        case .custom: return "Custom Range"
        case .allTime: return "All Time"
        }
    }
}

/// Tag filter mode options
enum TagFilterMode {
    case all    // Entries must have ALL selected tags
    case any    // Entries must have ANY selected tag
    case exclude // Entries must NOT have selected tags
}

/// Sort order options for journal entries
enum SortOrder: String, CaseIterable, Identifiable {
    case newestFirst = "Newest First"
    case oldestFirst = "Oldest First"
    case durationLongest = "Longest Duration"
    case durationShortest = "Shortest Duration"
    case titleAZ = "Title A-Z"
    case titleZA = "Title Z-A"
    
    var id: String { self.rawValue }
}
