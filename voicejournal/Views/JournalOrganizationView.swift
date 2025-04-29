//
//  JournalOrganizationView.swift
//  voicejournal
//
//  Created on 4/29/25.
//

import SwiftUI
import CoreData

/// A view that provides different ways to organize and browse journal entries
struct JournalOrganizationView: View {
    // MARK: - Environment
    
    @Environment(\.managedObjectContext) private var viewContext
    
    // MARK: - State
    
    @State private var selectedTab: JournalViewTab = .list
    
    // MARK: - Body
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // List View
            NavigationView {
                EnhancedJournalEntriesView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .tabItem {
                Label("List", systemImage: "list.bullet")
            }
            .tag(JournalViewTab.list)
            
            // Calendar View
            NavigationView {
                CalendarView(context: viewContext)
                    .navigationTitle("Calendar")
            }
            .tabItem {
                Label("Calendar", systemImage: "calendar")
            }
            .tag(JournalViewTab.calendar)
            
            // Timeline View
            NavigationView {
                TimelineView(context: viewContext)
                    .navigationTitle("Timeline")
            }
            .tabItem {
                Label("Timeline", systemImage: "clock")
            }
            .tag(JournalViewTab.timeline)
        }
    }
}

// MARK: - Journal View Tab

/// Tabs for the different journal organization views
enum JournalViewTab {
    case list
    case calendar
    case timeline
}

// MARK: - Preview

#Preview {
    JournalOrganizationView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
