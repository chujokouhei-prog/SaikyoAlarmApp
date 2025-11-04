// ContentView.swift

import SwiftUI

struct ContentView: View {
    var body: some View {
        // 画面下部にタブバーを表示する
        TabView {
            // 1つ目のタブ：アラーム設定画面
            AlarmSettingView()
                .tabItem {
                    Image(systemName: "alarm.fill")
                    Text("設定")
                }
            
            // 2つ目のタブ：カレンダー画面
            CalendarView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("カレンダー")
                }
        }
    }
}

// これまでのアラーム設定画面のコードをここに移動
struct AlarmSettingView: View {
    @State private var selectedDate = Date()
    @State private var weekdaysOnly = true
    @State private var isShowingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    DatePicker("時刻を選択", selection: $selectedDate, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                } header: {
                    Text("時刻")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }

                Section {
                    Toggle(isOn: $weekdaysOnly) {
                        Text("平日のみ鳴らす")
                    }
                } header: {
                    Text("繰り返し")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("アラームを設定")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("セット") {
                        setAlarm()
                    }
                    .font(.headline)
                }
            }
        }
        .alert(isPresented: $isShowingAlert) {
            Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    // --- 以下、アラームを設定するための関数群（変更なし） ---

    func setAlarm() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("既存のアラームを全て削除しました。")

        if weekdaysOnly {
            setWeekdaysAlarm()
        } else {
            setEverydayAlarm()
        }
    }
    
    func setEverydayAlarm() {
        let content = UNMutableNotificationContent()
        content.title = "時間です！"
        content.body = "アラームが鳴りました"
        content.sound = UNNotificationSound.default

        let dateComponents = Calendar.current.dateComponents([.hour, .minute], from: selectedDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "everyday_alarm", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            handleAlarmSetResult(error: error, message: "毎日")
        }
    }
    
    func setWeekdaysAlarm() {
        let calendar = Calendar.current
        var notificationCount = 0
        
        for i in 0..<60 {
            guard let targetDate = calendar.date(byAdding: .day, value: i, to: Date()) else { continue }
            
            let weekday = calendar.component(.weekday, from: targetDate)
            let isWeekday = (weekday >= 2 && weekday <= 6)
            let isHoliday = HolidayManager.shared.isHoliday(targetDate)
            
            if isWeekday && !isHoliday {
                let content = UNMutableNotificationContent()
                content.title = "時間です！"
                content.body = "アラームが鳴りました"
                content.sound = UNNotificationSound.default
                
                var dateComponents = calendar.dateComponents([.year, .month, .day], from: targetDate)
                dateComponents.hour = calendar.component(.hour, from: selectedDate)
                dateComponents.minute = calendar.component(.minute, from: selectedDate)
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                
                UNUserNotificationCenter.current().add(request)
                notificationCount += 1
            }
        }
        
        print("\(notificationCount)件の平日アラームをセットしました。")
        handleAlarmSetResult(error: nil, message: "平日（祝日を除く）")
    }
    
    func handleAlarmSetResult(error: Error?, message: String) {
        DispatchQueue.main.async {
            if let error = error {
                self.alertTitle = "エラー"
                self.alertMessage = "アラームのセットに失敗しました: \(error.localizedDescription)"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "H:mm"
                self.alertTitle = "セット完了"
                self.alertMessage = "\(message) \(formatter.string(from: selectedDate)) にアラームが鳴ります。"
            }
            self.isShowingAlert = true
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
