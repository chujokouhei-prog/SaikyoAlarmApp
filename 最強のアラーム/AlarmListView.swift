// AlarmListView.swift

import SwiftUI

struct AlarmListView: View {
    @EnvironmentObject var alarmViewModel: AlarmViewModel
    @State private var showingAddSheet = false
    @State private var editingAlarm: AlarmItem?

    var body: some View {
        NavigationStack {
            List {
                if alarmViewModel.alarms.isEmpty {
                    Text("アラームがありません")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(alarmViewModel.alarms) { alarm in
                        AlarmRowView(
                            alarm: alarm,
                            onToggle: { isOn in
                                alarmViewModel.toggleEnabled(id: alarm.id, isOn: isOn)
                            },
                            onTap: {
                                editingAlarm = alarm
                            }
                        )
                    }
                    .onDelete(perform: alarmViewModel.delete)
                }
            }
            .navigationTitle("アラーム")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
        }
        // 新規追加
        .sheet(isPresented: $showingAddSheet) {
            let newAlarm = alarmViewModel.createNewAlarmTemplate()
            AlarmEditView(alarm: newAlarm, isNew: true)
                .environmentObject(alarmViewModel)
        }
        // 編集
        .sheet(item: $editingAlarm) { alarm in
            AlarmEditView(alarm: alarm, isNew: false)
                .environmentObject(alarmViewModel)
        }
    }
}

// 1行分の表示
private struct AlarmRowView: View {
    let alarm: AlarmItem
    let onToggle: (Bool) -> Void
    let onTap: () -> Void

    @State private var isOn: Bool

    init(alarm: AlarmItem,
         onToggle: @escaping (Bool) -> Void,
         onTap: @escaping () -> Void) {
        self.alarm = alarm
        self.onToggle = onToggle
        self.onTap = onTap
        _isOn = State(initialValue: alarm.isEnabled)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(alarm.timeString)
                    .font(.system(size: 36, weight: .light, design: .default))
                Text(alarm.detailText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .onTapGesture {
                onTap()
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.green)
                .onChange(of: isOn) { newValue in
                    onToggle(newValue)
                }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let vm = AlarmViewModel()
    vm.alarms = [
        AlarmItem(hour: 7, minute: 0),
        AlarmItem(hour: 8, minute: 30, repeatWeekdays: [], excludeJapaneseHolidays: false)
    ]
    return NavigationStack {
        AlarmListView()
            .environmentObject(vm)
    }
}
