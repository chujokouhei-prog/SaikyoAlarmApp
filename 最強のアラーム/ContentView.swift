// ContentView.swift

import SwiftUI

struct ContentView: View {
    // DatePickerで選択された時刻を保存するための変数
    @State private var selectedDate = Date()
    
    // 「平日のみ」スイッチの状態を保存するための変数
    @State private var weekdaysOnly = true
    
    // アラームがセットされたことを知らせるための変数
    @State private var isShowingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    var body: some View {
        // --- ここから下が変更された部分 ---
        
        NavigationView {
            Form {
                // --- 1つ目のセクション：時刻設定 ---
                Section {
                    DatePicker("時刻を選択", selection: $selectedDate, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden() // "時刻を選択"のラベルは表示しない
                } header: {
                    Text("時刻")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }

                // --- 2つ目のセクション：繰り返し設定 ---
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
            .navigationTitle("アラームを設定") // 画面上部のタイトル
            .toolbar {
                // ナビゲーションバーに「セット」ボタンを配置
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("セット") {
                        setAlarm()
                    }
                    .font(.headline)
                }
            }
        }
        // --- ここまでが変更された部分 ---
        
        // アラートを表示するための設定
        .alert(isPresented: $isShowingAlert) {
            Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    // アラーム（ローカル通知）を設定する関数
    func setAlarm() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("既存のアラームを全て削除しました。")

        if weekdaysOnly {
            setWeekdaysAlarm()
        } else {
            setEverydayAlarm()
        }
    }
    
    // 毎日鳴るアラームをセットする関数
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
    
    // 平日のみ鳴るアラームをセットする関数
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
    
    // アラームセット後のアラート表示処理
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
