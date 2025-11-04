// ContentView.swift (Corrected Naming)

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        TabView {
            AlarmSettingView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "alarm.fill")
                    Text("設定")
                }
            
            // Use the new, correct name here.
            CustomCalendarView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "calendar")
                    Text("カレンダー")
                }
        }
    }
}
