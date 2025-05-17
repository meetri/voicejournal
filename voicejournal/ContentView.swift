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
            ThemeUtility.updateSystemAppearance(with: themeManager.theme)
        }
        .onChange(of: themeManager.currentThemeID) { _, newValue in
            ThemeUtility.updateSystemAppearance(with: themeManager.theme)
        }
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
                    NavigationLink {
                        ThemeSelectorView()
                            .environment(\.managedObjectContext, viewContext)
                            .environmentObject(themeManager)
                    } label: {
                        HStack {
                            Label("Themes", systemImage: "paintbrush")
                            Spacer()
                            Text(getCurrentThemeName())
                                .foregroundColor(.secondary)
                        }
                    }
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
            .themedNavigation()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            EncryptedTagsAccessManager.shared.clearAllAccess()
                            authService.lock()
                        }
                    } label: {
                        Image(systemName: "lock.fill")
                    }
                }
            }
        }
    }
    
    private func getCurrentThemeName() -> String {
        if let builtInTheme = ThemeID(rawValue: themeManager.currentThemeID) {
            return builtInTheme.displayName
        }
        
        // For custom themes, we'd need to fetch from Core Data
        // This is a simplified version - you might want to cache the custom theme name
        let request = CustomTheme.fetchRequest()
        if let uuid = UUID(uuidString: themeManager.currentThemeID) {
            request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        }
        request.fetchLimit = 1
        
        do {
            let themes = try viewContext.fetch(request)
            if let customTheme = themes.first {
                return customTheme.name ?? "Custom"
            }
        } catch {
            print("Error fetching theme name: \(error)")
        }
        
        return "Custom"
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AuthenticationService())
}