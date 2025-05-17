//
//  ContentView.swift
//  voicejournal
//
//  Created by meetri on 4/27/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authService: AuthenticationService
    @Environment(\.themeManager) var themeManager
    
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Timeline tab
            NavigationView {
                TimelineView(context: viewContext)
                    .navigationTitle("Voice Journal")
                    .themedNavigation()
            }
            .tabItem {
                Label("Timeline", systemImage: "clock")
            }
            .tag(0)
            
            // Calendar tab
            NavigationView {
                CalendarView(context: viewContext)
                    .navigationTitle("Calendar")
                    .themedNavigation()
            }
            .tabItem {
                Label("Calendar", systemImage: "calendar")
            }
            .tag(1)
            
            // Settings tab
            SettingsTabView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
        .accentColor(themeManager.theme.accent)
        .themed()
        .onAppear {
            updateSystemAppearance()
        }
    }
    
    private func updateSystemAppearance() {
        // Apply theme to navigation bar
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(themeManager.theme.surface)
        appearance.titleTextAttributes = [.foregroundColor: UIColor(themeManager.theme.text)]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(themeManager.theme.text)]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Apply theme to tab bar
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(themeManager.theme.surface)
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
        // Apply to table views
        UITableView.appearance().backgroundColor = UIColor(themeManager.theme.background)
        UITableView.appearance().separatorColor = UIColor(themeManager.theme.surface)
    }
}

/// View for displaying journal entries
struct JournalEntriesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \JournalEntry.createdAt, ascending: false)],
        animation: .default)
    private var entries: FetchedResults<JournalEntry>
    
    var body: some View {
        NavigationView {
            List {
                ForEach(entries) { entry in
                    NavigationLink {
                        JournalEntryView(journalEntry: entry)
                    } label: {
                        JournalEntryRow(entry: entry)
                    }
                }
                .onDelete(perform: deleteEntries)
            }
            .navigationTitle("Journal Entries")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            
            // Placeholder for when no entry is selected
            Text("Select an entry")
                .font(.title2)
                .foregroundColor(.secondary)
        }
    }
    
    private func deleteEntries(offsets: IndexSet) {
        withAnimation {
            offsets.map { entries[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Error deleting entries: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}


/// Detail view for a journal entry
struct JournalEntryDetailView: View {
    let entry: JournalEntry
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Title
                Text(entry.title ?? "Untitled Entry")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Date
                if let createdAt = entry.createdAt {
                    Text("Created: \(createdAt, formatter: itemFormatter)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Audio recording
                if let recording = entry.audioRecording {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Audio Recording")
                            .font(.headline)
                        
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading) {
                                Text("Duration: \(formatDuration(recording.duration))")
                                Text("Size: \(formatFileSize(recording.fileSize))")
                            }
                            .font(.subheadline)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    .padding(.vertical)
                }
                
                // Transcription
                if let transcription = entry.transcription, let text = transcription.text {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transcription")
                            .font(.headline)
                        
                        Text(text)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    .padding(.vertical)
                } else {
                    Text("No transcription available")
                        .italic()
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    /// Format duration in seconds to MM:SS
    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// Format file size in bytes to human-readable string
    private func formatFileSize(_ size: Int64) -> String {
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = [.useKB, .useMB]
        byteCountFormatter.countStyle = .file
        
        return byteCountFormatter.string(fromByteCount: size)
    }
}

/// Settings tab view
struct SettingsTabView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.themeManager) var themeManager
    
    @State private var showTagManagement = false
    @State private var showEncryptedTagManagement = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: Binding(
                        get: { themeManager.themeID },
                        set: { 
                            themeManager.setTheme($0)
                            // Update UI appearance when theme changes
                            updateSystemAppearance()
                        }
                    )) {
                        ForEach(ThemeID.allCases, id: \.self) { id in
                            Text(id.displayName).tag(id)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Organization")) {
                    NavigationLink {
                        TagManagementView()
                            .environment(\.managedObjectContext, viewContext)
                    } label: {
                        Label("Manage Tags", systemImage: "tag")
                    }
                }
                
                Section(header: Text("Security")) {
                    Button {
                        authService.lock()
                    } label: {
                        Label("Lock App", systemImage: "lock")
                    }
                    
                    NavigationLink {
                        EncryptedTagManagementView()
                            .environment(\.managedObjectContext, viewContext)
                    } label: {
                        Label("Encrypted Tags", systemImage: "lock.shield")
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .themedList()
            .themedNavigation()
        }
    }
    
    private func updateSystemAppearance() {
        // Apply theme to navigation bar
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(themeManager.theme.surface)
        appearance.titleTextAttributes = [.foregroundColor: UIColor(themeManager.theme.text)]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(themeManager.theme.text)]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Apply theme to tab bar
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(themeManager.theme.surface)
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
        // Update table view appearance
        UITableView.appearance().backgroundColor = UIColor(themeManager.theme.background)
        UITableView.appearance().separatorColor = UIColor(themeManager.theme.surface)
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AuthenticationService())
}
