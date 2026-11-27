# LC歌词

在 LiveContainer 里跟 Apple Music 的歌词 App。版本 0.2.0（build 1）。

## 能做什么

- **Apple Music 跟随**：只用公开接口 `MPMusicPlayerController.systemMusicPlayer`，每 1 秒轮询，显示歌名 / 歌手 / 专辑 / 播放状态 / 进度条。
- **LRCLIB 歌词**：按歌名 + 歌手 + 专辑 + 时长先精确取词（`/api/get`），404 再退到搜索（`/api/search`）；同步歌词按进度跟当前行并高亮，没有同步歌词就显示纯文本，都没有就显示暂无歌词，不编。
- **应用内浮窗**：独立 `UIWindow`，可拖动，显示当前歌词行 + 歌名，可开关。

## 诚实说明（设备实测结论）

- **进度是估算**：`currentPlaybackTime` 在 LC 客体进程里永远是 NaN，进度按播放中的墙钟累加，暂停时冻结；界面上直接显示系统原始进度值。
- **只认播放 / 暂停时的歌名**：`playbackState` 为 0（已停止）时系统仍会返回上首歌的旧标题，那时当前曲目算无。
- **浮窗只在应用内有效**：切出应用即消失，不是系统悬浮窗，不支持锁屏、后台、跨应用。
- **仅支持 Apple Music**：QQ 音乐、网易云没有公开接口可读；不做 ShazamKit、不做系统 PiP、不用 MediaRemote、私有权限、激活码。

以上结论来自 LCProbe（T1–T9）设备实测，不是推测。

## 安装

1. 在 LiveContainer 里以 Guest 身份导入 `LCLyrics-0.2.0.ipa`。
2. 打开 App，在 Apple Music 里播放一首歌，歌词自动跟随。
3. 首次使用会请求媒体资料库权限（`NSAppleMusicUsageDescription`）。

## 构建

推代码到 `main` 即触发 GitHub Actions（macOS）：不签名 archive，导出 IPA 与 dSYM。仓库里没有 entitlements 文件，源码里没有写死的版本号，没有 MediaRemote 引用。

## License

MIT
