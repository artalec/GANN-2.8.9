import SwiftUI

extension RGBAColor {
    var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}

extension TimeInterval {
    var timecode: String {
        let total = Int(self)
        let seconds = total % 60
        let minutes = (total / 60) % 60
        let hours = total / 3600
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Палитра макета (CSS :root)

extension Color {
    /// Цвет из шестнадцатеричного значения 0xRRGGBB.
    init(gannHex hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

enum GANNTheme {
    /// Фон окна, заголовков и строки статуса.
    static let bg0 = Color(gannHex: 0x121214)
    /// Основной фон панелей.
    static let bg1 = Color(gannHex: 0x1A1A1D)
    /// Боковая панель, карточки эффектов.
    static let bg2 = Color(gannHex: 0x222226)
    /// Поля поиска, кнопки, подсветка наведения.
    static let bg3 = Color(gannHex: 0x2B2B30)
    /// Границы и разделители.
    static let stroke = Color(gannHex: 0x34343A)

    static let text1 = Color(gannHex: 0xF2F2F5)
    static let text2 = Color(gannHex: 0xA3A3AD)
    static let text3 = Color(gannHex: 0x6E6E78)

    /// Акцент интерфейса: выбранные строки, включённые режимы, основные кнопки.
    static let accent = Color(gannHex: 0x5B8DFF)
    static let accentSoft = Color(gannHex: 0x5B8DFF, opacity: 0.14)
}

/// Кнопка с тонкой рамкой (как «Загрузить» и «Сохранить» в макете).
struct GANNGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(GANNTheme.text2)
            .background(RoundedRectangle(cornerRadius: 6).stroke(GANNTheme.stroke, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Rectangle())
    }
}

/// Общая анимация перестановки: плейлисты и треки двигаются одинаково.
enum GANNMotion {
    static let reorder = Animation.easeInOut(duration: 0.18)
}

/// Ползунок в стиле макета: тонкая тёмная дорожка и белый маркер.
struct GANNSlider: View {
    let value: Double
    let range: ClosedRange<Double>
    var enabled: Bool = true
    let onChange: (Double) -> Void

    private let knob: CGFloat = 12

    var body: some View {
        GeometryReader { geo in
            let track = max(geo.size.width - knob, 1)
            let span = range.upperBound - range.lowerBound
            let fraction = span > 0 ? CGFloat((value - range.lowerBound) / span) : 0
            let clamped = min(max(fraction, 0), 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(GANNTheme.bg3)
                    .frame(height: 4)
                    .padding(.horizontal, knob / 2)
                Circle()
                    .fill(Color.white)
                    .frame(width: knob, height: knob)
                    .offset(x: clamped * track)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard enabled else { return }
                        let f = min(max((drag.location.x - knob / 2) / track, 0), 1)
                        onChange(range.lowerBound + Double(f) * span)
                    }
            )
        }
        .frame(height: knob + 2)
        .opacity(enabled ? 1 : 0.4)
    }
}

/// Переключатель в стиле макета: синяя капсула, белый маркер.
struct GANNSwitch: View {
    let isOn: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            ZStack {
                Capsule()
                    .fill(isOn ? GANNTheme.accent : GANNTheme.bg3)
                    .frame(width: 34, height: 20)
                Circle()
                    .fill(Color.white)
                    .frame(width: 16, height: 16)
                    .offset(x: isOn ? 7 : -7)
            }
            .animation(GANNMotion.reorder, value: isOn)
        }
        .buttonStyle(.plain)
    }
}
