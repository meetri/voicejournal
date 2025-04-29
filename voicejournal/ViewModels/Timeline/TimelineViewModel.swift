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
        
        // Initial data fetch
        fetchEntriesForDateRange()
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
            print("Error deleting journal entry: \(error)")
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
        request.predicate = NSPredicate(
            format: "createdAt >= %@ AND createdAt < %@",
            startDate as NSDate,
            endDate as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \JournalEntry.createdAt, ascending: false)]
        
        do {
            let fetchedEntries = try viewContext.fetch(request)
            processEntries(fetchedEntries)
        } catch {
            print("Error fetching timeline entries: \(error)")
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }
    
    /// Process fetched entries to organize by date
    private func processEntries(_ entries: [JournalEntry]) {
        var newEntriesByDate: [Date: [JournalEntry]] = [:]
        var newSortedDates: [Date] = []
        
        for entry in entries {
            guard let createdAt = entry.createdAt else { continue }
            
            let normalizedDate = calendar.startOfDay(for: createdAt)
            
            // Add entry to the entries dictionary
            if newEntriesByDate[normalizedDate] == nil {
                newEntriesByDate[normalizedDate] = [entry]
                newSortedDates.append(normalizedDate)
            } else {
                newEntriesByDate[normalizedDate]?.append(entry)
            }
        }
        
        // Sort the dates in descending order (newest first)
        newSortedDates.sort(by: >)
        
        // Sort entries within each date by creation time (newest first)
        for (date, dateEntries) in newEntriesByDate {
            newEntriesByDate[date] = dateEntries.sorted(by: { 
                ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast)
            })
        }
        
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
