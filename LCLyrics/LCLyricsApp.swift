import SwiftUI

/// LC歌词入口：Apple Music 跟随 + LRCLIB 歌词 + 应用内浮窗。
@main
struct LCLyricsApp: App {
    @StateObject private var engine = PlaybackEngine()
    @StateObject private var floating = FloatingWindowManager()

    var body: some Scene {
        WindowGroup {
            ContentView(engine: engine, floating: floating)
        }
    }
}
