// CalendarView.swift (完全修正版)

import SwiftUI
import Combine

struct CalendarView: View {
    @StateObject private var calendarViewModel = CalendarViewModel()
    @StateObject private var holidayManager = HolidayManager.shared

    var body: some View {
        NavigationView {
            CalendarRepresentable(
                alarmDates: $calendarViewModel.alarmDates,
                holidayManager: holidayManager
            )
            .navigationTitle("アラーム予定")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("リロード") {
                        calendarViewModel.loadScheduledAlarms()
                    }
                }
            }
        }
    }
}

@MainActor
class CalendarViewModel: ObservableObject {
    @Published var alarmDates: [Date] = []

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(loadScheduledAlarms),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        loadScheduledAlarms()
    }

    @objc func loadScheduledAlarms() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let calendar = Calendar.current
            let dates = requests.compactMap { request -> Date? in
                guard let trigger = request.trigger as? UNCalendarNotificationTrigger,
                      let nextTriggerDate = trigger.nextTriggerDate() else { return nil }
                let components = calendar.dateComponents([.year, .month, .day], from: nextTriggerDate)
                return calendar.date(from: components)
            }
            self.alarmDates = Array(Set(dates))
        }
    }
}

struct CalendarRepresentable: UIViewRepresentable {
    @Binding var alarmDates: [Date]
    @ObservedObject var holidayManager: HolidayManager

    func makeUIView(context: Context) -> UICalendarView {
        let calendarView = UICalendarView()
        calendarView.calendar = .current
        calendarView.locale = .current
        calendarView.fontDesign = .rounded
        
        let selection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        calendarView.selectionBehavior = selection
        
        // Coordinatorにビュー自身とHolidayManagerを渡す
        context.coordinator.calendarView = calendarView
        context.coordinator.holidayManager = holidayManager
        
        return calendarView
    }

    // --- ここが修正された部分 ---
    func updateUIView(_ uiView: UICalendarView, context: Context) {
        // Coordinatorに最新のデータを渡す
        context.coordinator.alarmDates = self.alarmDates
        
        // アラームの日付と独自休日の日付を結合して、更新が必要な日付のリストを作成
        let alarmDateComponents = self.alarmDates.map {
            Calendar.current.dateComponents([.year, .month, .day], from: $0)
        }
        let allHolidayComponents = Array(holidayManager.holidays)
        
        // 重複を除外して全ての日付コンポーネントを結合
        let componentsToReload = Array(Set(alarmDateComponents + allHolidayComponents))
        
        // 正しい引数名でデコレーションをリロード
        uiView.reloadDecorations(forDateComponents: componentsToReload, animated: true)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        weak var calendarView: UICalendarView?
        weak var holidayManager: HolidayManager? // HolidayManagerを弱参照で保持
        var alarmDates: [Date] = []
        private let calendar = Calendar.current
        
        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            guard let dateComponents = dateComponents,
                  let date = calendar.date(from: dateComponents) else { return }

            // holidayManagerのメソッドを安全に呼び出す
            holidayManager?.toggleCustomHoliday(date: date)
            
            selection.setSelected(nil, animated: true)
        }

        @MainActor
        func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            let isAlarmDay = self.alarmDates.contains { date in
                let components = self.calendar.dateComponents([.year, .month, .day], from: date)
                return components.year == dateComponents.year &&
                       components.month == dateComponents.month &&
                       components.day == dateComponents.day
            }
            
            // holidayManagerから安全にcustomHolidaysを取得
            let isCustomHoliday = self.holidayManager?.customHolidays.contains(dateComponents) ?? false

            if isAlarmDay && isCustomHoliday {
                return .default(color: .systemPurple)
            } else if isAlarmDay {
                return .default(color: .systemBlue)
            } else if isCustomHoliday {
                return .default(color: .systemGreen)
            } else {
                return nil
            }
        }
    }
}
