//
//  DanmakuTransport.swift
//  BilibiliStreamHelper
//

import Foundation

/// 弹幕长连接的传输层。
///
/// 单独抽协议是为了测试能喂假帧——和 `BilibiliAPI` / `FakeAPI` 是同一套思路。
nonisolated protocol DanmakuTransport: Sendable {
    func connect(url: URL) async throws
    func send(_ data: Data) async throws
    /// 等下一帧二进制数据。连接断开时抛错。
    func receive() async throws -> Data
    func close() async
}

enum DanmakuTransportError: Error, LocalizedError {
    case notConnected

    var errorDescription: String? {
        switch self {
        case .notConnected: return "弹幕连接未建立"
        }
    }
}

/// `URLSessionWebSocketTask` 的薄封装。
///
/// 任务只在 `DanmakuConnection` 这一个 actor 里串行使用，
/// 所以这里用 `@unchecked Sendable` 而不是再包一层锁。
nonisolated final class WebSocketTransport: DanmakuTransport, @unchecked Sendable {

    private let session: URLSession
    private var task: URLSessionWebSocketTask?

    init(session: URLSession = .shared) {
        self.session = session
    }

    func connect(url: URL) async throws {
        task?.cancel(with: .goingAway, reason: nil)
        let task = session.webSocketTask(with: url)
        task.resume()
        self.task = task
    }

    func send(_ data: Data) async throws {
        guard let task else { throw DanmakuTransportError.notConnected }
        try await task.send(.data(data))
    }

    func receive() async throws -> Data {
        guard let task else { throw DanmakuTransportError.notConnected }
        while true {
            let message = try await task.receive()
            switch message {
            case .data(let data):
                return data
            case .string(let text):
                return Data(text.utf8)
            @unknown default:
                continue
            }
        }
    }

    func close() async {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }
}
