// CustomCalendarView.swift

import SwiftUI

struct CustomCalendarView: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        NavigationView {
            VStack {
                // カレンダー上でアラーム予定の日付をハイライト
                MultiDatePicker(
                    "今後のアラーム予定",
                    selection: Binding(
                        get: { viewModel.alarmDates },
                        set: { _ in }
                    )
                )
                .padding()
                
                if viewModel.alarmDates.isEmpty {
                    Text("現在セットされているアラームはありません。")
                        .foregroundColor(.secondary)
                        .padding(.top)
                } else {
                    List {
                        ForEach(sortedAlarmDates, id: \.self) { comps in
                            if let date = Calendar.current.date(from: comps) {
                                HStack {
                                    Text(formattedDate(date))
                                    Spacer()
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                }
            }
            .navigationTitle("アラーム予定")
        }
    }
    
    /// alarmDates を日付順にソート
    private var sortedAlarmDates: [DateComponents] {
        let calendar = Calendar.current
        return viewModel.alarmDates.sorted { lhs, rhs in
            guard let d1 = calendar.date(from: lhs),
                  let d2 = calendar.date(from: rhs) else { return false }
            return d1 < d2
        }
    }
    
    /// 例: 3/5 (水) のような表示
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d (EEE)"
        return formatter.string(from: date)
    }
}

