// CalendarView.swift

import SwiftUI

struct CalendarView: View {
    @ObservedObject var viewModel: AppViewModel

    @State private var displayedMonth: Date = Date()
    @State private var isShowingDaySheet: Bool = false
    @State private var selectedDate: Date? = nil

    private let calendar = Calendar(identifier: .gregorian)

    // 月表示用フォーマッタ
    private static let monthTitleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年 M月"
        return f
    }()

    private var monthTitle: String {
        Self.monthTitleFormatter.string(from: displayedMonth)
    }

    // カレンダーに表示する日付（前後の空白を含む）
    private var daysForCalendar: [Date?] {
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)),
              let range = calendar.range(of: .day, in: .month, for: startOfMonth)
        else { return [] }

        let numberOfDays = range.count
        let firstWeekday = calendar.component(.weekday, from: startOfMonth) // 1=日曜〜7=土曜

        var result: [Date?] = []

        // 月初め前の空白
        for _ in 0..<(firstWeekday - 1) {
            result.append(nil)
        }

        // 当月の日付
        for offset in 0..<numberOfDays {
            if let date = calendar.date(byAdding: .day, value: offset, to: startOfMonth) {
                result.append(date)
            }
        }

        // 7の倍数になるように後ろも空白で埋める
        while result.count % 7 != 0 {
            result.append(nil)
        }

        return result
    }

    var body: some View {
        GeometryReader { geo in
            // 画面サイズに応じてセルの大きさを調整
            let cellHeight = geo.size.height * 0.75 / 6   // 画面高さの75%を6行で割る
            let cellWidth  = geo.size.width / 7

            VStack(spacing: 4) {
                monthHeader
                weekdayHeader
                calendarGrid(cellWidth: cellWidth, cellHeight: cellHeight)
            }
            .padding(.horizontal, 4)
            .sheet(isPresented: $isShowingDaySheet) {
                if let date = selectedDate {
                    DayAlarmDetailSheet(viewModel: viewModel, date: date)
                        .presentationDetents([.medium, .large])
                }
            }
        }
    }

    // MARK: - 月ヘッダー

    private var monthHeader: some View {
        HStack {
            Button { moveMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(monthTitle)
                .font(.title3)
                .fontWeight(.semibold)

            Spacer()

            Button { moveMonth(by: 1) } label: {
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
        switch weekday {
        case 1: return .red
        case 7: return .blue
        default: return .secondary
        }
    }

    // MARK: - カレンダー本体

    private func calendarGrid(cellWidth: CGFloat, cellHeight: CGFloat) -> some View {
        let days = daysForCalendar
        let numberOfWeeks = days.count / 7

        return VStack(spacing: 0) {
            ForEach(0..<numberOfWeeks, id: \.self) { weekIndex in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { weekdayIndex in
                        let index = weekIndex * 7 + weekdayIndex
                        let date = days[index]

                        if let date = date {
                            let isCurrentMonth = calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
                            let isHoliday = viewModel.isHoliday(date: date) || calendar.component(.weekday, from: date) == 1
                            let isSaturday = calendar.component(.weekday, from: date) == 7
                            let alarms = viewModel.alarmsForCalendar(on: date)

                            CalendarDayCell(
                                date: date,
                                isCurrentMonth: isCurrentMonth,
                                isHoliday: isHoliday,
                                isSaturday: isSaturday,
                                alarms: alarms,
                                width: cellWidth,
                                height: cellHeight
                            ) {
                                selectedDate = date
                                isShowingDaySheet = true
                            }
                        } else {
                            // 空白マス
                            Rectangle()
                                .foregroundColor(.clear)
                                .frame(width: cellWidth, height: cellHeight)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 1日セル

struct CalendarDayCell: View {
    let date: Date
    let isCurrentMonth: Bool
    let isHoliday: Bool
    let isSaturday: Bool
    let alarms: [DayAlarm]   // その日のアラーム
    let width: CGFloat
    let height: CGFloat
    let onTap: () -> Void

    private let calendar = Calendar(identifier: .gregorian)

    var body: some View {
        let enabledAlarms = alarms.filter { $0.isEnabled }

        // ★ 最大2件だけ時刻として出す
        let maxVisibleTimes = 2
        let visible = Array(enabledAlarms.prefix(maxVisibleTimes))
        let remainingCount = max(0, enabledAlarms.count - visible.count)

        Button(action: onTap) {
            VStack(spacing: 3) {
                // 日付（今日なら赤丸＋白文字）
                dateLabel

                // 時刻：1行に1件ずつ、最大2行
                ForEach(visible) { alarm in
                    Text(String(format: "%02d:%02d", alarm.hour, alarm.minute))
                        .font(.caption2)
                        .lineLimit(1)
                }

                // 残りがあれば「他◯件」
                if remainingCount > 0 {
                    Text("他\(remainingCount)件")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.clear)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isCurrentMonth)
        .opacity(isCurrentMonth ? 1.0 : 0.35)
    }

    /// 「今日」の見た目 + 通常日の色
    private var dateLabel: some View {
        let day = calendar.component(.day, from: date)
        let isToday = calendar.isDateInToday(date)

        return ZStack {
            if isToday {
                Circle()
                    .fill(Color.red)
                    .frame(width: 28, height: 28)
            }

            Text("\(day)")
                .font(.system(size: 15, weight: isToday ? .semibold : .regular))
                .foregroundColor(isToday ? .white : textColor)
        }
        .frame(height: 30)
    }

    /// 休日・土曜・平日で色分け
    private var textColor: Color {
        if isHoliday { return .red }
        if isSaturday { return .blue }
        return .primary
    }
}
// MARK: - 日付タップ時の詳細シート

struct DayAlarmDetailSheet: View {
    @ObservedObject var viewModel: AppViewModel
    let date: Date

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
                                    EmptyView()
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
