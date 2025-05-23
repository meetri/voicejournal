import SwiftUI
import UIKit

struct ThemeUtility {
    static func updateSystemAppearance(with theme: ThemeProtocol) {
        // Apply theme to navigation bar with transparency
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor(theme.surface)
        appearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
        appearance.titleTextAttributes = [.foregroundColor: UIColor(theme.text)]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(theme.text)]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Apply theme to tab bar with transparency
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        tabBarAppearance.backgroundColor = UIColor(theme.tabBarBackground)
        tabBarAppearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
        // Apply theme to table view
        UITableView.appearance().backgroundColor = UIColor(theme.background)
        UITableView.appearance().separatorColor = UIColor(theme.surface)
        
        // Apply theme to collection view (for calendar)
        UICollectionView.appearance().backgroundColor = UIColor(theme.background)
    }
}
