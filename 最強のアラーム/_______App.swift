// 最強のアラームApp.swift

import SwiftUI
import UserNotifications  // ← 追加

@main
struct 最強のアラームApp: App {
    
    init() {
        // 起動時に通知許可をリクエスト
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

