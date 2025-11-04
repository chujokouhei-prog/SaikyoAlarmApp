// CustomCalendarView.swift

import SwiftUI

struct CustomCalendarView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var selectedDate: Date = Date()

    var body: some View {
        VStack(spacing: 24) {

            // ① 日付を選ぶカレンダー（表示専用）
            DatePicker(
                "日付を選択",
                selection: $selectedDate,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .padding(.horizontal)

            // ② 選択中の日付の説明
            VStack(spacing: 8) {
                Text(dateLabel(selectedDate))
                    .font(.headline)

                Text("この画面からは休日設定はできません。")
                    .font(.subheadline)

                Text("→ 休日の扱いはアプリのカレンダー画面の仕様に従います。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            Spacer()
        }
        .navigationTitle("カレンダー")
    }

    // MARK: - ヘルパー

    /// 画面に表示する日付のラベル（例: "2025年11月6日(木)"）
    private func dateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日(EEE)"
        return formatter.string(from: date)
    }
}
