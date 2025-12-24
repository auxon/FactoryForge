import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = GameViewController()
        window?.makeKeyAndVisible()
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Pause game when app loses focus
        NotificationCenter.default.post(name: .gameShouldPause, object: nil)
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Resume game when app gains focus
        NotificationCenter.default.post(name: .gameShouldResume, object: nil)
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

