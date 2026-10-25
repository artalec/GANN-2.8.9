import SwiftUI
import AVFoundation

/// Технические параметры файла трека.
struct TrackTechInfo: Equatable {
    let bitrateKbps: Int?
    let sampleRate: Double?
    let channels: Int?
    let sizeBytes: Int64?
}

/// Читает параметры файла. Вызывать вне главного потока.
enum TrackTechLoader {

    static func load(url: URL) async -> TrackTechInfo {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            return TrackTechInfo(bitrateKbps: nil, sampleRate: nil, channels: nil, sizeBytes: nil)
        }

        let attrs = try? fm.attributesOfItem(atPath: url.path)
        let size = (attrs?[.size] as? NSNumber)?.int64Value

        var sampleRate: Double?
        var channels: Int?
        var duration: Double = 0
        if let file = try? AVAudioFile(forReading: url) {
            let format = file.processingFormat
            sampleRate = format.sampleRate
            channels = Int(format.channelCount)
            if format.sampleRate > 0 {
                duration = Double(file.length) / format.sampleRate
            }
        }

        // Битрейт из заголовка аудиодорожки. Если его нет (WAV, AIFF), считаем по размеру и длительности.
        var bitrate: Int?
        let asset = AVURLAsset(url: url)
        if let track = try? await asset.loadTracks(withMediaType: .audio).first,
           let rate = try? await track.load(.estimatedDataRate), rate > 0 {
            bitrate = Int((Double(rate) / 1000).rounded())
        }
        if bitrate == nil, let size, duration > 0 {
            bitrate = Int((Double(size) * 8 / duration / 1000).rounded())
        }

        return TrackTechInfo(bitrateKbps: bitrate, sampleRate: sampleRate,
                             channels: channels, sizeBytes: size)
    }
}

/// Нижняя строка окна: параметры выделенного трека (или играющего, если ничего не выделено).
struct TrackInfoBar: View {

    @EnvironmentObject private var model: AppModel
    @State private var info: TrackTechInfo?

    /// Ключ для перезагрузки: меняется при выборе другого трека или замене файла.
    private var taskKey: String {
        guard let track = model.displayedTrack else { return "" }
        return "\(track.id.uuidString)|\(track.path)"
    }

    var body: some View {
        HStack(spacing: 8) {
            if let track = model.displayedTrack {
                let playing = model.audioEngine.currentTrack?.id == track.id
                Text(playing ? "Сейчас:" : "Выбрано:")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(track.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 8)

                if let info, info.sizeBytes != nil {
                    Text(techLine(info))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if info != nil {
                    Text("файл не найден").foregroundStyle(Color.red)
                } else {
                    Text("загрузка…").foregroundStyle(.secondary)
                }
            } else {
                Text("Трек не выбран")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .frame(height: 28)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .background(GANNTheme.bg0)
        .task(id: taskKey) {
            info = nil
            guard let track = model.displayedTrack else { return }
            let url = track.url
            let loaded = await Task.detached(priority: .utility) {
                await TrackTechLoader.load(url: url)
            }.value
            if !Task.isCancelled { info = loaded }
        }
    }

    /// «Битрейт 320 kbps · Частота 48.0 kHz · Стерео · 150,7 MB».
    private func techLine(_ info: TrackTechInfo) -> String {
        var parts: [String] = []
        parts.append("Битрейт " + (info.bitrateKbps.map { "\($0) kbps" } ?? "—"))
        parts.append("Частота " + (info.sampleRate.map { TrackFormat.sampleRate($0) } ?? "—"))
        if let channels = TrackFormat.channels(info.channels) { parts.append(channels) }
        if let size = info.sizeBytes { parts.append(TrackFormat.megabytes(size)) }
        return parts.joined(separator: " · ")
    }
}
