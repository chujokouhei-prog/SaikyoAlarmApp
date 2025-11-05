// AppViewModel.swift

import SwiftUI
import Combine
import EventKit
import UserNotifications

// MARK: - モデル: 1つのアラームのルール

struct AlarmRule: Identifiable, Codable, Equatable {
    let id: UUID
    var hour: Int
    var minute: Int
    var weekdaysOnly: Bool      // 平日のみ
    var isEnabled: Bool         // 基本状態としての有効/無効
    var snoozeEnabled: Bool     // スヌーズON/OFF

    init(
        id: UUID = UUID(),
        hour: Int,
        minute: Int,
        weekdaysOnly: Bool,
        isEnabled: Bool = true,
        snoozeEnabled: Bool = false
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.weekdaysOnly = weekdaysOnly
        self.isEnabled = isEnabled
        self.snoozeEnabled = snoozeEnabled
    }

    /// 例: "7:30"
    var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }
}

// MARK: - 日付ごとの表示用アラーム（ビュー専用）

struct DayAlarm: Identifiable {
    let id: UUID
    let hour: Int
    let minute: Int
    let weekdaysOnly: Bool
    let snoozeEnabled: Bool
    var isEnabled: Bool     // その日だけのON/OFF（例外込み）

    var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }
}

// MARK: - ビューモデル

final class AppViewModel: ObservableObject {

    // 公開プロパティ ---------------------------------------------------------

    /// すべてのアラームルール（基本状態）
    @Published var alarmRules: [AlarmRule] = [] {
        didSet {
            saveAlarmRules()
            rescheduleAllAlarms()
        }
    }

    /// ログ表示用
    @Published var logMessages: [String] = []

    /// 通知権限
    @Published var notificationPermissionGranted: Bool = false

    /// 「その日だけ ON/OFF」の例外
    /// key: その日の 0:00, value: [アラームID: その日のON/OFF]
    @Published var perDayEnabledOverrides: [Date: [UUID: Bool]] = [:]

    /// 「その日だけ時間変更」の例外
    /// key: その日の 0:00, value: [アラームID: (hour, minute)]
    @Published var perDayTimeOverrides: [Date: [UUID: (Int, Int)]] = [:]

    // 内部 ---------------------------------------------------------

    private let notificationCenter = UNUserNotificationCenter.current()
    private let eventStore = EKEventStore()
    private let calendar = Calendar(identifier: .gregorian)

    /// 祝日（その日の 0:00 の Date）
    private var holidayDates: Set<Date> = []

    private let alarmsUserDefaultsKey = "AlarmRules_v1"

    // MARK: - 初期化

    init() {
        loadSavedAlarms()
        requestNotificationPermission()
        requestCalendarAccessAndLoadHolidays()
    }

    // MARK: - 公開メソッド: アラームの追加・削除・更新

    /// 新しいアラームを追加
    func addAlarm(hour: Int, minute: Int, weekdaysOnly: Bool, snoozeEnabled: Bool) {
        let new = AlarmRule(
            hour: hour,
            minute: minute,
            weekdaysOnly: weekdaysOnly,
            isEnabled: true,
            snoozeEnabled: snoozeEnabled
        )
        alarmRules.append(new)
        appendLog("アラーム追加: \(new.timeString)")
    }

    /// アラーム削除（List の .onDelete から呼び出す想定）
    func deleteAlarms(at offsets: IndexSet) {
        alarmRules.remove(atOffsets: offsets)
        appendLog("アラーム削除")
    }

    /// 1つのアラームの「基本状態としての」有効/無効をトグル
    func toggleEnabled(for rule: AlarmRule) {
        if let index = alarmRules.firstIndex(of: rule) {
            alarmRules[index].isEnabled.toggle()
            appendLog("アラーム \(alarmRules[index].timeString) を \(alarmRules[index].isEnabled ? "常にON" : "常にOFF") に変更")
        }
    }

    /// 基本状態としての ON/OFF を設定（「今後のすべて」に相当）
    func setAlarmEnabled(id: UUID, enabled: Bool) {
        if let index = alarmRules.firstIndex(where: { $0.id == id }) {
            alarmRules[index].isEnabled = enabled
            appendLog("アラーム \(alarmRules[index].timeString) の基本状態を \(enabled ? "ON" : "OFF") に設定")
        }
    }

