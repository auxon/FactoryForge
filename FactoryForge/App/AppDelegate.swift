import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Scene-based apps handle window creation in SceneDelegate
        return true
    }

    // MARK: UISceneSession Lifecycle
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        let sceneConfig = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        sceneConfig.delegateClass = SceneDelegate.self
        return sceneConfig
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Auto-save before termination
        NotificationCenter.default.post(name: .gameShouldSave, object: nil)
    }
}

extension Notification.Name {
    static let gameShouldPause = Notification.Name("gameShouldPause")
    static let gameShouldResume = Notification.Name("gameShouldResume")
    static let gameShouldSave = Notification.Name("gameShouldSave")
}

