import SwiftUI

@main
struct SaikyoAlarmAppApp: App {
    // この init() { ... } の部分を追記します
    init() {
        // 通知の許可をリクエスト
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { (granted, error) in
            if granted {
                print("通知が許可されました")
            } else {
                print("通知が拒否されました")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
