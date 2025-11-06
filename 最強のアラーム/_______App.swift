// ______App.swift

import SwiftUI

@main
struct SaikyoAlarmApp: App {
    @StateObject private var alarmViewModel = AlarmViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(alarmViewModel)
        }
    }
}
