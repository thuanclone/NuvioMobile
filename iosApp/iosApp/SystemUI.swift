import Combine
import UIKit

@MainActor
final class SystemUI: ObservableObject {
    static let shared = SystemUI()

    private init() {}

    private(set) weak var activePlayer: UIViewController?
    @Published private(set) var isPlayerImmersive = false

    /// Tab bars we hid while the player was immersive so we can restore them.
    private var hiddenTabBars: [ObjectIdentifier: UITabBar] = [:]

    func playerDidBecomeVisible(_ player: UIViewController) {
        guard activePlayer !== player else { return }
        activePlayer = player
        isPlayerImmersive = true
        refresh()
    }

    func playerDidBecomeHidden(_ player: UIViewController) {
        guard activePlayer === player || activePlayer == nil else { return }
        activePlayer = nil
        isPlayerImmersive = false
        refresh()
    }

    private func refresh() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                guard let root = window.rootViewController else { continue }
                markNeedsUpdate(root)
                updateTabBars(in: root)
            }
        }

        if !isPlayerImmersive {
            // Restore any tab bars we hid while immersive, even if the
            // controller tree no longer reports them as children.
            for (_, tabBar) in hiddenTabBars {
                tabBar.isHidden = false
                tabBar.alpha = 1
            }
            hiddenTabBars.removeAll()
        }
    }

    private func markNeedsUpdate(_ controller: UIViewController) {
        controller.setNeedsUpdateOfHomeIndicatorAutoHidden()
        controller.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
        controller.setNeedsStatusBarAppearanceUpdate()

        for child in controller.children {
            markNeedsUpdate(child)
        }
        if let presented = controller.presentedViewController {
            markNeedsUpdate(presented)
        }
    }

    /// Force-hide the system tab bar while the in-app player is fullscreen.
    /// SwiftUI `.toolbar(.hidden, for: .tabBar)` is unreliable on iOS 26
    /// (especially with the new `Tab` API / liquid-glass minimize behavior),
    /// so we also drive visibility at the UIKit layer.
    private func updateTabBars(in controller: UIViewController) {
        if let tabBarController = controller as? UITabBarController {
            let tabBar = tabBarController.tabBar
            let id = ObjectIdentifier(tabBar)
            if isPlayerImmersive {
                if !tabBar.isHidden {
                    hiddenTabBars[id] = tabBar
                }
                tabBar.isHidden = true
                tabBar.alpha = 0
            } else if hiddenTabBars[id] != nil || tabBar.isHidden {
                tabBar.isHidden = false
                tabBar.alpha = 1
                hiddenTabBars.removeValue(forKey: id)
            }
        }

        for child in controller.children {
            updateTabBars(in: child)
        }
        if let presented = controller.presentedViewController {
            updateTabBars(in: presented)
        }
    }
}
