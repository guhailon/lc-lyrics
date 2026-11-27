import Foundation

/// LRCLIB 歌词记录。借用 TrollLyricsDesk 的 LRCLibClient 逻辑（只借取词，不搬别的模块）。
struct LRCLyricsRecord: Codable, Identifiable {
    let id: Int
    let trackName: String
    let artistName: String
    let albumName: String?
    let duration: Double
    let instrumental: Bool?
    let plainLyrics: String?
    let syncedLyrics: String?
}

enum LRCLibError: LocalizedError {
    case invalidURL
    case invalidResponse
    case notFound
    case rateLimited
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "搜索地址无效"
        case .invalidResponse:
            return "服务器返回的数据无效"
        case .notFound:
            return "没有找到匹配的歌词"
        case .rateLimited:
            return "请求过于频繁，请稍后再试"
        case .serverError(let code):
            return "服务器错误：\(code)"
        }
    }
}

final class LRCLibClient {

    static let shared = LRCLibClient()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        session = URLSession(configuration: config)
    }

    private func makeRequest(
        path: String,
        queryItems: [URLQueryItem]
    ) throws -> URLRequest {

        var components = URLComponents(
            string: "https://lrclib.net"
        )!

        components.path = path
        components.queryItems = queryItems

        guard let url = components.url else {
            throw LRCLibError.invalidURL
        }

        var request = URLRequest(url: url)

        request.httpMethod = "GET"

        request.setValue(
            "LCLyrics/0.2 (iOS 16)",
            forHTTPHeaderField: "User-Agent"
        )

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        return request
    }

    /// 先按歌名+歌手+专辑+时长精确取词（/api/get），404 再退到搜索（/api/search），取第一条。
    func fetchBest(
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval
    ) async throws -> LRCLyricsRecord {

        var items: [URLQueryItem] = [
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "track_name", value: title),
        ]
        if !album.isEmpty {
            items.append(URLQueryItem(name: "album_name", value: album))
        }
        if duration > 0 {
            items.append(URLQueryItem(
                name: "duration",
                value: String(format: "%.0f", duration)
            ))
        }

        let getRequest = try makeRequest(path: "/api/get", queryItems: items)
        let (data, response) = try await session.data(for: getRequest)
        guard let http = response as? HTTPURLResponse else {
            throw LRCLibError.invalidResponse
        }
        switch http.statusCode {
        case 200:
            return try JSONDecoder().decode(LRCLyricsRecord.self, from: data)
        case 429:
            throw LRCLibError.rateLimited
        case 404:
            break // 退到搜索
        default:
            throw LRCLibError.serverError(http.statusCode)
        }

        // /api/get 404：退到 /api/search，取第一条。
        let searchRequest = try makeRequest(
            path: "/api/search",
            queryItems: [
                URLQueryItem(name: "track_name", value: title),
                URLQueryItem(name: "artist_name", value: artist),
            ]
        )
        let (searchData, searchResponse) = try await session.data(for: searchRequest)
        guard let searchHTTP = searchResponse as? HTTPURLResponse else {
            throw LRCLibError.invalidResponse
        }
        switch searchHTTP.statusCode {
        case 200:
            break
        case 404:
            throw LRCLibError.notFound
        case 429:
            throw LRCLibError.rateLimited
        default:
            throw LRCLibError.serverError(searchHTTP.statusCode)
        }
        let results = try JSONDecoder().decode([LRCLyricsRecord].self, from: searchData)
        guard let first = results.first else {
            throw LRCLibError.notFound
        }
        return first
    }
}
