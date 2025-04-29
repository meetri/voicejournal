//
//  CalendarViewModel.swift
//  voicejournal
//
//  Created on 4/29/25.
//

import Foundation
import CoreData
import Combine
import SwiftUI

/// View model for the calendar view that manages date selection and entry data
class CalendarViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// The currently displayed date (determines the visible month/year/week)
    @Published var displayDate: Date = Date()
    
    /// The currently selected date
    @Published var selectedDate: Date = Date()
    
    /// The current zoom level of the calendar
    @Published var zoomLevel: CalendarZoomLevel = .month
    
    /// Dictionary mapping dates to journal entries
    @Published var entriesByDate: [Date: [JournalEntry]] = [:]
    
    /// Dictionary mapping dates to tag information for visual indicators
    @Published var tagsByDate: [Date: [TagInfo]] = [:]
    
    // MARK: - Private Properties
    
    private var viewContext: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()
    private let calendar = Calendar.current
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
        
        // Set up publishers to refresh data when display date or zoom level changes
        $displayDate
            .combineLatest($zoomLevel)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] (_, _) in
                self?.fetchEntriesForVisibleRange()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Move to the next time period (month/year/week) based on current zoom level
    func moveToNext() {
        switch zoomLevel {
        case .year:
            displayDate = calendar.date(byAdding: .year, value: 1, to: displayDate) ?? displayDate
        case .month:
            displayDate = calendar.date(byAdding: .month, value: 1, to: displayDate) ?? displayDate
        case .week:
            displayDate = calendar.date(byAdding: .weekOfYear, value: 1, to: displayDate) ?? displayDate
        }
    }
    
    /// Move to the previous time period (month/year/week) based on current zoom level
    func moveToPrevious() {
        switch zoomLevel {
        case .year:
            displayDate = calendar.date(byAdding: .year, value: -1, to: displayDate) ?? displayDate
        case .month:
            displayDate = calendar.date(byAdding: .month, value: -1, to: displayDate) ?? displayDate
        case .week:
            displayDate = calendar.date(byAdding: .weekOfYear, value: -1, to: displayDate) ?? displayDate
        }
    }
    
    /// Move to today's date
    func moveToToday() {
        displayDate = Date()
        selectedDate = Date()
    }
    
    /// Select a specific date
    func selectDate(_ date: Date) {
        selectedDate = date
    }
    
    /// Change the zoom level
    func setZoomLevel(_ level: CalendarZoomLevel) {
        zoomLevel = level
    }
    
    /// Get entries for a specific date
    func entries(for date: Date) -> [JournalEntry] {
        let normalizedDate = normalizeDate(date)
        return entriesByDate[normalizedDate] ?? []
    }
    
    /// Get tag information for a specific date
    func tagInfo(for date: Date) -> [TagInfo] {
        let normalizedDate = normalizeDate(date)
        return tagsByDate[normalizedDate] ?? []
    }
    
    /// Check if a date has any entries
    func hasEntries(on date: Date) -> Bool {
        let normalizedDate = normalizeDate(date)
        return (entriesByDate[normalizedDate]?.isEmpty == false)
    }
    
    /// Get the count of entries for a specific date
    func entryCount(for date: Date) -> Int {
        let normalizedDate = normalizeDate(date)
        return entriesByDate[normalizedDate]?.count ?? 0
    }
    
    /// Get the title for the current display period based on zoom level
    func displayTitle() -> String {
        let dateFormatter = DateFormatter()
        
        switch zoomLevel {
        case .year:
            dateFormatter.dateFormat = "yyyy"
        case .month:
            dateFormatter.dateFormat = "MMMM yyyy"
        case .week:
            // For week view, show the date range
            let weekStart = startOfWeek(for: displayDate)
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            
            let startFormatter = DateFormatter()
            let endFormatter = DateFormatter()
            
            // If same month
            if calendar.component(.month, from: weekStart) == calendar.component(.month, from: weekEnd) {
                startFormatter.dateFormat = "d"
                endFormatter.dateFormat = "d MMMM yyyy"
                return "\(startFormatter.string(from: weekStart)) - \(endFormatter.string(from: weekEnd))"
            } else {
                // Different months
                startFormatter.dateFormat = "d MMM"
                endFormatter.dateFormat = "d MMM yyyy"
                return "\(startFormatter.string(from: weekStart)) - \(endFormatter.string(from: weekEnd))"
            }
        }
        
        return dateFormatter.string(from: displayDate)
    }
    
    // MARK: - Date Helpers
    
    /// Get the days in the current month
    func daysInMonth() -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayDate) else { return [] }
        
        let startDate = monthInterval.start
        let endDate = monthInterval.end
        
        var dates: [Date] = []
        var currentDate = startDate
        
        // Find the first day of the week containing the start date
        let firstWeekday = calendar.firstWeekday
        let weekdayOfStartDate = calendar.component(.weekday, from: startDate)
        let daysToSubtract = (weekdayOfStartDate - firstWeekday + 7) % 7
        
        if daysToSubtract > 0 {
            currentDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: startDate) ?? startDate
        }
        
        // Add dates until we've gone past the end of the month
        // and completed the last week
        while currentDate < endDate || calendar.component(.weekday, from: currentDate) != firstWeekday {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return dates
    }
    
    /// Get the months in the current year
    func monthsInYear() -> [Date] {
        let year = calendar.component(.year, from: displayDate)
        var months: [Date] = []
        
        for month in 1...12 {
            var dateComponents = DateComponents()
            dateComponents.year = year
            dateComponents.month = month
            dateComponents.day = 1
            
            if let date = calendar.date(from: dateComponents) {
                months.append(date)
            }
        }
        
        return months
    }
    
    /// Get the days in the current week
    func daysInWeek() -> [Date] {
        let weekStart = startOfWeek(for: displayDate)
        var days: [Date] = []
        
        for day in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: day, to: weekStart) {
                days.append(date)
            }
        }
        
        return days
    }
    
    /// Get the start of the week for a given date
    func startOfWeek(for date: Date) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        let daysToSubtract = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -daysToSubtract, to: date) ?? date
    }
    
    /// Check if a date is in the current month
    func isInCurrentMonth(_ date: Date) -> Bool {
        calendar.isDate(date, equalTo: displayDate, toGranularity: .month)
    }
    
    /// Check if a date is today
    func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }
    
    /// Check if a date is the selected date
    func isSelected(_ date: Date) -> Bool {
        calendar.isDate(date, equalTo: selectedDate, toGranularity: .day)
    }
    
    // MARK: - Private Methods
    
    /// Normalize a date to the start of the day for consistent dictionary keys
    private func normalizeDate(_ date: Date) -> Date {
        return calendar.startOfDay(for: date)
    }
    
    /// Fetch entries for the visible date range based on zoom level
    private func fetchEntriesForVisibleRange() {
        var startDate: Date
        var endDate: Date
        
        switch zoomLevel {
        case .year:
            let year = calendar.component(.year, from: displayDate)
            var startComponents = DateComponents()
            startComponents.year = year
            startComponents.month = 1
            startComponents.day = 1
            
            var endComponents = DateComponents()
            endComponents.year = year + 1
            endComponents.month = 1
            endComponents.day = 1
            
            startDate = calendar.date(from: startComponents) ?? displayDate
            endDate = calendar.date(from: endComponents) ?? displayDate
            
        case .month:
            guard let monthInterval = calendar.dateInterval(of: .month, for: displayDate) else { return }
            startDate = monthInterval.start
            endDate = monthInterval.end
            
            // Extend to include days from previous/next month that appear in the calendar view
            let firstWeekday = calendar.firstWeekday
            let weekdayOfStartDate = calendar.component(.weekday, from: startDate)
            let daysToSubtract = (weekdayOfStartDate - firstWeekday + 7) % 7
            
            if daysToSubtract > 0 {
                startDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: startDate) ?? startDate
            }
            
            let weekdayOfEndDate = calendar.component(.weekday, from: endDate)
            let daysToAdd = (firstWeekday - weekdayOfEndDate + 7) % 7
            
            if daysToAdd > 0 {
                endDate = calendar.date(byAdding: .day, value: daysToAdd, to: endDate) ?? endDate
            }
            
        case .week:
            startDate = startOfWeek(for: displayDate)
            endDate = calendar.date(byAdding: .day, value: 7, to: startDate) ?? startDate
        }
        
        fetchEntries(from: startDate, to: endDate)
    }
    
    /// Fetch entries between two dates
    private func fetchEntries(from startDate: Date, to endDate: Date) {
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "createdAt >= %@ AND createdAt < %@",
            startDate as NSDate,
            endDate as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \JournalEntry.createdAt, ascending: true)]
        
        do {
            let fetchedEntries = try viewContext.fetch(request)
            processEntries(fetchedEntries)
        } catch {
            print("Error fetching calendar entries: \(error)")
        }
    }
    
    /// Process fetched entries to organize by date and extract tag information
    private func processEntries(_ entries: [JournalEntry]) {
        var newEntriesByDate: [Date: [JournalEntry]] = [:]
        var newTagsByDate: [Date: [TagInfo]] = [:]
        
        for entry in entries {
            guard let createdAt = entry.createdAt else { continue }
            
            let normalizedDate = normalizeDate(createdAt)
            
            // Add entry to the entries dictionary
            if newEntriesByDate[normalizedDate] == nil {
                newEntriesByDate[normalizedDate] = [entry]
            } else {
                newEntriesByDate[normalizedDate]?.append(entry)
            }
            
            // Process tags for visual indicators
            if let tags = entry.tags as? Set<Tag> {
                for tag in tags {
                    guard let name = tag.name, let color = tag.color else { continue }
                    
                    let tagInfo = TagInfo(name: name, color: color, iconName: tag.iconName)
                    
                    if newTagsByDate[normalizedDate] == nil {
                        newTagsByDate[normalizedDate] = [tagInfo]
                    } else if !newTagsByDate[normalizedDate]!.contains(where: { $0.name == name }) {
                        newTagsByDate[normalizedDate]?.append(tagInfo)
                    }
                }
            }
        }
        
        DispatchQueue.main.async {
            self.entriesByDate = newEntriesByDate
            self.tagsByDate = newTagsByDate
        }
    }
}

// MARK: - Supporting Types

/// Zoom levels for the calendar view
enum CalendarZoomLevel {
    case year
    case month
    case week
}

/// Structure to hold tag information for visual indicators
struct TagInfo: Identifiable {
    let id = UUID()
    let name: String
    let color: String
    let iconName: String?
}
