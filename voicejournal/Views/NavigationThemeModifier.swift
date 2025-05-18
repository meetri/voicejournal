//
//  NavigationThemeModifier.swift
//  voicejournal
//
//  Created on 5/17/25.
//

import SwiftUI
import UIKit

/// A view modifier that applies theme styling to navigation views
struct NavigationThemeModifier: ViewModifier {
    @Environment(\.themeManager) var themeManager
    
    func body(content: Content) -> some View {
        content
            .background(
                NavigationBarConfigurator(theme: themeManager.theme)
            )
    }
}

/// UIViewControllerRepresentable to configure navigation bar appearance
struct NavigationBarConfigurator: UIViewControllerRepresentable {
    let theme: ThemeProtocol
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Create appearance configuration
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor(theme.surface)
        appearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
        appearance.titleTextAttributes = [.foregroundColor: UIColor(theme.text)]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(theme.text)]
        
        // Find the navigation controller and update its navigation bar
        if let navigationController = uiViewController.navigationController {
            navigationController.navigationBar.standardAppearance = appearance
            navigationController.navigationBar.compactAppearance = appearance
            navigationController.navigationBar.scrollEdgeAppearance = appearance
            navigationController.navigationBar.tintColor = UIColor(theme.accent)
        }
        
        // Also update the tab bar if we're in a tab controller
        if let tabBarController = uiViewController.tabBarController {
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithTransparentBackground()
            tabBarAppearance.backgroundColor = UIColor(theme.tabBarBackground)
            tabBarAppearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
            
            tabBarController.tabBar.standardAppearance = tabBarAppearance
            tabBarController.tabBar.scrollEdgeAppearance = tabBarAppearance
            tabBarController.tabBar.tintColor = UIColor(theme.accent)
        }
    }
}

/// Extension to easily apply the navigation theme modifier
extension View {
    func navigationThemeUpdater() -> some View {
        self.modifier(NavigationThemeModifier())
    }
}