    /// 特定の日だけの ON/OFF を設定（「この日のみ」に相当）
    func setAlarmEnabled(id: UUID, on date: Date, enabled: Bool) {
        let key = dayKey(for: date)
        var map = perDayEnabledOverrides[key] ?? [:]
        map[id] = enabled
        perDayEnabledOverrides[key] = map

        appendLog("日付 \(shortDateString(date)) のアラームID:\(id) を \(enabled ? "ON" : "OFF") にしました（1日だけの設定）")

        rescheduleAllAlarms()
    }

    /// 「この日のアラームをすべてオフ」ボタン用
    func setAllAlarmsEnabled(_ enabled: Bool, on date: Date) {
        let key = dayKey(for: date)
        var map = perDayEnabledOverrides[key] ?? [:]
        for rule in alarmRules {
            map[rule.id] = enabled
        }
        perDayEnabledOverrides[key] = map

        appendLog("日付 \(shortDateString(date)) のアラームをすべて \(enabled ? "ON" : "OFF") にしました（1日だけ）")

        rescheduleAllAlarms()
    }

    /// 「この日だけ時間を変更」用
    func setAlarmTime(id: UUID, on date: Date, hour: Int, minute: Int) {
        let key = dayKey(for: date)
        var map = perDayTimeOverrides[key] ?? [:]
        map[id] = (hour, minute)
        perDayTimeOverrides[key] = map

        appendLog("日付 \(shortDateString(date)) のアラームID:\(id) の時刻を \(String(format: "%02d:%02d", hour, minute)) に変更（1日だけ）")

        rescheduleAllAlarms()
    }

    /// 「今後のすべての時間を変更」用
    func updateAlarmTime(id: UUID, hour: Int, minute: Int) {
        guard let index = alarmRules.firstIndex(where: { $0.id == id }) else { return }
        alarmRules[index].hour = hour
        alarmRules[index].minute = minute
        appendLog("アラーム \(alarmRules[index].timeString) の基本時刻を変更")
        // alarmRules の didSet で再スケジュールされる
    }

    /// カレンダー用: 指定日のアラーム一覧（その日だけのON/OFF・時間を反映した DayAlarm を返す）
    func alarmsForCalendar(on date: Date) -> [DayAlarm] {
        alarmRules.map { rule in
            let time = timeFor(rule, on: date)
            return DayAlarm(
                id: rule.id,
                hour: time.hour,
                minute: time.minute,
                weekdaysOnly: rule.weekdaysOnly,
                snoozeEnabled: rule.snoozeEnabled,
                isEnabled: isAlarmEnabled(rule, on: date)
            )
        }
    }

    /// 指定日が祝日かどうか
    func isHoliday(date: Date) -> Bool {
        let day = calendar.startOfDay(for: date)
        return holidayDates.contains(day)
    }

    // MARK: - 内部ヘルパー（日付キー・有効判定・時間判定）

    private func dayKey(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    /// 例外込みで、その日そのアラームが「有効かどうか」
    private func isAlarmEnabled(_ rule: AlarmRule, on date: Date) -> Bool {
        let key = dayKey(for: date)
        if let map = perDayEnabledOverrides[key], let overrideValue = map[rule.id] {
            return overrideValue
        }
        return rule.isEnabled
    }

    /// 例外込みで、その日そのアラームが鳴る時刻
    private func timeFor(_ rule: AlarmRule, on date: Date) -> (hour: Int, minute: Int) {
        let key = dayKey(for: date)
        if let map = perDayTimeOverrides[key], let overrideTime = map[rule.id] {
            return overrideTime
        }
        return (rule.hour, rule.minute)
    }

    // MARK: - ログ

    private func appendLog(_ message: String) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm:ss"

        let time = formatter.string(from: Date())
        let line = "[\(time)] \(message)"
        DispatchQueue.main.async {
            self.logMessages.insert(line, at: 0)
        }
    }

    private func shortDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    // MARK: - 保存/読み込み（ルールのみ保存）

    private func saveAlarmRules() {
        do {
            let data = try JSONEncoder().encode(alarmRules)
            UserDefaults.standard.set(data, forKey: alarmsUserDefaultsKey)
        } catch {
            appendLog("アラーム保存に失敗: \(error.localizedDescription)")
        }
    }

