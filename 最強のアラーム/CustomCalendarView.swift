// CustomCalendarView.swift
// アラーム表示つきカレンダー（スワイプ・今日ボタン・祝日色・1日だけOFF）

import SwiftUI

struct CustomCalendarView: View {
    @EnvironmentObject var alarmViewModel: AlarmViewModel

    @State private var monthOffset: Int = 0
    @State private var selectedDate: Date = Date()

    @State private var showingDayAlarmsSheet = false
    @State private var editingAlarm: AlarmItem?

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "ja_JP")
        cal.firstWeekday = 1
        return cal
    }

    private var displayMonth: Date {
        calendar.date(byAdding: .month,
                      value: monthOffset,
                      to: firstOfMonth(for: Date())) ?? Date()
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomLeading) {
                VStack(spacing: 12) {
                    headerView
                    weekdayHeader
                    calendarGrid

                    Text("選択中: \(dateString(selectedDate))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 40)
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            if value.translation.width < -50 {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    monthOffset += 1
                                }
                            } else if value.translation.width > 50 {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    monthOffset -= 1
                                }
                            }
                        }
                )

                Button(action: moveToToday) {
                    Text("今日")
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
            .navigationTitle("カレンダー")
        }
        .sheet(isPresented: $showingDayAlarmsSheet) {
            DayAlarmsSheetView(
                date: selectedDate
            ) { alarm in
                editingAlarm = alarm
            }
            .environmentObject(alarmViewModel)
        }
        .sheet(item: $editingAlarm) { alarm in
            AlarmEditView(alarm: alarm, isNew: false)
                .environmentObject(alarmViewModel)
        }
    }

    // MARK: - ヘッダー

    private var headerView: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    monthOffset -= 1
                }
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(monthTitle(displayMonth))
                .font(.headline)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    monthOffset += 1
                }
            } label: {
                Image(systemName: "chevron.right")
            }
        }
    }

    private var weekdayHeader: some View {
        let symbols = ["日", "月", "火", "水", "木", "金", "土"]
        return HStack(spacing: 0) {
            ForEach(0..<symbols.count, id: \.self) { idx in
                Text(symbols[idx])
                    .font(.subheadline)
                    .foregroundColor(idx == 0 ? .red : (idx == 6 ? .blue : .secondary))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - カレンダー本体

    private var calendarGrid: some View {
        let dates = calendarDates(for: displayMonth)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        let rowCount = dates.count / 7
        let lastRow = rowCount - 1
        let lastColumn = 6

        return LazyVGrid(columns: columns, spacing: 0) {
            ForEach(dates.indices, id: \.self) { index in
                let row = index / 7
                let column = index % 7
                if let date = dates[index] {
                    dayCell(for: date,
                            row: row,
                            column: column,
                            lastRow: lastRow,
                            lastColumn: lastColumn)
                } else {
                    emptyCell(row: row,
                              column: column,
                              lastRow: lastRow,
                              lastColumn: lastColumn)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func emptyCell(row: Int, column: Int, lastRow: Int, lastColumn: Int) -> some View {
        Rectangle()
            .foregroundColor(.clear)
            .frame(height: 64)
            .cellBorder(row: row,
                        column: column,
                        lastRow: lastRow,
                        lastColumn: lastColumn)
    }

    // MARK: - 日セル

    private func dayCell(for date: Date,
                         row: Int,
                         column: Int,
                         lastRow: Int,
                         lastColumn: Int) -> some View {
        let day = calendar.component(.day, from: date)
        let isToday = calendar.isDateInToday(date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isThisMonth = calendar.isDate(date, equalTo: displayMonth, toGranularity: .month)
        let weekday = calendar.component(.weekday, from: date)
        let isHoliday = isJapaneseHoliday(date)

        let todayStart = calendar.startOfDay(for: Date())
        let dayStart = calendar.startOfDay(for: date)
        let isPast = dayStart < todayStart

        let baseColor: Color = {
            if !isThisMonth { return .secondary }
            if isHoliday { return .red }
            if weekday == 1 { return .red }
            if weekday == 7 { return .blue }
            return .primary
        }()

        // ⭐ 過去の日は表示しない、それ以外は「その日に関係あるアラーム」を全部表示
        let dayAlarms: [AlarmItem] = isPast ? [] : alarmsFor(date: date)
        let textColor: Color = isToday ? .white : baseColor

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedDate = date
            }
            if !dayAlarms.isEmpty {
                showingDayAlarmsSheet = true
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if isToday {
                        Circle().fill(Color.red)
                    }
                    if isSelected {
                        Circle().stroke(Color.accentColor, lineWidth: 2)
                    }

                    Text("\(day)")
                        .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(textColor)
                }
                .frame(height: 32)

                VStack(spacing: 2) {
                    ForEach(dayAlarms.prefix(2), id: \.id) { alarm in
                        Text(alarm.timeString)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(alarm.isEnabled ? .accentColor : .gray)
                    }
                    if dayAlarms.count > 2 {
                        Text("他\(dayAlarms.count - 2)件")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 4)
            }
            .frame(height: 64)
            .cellBorder(row: row,
                        column: column,
                        lastRow: lastRow,
                        lastColumn: lastColumn)
        }
        .buttonStyle(.plain)
    }

    // MARK: - その日に鳴るアラーム（カレンダー表示用）

    private func alarmsFor(date: Date) -> [AlarmItem] {
        let weekday = calendar.component(.weekday, from: date)
        let dayStart = calendar.startOfDay(for: date)
        let todayStart = calendar.startOfDay(for: Date())

        // 今日より過去は表示しない
        guard dayStart >= todayStart else { return [] }

        // ✅ isEnabled かつ、その曜日に鳴る ＋
        // ✅ その日付が disabledDates に含まれていないものだけ表示
        return alarmViewModel.alarms.filter { alarm in
            alarm.isEnabled &&
            alarm.repeatWeekdays.contains(weekday) &&
            !alarm.disabledDates.contains(dayStart)
        }
    }
    
    // MARK: - 日付ヘルパーなど

    private func moveToToday() {
        withAnimation(.easeInOut(duration: 0.25)) {
            monthOffset = 0
            selectedDate = Date()
        }
    }

    private func firstOfMonth(for date: Date) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? date
    }

    private func monthTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年M月"
        return f.string(from: date)
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy/MM/dd(E)"
        return f.string(from: date)
    }

    private func calendarDates(for month: Date) -> [Date?] {
        let first = firstOfMonth(for: month)
        let range = calendar.range(of: .day, in: .month, for: first) ?? 1..<2
        let numberOfDays = range.count

        let firstWeekday = calendar.component(.weekday, from: first)
        var result: [Date?] = Array(repeating: nil, count: firstWeekday - 1)

        for day in 1...numberOfDays {
            var comps = calendar.dateComponents([.year, .month], from: first)
            comps.day = day
            if let d = calendar.date(from: comps) {
                result.append(d)
            }
        }
        while result.count % 7 != 0 {
            result.append(nil)
        }
        return result
    }

    // 日本の祝日（簡易版＋振替）※前と同じ
    private func isJapaneseHoliday(_ date: Date) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        let year = calendar.component(.year, from: dayStart)

        var holidays = Set<Date>()

        func add(_ month: Int, _ day: Int) {
            var c = DateComponents()
            c.year = year
            c.month = month
            c.day = day
            if let d = calendar.date(from: c) {
                holidays.insert(calendar.startOfDay(for: d))
            }
        }

        func nthWeekday(_ n: Int, _ weekday: Int, month: Int) {
            var c = DateComponents()
            c.year = year
            c.month = month
            c.weekday = weekday
            c.weekdayOrdinal = n
            if let d = calendar.date(from: c) {
                holidays.insert(calendar.startOfDay(for: d))
            }
        }

        func vernalEquinoxDay() -> Int {
            let y = Double(year)
            return Int(20.8431 + 0.242194 * (y - 1980) - floor((y - 1980)/4))
        }
        func autumnalEquinoxDay() -> Int {
            let y = Double(year)
            return Int(23.2488 + 0.242194 * (y - 1980) - floor((y - 1980)/4))
        }

        add(1,1); add(2,11); add(2,23)
        add(4,29); add(5,3); add(5,4); add(5,5)
        add(8,11); add(11,3); add(11,23)

        nthWeekday(2,2,month:1)
        nthWeekday(3,2,month:7)
        nthWeekday(3,2,month:9)
        nthWeekday(2,2,month:10)

        add(3, vernalEquinoxDay())
        add(9, autumnalEquinoxDay())

        var withSub = holidays
        for d in holidays {
            let w = calendar.component(.weekday, from: d)
            if w == 1 {
                var next = calendar.date(byAdding: .day, value: 1, to: d)!
                while holidays.contains(next) {
                    next = calendar.date(byAdding: .day, value: 1, to: next)!
                }
                withSub.insert(calendar.startOfDay(for: next))
            }
        }

        return withSub.contains(dayStart)
    }
}

// 罫線を揃える Modifier（前と同じ）

private struct CellBorderModifier: ViewModifier {
    let row: Int
    let column: Int
    let lastRow: Int
    let lastColumn: Int
    let color = Color.gray.opacity(0.15)
    let width: CGFloat = 0.5

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if row < lastRow {
                    Rectangle()
                        .frame(height: width)
                        .foregroundColor(color)
                }
            }
            .overlay(alignment: .trailing) {
                if column < lastColumn {
                    Rectangle()
                        .frame(width: width)
                        .foregroundColor(color)
                }
            }
    }
}

