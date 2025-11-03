// 最強のアラームApp.swift

import SwiftUI
import EventKit

@main
struct 最強のアラームApp: App {

    // カレンダーへのアクセスを管理するオブジェクト
    let eventStore = EKEventStore()

    init() {
        // --- 通知の許可リクエスト ---
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { (granted, error) in
            if granted {
                print("通知が許可されました")
            } else {
                print("通知が拒否されました")
            }
        }

        // --- カレンダーへのアクセス許可リクエスト ---
        eventStore.requestFullAccessToEvents { (granted, error) in
            if granted {
                print("カレンダーへのアクセスが許可されました")
                // 許可されたら、バックグラウンドで祝日リストを読み込む
                DispatchQueue.global(qos: .background).async {
                    HolidayManager.shared.loadHolidays()
                }
            } else {
                print("カレンダーへのアクセスが拒否されました")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
