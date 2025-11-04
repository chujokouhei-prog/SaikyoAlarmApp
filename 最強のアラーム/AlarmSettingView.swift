// AlarmSettingView.swift

import SwiftUI

struct AlarmSettingView: View {
    @ObservedObject var viewModel: AppViewModel

    @State private var selectedDate = Date()
    @State private var weekdaysOnly = true
    @State private var snoozeEnabled = true   // ← 追加：スヌーズON/OFF
    @State private var isShowingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            Form {
                // 新しいアラームの追加
                Section(header: Text("新しいアラームを追加")) {
                    DatePicker("時刻", selection: $selectedDate, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)

                    Toggle("平日のみ鳴らす（祝日を除く）", isOn: $weekdaysOnly)

                    Toggle("スヌーズあり（5分 × 3回）", isOn: $snoozeEnabled)

                    Button("この内容でアラームを追加") {
                        viewModel.addAlarm(
                            selectedDate: selectedDate,
                            weekdaysOnly: weekdaysOnly,
                            snoozeEnabled: snoozeEnabled
                        )
                        let formatter = DateFormatter(); formatter.dateFormat = "H:mm"
                        let mode = weekdaysOnly ? "平日（祝日を除く）" : "毎日"
                        let snoozeText = snoozeEnabled ? "スヌーズあり" : "スヌーズなし"
                        alertMessage = "\(mode) \(formatter.string(from: selectedDate))（\(snoozeText)）のアラームを追加しました。"
                        isShowingAlert = true
                    }
                }

                // 登録済みアラーム一覧
                Section(header: Text("登録済みのアラーム")) {
                    if viewModel.alarms.isEmpty {
                        Text("まだアラームが登録されていません。")
                            .foregroundColor(.secondary)
                    } else {
                        List {
                            ForEach(sortedAlarms) { alarm in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(alarm.timeString)
                                            .font(.title2)
                                        Text("\(alarm.modeDescription) ・ スヌーズ\(alarm.snoozeEnabled ? "ON" : "OFF")")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Toggle("", isOn: Binding(
                                        get: { alarm.isEnabled },
                                        set: { _ in
                                            viewModel.toggleAlarmEnabled(alarm)
                                        }
                                    ))
                                    .labelsHidden()
                                }
                            }
                            .onDelete { indexSet in
                                // 表示はソート済みなので、元の配列の位置に変換
                                let alarmsToDelete = indexSet.map { sortedAlarms[$0] }
                                let idsToDelete = Set(alarmsToDelete.map { $0.id })
                                let newList = viewModel.alarms.filter { !idsToDelete.contains($0.id) }
                                viewModel.alarms = newList
                            }
                        }
                        .frame(minHeight: 150, maxHeight: 260)
                    }
                }
            }
            .navigationTitle("アラームを設定")
        }
        .alert("追加完了", isPresented: $isShowingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    /// 時刻順にソートしたアラーム
    private var sortedAlarms: [AlarmRule] {
        viewModel.alarms.sorted { lhs, rhs in
            if lhs.hour == rhs.hour {
                return lhs.minute < rhs.minute
            } else {
                return lhs.hour < rhs.hour
            }
        }
    }
}

