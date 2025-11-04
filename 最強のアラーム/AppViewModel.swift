// AppViewModel.swift

import SwiftUI
import EventKit
import Combine
import UserNotifications

// 1つのアラームの「ルール」
struct AlarmRule: Identifiable, Codable, Equatable {
    let id: UUID
    var hour: Int
    var minute: Int
    var weekdaysOnly: Bool
    var isEnabled: Bool
    var snoozeEnabled: Bool   // スヌーズON/OFF

    // 例: "7:30"
    var timeString: String {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let calendar = Calendar.current
        let date = calendar.date(from: comps) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "H:mm"
        return formatter.string(from: date)
    }

    // 例: "平日（祝日除く）" or "毎日"
    var modeDescription: String {
        weekdaysOnly ? "平日（祝日除く）" : "毎日"
    }
}

@MainActor
class AppViewModel: ObservableObject {
    // 登録されているアラームの一覧
    @Published var alarms: [AlarmRule] = [] {
        didSet {
            saveAlarms()
            rescheduleAllNotifications()
        }
    }

    // カレンダー用：アラームがある「日付（年月日だけ）」の集合
    @Published var alarmDates: Set<DateComponents> = []

    // 手動で追加した休み（カスタム休日）
    @Published var customHolidays: Set<DateComponents> = [] {
        didSet {
            saveCustomHolidays()
            rescheduleAllNotifications()
        }
    }

    private let userDefaultsHolidaysKey = "customHolidays_swiftui"
    private let userDefaultsAlarmsKey = "alarms_swiftui_rules"

    private let eventStore = EKEventStore()
    private var japaneseHolidays: Set<DateComponents> = []

    // スヌーズ設定（固定値）
    private let snoozeIntervalMinutes = 5
    private let snoozeRepeatCount = 3   // 3回（＝合計4回鳴る）

    // 祝前日通知の時刻（21:00固定）
    private let holidayEveNotificationHour = 21
    private let holidayEveNotificationMinute = 0

    init() {
        loadCustomHolidays()
        loadAlarms()
        requestCalendarAccessAndLoadHolidays()
        rescheduleAllNotifications()
    }

    // MARK: - 画面から呼ぶAPI

