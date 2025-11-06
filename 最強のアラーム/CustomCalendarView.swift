// CustomCalendarView.swift
// カード風デザインのアラーム付きカレンダー（祝日・1日だけOFF・単発アラーム対応）

import SwiftUI

struct CustomCalendarView: View {
    @EnvironmentObject var alarmViewModel: AlarmViewModel

    @State private var monthOffset: Int = 0
    @State private var selectedDate: Date = Date()

    @State private var showingDayAlarmsSheet = false
    @State private var editingAlarm: AlarmItem?
    @State private var creatingAlarm: AlarmItem?      // 新規作成用

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "ja_JP")
        cal.firstWeekday = 1
        return cal
    }

    private var displayMonth: Date {
        calendar.date(
            byAdding: .month,
            value: monthOffset,
            to: firstOfMonth(for: Date())
        ) ?? Date()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGray5)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    titleView
                    headerView
                    weekdayHeader
                    calendarGrid
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
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

                // 今日ボタン
                VStack {
                    Spacer()
                    HStack {
                        Button(action: moveToToday) {
                            Text("今日")
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .shadow(color: .gray.opacity(0.2), radius: 4, x: 0, y: 2)
                        }
                        .padding(.leading, 24)
                        .padding(.bottom, 16)

                        Spacer()
                    }
                }
            }
        }
        // 日別アラーム一覧シート
        .sheet(isPresented: $showingDayAlarmsSheet) {
            DayAlarmsSheetView(
                date: selectedDate,
                onSelectAlarm: { alarm in
                    editingAlarm = alarm
                },
                onCreateNew: { newAlarm in
                    creatingAlarm = newAlarm
                }
            )
            .environmentObject(alarmViewModel)
        }
        // 既存アラーム編集
        .sheet(item: $editingAlarm) { alarm in
            AlarmEditView(alarm: alarm, isNew: false)
                .environmentObject(alarmViewModel)
        }
        // 新規アラーム作成（カレンダーから）
        .sheet(item: $creatingAlarm) { alarm in
            AlarmEditView(alarm: alarm, isNew: true)
                .environmentObject(alarmViewModel)
        }
    }

    // MARK: - 画面タイトル

    private var titleView: some View {
        HStack {
            Text("カレンダー")
                .font(.system(size: 34, weight: .bold))
                .padding(.leading, 4)
            Spacer()
        }
    }

    // MARK: - ヘッダー（年月＋前後月ボタン）

    private var headerView: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    monthOffset -= 1
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
            }

            Spacer()

            Text(monthTitle(displayMonth))
                .font(.system(size: 22, weight: .semibold))
                .tracking(1.0)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    monthOffset += 1
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
            }
        }
    }

    // MARK: - 曜日ヘッダー

    private var weekdayHeader: some View {
        let symbols = ["日", "月", "火", "水", "木", "金", "土"]

        return HStack(spacing: 8) {
            ForEach(0..<symbols.count, id: \.self) { idx in
                Text(symbols[idx])
                    .font(.caption.weight(.medium))
                    .foregroundColor(idx == 0 ? .red : (idx == 6 ? .blue : .secondary))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    // MARK: - カレンダー本体

    private var calendarGrid: some View {
        let dates = calendarDates(for: displayMonth)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(dates.indices, id: \.self) { index in
                if let date = dates[index] {
                    dayCell(for: date)
                } else {
                    Color.clear
                        .frame(height: 72)
                }
            }
        }
    }

    // MARK: - 日セル（カード＋バッジ）

    private func dayCell(for date: Date) -> some View {
        let day = calendar.component(.day, from: date)
        let isToday = calendar.isDateInToday(date)
        let isThisMonth = calendar.isDate(date, equalTo: displayMonth, toGranularity: .month)
        let weekday = calendar.component(.weekday, from: date)
        let isHoliday = isJapaneseHoliday(date)

        let todayStart = calendar.startOfDay(for: Date())
        let dayStart = calendar.startOfDay(for: date)
        let isPast = dayStart < todayStart

        let baseColor: Color = {
            if !isThisMonth { return .secondary.opacity(0.5) }
            if isHoliday { return .red }
            if weekday == 1 { return .red }
            if weekday == 7 { return .blue }
            return .primary
        }()

        let textColor: Color = isToday ? .white : baseColor
        let dayAlarms: [AlarmItem] = isPast ? [] : alarmsFor(date: date)

        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                selectedDate = date
            }
            // アラームがなくても必ずシートを出す
            showingDayAlarmsSheet = true
        } label: {
            VStack(alignment: .center, spacing: 6) {
                // 日付
                ZStack {
                    if isToday {
                        Circle()
                            .fill(Color.red.gradient)
                            .overlay(
                                Circle().stroke(Color.white, lineWidth: 1)
                            )
                            .shadow(color: .red.opacity(0.25), radius: 4, x: 0, y: 2)
                    }
                    Text("\(day)")
                        .font(.system(size: 19, weight: isToday ? .semibold : .regular))
                        .foregroundColor(textColor)
                }
                .frame(height: 26)

                // アラームがある場合はピル型バッジで表示
                if !dayAlarms.isEmpty {
                    VStack(spacing: 4) {
                        ForEach(dayAlarms.prefix(2), id: \.id) { alarm in
                            HStack(spacing: 4) {
                                Text(alarm.timeString)
                                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .fill(
                                                alarm.isEnabled
                                                ? Color.accentColor.opacity(0.10)
                                                : Color.gray.opacity(0.18)
                                            )
                                    )
                                    .foregroundColor(
                                        alarm.isEnabled
                                        ? Color.accentColor.opacity(0.8)
                                        : Color.gray
                                    )

                                Spacer(minLength: 0)
                            }
                        }

                        if dayAlarms.count > 2 {
                            HStack {
                                Spacer(minLength: 0)
                                Text("他\(dayAlarms.count - 2)件")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary.opacity(0.7))
                            }
                        }
                    }
                } else if !isPast {
                    // アラームが無い未来の日は、小さなドットでリズムを揃える
                    Circle()
                        .fill(Color.gray.opacity(0.12))
                        .frame(width: 4, height: 4)
                }
            }
            .frame(height: 72)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemGray6))
                    .shadow(color: Color.black.opacity(0.02), radius: 1, x: 0, y: 0.5)
            )
            .opacity(isPast ? 0.4 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - その日に鳴るアラーム（カレンダー表示用）
    // 🔵 単発アラーム（specificDates）＋ 繰り返しアラーム（repeatWeekdays）の両方を考慮

    private func alarmsFor(date: Date) -> [AlarmItem] {
        let weekday = calendar.component(.weekday, from: date)
        let dayStart = calendar.startOfDay(for: date)
        let todayStart = calendar.startOfDay(for: Date())

        // 昨日以前は表示しない
        guard dayStart >= todayStart else { return [] }

        return alarmViewModel.alarms.filter { alarm in
            guard alarm.isEnabled else { return false }

            // 単発アラーム：specificDates にこの日が含まれている
            let isOneTime = alarm.specificDates.contains(dayStart)

            // 繰り返しアラーム：曜日が合っていて、この日が「OFF指定」でない
            let isRepeating =
                alarm.repeatWeekdays.contains(weekday) &&
                !alarm.disabledDates.contains(dayStart)

            return isOneTime || isRepeating
        }
    }

    // MARK: - 日付ヘルパーなど

    private func moveToToday() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
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

    // MARK: - 日本の祝日（簡易版＋振替）
    // ※ここは以前のまま

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
            return Int(20.8431 + 0.242194 * (y - 1980) - floor((y - 1980) / 4.0))
        }

        func autumnalEquinoxDay() -> Int {
            let y = Double(year)
            return Int(23.2488 + 0.242194 * (y - 1980) - floor((y - 1980) / 4.0))
        }

        // 固定祝日
        add(1, 1)
        add(2, 11)
        add(2, 23)
        add(4, 29)
        add(5, 3)
        add(5, 4)
        add(5, 5)
        add(8, 11)
        add(11, 3)
        add(11, 23)

        // ハッピーマンデー
        nthWeekday(2, 2, month: 1)
        nthWeekday(3, 2, month: 7)
        nthWeekday(3, 2, month: 9)
        nthWeekday(2, 2, month: 10)

        // 春分・秋分
        add(3, vernalEquinoxDay())
        add(9, autumnalEquinoxDay())

        // 振替休日
        var withSubstitute = holidays
        for d in holidays {
            let weekday = calendar.component(.weekday, from: d)
            if weekday == 1 {
                var next = calendar.date(byAdding: .day, value: 1, to: d)!
                while holidays.contains(next) {
                    next = calendar.date(byAdding: .day, value: 1, to: next)!
                }
                withSubstitute.insert(calendar.startOfDay(for: next))
            }
        }

        return withSubstitute.contains(dayStart)
    }
}

