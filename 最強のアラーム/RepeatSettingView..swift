// RepeatSettingView..swift

import SwiftUI

struct RepeatSettingView: View {
    @Binding var repeatWeekdays: Set<Int>   // 1=日...7=土
    @Binding var excludeJapaneseHolidays: Bool

    private let weekdaySymbols = [
        (1, "日"), (2, "月"), (3, "火"),
        (4, "水"), (5, "木"), (6, "金"), (7, "土")
    ]

    var body: some View {
        List {
            Section {
                Toggle("日本の祝日は鳴らさない", isOn: $excludeJapaneseHolidays)
            }

            Section(header: Text("曜日")) {
                ForEach(weekdaySymbols, id: \.0) { (num, label) in
                    Button {
                        toggleDay(num)
                    } label: {
                        HStack {
                            Text(label)
                            Spacer()
                            if repeatWeekdays.contains(num) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }

            Section {
                Button("毎日") {
                    repeatWeekdays = Set(1...7)
                }
                Button("平日") {
                    repeatWeekdays = [2,3,4,5,6]
                }
                Button("週末") {
                    repeatWeekdays = [1,7]
                }
                Button("なし") {
                    repeatWeekdays = []
                }
            }
        }
        .navigationTitle("繰り返し")
    }

    private func toggleDay(_ day: Int) {
        if repeatWeekdays.contains(day) {
            repeatWeekdays.remove(day)
        } else {
            repeatWeekdays.insert(day)
        }
    }
}

#Preview {
    @State var set: Set<Int> = [2,3,4,5,6]
    @State var exclude = true
    return NavigationStack {
        RepeatSettingView(repeatWeekdays: $set, excludeJapaneseHolidays: $exclude)
    }
}
