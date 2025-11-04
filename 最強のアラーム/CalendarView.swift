// CalendarView.swift

import SwiftUI

/// カレンダー画面
/// - 土曜日は青
/// - 日曜日＆祝日は赤
/// - カレンダー上に、その日の最も早いアラーム＋件数を表示
/// - 日付タップで、その日のアラーム一覧＋「この日のアラームを全てオフ」ボタン
struct CalendarView: View {
    @ObservedObject var viewModel: AppViewModel

    @State private var displayedMonth: Date = Date()
    @State private var isShowingDaySheet: Bool = false
    @State private var selectedDate: Date? = nil

    private let calendar = Calendar(identifier: .gregorian)

    // 月表示タイトル用
    private static let monthTitleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年 M月"
        return f
    }()

    // 表示している月のタイトル
    private var monthTitle: String {
        Self.monthTitleFormatter.string(from: displayedMonth)
    }

    // カレンダーに表示する日付（前後の空白含む）
    private var daysForCalendar: [Date?] {
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)),
              let range = calendar.range(of: .day, in: .month, for: startOfMonth)
        else {
            return []
        }

        let numberOfDays = range.count
        let firstWeekday = calendar.component(.weekday, from: startOfMonth) // 1=日曜〜7=土曜

        var result: [Date?] = []

        // 月初め前の空白
        for _ in 0..<(firstWeekday - 1) {
            result.append(nil)
        }

        // 当月の日付
        for dayOffset in 0..<numberOfDays {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfMonth) {
                result.append(date)
            }
        }

        // 7の倍数になるように後ろを空白で埋める
        while result.count % 7 != 0 {
            result.append(nil)
        }

        return result
    }

    var body: some View {
        VStack(spacing: 8) {
            monthHeader

            weekdayHeader

            calendarGrid
        }
        .padding(.horizontal)   // 横だけ余白、縦は詰める
        .padding(.top, 8)
        .sheet(isPresented: $isShowingDaySheet) {
            if let date = selectedDate {
                DayAlarmDetailSheet(viewModel: viewModel, date: date)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Header (月切り替え)

    private var monthHeader: some View {
        HStack {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(monthTitle)
                .font(.headline)

            Spacer()

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.bottom, 4)
    }

    private func moveMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }

    // MARK: - 曜日ヘッダー

    private var weekdayHeader: some View {
        let symbols = ["日", "月", "火", "水", "木", "金", "土"]

        return HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                Text(symbols[index])
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .foregroundColor(weekdayColor(for: index + 1))
            }
        }
    }

    private func weekdayColor(for weekday: Int) -> Color {
        // 1=日曜, 7=土曜
        if weekday == 1 {
            return .red
        } else if weekday == 7 {
            return .blue
        } else {
            return .secondary
        }
    }

    // MARK: - カレンダー本体

    private var calendarGrid: some View {
        let days = daysForCalendar
        let numberOfWeeks = days.count / 7

        return VStack(spacing: 2) {   // ← 行と行の間の余白を小さく
            ForEach(0..<numberOfWeeks, id: \.self) { weekIndex in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { weekdayIndex in
                        let index = weekIndex * 7 + weekdayIndex
                        let date = days[index]

                        if let date = date {
                            let isCurrentMonth = calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
                            let isHoliday = viewModel.isHoliday(date: date) || calendar.component(.weekday, from: date) == 1
                            let isSaturday = calendar.component(.weekday, from: date) == 7
                            let summary = daySummary(for: date)

                            CalendarDayCell(
                                date: date,
                                isCurrentMonth: isCurrentMonth,
                                isHoliday: isHoliday,
                                isSaturday: isSaturday,
                                summary: summary
                            ) {
                                selectedDate = date
                                isShowingDaySheet = true
                            }
                        } else {
                            // 空白マス
                            Rectangle()
                                .foregroundColor(.clear)
                                .frame(maxWidth: .infinity, minHeight: 40)  // ← 高さを少し低めに
                        }
                    }
                }
            }
        }
    }

    // その日のアラーム概要（最も早い時間＋件数）
    private func daySummary(for date: Date) -> DaySummary? {
        let alarms = viewModel.alarmsForCalendar(on: date)
            .filter { $0.isEnabled }

        guard !alarms.isEmpty else { return nil }

        // 時刻順にソート
        let sorted = alarms.sorted {
            if $0.hour == $1.hour {
                return $0.minute < $1.minute
            } else {
                return $0.hour < $1.hour
            }
        }

        let first = sorted[0]
        let timeText = String(format: "%02d:%02d", first.hour, first.minute)

        return DaySummary(earliestTimeText: timeText, alarmCount: alarms.count)
    }
}

// MARK: - DaySummary

struct DaySummary {
    let earliestTimeText: String
    let alarmCount: Int
}

// MARK: - 1日分のセル表示

struct CalendarDayCell: View {
    let date: Date
    let isCurrentMonth: Bool
    let isHoliday: Bool
    let isSaturday: Bool
    let summary: DaySummary?
    let onTap: () -> Void

    private let calendar = Calendar(identifier: .gregorian)

    var body: some View {
        let day = calendar.component(.day, from: date)

        Button(action: onTap) {
            VStack(spacing: 2) {        // ← 文字と文字の間も少し詰める
                Text("\(day)")
                    .font(.body)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundColor(textColor)

                if let summary = summary {
                    if summary.alarmCount > 1 {
                        Text("\(summary.earliestTimeText) 他\(summary.alarmCount - 1)件")
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    } else {
                        Text(summary.earliestTimeText)
                            .font(.caption2)
                    }
                } else {
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, minHeight: 40)  // ← 高さ40・余白なしでコンパクトに
            .padding(.vertical, 1)                      // ← ほんの少しだけ縦の余白
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isToday ? Color.gray.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isCurrentMonth)
        .opacity(isCurrentMonth ? 1.0 : 0.35)
    }

    private var isToday: Bool {
        calendar.isDateInToday(date)
    }

    private var textColor: Color {
        if isHoliday {
            return .red
        }
        if isSaturday {
            return .blue
        }
        return .primary
    }
}

// MARK: - 日付タップ時のシート

struct DayAlarmDetailSheet: View {
    @ObservedObject var viewModel: AppViewModel
    let date: Date

    private let calendar = Calendar(identifier: .gregorian)

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日（E）"
        return f
    }()

    private var titleText: String {
        Self.dateFormatter.string(from: date)
    }

    var body: some View {
        NavigationStack {
            VStack {
                List {
                    Section {
                        ForEach(viewModel.alarmsForCalendar(on: date)) { alarm in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(String(format: "%02d:%02d", alarm.hour, alarm.minute))
                                        .font(.headline)
                                    if alarm.weekdaysOnly {
                                        Text("平日のみ")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                Toggle(isOn: Binding(
                                    get: { alarm.isEnabled },
                                    set: { newValue in
                                        viewModel.setAlarmEnabled(id: alarm.id, enabled: newValue)
                                    }
                                )) {
                                    Text("")
                                }
                                .labelsHidden()
                            }
                        }
                    } header: {
                        Text("この日のアラーム")
                    }
                }
                .listStyle(.insetGrouped)

                Button(role: .destructive) {
                    viewModel.setAllAlarmsEnabled(false, on: date)
                } label: {
                    Text("この日のアラームをすべてオフにする")
                        .frame(maxWidth: .infinity)
                }
                .padding()
            }
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
