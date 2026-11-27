import SwiftUI

/// 主界面：Apple Music 跟随 + LRCLIB 歌词 + 浮窗开关。
struct ContentView: View {
    @ObservedObject var engine: PlaybackEngine
    @ObservedObject var floating: FloatingWindowManager

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? ""
        let build = info?["CFBundleVersion"] as? String ?? ""
        return "\(short) (build \(build))"
    }

    private func timeText(_ time: TimeInterval) -> String {
        guard time.isFinite, time >= 0 else { return "--:--" }
        let total = Int(time)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var rawTimeText: String {
        engine.rawPlaybackTime.isNaN ? "NaN" : timeText(engine.rawPlaybackTime)
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 12) {
                // 当前歌曲
                GroupBox {
                    if engine.hasTrack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(engine.title)
                                .font(.title3)
                                .fontWeight(.bold)
                                .lineLimit(2)
                            Text("\(engine.artist) — \(engine.album)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                            Text("状态：\(engine.stateLabel)")
                                .font(.subheadline)
                            ProgressView(
                                value: engine.duration > 0
                                    ? min(engine.estimatedProgress, engine.duration)
                                    : 0,
                                total: engine.duration > 0 ? engine.duration : 1
                            )
                            HStack {
                                Text(timeText(engine.estimatedProgress))
                                Spacer()
                                Text("进度为估算")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(timeText(engine.duration))
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            Text("系统原始进度：\(rawTimeText)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("未在播放")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("请在 Apple Music 里播放一首歌")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("系统原始进度：\(rawTimeText)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // 浮窗开关
                GroupBox {
                    Toggle("应用内浮窗", isOn: Binding(
                        get: { floating.isEnabled },
                        set: { floating.setEnabled($0, engine: engine) }
                    ))
                    Text("仅在应用内显示，可拖动；切出应用即消失，不是系统悬浮窗。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // 歌词区
                GroupBox {
                    HStack {
                        Text("歌词")
                            .font(.headline)
                        Spacer()
                        Text(engine.lyricsStatusText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    lyricsBody
                }

                Spacer()
                Text("LC歌词 \(versionText) · 仅支持 Apple Music · 进度为估算 · 浮窗仅应用内有效")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
            .navigationTitle("LC歌词")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }

    @ViewBuilder
    private var lyricsBody: some View {
        switch engine.lyricsState {
        case .idle:
            Text("等 Apple Music 播放后自动查歌词")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .loading:
            HStack {
                ProgressView()
                Text("正在查歌词…")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .synced:
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(engine.syncedLines.enumerated()), id: \.element.id) { index, line in
                            Text(line.text.isEmpty ? "♪" : line.text)
                                .font(index == engine.currentLineIndex ? .headline : .body)
                                .fontWeight(index == engine.currentLineIndex ? .bold : .regular)
                                .foregroundColor(index == engine.currentLineIndex ? .accentColor : .primary)
                                .id(line.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: engine.currentLineIndex) { index in
                    guard index >= 0, index < engine.syncedLines.count else { return }
                    withAnimation {
                        proxy.scrollTo(engine.syncedLines[index].id, anchor: .center)
                    }
                }
            }
        case .plain:
            ScrollView {
                Text(engine.plainLyrics)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .none:
            Text("暂无歌词")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