    private func loadSavedAlarms() {
        guard let data = UserDefaults.standard.data(forKey: alarmsUserDefaultsKey) else {
            alarmRules = []
            return
        }

        do {
            let decoded = try JSONDecoder().decode([AlarmRule].self, from: data)
            alarmRules = decoded
            appendLog("保存済みアラーム読み込み: \(decoded.count)件")
        } catch {
            appendLog("アラーム読み込みに失敗: \(error.localizedDescription)")
            alarmRules = []
        }
    }

    // MARK: - 通知まわり

    private func requestNotificationPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.notificationPermissionGranted = granted
                if let error = error {
                    self?.appendLog("通知許可エラー: \(error.localizedDescription)")
                } else {
                    self?.appendLog("通知許可: \(granted ? "許可" : "未許可")")
                }

                if granted {
                    self?.rescheduleAllAlarms()
                }
            }
        }
    }

    /// すべてのアラームに対して、今後数日分の通知を再登録
    private func rescheduleAllAlarms() {
        guard notificationPermissionGranted else {
            appendLog("通知権限がないため、再スケジュールをスキップ")
            return
        }

        notificationCenter.removeAllPendingNotificationRequests()

        let daysAhead = 30
        let today = calendar.startOfDay(for: Date())

        for rule in alarmRules {
            for offset in 0..<daysAhead {
                guard let targetDate = calendar.date(byAdding: .day, value: offset, to: today) else { continue }

                if shouldFire(rule: rule, on: targetDate) {
                    scheduleNotification(for: rule, on: targetDate)
                }
            }
        }

        appendLog("通知を再スケジュールしました。アラーム数: \(alarmRules.count)")
    }

    /// そのルールが、指定日に鳴るべきかどうか（1日だけOFFも考慮）
    private func shouldFire(rule: AlarmRule, on date: Date) -> Bool {
        // その日だけOFFなら鳴らさない
        if !isAlarmEnabled(rule, on: date) {
            return false
        }

        let weekday = calendar.component(.weekday, from: date) // 1=日曜〜7=土曜

        if rule.weekdaysOnly {
            // 月〜金 かつ 祝日ではない
            let isWeekday = (2...6).contains(weekday)
            if !isWeekday { return false }
            if isHoliday(date: date) { return false }
        }

        return true
    }

    /// 実際に UNUserNotificationCenter に通知を登録
    private func scheduleNotification(for rule: AlarmRule, on date: Date) {
        let time = timeFor(rule, on: date)

        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = time.hour
        components.minute = time.minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = "アラーム"
        content.body = rule.weekdaysOnly ? "平日アラーム \(rule.timeString)" : "アラーム \(rule.timeString)"
        content.sound = rule.snoozeEnabled ? UNNotificationSound.defaultCritical : UNNotificationSound.default

        let id = "alarm-\(rule.id.uuidString)-\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        notificationCenter.add(request) { [weak self] error in
            if let error = error {
                self?.appendLog("通知登録エラー: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - 祝日 EventKit まわり

    private func requestCalendarAccessAndLoadHolidays() {
        eventStore.requestAccess(to: .event) { [weak self] granted, error in
            if let error = error {
                self?.appendLog("カレンダーアクセスエラー: \(error.localizedDescription)")
            }
            guard granted else {
                self?.appendLog("カレンダーアクセスが拒否されました（祝日連携なしで動作）")
                return
            }
            self?.loadJapaneseHolidays()
        }
    }

    /// iOS標準の「日本の祝日」カレンダーから祝日データを読み込む
    private func loadJapaneseHolidays() {
        let now = Date()
        guard
            let start = calendar.date(byAdding: .year, value: -1, to: now),
            let end = calendar.date(byAdding: .year, value: 1, to: now)
        else { return }

        let holidayCalendars = eventStore.calendars(for: .event).filter {
            $0.title.contains("祝日") || $0.title.contains("Japanese Holidays")
        }

        if holidayCalendars.isEmpty {
            appendLog("祝日カレンダーが見つかりませんでした")
            return
        }

        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: holidayCalendars)
        let events = eventStore.events(matching: predicate)

        var set: Set<Date> = []
        for event in events {
            let day = calendar.startOfDay(for: event.startDate)
            set.insert(day)
        }

        DispatchQueue.main.async {
            self.holidayDates = set
            self.appendLog("祝日データ読み込み完了: \(set.count)日")
            self.rescheduleAllAlarms()
        }
    }
}
