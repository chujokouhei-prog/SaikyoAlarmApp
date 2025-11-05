// CalendarView.swift

import SwiftUI

// シート表示用に、日付を包むだけのラッパー
struct SelectedDay: Identifiable {
    let id = UUID()
    let date: Date
}

/// 月カレンダー画面
/// - 横スワイプで月送り（TabView のページング）
/// - 矢印ボタンでも前月/翌月に移動
/// - 土曜=青, 日曜/祝日=赤
/// - 1日あたり最大2件のアラーム時刻 +「他◯件」
/// - カレンダー上の表示は今日以降のアラームだけ
struct CalendarView: View {
    @ObservedObject var viewModel: AppViewModel

    private let calendar = Calendar(identifier: .gregorian)

    /// 表示可能な月の一覧（今日の月を中心に ±24ヶ月）
    private let months: [Date]

    /// 現在表示している月のインデックス（months 配列の何番目か）
    @State private var currentIndex: Int

    /// シートで表示する「選択された日」
    @State private var selectedDay: SelectedDay?

    // MARK: - 初期化

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel

        let today = Date()
        let cal = Calendar(identifier: .gregorian)
        let startOfThisMonth = cal.date(from: cal.dateComponents([.year, .month], from: today))!

        var tmp: [Date] = []
        // だいたい4年分（-24ヶ月〜+24ヶ月）
        for offset in -24...24 {
            if let m = cal.date(byAdding: .month, value: offset, to: startOfThisMonth) {
                tmp.append(m)
            }
        }
        self.months = tmp
        _currentIndex = State(initialValue: 24) // 真ん中（＝今月）からスタート
    }

    // MARK: - フォーマッタ

    private static let monthTitleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年 M月"
        return f
    }()

    private var monthTitle: String {
        Self.monthTitleFormatter.string(from: months[currentIndex])
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let cellHeight = geo.size.height * 0.75 / 6
            let cellWidth  = geo.size.width / 7

            VStack(spacing: 4) {
                header
                weekdayHeader

                // 横スワイプで月切り替え
                TabView(selection: $currentIndex) {
                    ForEach(months.indices, id: \.self) { index in
                        MonthGridView(
                            monthDate: months[index],
                            viewModel: viewModel,
                            calendar: calendar,
                            cellWidth: cellWidth,
                            cellHeight: cellHeight
                        ) { date in
                            selectedDay = SelectedDay(date: date)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .padding(.horizontal, 4)
            .sheet(item: $selectedDay) { selected in
                DayAlarmDetailSheet(viewModel: viewModel, date: selected.date)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - ヘッダー（年・月＋矢印）

    private var header: some View {
        HStack {
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    if currentIndex > 0 {
                        currentIndex -= 1
                    }
                }
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(monthTitle)
                .font(.title3)
                .fontWeight(.semibold)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    if currentIndex < months.count - 1 {
                        currentIndex += 1
                    }
                }
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.bottom, 4)
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
}

// MARK: - 1ヶ月分のグリッド

struct MonthGridView: View {
    let monthDate: Date
    @ObservedObject var viewModel: AppViewModel
    let calendar: Calendar
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let onSelectDate: (Date) -> Void

    private var daysForCalendar: [Date?] {
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate)),
              let range = calendar.range(of: .day, in: .month, for: startOfMonth)
        else { return [] }

        let numberOfDays = range.count
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)

        var result: [Date?] = []

        // 月初め前の空白
        for _ in 0..<(firstWeekday - 1) { result.append(nil) }

        // 当月の日付
        for offset in 0..<numberOfDays {
            if let date = calendar.date(byAdding: .day, value: offset, to: startOfMonth) {
                result.append(date)
            }
        }

        // 最後の週の空白
        while result.count % 7 != 0 { result.append(nil) }

        return result
    }

    var body: some View {
        let days = daysForCalendar
        let numberOfWeeks = days.count / 7

        VStack(spacing: 0) {
            ForEach(0..<numberOfWeeks, id: \.self) { weekIndex in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { weekdayIndex in
                        let index = weekIndex * 7 + weekdayIndex
                        let date = days[index]

                        if let date = date {
                            let isCurrentMonth = calendar.isDate(date, equalTo: monthDate, toGranularity: .month)
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
                                onSelectDate(date)
                            }
                        } else {
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

// MARK: - 1日セル（最大2件＋他◯件・過去は非表示）

struct CalendarDayCell: View {
    let date: Date
    let isCurrentMonth: Bool
    let isHoliday: Bool
    let isSaturday: Bool
    let alarms: [DayAlarm]
    let width: CGFloat
    let height: CGFloat
    let onTap: () -> Void

    private let calendar = Calendar(identifier: .gregorian)

    var body: some View {
        let today = calendar.startOfDay(for: Date())
        let isPast = calendar.startOfDay(for: date) < today

        // 過去の日付はカレンダー上の時刻表示を消す
        let enabledAlarms = isPast ? [] : alarms.filter { $0.isEnabled }

        let maxVisibleTimes = 2
        let visible = Array(enabledAlarms.prefix(maxVisibleTimes))
        let remainingCount = max(0, enabledAlarms.count - visible.count)

        Button(action: onTap) {
            VStack(spacing: 3) {
                dateLabel

                ForEach(visible) { alarm in
                    Text(String(format: "%02d:%02d", alarm.hour, alarm.minute))
                        .font(.caption2)
                        .lineLimit(1)
                }

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

    private var textColor: Color {
        if isHoliday { return .red }
        if isSaturday { return .blue }
        return .primary
    }
}

// MARK: - シート: その日の詳細

private struct ToggleTarget {
    let alarm: DayAlarm
    let newValue: Bool
}

struct DayAlarmDetailSheet: View {
    @ObservedObject var viewModel: AppViewModel
    let date: Date

    @State private var toggleTarget: ToggleTarget?
    @State private var isShowingToggleDialog = false
    @State private var editingAlarm: DayAlarm?

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

                                Button("編集") {
                                    editingAlarm = alarm
                                }
                                .font(.caption)

                                Toggle(isOn: Binding(
                                    get: {
                                        viewModel
                                            .alarmsForCalendar(on: date)
                                            .first(where: { $0.id == alarm.id })?
                                            .isEnabled ?? false
                                    },
                                    set: { newValue in
                                        toggleTarget = ToggleTarget(alarm: alarm, newValue: newValue)
                                        isShowingToggleDialog = true
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
        // ON/OFF の変更方法を選ぶダイアログ（Bool版）
        .confirmationDialog(
            "アラームの変更",
            isPresented: $isShowingToggleDialog,
            titleVisibility: .automatic
        ) {
            if let target = toggleTarget {
                let onOffText = target.newValue ? "オン" : "オフ"

                Button("この日だけ\(onOffText)にする") {
                    viewModel.setAlarmEnabled(id: target.alarm.id, on: date, enabled: target.newValue)
                }

                Button("今後のすべてを\(onOffText)にする", role: .destructive) {
                    viewModel.setAlarmEnabled(id: target.alarm.id, enabled: target.newValue)
                }
            }

            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("このアラームを「この日だけ」変えるか、「今後のすべて」に適用するか選んでください。")
        }
        // 時刻編集シート
        .sheet(item: $editingAlarm) { alarm in
            AlarmTimeEditSheet(viewModel: viewModel, alarm: alarm, date: date)
        }
    }
}

// MARK: - 時刻編集用シート

struct AlarmTimeEditSheet: View {
    @ObservedObject var viewModel: AppViewModel
    let alarm: DayAlarm
    let date: Date

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTime: Date = Date()

    private let calendar = Calendar(identifier: .gregorian)

    init(viewModel: AppViewModel, alarm: DayAlarm, date: Date) {
        self.viewModel = viewModel
        self.alarm = alarm
        self.date = date
    }

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "時刻",
                    selection: $selectedTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding()

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        applyChange(onlyThisDay: true)
                    } label: {
                        Text("この日だけこの時刻にする")
                            .frame(maxWidth: .infinity)
                    }

                    Button {
                        applyChange(onlyThisDay: false)
                    } label: {
                        Text("今後のすべてをこの時刻にする")
                            .frame(maxWidth: .infinity)
                    }

                    Button("キャンセル", role: .cancel) {
                        dismiss()
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("時刻を編集")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                var comps = DateComponents()
                comps.hour = alarm.hour
                comps.minute = alarm.minute
                selectedTime = calendar.date(from: comps) ?? Date()
            }
        }
    }

    private func applyChange(onlyThisDay: Bool) {
        let comps = calendar.dateComponents([.hour, .minute], from: selectedTime)
        let hour = comps.hour ?? alarm.hour
        let minute = comps.minute ?? alarm.minute

        if onlyThisDay {
            viewModel.setAlarmTime(id: alarm.id, on: date, hour: hour, minute: minute)
        } else {
            viewModel.updateAlarmTime(id: alarm.id, hour: hour, minute: minute)
        }
        dismiss()
    }
}
