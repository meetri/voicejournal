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
                    .navigationTitle("Vox Cipher")
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
        .navigationThemeUpdater()
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
    @State private var showingLanguageSettings = false
    
    var body: some View {
        NavigationView {
            List {
                // MARK: - General Section
                Section {
                    // Language settings
                    NavigationLink {
                        LanguageSelectionView()
                    } label: {
                        SettingsRow(
                            icon: "globe",
                            iconColor: .blue,
                            title: "Language",
                            value: getCurrentLanguageName(),
                            showDisclosure: false
                        )
                    }
                } header: {
                    Text("General")
                        .textCase(nil)
                        .font(.headline)
                        .foregroundColor(themeManager.theme.text)
                        .padding(.bottom, 4)
                }
                
                // MARK: - Appearance Section
                Section {
                    NavigationLink {
                        ThemeSelectorView()
                            .environment(\.managedObjectContext, viewContext)
                            .environmentObject(themeManager)
                    } label: {
                        SettingsRow(
                            icon: "paintbrush.fill",
                            iconColor: .purple,
                            title: "Theme",
                            value: getCurrentThemeName(),
                            showDisclosure: false
                        )
                    }
                } header: {
                    Text("Appearance")
                        .textCase(nil)
                        .font(.headline)
                        .foregroundColor(themeManager.theme.text)
                        .padding(.bottom, 4)
                }
                
                // MARK: - Organization Section
                Section {
                    NavigationLink {
                        TagManagementView()
                            .environment(\.managedObjectContext, viewContext)
                    } label: {
                        SettingsRow(
                            icon: "tag.fill",
                            iconColor: .green,
                            title: "Tags",
                            value: nil,
                            showDisclosure: false
                        )
                    }
                } header: {
                    Text("Organization")
                        .textCase(nil)
                        .font(.headline)
                        .foregroundColor(themeManager.theme.text)
                        .padding(.bottom, 4)
                }
                
                // MARK: - Privacy & Security Section
                Section {
                    NavigationLink {
                        EncryptedTagManagementView()
                            .environment(\.managedObjectContext, viewContext)
                    } label: {
                        SettingsRow(
                            icon: "lock.shield.fill",
                            iconColor: .red,
                            title: "Encrypted Tags",
                            value: nil,
                            showDisclosure: false
                        )
                    }
                    
                    Button {
                        authService.lock()
                    } label: {
                        SettingsRow(
                            icon: "lock.fill",
                            iconColor: .orange,
                            title: "Lock App",
                            value: nil,
                            showDisclosure: false
                        )
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Privacy & Security")
                        .textCase(nil)
                        .font(.headline)
                        .foregroundColor(themeManager.theme.text)
                        .padding(.bottom, 4)
                }
                
                // MARK: - AI Configuration Section
                Section {
                    NavigationLink {
                        AIConfigurationView()
                            .environment(\.managedObjectContext, viewContext)
                    } label: {
                        SettingsRow(
                            icon: "brain",
                            iconColor: .purple,
                            title: "AI Configuration",
                            value: nil,
                            showDisclosure: false
                        )
                    }
                } header: {
                    Text("AI Settings")
                        .textCase(nil)
                        .font(.headline)
                        .foregroundColor(themeManager.theme.text)
                        .padding(.bottom, 4)
                }
                
                // MARK: - Data & Backup Section
                Section {
                    NavigationLink {
                        BackupSettingsView()
                            .environment(\.managedObjectContext, viewContext)
                    } label: {
                        SettingsRow(
                            icon: "icloud.fill",
                            iconColor: .blue,
                            title: "Backup Settings",
                            value: nil,
                            showDisclosure: false
                        )
                    }
                } header: {
                    Text("Data & Backup")
                        .textCase(nil)
                        .font(.headline)
                        .foregroundColor(themeManager.theme.text)
                        .padding(.bottom, 4)
                }
                
                // MARK: - Debug Section (Temporary)
                Section {
                    NavigationLink {
                        AudioFileDebugView()
                            .environment(\.managedObjectContext, viewContext)
                    } label: {
                        SettingsRow(
                            icon: "ant.circle.fill",
                            iconColor: .red,
                            title: "Audio File Debug",
                            value: nil,
                            showDisclosure: false
                        )
                    }
                    
                    NavigationLink {
                        PathTestView()
                    } label: {
                        SettingsRow(
                            icon: "folder.circle.fill",
                            iconColor: .orange,
                            title: "Path Test",
                            value: nil,
                            showDisclosure: false
                        )
                    }
                } header: {
                    Text("Debug")
                        .textCase(nil)
                        .font(.headline)
                        .foregroundColor(themeManager.theme.text)
                        .padding(.bottom, 4)
                }
                
                // MARK: - About Section
                Section {
                    HStack {
                        SettingsIcon(systemName: "info.circle.fill", color: .blue)
                        Text("Version")
                        Spacer()
                        Text(getAppVersion())
                            .foregroundColor(themeManager.theme.textSecondary)
                    }
                    
                    Link(destination: URL(string: "https://github.com/voicejournal/privacy")!) {
                        SettingsRow(
                            icon: "hand.raised.fill",
                            iconColor: .indigo,
                            title: "Privacy Policy",
                            value: nil,
                            showDisclosure: false
                        )
                    }
                    
                    Link(destination: URL(string: "https://github.com/voicejournal/terms")!) {
                        SettingsRow(
                            icon: "doc.text.fill",
                            iconColor: .cyan,
                            title: "Terms of Service",
                            value: nil,
                            showDisclosure: false
                        )
                    }
                } header: {
                    Text("About")
                        .textCase(nil)
                        .font(.headline)
                        .foregroundColor(themeManager.theme.text)
                        .padding(.bottom, 4)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .background(themeManager.theme.background)
            .scrollContentBackground(.hidden)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
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
                            .foregroundColor(themeManager.theme.accent)
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .navigationThemeUpdater()
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
    
    private func getCurrentLanguageName() -> String {
        let locale = LanguageSettings.shared.selectedLocale
        return LanguageSettings.shared.localizedName(for: locale)
    }
    
    private func getAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Settings Components

/// A reusable settings row component
struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String?
    var showDisclosure: Bool = true
    
    @Environment(\.themeManager) var themeManager
    
    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(systemName: icon, color: iconColor)
            
            Text(title)
                .foregroundColor(themeManager.theme.text)
            
            Spacer()
            
            if let value = value {
                Text(value)
                    .foregroundColor(themeManager.theme.textSecondary)
                    .font(.callout)
            }
            
            if showDisclosure {
                Image(systemName: "chevron.right")
                    .foregroundColor(themeManager.theme.textSecondary)
                    .font(.caption)
            }
        }
        .padding(.vertical, 6)
    }
}

/// A settings icon component
struct SettingsIcon: View {
    let systemName: String
    let color: Color
    
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 20))
            .foregroundColor(.white)
            .frame(width: 30, height: 30)
            .background(color)
            .cornerRadius(8)
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AuthenticationService())
}