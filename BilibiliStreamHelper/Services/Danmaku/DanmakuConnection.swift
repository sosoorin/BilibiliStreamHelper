//
//  DanmakuConnection.swift
//  BilibiliStreamHelper
//

import Foundation
import os

enum DanmakuConnectionError: Error, LocalizedError {
    case noHost
    case authFailed(String)
    case unexpectedAuthReply

    /// 这类错误重连也没用，直接停。
    var isFatal: Bool {
        if case .authFailed = self { return true }
        return false
    }

    var errorDescription: String? {
        switch self {
        case .noHost:
            return "没有拿到弹幕服务器地址"
        case .authFailed(let message):
            return message.isEmpty ? "弹幕认证失败" : message
        case .unexpectedAuthReply:
            return "弹幕认证回执异常"
        }
    }
}

/// 一条弹幕连接：取 token、握手、心跳、收包、断线重连。
///
/// 对外只吐 `AsyncStream<DanmakuEvent>`，不直接碰 UI。
/// 重连退避时间可由测试注入，生产用 5/10/20/40/60 秒。
actor DanmakuConnection {

    typealias ServerInfoProvider = @Sendable @MainActor (String) async throws -> DanmakuServerInfo
    typealias TransportFactory = @Sendable () -> any DanmakuTransport

    private let provider: ServerInfoProvider
    private let makeTransport: TransportFactory
    private let reconnectDelays: [TimeInterval]

    private var runTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var transport: (any DanmakuTransport)?
    private var continuation: AsyncStream<DanmakuEvent>.Continuation?
    private var selfUID: UInt64 = 0
    /// 断线重连时复用上一次的 token，别每次都去打风控敏感的 getDanmuInfo。
    /// 必须带上 roomId：换直播间了还拿旧 token 会连到别人的房间去。
    private var cachedServerInfo: (roomId: String, info: DanmakuServerInfo, date: Date)?
    private let tokenLifetime: TimeInterval = 3600

    init(
        provider: @escaping ServerInfoProvider,
        makeTransport: @escaping TransportFactory = { WebSocketTransport() },
        reconnectDelays: [TimeInterval] = [5, 10, 20, 40, 60]
    ) {
        self.provider = provider
        self.makeTransport = makeTransport
        self.reconnectDelays = reconnectDelays
    }

    /// 开始连接，返回事件流。重复调用会先把旧连接停掉。
    func start(roomId: String, uid: UInt64) async -> AsyncStream<DanmakuEvent> {
        await stop()

        selfUID = uid
        let (stream, continuation) = AsyncStream<DanmakuEvent>.makeStream(bufferingPolicy: .bufferingNewest(256))
        self.continuation = continuation

        runTask = Task { [weak self] in
            await self?.runLoop(roomId: roomId, uid: uid)
        }
        return stream
    }

    func stop() async {
        runTask?.cancel()
        runTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        continuation?.finish()
        continuation = nil
        if let transport {
            await transport.close()
        }
        transport = nil
    }

    // MARK: - 主循环

    private func runLoop(roomId: String, uid: UInt64) async {
        var attempt = 0

        while !Task.isCancelled {
            emit(.state(attempt == 0 ? .connecting : .reconnecting(attempt: attempt)))
            var usedCachedToken = false
            do {
                let (info, fromCache) = try await serverInfo(roomId: roomId)
                usedCachedToken = fromCache
                guard let host = info.hosts.first else { throw DanmakuConnectionError.noHost }

                let transport = makeTransport()
                self.transport = transport

                guard let url = URL(string: "wss://\(host.host):\(host.wssPort)/sub") else {
                    throw DanmakuConnectionError.noHost
                }
                try await transport.connect(url: url)
                try await transport.send(authPacket(token: info.token, roomId: roomId, uid: uid))
                AppLog.danmaku.info("已连接弹幕服务器 \(host.host, privacy: .public)")

                startHeartbeat(on: transport)
                emit(.state(.connected))
                attempt = 0

                try await receiveLoop(transport)
                // receive 正常返回说明对端关了
                throw DanmakuTransportError.notConnected

            } catch let error as DanmakuConnectionError where error.isFatal {
                await cleanupTransport()
                // 缓存的 token 过期也会报认证失败，先清掉换新的再来一次；
                // 新 token 还失败才是真的登录失效。
                if usedCachedToken {
                    cachedServerInfo = nil
                    continue
                }
                let message = error.localizedDescription
                emit(.system(message))
                emit(.state(.failed(message)))
                return
            } catch {
                if Task.isCancelled { return }
                await cleanupTransport()
                attempt += 1
                let delay = backoff(attempt: attempt, error: error)
                AppLog.danmaku.error("弹幕连接断开：\(error.localizedDescription, privacy: .public)")
                emit(.state(.reconnecting(attempt: attempt)))
                if isRateLimited(error) {
                    emit(.system("请求太频繁被风控了，\(Int(delay)) 秒后再试（第 \(attempt) 次）"))
                } else {
                    emit(.system("连接断开，\(Int(delay)) 秒后重试（第 \(attempt) 次）"))
                }
                try? await Task.sleep(for: .seconds(delay))
            }
        }
    }

    // MARK: - token 与退避

    private func serverInfo(roomId: String) async throws -> (info: DanmakuServerInfo, fromCache: Bool) {
        if let cached = cachedServerInfo,
           cached.roomId == roomId,
           Date().timeIntervalSince(cached.date) < tokenLifetime {
            return (cached.info, true)
        }
        let info = try await provider(roomId)
        cachedServerInfo = (roomId, info, Date())
        return (info, false)
    }

    /// -352 是 B站的风控码，撞上了还按 5 秒重试只会越撞越狠，
    /// 所以风控走单独的阶梯：30 秒起，逐次翻倍到 5 分钟。
    private func backoff(attempt: Int, error: Error) -> TimeInterval {
        let base = reconnectDelays[min(attempt - 1, reconnectDelays.count - 1)]
        guard isRateLimited(error) else { return base }
        let ladder: [TimeInterval] = [30, 60, 120, 300]
        return ladder[min(attempt - 1, ladder.count - 1)]
    }

    private func isRateLimited(_ error: Error) -> Bool {
        if case BilibiliAPIError.apiError(-352, _) = error { return true }
        return false
    }

    // MARK: - 收包

    private func receiveLoop(_ transport: any DanmakuTransport) async throws {
        while !Task.isCancelled {
            let data = try await transport.receive()
            for packet in DanmakuPacketCodec.decode(data) {
                switch packet.operation {
                case DanmakuPacketCodec.Operation.popularity.rawValue:
                    guard packet.body.count >= 4 else { continue }
                    let value = packet.body.withUnsafeBytes {
                        $0.loadUnaligned(as: UInt32.self).bigEndian
                    }
                    emit(.popularity(Int(value)))

                case DanmakuPacketCodec.Operation.command.rawValue:
                    handleCommand(packet.body)

                case DanmakuPacketCodec.Operation.authReply.rawValue:
                    try checkAuthReply(packet.body)

                default:
                    break
                }
            }
        }
    }

    private func handleCommand(_ body: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            AppLog.danmaku.error("命令包不是合法 JSON")
            return
        }
        if let event = DanmakuCommandParser.parse(json, selfUID: selfUID) {
            emit(event)
        }
    }

    private func checkAuthReply(_ body: Data) throws {
        guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let code = json["code"] as? Int else {
            throw DanmakuConnectionError.unexpectedAuthReply
        }
        if code != 0 {
            throw DanmakuConnectionError.authFailed(json["message"] as? String ?? "")
        }
    }

    // MARK: - 心跳

    private func startHeartbeat(on transport: any DanmakuTransport) {
        heartbeatTask?.cancel()
        heartbeatTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { return }
                do {
                    try await transport.send(DanmakuPacketCodec.encode(operation: 2, body: Data()))
                } catch {
                    // 心跳发不出去，收包那边也活不了，主动关掉让它抛错走重连
                    await transport.close()
                    return
                }
            }
        }
    }

    // MARK: - 工具

    private func authPacket(token: String, roomId: String, uid: UInt64) throws -> Data {
        let auth: [String: Any] = [
            "uid": uid,
            "roomid": Int(roomId) ?? 0,
            "protover": 2,
            "platform": "web",
            "type": 2,
            "key": token
        ]
        let body = try JSONSerialization.data(withJSONObject: auth)
        return DanmakuPacketCodec.encode(operation: DanmakuPacketCodec.Operation.auth.rawValue, body: body)
    }

    private func cleanupTransport() async {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        if let transport {
            await transport.close()
        }
        transport = nil
    }

    private func emit(_ event: DanmakuEvent) {
        continuation?.yield(event)
    }
}