    /// 新しいアラームを追加
    func addAlarm(selectedDate: Date, weekdaysOnly: Bool, snoozeEnabled: Bool) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: selectedDate)
        let minute = calendar.component(.minute, from: selectedDate)

        let newRule = AlarmRule(
            id: UUID(),
            hour: hour,
            minute: minute,
            weekdaysOnly: weekdaysOnly,
            isEnabled: true,
            snoozeEnabled: snoozeEnabled
        )
        alarms.append(newRule)
        print("アラームを追加: \(newRule.timeString) \(newRule.modeDescription) スヌーズ: \(newRule.snoozeEnabled)")
    }

    /// ON/OFF切り替え
    func toggleAlarmEnabled(_ alarm: AlarmRule) {
        guard let index = alarms.firstIndex(of: alarm) else { return }
        alarms[index].isEnabled.toggle()
    }

    /// 削除（Listの .onDelete から呼ぶ）
    func deleteAlarms(at offsets: IndexSet) {
        alarms.remove(atOffsets: offsets)
    }

    /// カレンダーで使う「カスタム休日」の ON/OFF
    func toggleCustomHoliday(date: Date) {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        if customHolidays.contains(components) {
            customHolidays.remove(components)
        } else {
            customHolidays.insert(components)
        }
    }

    // MARK: - 通知の再スケジュール（スヌーズ＋祝前日込み）

    /// 現在の alarms / 休日設定 をもとに、通知を全部作り直す
    private func rescheduleAllNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let calendar = Calendar.current
        let allHolidays = japaneseHolidays.union(customHolidays)
        var newAlarmDates: Set<DateComponents> = []
        let today = Date()

        // 各アラームごとに、今後64日分の「アラーム本体通知」を作る
        for alarm in alarms where alarm.isEnabled {
            for i in 0..<64 {
                guard let targetDate = calendar.date(byAdding: .day, value: i, to: today) else { continue }

                let dayComponents = calendar.dateComponents([.year, .month, .day], from: targetDate)

                let scheduleThisDate: Bool
                if alarm.weekdaysOnly {
                    let weekday = calendar.component(.weekday, from: targetDate)
                    let isWeekday = (weekday >= 2 && weekday <= 6) // 月〜金
                    let isHoliday = allHolidays.contains(dayComponents)
                    scheduleThisDate = isWeekday && !isHoliday
                } else {
                    scheduleThisDate = true
                }

                guard scheduleThisDate else { continue }

                // ベースの通知（1回目）
                var baseComponents = dayComponents
                baseComponents.hour = alarm.hour
                baseComponents.minute = alarm.minute

                if let baseDate = calendar.date(from: baseComponents) {
                    // 1回目（通常）
                    scheduleNotification(center: center,
                                         date: baseDate,
                                         alarm: alarm,
                                         isSnooze: false)

                    // スヌーズ（5分おきに3回）
                    if alarm.snoozeEnabled {
                        for n in 1...snoozeRepeatCount {
                            if let snoozeDate = calendar.date(byAdding: .minute,
                                                              value: snoozeIntervalMinutes * n,
                                                              to: baseDate) {
                                scheduleNotification(center: center,
                                                     date: snoozeDate,
                                                     alarm: alarm,
                                                     isSnooze: true)
                            }
                        }
                    }

                    // カレンダー表示用：その日に少なくとも1つアラームがある
                    newAlarmDates.insert(dayComponents)
                }
            }
        }

        // --- ここから「祝日前夜通知」をスケジュールする ---

        // 平日専用アラームが1つでも有効なら、祝前日通知を付ける
        let hasWeekdayOnlyAlarm = alarms.contains { $0.isEnabled && $0.weekdaysOnly }

        if hasWeekdayOnlyAlarm {
            for i in 0..<64 {
                guard let holidayDate = calendar.date(byAdding: .day, value: i, to: today) else { continue }
                let holidayComponents = calendar.dateComponents([.year, .month, .day], from: holidayDate)

                // 「祝日 or カスタム休日」のみ対象（週末だけはここでは扱わない）
                let isHoliday = allHolidays.contains(holidayComponents)
                guard isHoliday else { continue }

                // 前日を計算（範囲外や過去ならスキップ）
                guard let eveDateRaw = calendar.date(byAdding: .day, value: -1, to: holidayDate) else { continue }

                // 通知を出すのは 21:00 固定
                var eveComponents = calendar.dateComponents([.year, .month, .day], from: eveDateRaw)
                eveComponents.hour = holidayEveNotificationHour
                eveComponents.minute = holidayEveNotificationMinute

                guard let eveDate = calendar.date(from: eveComponents),
                      eveDate > today else {
                    continue
                }

                let isCustom = customHolidays.contains(holidayComponents)

                scheduleHolidayEveNotification(center: center,
                                               eveComponents: eveComponents,
                                               holidayDate: holidayDate,
                                               isCustomHoliday: isCustom)
            }
        }

        self.alarmDates = newAlarmDates
        print("通知を再スケジュールしました。アラーム日数: \(newAlarmDates.count)")
    }

    /// 実際に1つの「アラーム本体通知」を登録する共通処理
    private func scheduleNotification(center: UNUserNotificationCenter,
                                      date: Date,
                                      alarm: AlarmRule,
                                      isSnooze: Bool) {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)

        let content = UNMutableNotificationContent()
        content.title = isSnooze ? "スヌーズ" : "時間です！"
        content.body = "\(alarm.modeDescription) \(alarm.timeString) のアラームです"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: trigger)
        center.add(request)
    }

    /// 「明日は祝日（or カスタム休日）です」通知を登録
    private func scheduleHolidayEveNotification(center: UNUserNotificationCenter,
                                                eveComponents: DateComponents,
                                                holidayDate: Date,
                                                isCustomHoliday: Bool) {
        let calendar = Calendar.current

        // 表示用に祝日の日付をフォーマット
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日(EEE)"

        let holidayString = formatter.string(from: holidayDate)
        let kind = isCustomHoliday ? "お休み" : "祝日"

        let content = UNMutableNotificationContent()
        content.title = "明日は\(kind)です"
        content.body = "明日 \(holidayString) は\(kind)なので、平日専用アラームは鳴りません。"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: eveComponents, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: trigger)
        center.add(request)

        print("祝前日通知を登録: \(holidayString) の前日")
    }

    // MARK: - 日本の祝日読み込み

    private func requestCalendarAccessAndLoadHolidays() {
        eventStore.requestAccess(to: .event) { [weak self] granted, error in
            if granted {
                Task { await self?.loadJapaneseHolidays() }
            } else if let error = error {
                print("カレンダーアクセスエラー: \(error.localizedDescription)")
            }
        }
    }

    private func loadJapaneseHolidays() async {
        let calendar = Calendar.current
        guard let start = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1)),
              let end = calendar.date(from: DateComponents(year: 2026, month: 12, day: 31)) else { return }
        guard let cal = eventStore.calendars(for: .event).first(where: { $0.title == "日本の祝日" }) else { return }
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: [cal])
        let events = eventStore.events(matching: predicate)
        let holidays = Set(events.map { calendar.dateComponents([.year, .month, .day], from: $0.startDate) })
        await MainActor.run {
            self.japaneseHolidays = holidays
            print("日本の祝日を読み込みました: \(self.japaneseHolidays.count)")
            self.rescheduleAllNotifications()
        }
    }

    // MARK: - カスタム休日の保存・読み込み

    private func loadCustomHolidays() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsHolidaysKey),
              let holidays = try? JSONDecoder().decode(Set<DateComponents>.self, from: data) else { return }
        self.customHolidays = holidays
    }

    private func saveCustomHolidays() {
        guard let data = try? JSONEncoder().encode(customHolidays) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsHolidaysKey)
    }

    // MARK: - アラームの保存・読み込み

    private func loadAlarms() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsAlarmsKey),
              let savedAlarms = try? JSONDecoder().decode([AlarmRule].self, from: data) else { return }
        self.alarms = savedAlarms
    }

    private func saveAlarms() {
        guard let data = try? JSONEncoder().encode(alarms) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsAlarmsKey)
    }
}