// MARK: - 日別アラーム一覧シート（その日だけON/OFF＋新規作成）

struct DayAlarmsSheetView: View {
    let date: Date
    let onSelectAlarm: (AlarmItem) -> Void
    let onCreateNew: (AlarmItem) -> Void

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

    /// この日に関係するアラーム（単発 + 繰り返し）を一覧表示
    private var alarmsForDate: [AlarmItem] {
        let weekday = calendar.component(.weekday, from: date)
        let dayStart = calendar.startOfDay(for: date)

        return alarmViewModel.alarms.filter { alarm in
            guard alarm.isEnabled else { return false }

            let isOneTime = alarm.specificDates.contains(dayStart)
            let isRepeating = alarm.repeatWeekdays.contains(weekday)

            return isOneTime || isRepeating
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
                // この日の新規アラームを追加（「単発」として作る）
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        let dayStart = calendar.startOfDay(for: date)

                        let newAlarm = AlarmItem(
                            hour: 7,
                            minute: 0,
                            repeatWeekdays: [],          // 繰り返しなし
                            specificDates: [dayStart]    // この日だけ鳴る
                        )

                        dismiss()
                        onCreateNew(newAlarm)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("アラームを追加")
                }
            }
        }
    }
}

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
            VStack(alignment: .leading, spacing: 4) {
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
