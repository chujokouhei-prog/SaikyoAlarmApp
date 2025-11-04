// CustomCalendarView.swift

import SwiftUI

struct CustomCalendarView: View {
    @ObservedObject var viewModel: AppViewModel
    
    // 表示モード（アラーム予定 / 休日設定）
    enum CalendarDisplayMode: String, CaseIterable, Identifiable {
        case alarms
        case holidays
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .alarms:   return "アラーム予定"
            case .holidays: return "休日設定"
            }
        }
        
        /// モードごとの説明テキスト
        var description: String {
            switch self {
            case .alarms:
                return "アラームが設定されている日を確認できます。"
            case .holidays:
                return "タップした日付を「独自の休み」としてON/OFFできます。"
            }
        }
        
        /// モードごとのアイコン
        var systemImageName: String {
            switch self {
            case .alarms:   return "alarm"
            case .holidays: return "beach.umbrella"
            }
        }
    }
    
    @State private var displayMode: CalendarDisplayMode = .alarms
    
    var body: some View {
        NavigationView {
            ZStack {
                // 画面全体の背景
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // 今日の日付
                    todayHeader
                    
                    // 表示モード切り替え
                    modePicker
                    
                    // カレンダー部分（カード風）
                    calendarCard
                    
                    // 下部の説明・リスト
                    Group {
                        switch displayMode {
                        case .alarms:
                            alarmInfoSection
                        case .holidays:
                            holidayInfoSection
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 8)
                }
            }
            .navigationTitle("カレンダー")
        }
    }
    
    // MARK: - 上部 UI（今日＋モード切替）
    
    /// 「今日：3/5(水)」の表示
    private var todayHeader: some View {
        HStack {
            Text("今日：")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(formattedDate(Date()))
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    /// アラーム予定 / 休日設定 の切替ピッカー
    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker("表示モード", selection: $displayMode) {
                ForEach(CalendarDisplayMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            
            HStack(spacing: 6) {
                Image(systemName: displayMode.systemImageName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(displayMode.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - カレンダーカード
    
    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            // カード上部のタイトル
            HStack {
                Text(displayMode == .alarms ? "アラームカレンダー" : "休日カレンダー")
                    .font(.headline)
                Spacer()
            }
            
            // カレンダー本体
            MultiDatePicker(
                "カレンダー",
                selection: calendarSelectionBinding
            )
            .tint(displayMode == .alarms ? .blue : .green) // モードに応じて色を変える
            
            // 凡例（レジェンド）
            legendView
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal)
        .padding(.top, 4)
    }
    
    /// モードに応じた凡例
    private var legendView: some View {
        HStack(spacing: 16) {
            if displayMode == .alarms {
                legendItem(color: .blue, text: "アラームがある日")
            } else {
                legendItem(color: .green, text: "独自の休み")
            }
            Spacer()
        }
        .font(.caption2)
        .foregroundColor(.secondary)
        .padding(.top, 4)
    }
    
    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(text)
        }
    }
    
    // MARK: - カレンダーに渡す Binding
    
    /// 表示モードによって、バインドするデータセットを切り替える
    private var calendarSelectionBinding: Binding<Set<DateComponents>> {
        switch displayMode {
        case .alarms:
            // アラーム予定モードでは「表示専用」
            return Binding(
                get: { viewModel.alarmDates },
                set: { _ in }
            )
        case .holidays:
            // 休日設定モードでは、「タップ＝customHolidaysのON/OFF」
            return Binding(
                get: { viewModel.customHolidays },
                set: { newValue in
                    viewModel.customHolidays = newValue
                }
            )
        }
    }
    
    // MARK: - アラーム予定モードの下部表示
    
    private var alarmInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.alarmDates.isEmpty {
                Text("現在セットされているアラームはありません。")
                    .foregroundColor(.secondary)
            } else {
                Text("アラームが設定されている日")
                    .font(.subheadline)
                    .bold()
                
                List {
                    ForEach(sortedAlarmDates, id: \.self) { comps in
                        if let date = Calendar.current.date(from: comps) {
                            HStack {
                                Image(systemName: "bell.fill")
                                    .foregroundColor(.blue)
                                Text(formattedDate(date))
                                Spacer()
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .frame(maxHeight: 220)
            }
        }
    }
    
    // MARK: - 休日設定モードの下部表示
    
    private var holidayInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("登録した「独自の休み」は、平日専用アラームの対象外になります。")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if viewModel.customHolidays.isEmpty {
                Text("登録されている独自の休みはありません。")
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            } else {
                Text("登録済みの独自の休み")
                    .font(.subheadline)
                    .bold()
                
                List {
                    ForEach(sortedCustomHolidays, id: \.self) { comps in
                        if let date = Calendar.current.date(from: comps) {
                            HStack {
                                Image(systemName: "beach.umbrella.fill")
                                    .foregroundColor(.green)
                                Text(formattedDate(date))
                                Spacer()
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .frame(maxHeight: 220)
            }
        }
    }
    
    // MARK: - 並び替えと日付フォーマット
    
    /// alarmDates を日付順にソート
    private var sortedAlarmDates: [DateComponents] {
        sortDateComponents(viewModel.alarmDates)
    }
    
    /// customHolidays を日付順にソート
    private var sortedCustomHolidays: [DateComponents] {
        sortDateComponents(viewModel.customHolidays)
    }
    
    /// 共通：Set<DateComponents> を日付順に並べ替える
    private func sortDateComponents(_ set: Set<DateComponents>) -> [DateComponents] {
        let calendar = Calendar.current
        return set.sorted { lhs, rhs in
            guard let d1 = calendar.date(from: lhs),
                  let d2 = calendar.date(from: rhs) else { return false }
            return d1 < d2
        }
    }
    
    /// 例: 3/5 (水) のような表示
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d (EEE)"
        return formatter.string(from: date)
    }
}

