// ContentView.swift

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var alarmViewModel: AlarmViewModel

    var body: some View {
        TabView {
            AlarmListView()
                .environmentObject(alarmViewModel)
                .tabItem {
                    Label("アラーム", systemImage: "alarm")
                }

            CustomCalendarView()
                .environmentObject(alarmViewModel)
                .tabItem {
                    Label("カレンダー", systemImage: "calendar")
                }
        }
    }
}

#Preview {
    let vm = AlarmViewModel()
    return ContentView()
        .environmentObject(vm)
}
