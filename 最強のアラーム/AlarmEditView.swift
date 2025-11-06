// AlarmEditView.swift

import SwiftUI

struct AlarmEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var alarmViewModel: AlarmViewModel

    @State private var editingAlarm: AlarmItem
    let isNew: Bool

    init(alarm: AlarmItem, isNew: Bool) {
        _editingAlarm = State(initialValue: alarm)
        self.isNew = isNew
    }

    var body: some View {
        NavigationStack {
            Form {
                // 時刻
                Section {
                    DatePicker(
                        "時刻",
                        selection: Binding(
                            get: { editingAlarm.timeAsDate },
                            set: { date in
                                editingAlarm.updateTime(from: date)
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                }

                // 繰り返し
                Section {
                    NavigationLink {
                        RepeatSettingView(
                            repeatWeekdays: $editingAlarm.repeatWeekdays,
                            excludeJapaneseHolidays: $editingAlarm.excludeJapaneseHolidays
                        )
                    } label: {
                        HStack {
                            Text("繰り返し")
                            Spacer()
                            Text(editingAlarm.repeatDescription + (editingAlarm.excludeJapaneseHolidays ? "・祝日オフ" : ""))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // サウンド
                Section {
                    Picker("サウンド", selection: $editingAlarm.soundName) {
                        ForEach(alarmViewModel.availableSounds, id: \.self) { sound in
                            Text(sound).tag(sound)
                        }
                    }
                }

                // スヌーズ
                Section {
                    Toggle("スヌーズ", isOn: $editingAlarm.snoozeEnabled)
                }
            }
            .navigationTitle(isNew ? "新規アラーム" : "アラームを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                }
            }
        }
    }

    private func save() {
        if isNew {
            alarmViewModel.add(alarm: editingAlarm)
        } else {
            alarmViewModel.update(alarm: editingAlarm)
        }
        dismiss()
    }
}

#Preview {
    let vm = AlarmViewModel()
    let alarm = AlarmItem(hour: 7, minute: 0)
    return AlarmEditView(alarm: alarm, isNew: true)
        .environmentObject(vm)
}
