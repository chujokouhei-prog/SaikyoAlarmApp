import Foundation

/// 繰り返しの種類
enum RepeatStyle: String, Codable, CaseIterable, Identifiable {
    case none       // 繰り返しなし（単発）
    case weekdays   // 平日だけ
    case everyday   // 毎日
    case custom     // 好きな曜日だけ

    var id: String { rawValue }

    /// 画面に出すとき用の表示名
    var displayName: String {
        switch self {
        case .none: return "繰り返しなし"
        case .weekdays: return "平日"
        case .everyday: return "毎日"
        case .custom: return "カスタム"
        }
    }
}

/// アラーム1件分のデータ
struct Alarm: Identifiable, Codable, Hashable {
    /// 一意に識別するためのID（List表示などで使う）
    let id: UUID

    /// アラームの時間
    /// - 繰り返しアラームのときは「時刻」だけを使うイメージ
    /// - 単発アラームのときは「日付＋時刻」
    var time: Date

    /// 繰り返しの種類（なし / 平日 / 毎日 / カスタム）
    var repeatStyle: RepeatStyle

    /// カスタム繰り返しで使う曜日
    /// Calendarのweekdayと同じで 1=日曜, 2=月曜, ... , 7=土曜
    var customWeekdays: Set<Int>

    /// 日本の祝日は鳴らさないか
    var skipJapanHolidays: Bool

    /// ユーザーが設定した独自休日（年末年始・お盆など）は鳴らさないか
    var skipUserHolidays: Bool

    /// 「この日だけオフ」にした日付のリスト
    /// 年月日が同じなら同じ日とみなします
    var exceptionDates: [Date]

    /// アラーム全体のON / OFF
    var isEnabled: Bool

    // MARK: - 便利プロパティ

    /// 単発アラームかどうか（＝繰り返しなし）
    var isOneTime: Bool {
        repeatStyle == .none
    }

    /// このアラームが有効になる曜日一覧（繰り返しアラーム用）
    /// - 1=日曜, 2=月曜, ... , 7=土曜
    var activeWeekdays: Set<Int> {
        switch repeatStyle {
        case .none:
            return [] // 単発は曜日で管理しない
        case .everyday:
            return Set(1...7)
        case .weekdays:
            return Set(2...6) // 月〜金
        case .custom:
            return customWeekdays
        }
    }

    // MARK: - イニシャライザ

    init(
        id: UUID = UUID(),
        time: Date,
        repeatStyle: RepeatStyle = .none,
        customWeekdays: Set<Int> = [],
        skipJapanHolidays: Bool = false,
        skipUserHolidays: Bool = false,
        exceptionDates: [Date] = [],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.time = time
        self.repeatStyle = repeatStyle
        self.customWeekdays = customWeekdays
        self.skipJapanHolidays = skipJapanHolidays
        self.skipUserHolidays = skipUserHolidays
        self.exceptionDates = exceptionDates
        self.isEnabled = isEnabled
    }
}

