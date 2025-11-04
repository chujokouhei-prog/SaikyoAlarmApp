// 最強のアラームApp.swift

import SwiftUI

@main
struct 最強のアラームApp: App {
    
    init() {
        // HolidayManagerの初期化（祝日の読み込みなどを開始させる）
        let _ = HolidayManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