private extension View {
    func cellBorder(row: Int, column: Int, lastRow: Int, lastColumn: Int) -> some View {
        modifier(CellBorderModifier(row: row, column: column, lastRow: lastRow, lastColumn: lastColumn))
    }
}

// MARK: - 日別アラーム一覧シート
// ここでは disabledDates を見てトグル状態だけ変える

struct DayAlarmsSheetView: View {
    let date: Date
    let onSelectAlarm: (AlarmItem) -> Void

    @EnvironmentObject var alarmViewModel: AlarmViewModel
    @Environment(\.dismiss) private var dismiss

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "ja_JP")
        cal.firstWeekday = 1
        return cal
    }

    private var titleString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日(E)"
        return f.string(from: date)
    }

    private var alarmsForDate: [AlarmItem] {
        let weekday = calendar.component(.weekday, from: date)
        // ⭐ disabledDates はここでは絞り込まない
        return alarmViewModel.alarms.filter {
            $0.repeatWeekdays.contains(weekday) && $0.isEnabled
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if alarmsForDate.isEmpty {
                    Text("この日に鳴るアラームはありません")
                        .foregroundColor(.secondary)
                } else {
                    let dayStart = calendar.startOfDay(for: date)
                    ForEach(alarmsForDate) { alarm in
                        let isOnInitial = !alarm.disabledDates.contains(dayStart)
                        DayAlarmRow(
                            alarm: alarm,
                            dayStart: dayStart,
                            isOnInitial: isOnInitial,
                            onToggle: { isOn in
                                alarmViewModel.updateDisabledDate(
                                    for: alarm.id,
                                    date: date,
                                    enabled: isOn
                                )
                            },
                            onTap: {
                                dismiss()
                                onSelectAlarm(alarm)
                            }
                        )
                    }
                }
            }
            .navigationTitle(titleString)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

// 1行分：トグルでその日だけON/OFF、タップで編集

private struct DayAlarmRow: View {
    let alarm: AlarmItem
    let dayStart: Date
    let onToggle: (Bool) -> Void
    let onTap: () -> Void

    @State private var isOn: Bool

    init(
        alarm: AlarmItem,
        dayStart: Date,
        isOnInitial: Bool,
        onToggle: @escaping (Bool) -> Void,
        onTap: @escaping () -> Void
    ) {
        self.alarm = alarm
        self.dayStart = dayStart
        self.onToggle = onToggle
        self.onTap = onTap
        _isOn = State(initialValue: isOnInitial)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(alarm.timeString)
                    .font(.title2)
                Text(alarm.detailText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .onTapGesture { onTap() }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.green)
                .onChange(of: isOn) { newValue in
                    onToggle(newValue)
                }
        }
    }
}

#Preview {
    let vm = AlarmViewModel()
    vm.alarms = [
        AlarmItem(hour: 7, minute: 0, repeatWeekdays: [2,3,4,5,6]),
        AlarmItem(hour: 8, minute: 0, repeatWeekdays: [2,3,4,5,6])
    ]
    return CustomCalendarView()
        .environmentObject(vm)
}
