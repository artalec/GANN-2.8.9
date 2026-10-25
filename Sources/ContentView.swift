import SwiftUI
import AppKit

/// Главное окно.
///
/// Раскладка:
///   слева  — список плейлистов
///   справа — waveform с маркерами обрезки, панель управления, список треков
struct ContentView: View {

    @EnvironmentObject private var model: AppModel

    var body: some View {
        mainContent
            .toolbar {
                // Верхняя панель: громкость и устройство вывода — справа, рядом с системными кнопками окна.
                ToolbarItemGroup(placement: .primaryAction) {
                    volumeToolbar
                    deviceToolbar
                }
            }
    }

    /// Значок громкости в контурном стиле, как в макете.
    private var volumeIcon: String {
        let v = model.state.settings.volume
        if v <= 0.001 { return "speaker.slash" }
        if v < 0.5 { return "speaker.wave.1" }
        return "speaker.wave.2"
    }

    /// Громкость в верхней панели: значок, ползунок, проценты.
    /// Громкость: контурный значок, тонкий ползунок, проценты серым моноширинным шрифтом.
    private var volumeToolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: volumeIcon)
                .font(.system(size: 13))
                .foregroundStyle(GANNTheme.text2)
            GANNSlider(value: model.state.settings.volume, range: 0...1) { value in
                model.setVolume(value)
            }
            .frame(width: 130)
            Text("\(Int(model.state.settings.volume * 100))%")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(GANNTheme.text3)
                .frame(width: 36, alignment: .trailing)
        }
        .help("Громкость")
    }

    /// Устройство вывода в верхней панели.
    /// Выбор устройства: тёмная пилюля с названием и стрелками, список открывается меню.
    private var deviceToolbar: some View {
        Menu {
            Button {
                model.setOutputDevice(nil)
            } label: {
                Text(model.outputDeviceSelection == nil ? "✓  Системное по умолчанию" : "Системное по умолчанию")
            }
            Divider()
            ForEach(model.outputDevices) { device in
                Button {
                    model.setOutputDevice(device.uid)
                } label: {
                    Text(model.outputDeviceSelection == device.uid ? "✓  \(device.name)" : device.name)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "hifispeaker")
                    .font(.system(size: 12))
                    .foregroundStyle(GANNTheme.text2)
                Text(currentDeviceName)
                    .font(.system(size: 12))
                    .foregroundStyle(GANNTheme.text1)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(GANNTheme.text3)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 7).fill(GANNTheme.bg2))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(GANNTheme.stroke, lineWidth: 1))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Устройство, через которое играет плеер")
    }

    /// Название выбранного устройства или «Системное по умолчанию».
    private var currentDeviceName: String {
        guard let uid = model.outputDeviceSelection,
              let device = model.outputDevices.first(where: { $0.uid == uid }) else {
            return "Системное по умолчанию"
        }
        return device.name
    }

    private var mainContent: some View {
        HSplitView {
            if model.isSidebarVisible {
                PlaylistSidebar()
                    .frame(minWidth: 210, idealWidth: 250, maxWidth: 340)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            // Когда список плейлистов скрыт, этот блок остаётся единственным
            // в HSplitView и занимает всё окно.
            VStack(spacing: 0) {
                WaveformPanel(engine: model.audioEngine)
                Divider()
                TrackList()
                Divider()
                TrackInfoBar()
            }
            .frame(minWidth: 620)
            // Кнопка возврата списка: у левого края окна, по центру высоты.
            .overlay(alignment: .leading) {
                if !model.isSidebarVisible {
                    SidebarToggleButton(
                        systemName: "chevron.right",
                        help: "Показать список плейлистов",
                        action: { model.toggleSidebar() }
                    )
                }
            }
        }
        .frame(minWidth: 880, minHeight: 640)
        .animation(.easeInOut(duration: 0.2), value: model.isSidebarVisible)
    }
}

/// Кнопка скрытия и показа списка плейлистов: стрелка на границе области.
struct SidebarToggleButton: View {

    let systemName: String
    let help: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 42)
                // RoundedRectangle, а не UnevenRoundedRectangle: последний появился
                // только в macOS 14, а проект собирается под macOS 13.
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(GANNTheme.bg3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                        )
                        .shadow(radius: 1)
                )
                .opacity(isHovering ? 1.0 : 0.75)
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Верхняя часть: информация, waveform, управление

private struct WaveformPanel: View {

