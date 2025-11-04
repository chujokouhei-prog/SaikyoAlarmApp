// ContentView.swift

import SwiftUI

struct ContentView: View {
    // アプリ全体で共有するビューModel
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        TabView {
            // ① アラーム設定タブ
            AlarmSettingView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "alarm")
                    Text("設定")
                }

            // ② カレンダータブ（★ここで新しい CalendarView を使う）
            CalendarView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "calendar")
                    Text("カレンダー")
                }
        }
    }
}

#Preview {
    ContentView()
}
