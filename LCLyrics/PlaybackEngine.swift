import Foundation
import MediaPlayer

/// v0.2 播放跟随引擎：只用公开接口 MPMusicPlayerController.systemMusicPlayer。
///
/// 已证事实（LCProbe T2/T3，设备实测）：
/// - 能读 Apple Music 的歌名/歌手/专辑/时长/播放状态；
/// - currentPlaybackTime 永远是 NaN，进度必须用墙钟估算；
/// - state=0（已停止）时仍会返回上首歌的旧标题，只认 state 1/2 时的标题。
/// 绝不调用任何私有播放接口。
final class PlaybackEngine: ObservableObject {

    enum LyricsState {
        case idle
        case loading
        case synced
        case plain
        case none
    }

    @Published var hasTrack = false
    @Published var title = ""
    @Published var artist = ""
    @Published var album = ""
    @Published var duration: TimeInterval = 0
    @Published var stateRaw = 0
    @Published var stateLabel = "未在播放"
    @Published var estimatedProgress: TimeInterval = 0
    @Published var rawPlaybackTime: TimeInterval = .nan
    @Published var lyricsState: LyricsState = .idle
    @Published var lyricsStatusText = ""
    @Published var syncedLines: [LyricLine] = []
    @Published var plainLyrics = ""
    @Published var currentLineIndex = -1

    /// 浮窗显示的当前行文本（同步歌词优先，没有就取纯文本第一行）。
    var currentLyricText: String {
        if !syncedLines.isEmpty, currentLineIndex >= 0, currentLineIndex < syncedLines.count {
            return syncedLines[currentLineIndex].text
        }
        if !plainLyrics.isEmpty {
            return plainLyrics.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .first { !$0.isEmpty } ?? ""
        }
        return ""
    }

    private let player = MPMusicPlayerController.systemMusicPlayer
    private var timer: Timer?
    private var lastTick = Date()
    private var currentIdentity = ""
    private var lyricsTask: Task<Void, Never>?

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        tick()
    }

    deinit {
        timer?.invalidate()
        lyricsTask?.cancel()
    }

    private func label(for state: MPMusicPlaybackState) -> String {
        switch state {
        case .stopped: return "已停止"
        case .playing: return "正在播放"
        case .paused: return "已暂停"
        case .interrupted: return "被打断"
        case .seekingForward: return "快进中"
        case .seekingBackward: return "快退中"
        default: return "未知"
        }
    }

    private func trackIdentity(of item: MPMediaItem) -> String {
        let pid = item.persistentID
        if pid != 0 {
            return "id:\(pid)"
        }
        return "t:\(item.title ?? "")|\(item.artist ?? "")|\(item.albumTitle ?? "")"
    }

    private func tick() {
        let now = Date()
        let state = player.playbackState
        let item = player.nowPlayingItem
        rawPlaybackTime = player.currentPlaybackTime
        stateRaw = state.rawValue
        stateLabel = label(for: state)

        // 只认 state 1（播放）/2（暂停）时的标题；state=0 的旧标题不认。
        let valid = (state == .playing || state == .paused) && item?.title != nil
        if !valid {
            if hasTrack {
                hasTrack = false
                title = ""
                artist = ""
                album = ""
                duration = 0
                estimatedProgress = 0
                syncedLines = []
                plainLyrics = ""
                currentLineIndex = -1
                lyricsState = .idle
                lyricsStatusText = ""
                currentIdentity = ""
                lyricsTask?.cancel()
            }
            lastTick = now
            return
        }

        guard let item = item else {
            lastTick = now
            return
        }

        let identity = trackIdentity(of: item)
        if identity != currentIdentity {
            currentIdentity = identity
            title = item.title ?? ""
            artist = item.artist ?? ""
            album = item.albumTitle ?? ""
            duration = item.playbackDuration
            estimatedProgress = 0
            hasTrack = true
            syncedLines = []
            plainLyrics = ""
            currentLineIndex = -1
            lyricsState = .loading
            lyricsStatusText = "正在查歌词…"
            lastTick = now
            fetchLyrics(
                title: title,
                artist: artist,
                album: album,
                duration: duration,
                identity: identity
            )
        } else if state == .playing {
            // 墙钟估算：系统不提供真实进度，按播放中的墙钟累加；暂停时冻结。
            estimatedProgress += now.timeIntervalSince(lastTick)
            if duration > 0, estimatedProgress > duration {
                estimatedProgress = duration
            }
        }
        lastTick = now
        updateCurrentLine()
    }

    private func updateCurrentLine() {
        guard !syncedLines.isEmpty else {
            currentLineIndex = -1
            return
        }
        var index = -1
        for (i, line) in syncedLines.enumerated() {
            if line.time <= estimatedProgress {
                index = i
            } else {
                break
            }
        }
        currentLineIndex = index
    }

    private func fetchLyrics(
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval,
        identity: String
    ) {
        lyricsTask?.cancel()
        lyricsTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let record = try await LRCLibClient.shared.fetchBest(
                    title: title,
                    artist: artist,
                    album: album,
                    duration: duration
                )
                guard self.currentIdentity == identity else { return }
                if let synced = record.syncedLyrics, !synced.isEmpty {
                    let lines = LyricParser.parse(synced)
                    if lines.isEmpty {
                        self.applyPlain(record)
                    } else {
                        self.syncedLines = lines
                        self.lyricsState = .synced
                        self.lyricsStatusText = "同步歌词"
                        self.updateCurrentLine()
                    }
                } else {
                    self.applyPlain(record)
                }
            } catch {
                guard self.currentIdentity == identity else { return }
                self.lyricsState = .none
                self.lyricsStatusText = "暂无歌词"
            }
        }
    }

    private func applyPlain(_ record: LRCLyricsRecord) {
        if let plain = record.plainLyrics, !plain.isEmpty {
            plainLyrics = plain
            lyricsState = .plain
            lyricsStatusText = "纯文本歌词"
        } else {
            lyricsState = .none
            lyricsStatusText = "暂无歌词"
        }
    }
}