    @EnvironmentObject private var model: AppModel
    /// Движок подписан напрямую: курсор меняется 20 раз в секунду, и перерисовывать
    /// из-за него всё окно не нужно.
    @ObservedObject var engine: AudioEngine

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                trackInfo
                Spacer(minLength: 8)
                effectControls
            }

            WaveformView(
                peaks: model.displayedWaveform,
                currentTime: progressTime,
                duration: displayedDuration,
                accent: displayedAccent,
                trimStart: displayedTrimStart,
                trimEnd: displayedTrimEnd,
                onSeek: { time, shouldPlay, crossfade in
                    model.seekDisplayed(to: time, thenPlay: shouldPlay, crossfade: crossfade)
                },
                onTrimChange: { start, end in
                    guard let track = model.displayedTrack else { return }
                    model.setTrim(for: track.id, start: start, end: end)
                }
            )
            .frame(height: 96)

            transportBar
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(GANNTheme.bg1)
    }

    // MARK: Данные для waveform

    private var displayedTrack: Track? { model.displayedTrack }

    private var displayedDuration: TimeInterval {
        displayedTrack?.duration ?? 0
    }

    private var displayedTrimStart: TimeInterval {
        displayedTrack?.trimStart ?? 0
    }

    private var displayedTrimEnd: TimeInterval {
        guard let track = displayedTrack else { return 0 }
        return track.trimEnd ?? track.duration
    }

    private var displayedAccent: RGBAColor {
        displayedTrack.map { model.accentColor(for: $0) } ?? RGBAColor(red: 0.2, green: 0.55, blue: 1.0)
    }

    /// Время для курсора: если играет этот трек — реальное, если это выбранный,
    /// но не играющий трек — сохранённая точка старта, иначе 0.
    private var progressTime: TimeInterval {
        guard let track = displayedTrack else { return 0 }
        if engine.currentTrack?.id == track.id {
            return engine.currentTime
        }
        return model.pendingStart(for: track.id)
    }

    // MARK: Информация о треке

    private var trackInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let track = displayedTrack {
                Text(track.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(engine.currentTrack?.id == track.id
                         ? engine.currentTime.timecode
                         : track.trimStart.timecode)
                    Text("/")
                    Text(track.effectiveDuration.timecode)

                    if engine.isTransitioning {
                        Text("· переход…").foregroundStyle(Color.orange)
                    }
                    if track.trimStart > 0 || track.trimEnd != nil {
                        Text("· Start \(track.trimStart.timecode)  End \((track.trimEnd ?? track.duration).timecode)")
                            .foregroundStyle(Color.cyan)
                    }
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
            } else {
                Text("Ничего не выбрано")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Выберите трек в списке")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 80, maxWidth: 340, alignment: .leading)
    }

    // MARK: Эффекты

    private var effectControls: some View {
        HStack(alignment: .top, spacing: 12) {
            // Focus Fade — слева от Crossfade.
            effectBlock(
                title: "Focus Fade",
                isOn: Binding(
                    get: { model.state.settings.focusFadeEnabled },
                    set: { value in model.updateSettings { $0.focusFadeEnabled = value } }
                ),
                help: "Плавно останавливает воспроизведение при переходе в другую программу и плавно возобновляет его при возвращении к плееру"
            ) {
                sliderRow(label: "время",
                          value: model.state.settings.focusFadeDuration,
                          range: 0.2...10,
                          enabled: model.state.settings.focusFadeEnabled) { value in
                    model.updateSettings { $0.focusFadeDuration = value }
                }
            }

            effectBlock(
                title: "Crossfade",
                isOn: Binding(
                    get: { model.state.settings.crossfadeEnabled },
                    set: { value in model.updateSettings { $0.crossfadeEnabled = value } }
                ),
                help: "Плавный переход между треками"
            ) {
                sliderRow(label: "переход",
                          value: model.state.settings.crossfadeDuration,
                          range: 0.5...15,
                          enabled: model.state.settings.crossfadeEnabled) { value in
                    model.updateSettings { $0.crossfadeDuration = value }
                }
            }

            effectBlock(
                title: "High-cut",
                isOn: Binding(
                    get: { model.state.settings.highCutEnabled },
                    set: { value in model.updateSettings { $0.highCutEnabled = value } }
                ),
                help: "Плавно уводит верхи у играющего трека, затем запускает следующий"
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    sliderRow(label: "эффект",
                              value: model.state.settings.highCutDuration,
                              range: 0.3...10,
                              enabled: model.state.settings.highCutEnabled) { value in
                        model.updateSettings { $0.highCutDuration = value }
                    }

                    sliderRow(label: "пауза",
                              value: model.state.settings.highCutPauseAfter,
                              range: 0...10,
                              enabled: model.state.settings.highCutEnabled) { value in
                        model.updateSettings { $0.highCutPauseAfter = value }
                    }
                }
            }
        }
        // Блоки не сжимаются и не переносятся: размер задан внутри effectBlock.
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(1)
    }

    /// Строка регулятора. Размеры фиксированы, текст не переносится:
    /// блоки эффектов должны выглядеть одинаково при любом размере окна.
    /// Строка регулятора: серая подпись, тонкий ползунок, значение моноширинным шрифтом.
    private func sliderRow(label: String,
                           value: Double,
                           range: ClosedRange<Double>,
                           enabled: Bool,
                           onChange: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(enabled ? GANNTheme.text2 : GANNTheme.text3)
                .lineLimit(1)
                .frame(width: 54, alignment: .leading)
            GANNSlider(value: value, range: range, enabled: enabled, onChange: onChange)
                .frame(maxWidth: .infinity)
            Text(String(format: "%.1f", value))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(enabled ? GANNTheme.text2 : GANNTheme.text3)
                .frame(width: 30, alignment: .trailing)
        }
    }

    /// Один блок эффекта: заголовок и регуляторы. Ширина фиксирована, поэтому
    /// при сжатии окна блок не сжимается и название не пропадает.
    /// Карточка эффекта: заголовок и переключатель в одной строке, ниже регуляторы.
    private func effectBlock<Content: View>(title: String,
                                            isOn: Binding<Bool>,
                                            help: String,
                                            @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(GANNTheme.text1)
                    .lineLimit(1)
                Spacer(minLength: 8)
                GANNSwitch(isOn: isOn.wrappedValue) {
                    isOn.wrappedValue = !isOn.wrappedValue
                }
            }
            content()
        }
        .padding(12)
        .frame(width: 200, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(GANNTheme.bg2))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(GANNTheme.stroke, lineWidth: 1))
        .help(help)
    }

    // MARK: Панель управления и громкость

    /// Нижняя панель: четыре блока делят ширину поровну, разделители фиксированы.
    private var transportBar: some View {
        HStack(spacing: 0) {
            transportButtons
                .frame(maxWidth: .infinity)
            Divider().frame(height: 22)
            playlistModeButtons
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    /// Предыдущий / Пауза / Играть / Стоп / Следующий — в этом порядке.
    private var transportButtons: some View {
        HStack(spacing: 8) {
            Button {
                model.playPrevious()
            } label: {
                Image(systemName: "backward.fill").frame(width: 20)
            }
            .help("Предыдущий трек")

            Button {
                model.audioEngine.pause()
            } label: {
                Image(systemName: "pause.fill").frame(width: 22)
            }
            .help("Пауза")
            .disabled(!model.audioEngine.isPlaying)

            Button {
                playSelectedOrResume()
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(GANNTheme.bg0)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(GANNTheme.text1))
            }
            .help("Воспроизвести выделенный или возобновить (Пробел)")

            Button {
                model.audioEngine.stop()
            } label: {
                Image(systemName: "stop.fill").frame(width: 20)
            }
            .help("Стоп (Esc)")

            Button {
                model.playNext()
            } label: {
                Image(systemName: "forward.fill").frame(width: 20)
            }
            .help("Следующий трек")
        }
        .buttonStyle(.borderless)
    }

    /// Три режима плейлиста: повтор трека, зацикливание плейлиста, автопереход.
    private var playlistModeButtons: some View {
        HStack(spacing: 6) {
            Toggle(isOn: Binding(
                get: { model.state.settings.loopTrackEnabled },
                set: { value in model.updateSettings { $0.loopTrackEnabled = value } }
            )) {
                Image(systemName: "repeat.1")
            }
            .toggleStyle(.button)
            .help("Зациклить текущий трек")

            Toggle(isOn: Binding(
                get: { model.selectedPlaylist?.loopEnabled ?? false },
                set: { model.setLoopPlaylist($0) }
            )) {
                Image(systemName: "repeat")
            }
            .toggleStyle(.button)
            .help("Зациклить плейлист")

            Toggle(isOn: Binding(
                get: { model.selectedPlaylist?.autoplayEnabled ?? false },
                set: { model.setAutoplay($0) }
            )) {
                Image(systemName: "arrow.forward.to.line")
            }
            .toggleStyle(.button)
            .help("Автоматически переходить к следующему треку")
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 10).fill(GANNTheme.bg2))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(GANNTheme.stroke, lineWidth: 1))
    }



    /// Запускает выделенный трек, иначе возобновляет текущий или запускает первый.
    private func playSelectedOrResume() {
        if let playlist = model.selectedPlaylist, !model.selection.isEmpty,
           let first = model.selection.selectedTracks(from: playlist.tracks).first {
            model.play(track: first)
            return
        }
        if engine.currentTrack != nil {
            engine.resume()
        } else {
            model.playFirstTrackOfSelectedPlaylist()
        }
    }

}
