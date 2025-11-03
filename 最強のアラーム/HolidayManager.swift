// HolidayManager.swift

import Foundation
import EventKit

class HolidayManager {

    static let shared = HolidayManager()
    private let eventStore = EKEventStore()

    private var holidays: Set<DateComponents> = []

    // 1年分の祝日を取得して、日付の「成分」だけを保存しておく関数
    func loadHolidays() {
        let calendar = Calendar.current
        // 検索範囲は当年1月1日から来年12月31日までにする
        guard let startDate = calendar.date(from: DateComponents(year: calendar.component(.year, from: Date()), month: 1, day: 1)),
              let endDate = calendar.date(from: DateComponents(year: calendar.component(.year, from: Date()) + 1, month: 12, day: 31)) else {
            return
        }

        // 日本の祝日カレンダーを取得
        guard let holidayCalendar = eventStore.calendars(for: .event)
            .first(where: { $0.title == "日本の祝日" }) else {
            print("日本の祝日カレンダーが見つかりません。iPhoneの「カレンダー」アプリで日本の祝日を追加してください。")
            return
        }

        // 検索範囲を定義
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: [holidayCalendar])

        // イベント（祝日）を検索
        let events = eventStore.events(matching: predicate)
        
        // 取得した祝日の日付（年・月・日）をSetとして保存しておく
        self.holidays = Set(events.map { calendar.dateComponents([.year, .month, .day], from: $0.startDate) })
        
        print("祝日を読み込みました: \(self.holidays.count)件")
    }

    // 指定された日付が祝日かどうかを判定する関数
    func isHoliday(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        
        // 保存しておいた祝日リストに、同じ日付（年・月・日）が含まれているかチェック
        return holidays.contains(components)
    }
}
