// AlarmModel.swift
// アラームのモデルと ViewModel

import Foundation
import SwiftUI
import Combine

// MARK: - 1つのアラーム

struct AlarmItem: Identifiable, Codable, Equatable {
    let id: UUID
    var hour: Int
    var minute: Int
    var isEnabled: Bool
    /// 1 = 日, 2 = 月, ... 7 = 土
    var repeatWeekdays: Set<Int>
    var excludeJapaneseHolidays: Bool
    var soundName: String
    var snoozeEnabled: Bool
    /// 「この日だけ鳴らさない」日付（0時で揃えた Date）
    var disabledDates: Set<Date>

    init(
        id: UUID = UUID(),
        hour: Int,
        minute: Int,
        isEnabled: Bool = true,
        repeatWeekdays: Set<Int> = [2, 3, 4, 5, 6], // デフォルト平日
        excludeJapaneseHolidays: Bool = true,
        soundName: String = "標準",
        snoozeEnabled: Bool = true,
        disabledDates: Set<Date> = []
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.isEnabled = isEnabled
        self.repeatWeekdays = repeatWeekdays
        self.excludeJapaneseHolidays = excludeJapaneseHolidays
        self.soundName = soundName
        self.snoozeEnabled = snoozeEnabled
        self.disabledDates = disabledDates
    }
}

// MARK: - 表示用ヘルパー

extension AlarmItem {

    /// 例: "7:30"
    var timeString: String {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let calendar = Calendar.current
        let date = calendar.date(from: comps) ?? Date()

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "H:mm"
        return formatter.string(from: date)
    }

    /// DatePicker 用
    var timeAsDate: Date {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps) ?? Date()
    }

    /// DatePicker で選んだ時間を反映
    mutating func updateTime(from date: Date) {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        self.hour = comps.hour ?? 0
        self.minute = comps.minute ?? 0
    }

    /// 繰り返しの説明（例: "平日", "月火水", "なし"）
    var repeatDescription: String {
        if repeatWeekdays.isEmpty {
            return "なし"
        }

        let allDays = Set(1...7)
        if repeatWeekdays == allDays {
            return "毎日"
        }
        let weekdays: Set<Int> = [2, 3, 4, 5, 6]
        if repeatWeekdays == weekdays {
            return "平日"
        }
        let weekend: Set<Int> = [1, 7]
        if repeatWeekdays == weekend {
            return "週末"
        }

        let map: [Int: String] = [
            1: "日", 2: "月", 3: "火",
            4: "水", 5: "木", 6: "金", 7: "土"
        ]
        let sorted = repeatWeekdays.sorted()
        let symbols = sorted.compactMap { map[$0] }
        return symbols.joined()
    }

    /// 行の下の小さな説明文
    var detailText: String {
        var parts: [String] = []

        if !repeatWeekdays.isEmpty {
            parts.append(repeatDescription)
        }
        if excludeJapaneseHolidays {
            parts.append("祝日オフ")
        }
        parts.append(soundName)

        if parts.isEmpty {
            return "なし"
        } else {
            return parts.joined(separator: "・")
        }
    }

    /// 並び替え用（0〜1439）
    var totalMinutes: Int {
        hour * 60 + minute
    }
}

// MARK: - ViewModel 本体

class AlarmViewModel: ObservableObject {

    @Published var alarms: [AlarmItem] = []

    /// サウンド候補（とりあえず固定の文字列だけ）
    let availableSounds: [String] = [
        "標準", "ビープ", "ベル", "鳥のさえずり"
    ]

    init() {
        loadInitialData()
    }

    private func loadInitialData() {
        alarms = []
        // 必要ならここにデバッグ用ダミーを入れてもOK
    }

    /// 新規作成用のデフォルトアラーム
    func createNewAlarmTemplate() -> AlarmItem {
        AlarmItem(
            hour: 7,
            minute: 0,
            isEnabled: true,
            repeatWeekdays: [2, 3, 4, 5, 6], // 平日
            excludeJapaneseHolidays: true,
            soundName: "標準",
            snoozeEnabled: true,
            disabledDates: []
        )
    }

    // MARK: CRUD

    func add(alarm: AlarmItem) {
        alarms.append(alarm)
        sort()
    }

    func update(alarm: AlarmItem) {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        alarms[index] = alarm
        sort()
    }

    func delete(at offsets: IndexSet) {
        alarms.remove(atOffsets: offsets)
    }

    func toggleEnabled(id: AlarmItem.ID, isOn: Bool) {
        guard let index = alarms.firstIndex(where: { $0.id == id }) else { return }
        alarms[index].isEnabled = isOn
    }

    /// 「この日だけ鳴らさない/鳴らす」を更新
    func updateDisabledDate(for id: UUID, date: Date, enabled: Bool) {
        let day = Calendar.current.startOfDay(for: date)
        guard let index = alarms.firstIndex(where: { $0.id == id }) else { return }

        if enabled {
            // その日だけ ON にする → disabled から削除
            alarms[index].disabledDates.remove(day)
        } else {
            // その日だけ OFF にする → disabled に追加
            alarms[index].disabledDates.insert(day)
        }
    }

    private func sort() {
        alarms.sort { $0.totalMinutes < $1.totalMinutes }
    }
}
