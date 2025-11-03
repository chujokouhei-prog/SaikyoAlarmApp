import SwiftUI

struct ContentView: View {
    // DatePickerで選択された時刻を保存するための変数
    @State private var selectedDate = Date()

    var body: some View {
        VStack(spacing: 40) {
            Text("アラームを設定")
                .font(.largeTitle)

            // 時刻を選択するためのピッカー
            DatePicker("時刻を選択", selection: $selectedDate, displayedComponents: .hourAndMinute)
                .labelsHidden() // "時刻を選択"のラベルを非表示にする
                .datePickerStyle(WheelDatePickerStyle()) // タイヤのような見た目にする

            // アラームを設定するボタン
            Button(action: {
                // ボタンが押されたらアラームをセットする関数を呼ぶ
                setAlarm()
            }) {
                Text("アラームをセット")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }

    // アラーム（ローカル通知）を設定する関数
    func setAlarm() {
        let content = UNMutableNotificationContent()
        content.title = "時間です！"
        content.body = "アラームが鳴りました"
        content.sound = UNNotificationSound.default

        // DatePickerで選択した時刻をコンポーネントに分解
        let dateComponents = Calendar.current.dateComponents([.hour, .minute], from: selectedDate)

        // 指定した時刻に毎日通知するトリガーを作成
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        // 通知リクエストを作成
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        // システムに通知リクエストを追加
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("通知のセットに失敗しました: \(error.localizedDescription)")
            } else {
                print("アラームをセットしました")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
