import SwiftUI
import UIKit

/// 应用内浮窗：独立 UIWindow，只在应用内有效。
/// 不是系统悬浮窗，不支持锁屏、后台、跨应用。
final class FloatingWindowManager: ObservableObject {

    @Published var isEnabled = false

    private var window: UIWindow?
    private weak var engine: PlaybackEngine?

    func setEnabled(_ enabled: Bool, engine: PlaybackEngine) {
        isEnabled = enabled
        if enabled {
            show(engine: engine)
        } else {
            hide()
        }
    }

    private func show(engine: PlaybackEngine) {
        self.engine = engine
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return }

        if window == nil {
            let w = UIWindow(windowScene: scene)
            let width = min(scene.screen.bounds.width - 24, 500)
            w.frame = CGRect(x: 12, y: 64, width: width, height: 76)
            w.windowLevel = UIWindow.Level(
                rawValue: UIWindow.Level.statusBar.rawValue + 1
            )
            w.backgroundColor = .clear
            let host = UIHostingController(
                rootView: FloatingLyricsView(engine: engine, manager: self)
            )
            host.view.backgroundColor = .clear
            w.rootViewController = host
            let pan = UIPanGestureRecognizer(
                target: self,
                action: #selector(dragged(_:))
            )
            w.addGestureRecognizer(pan)
            window = w
        }
        window?.isHidden = false
    }

    private func hide() {
        window?.isHidden = true
    }

    @objc private func dragged(_ gesture: UIPanGestureRecognizer) {
        guard let w = window else { return }
        let translation = gesture.translation(in: w)
        var frame = w.frame
        frame.origin.x += translation.x
        frame.origin.y += translation.y
        let screen = w.windowScene?.screen.bounds ?? UIScreen.main.bounds
        frame.origin.x = min(max(frame.origin.x, 0), screen.width - frame.width)
        frame.origin.y = min(max(frame.origin.y, 0), screen.height - frame.height)
        w.frame = frame
        gesture.setTranslation(.zero, in: w)
    }
}

/// 浮窗内容：当前歌词行 + 歌名。
struct FloatingLyricsView: View {
    @ObservedObject var engine: PlaybackEngine
    @ObservedObject var manager: FloatingWindowManager

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(engine.hasTrack ? (engine.currentLyricText.isEmpty ? "♪" : engine.currentLyricText) : "未在播放")
                .font(.headline)
                .lineLimit(1)
                .foregroundColor(.white)
            Text(engine.hasTrack ? "\(engine.title) — \(engine.artist)" : "LC歌词 · Apple Music 跟随")
                .font(.caption)
                .lineLimit(1)
                .foregroundColor(.white.opacity(0.75))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.72))
        .cornerRadius(12)
    }
}
