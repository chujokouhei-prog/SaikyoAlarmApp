// HolidayManager.swift (修正版)

import Foundation
import EventKit
import Combine // ← 不足していた一行を追加しました！

@MainActor
class HolidayManager: ObservableObject {

    static let shared = HolidayManager()
    private let eventStore = EKEventStore()
    
    @Published private(set) var holidays: Set<DateComponents> = []
    @Published private(set) var customHolidays: Set<DateComponents> = []
    
    private let userDefaultsKey = "customHolidays"

    private init() {
        loadCustomHolidays()
        requestCalendarAccess()
    }

    private func requestCalendarAccess() {
        // 非同期処理としてカレンダーアクセスを実行
        Task {
            do {
                // カレンダーへのアクセス許可をリクエスト
                let granted = try await eventStore.requestFullAccessToEvents()
                if granted {
                    print("カレンダーへのアクセスが許可されました")
                    await self.loadJapaneseHolidays()
                } else {
                    print("カレンダーへのアクセスが拒否されました")
                }
            } catch {
                print("カレンダーへのアクセスリクエストでエラーが発生しました: \(error)")
            }
        }
    }
    
    private func loadJapaneseHolidays() async {
        let calendar = Calendar.current
        guard let startDate = calendar.date(from: DateComponents(year: calendar.component(.year, from: Date()), month: 1, day: 1)),
              let endDate = calendar.date(from: DateComponents(year: calendar.component(.year, from: Date()) + 1, month: 12, day: 31)) else {
            return
        }

        guard let holidayCalendar = eventStore.calendars(for: .event).first(where: { $0.title == "日本の祝日" }) else {
            print("日本の祝日カレンダーが見つかりません。")
            // 日本の祝日がなくても、独自休日だけで動作するように設定
            self.holidays = self.customHolidays
            return
        }

        // predicateForEventsは同期的であるため、Task内で実行する
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: [holidayCalendar])
        let events = eventStore.events(matching: predicate)
        
        let japaneseHolidays = events.map { calendar.dateComponents([.year, .month, .day], from: $0.startDate) }
        
        self.holidays = Set(japaneseHolidays).union(self.customHolidays)
        
        print("日本の祝日を読み込みました: \(japaneseHolidays.count)件")
    }
    
    func toggleCustomHoliday(date: Date) {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        
        if customHolidays.contains(components) {
            customHolidays.remove(components)
            holidays.remove(components)
        } else {
            customHolidays.insert(components)
            holidays.insert(components)
        }
        saveCustomHolidays()
    }

    func isHoliday(_ date: Date) -> Bool {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return holidays.contains(components)
    }
    
    private func loadCustomHolidays() {
        let defaults = UserDefaults.standard
        if let savedData = defaults.object(forKey: userDefaultsKey) as? Data {
            let decoder = JSONDecoder()
            if let loadedHolidays = try? decoder.decode(Set<DateComponents>.self, from: savedData) {
                self.customHolidays = loadedHolidays
                print("独自休日を読み込みました: \(loadedHolidays.count)件")
            }
        }
    }
    
    private func saveCustomHolidays() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(customHolidays) {
            let defaults = UserDefaults.standard
            defaults.set(encoded, forKey: userDefaultsKey)
            print("独自休日を保存しました: \(customHolidays.count)件")
        }
    }
}
