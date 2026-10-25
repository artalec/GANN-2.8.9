import Foundation

/// Форматирование параметров трека для нижней строки. Без SwiftUI, чтобы проверяться отдельно.
enum TrackFormat {

    /// Размер файла: «150,7 MB» (один знак, запятая как в русской записи).
    static func megabytes(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.1f", mb).replacingOccurrences(of: ".", with: ",") + " MB"
    }

    /// Частота дискретизации: «48.0 kHz».
    static func sampleRate(_ hz: Double) -> String {
        String(format: "%.1f kHz", hz / 1000)
    }

    /// Каналы словами, как в макете: «Стерео», «Моно», иначе «N кан.».
    static func channels(_ count: Int?) -> String? {
        switch count {
        case .none: return nil
        case 1: return "Моно"
        case 2: return "Стерео"
        case .some(let n): return "\(n) кан."
        }
    }
}

/// Поиск по названию плейлистов в боковой панели.
/// Пустой запрос — весь список, без учёта регистра и лишних пробелов.
enum PlaylistFilter {

    static func filter<T>(_ items: [T], query: String, name: (T) -> String) -> [T] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return items }
        return items.filter { name($0).localizedCaseInsensitiveContains(needle) }
    }
}
