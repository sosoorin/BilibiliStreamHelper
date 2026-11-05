//
//  DanmakuConnectionTests.swift
//  BilibiliStreamHelperTests
//

import Foundation
import os
import Testing
@testable import BilibiliStreamHelper

/// 假传输：测试里手动往里推帧，不碰网络。
final class FakeTransport: DanmakuTransport, @unchecked Sendable {

    private struct State {
        var pending: [Data] = []
        var waiters: [CheckedContinuation<Data, Error>] = []
        var closed = false
        var sent: [Data] = []
        var url: URL?
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    var sentPackets: [Data] { state.withLock { $0.sent } }
    var pendingCount: Int { state.withLock { $0.pending.count } }
    var waiterCount: Int { state.withLock { $0.waiters.count } }
    var connectedURL: URL? { state.withLock { $0.url } }

    func connect(url: URL) async throws {
        state.withLock { $0.url = url }
    }

    func send(_ data: Data) async throws {
        let wasClosed = state.withLock { state -> Bool in
            if state.closed { return true }
            state.sent.append(data)
            return false
        }
        if wasClosed { throw DanmakuTransportError.notConnected }
    }

    func receive() async throws -> Data {
        let immediate = state.withLock { state -> Result<Data, Error>? in
            if !state.pending.isEmpty {
                return .success(state.pending.removeFirst())
            }
            if state.closed {
                return .failure(DanmakuTransportError.notConnected)
            }
            return nil
        }
        if let immediate { return try immediate.get() }

        return try await withCheckedThrowingContinuation { continuation in
            state.withLock { state in
                if state.closed {
                    continuation.resume(throwing: DanmakuTransportError.notConnected)
                } else {
                    state.waiters.append(continuation)
                }
            }
        }
    }

    func close() async {
        let waiters = state.withLock { state -> [CheckedContinuation<Data, Error>] in
            state.closed = true
            let waiters = state.waiters
            state.waiters.removeAll()
            return waiters
        }
        for waiter in waiters {
            waiter.resume(throwing: DanmakuTransportError.notConnected)
        }
    }

    func push(_ data: Data) {
        let waiter = state.withLock { state -> CheckedContinuation<Data, Error>? in
            if !state.waiters.isEmpty {
                return state.waiters.removeFirst()
            }
            state.pending.append(data)
            return nil
        }
        waiter?.resume(returning: data)
    }
}

@Suite("弹幕连接流程")
@MainActor
struct DanmakuConnectionTests {

    private func makeCenter(transport: FakeTransport) -> (DanmakuCenter, FakeAPI) {
        let api = FakeAPI()
        api.isLoggedIn = true
        api.currentRoomId = "12345"
        api.userInfo = UserInfo(mid: 9, uname: "我", face: "", money: 0, level: 1)
        api.danmakuServerInfoResult = .success(
            DanmakuServerInfo(token: "token-abc", hosts: [.init(host: "example.com", wssPort: 443)])
        )

        let center = DanmakuCenter(
            api: api,
            serverInfoProvider: { @MainActor _ in
                DanmakuServerInfo(token: "token-abc", hosts: [.init(host: "example.com", wssPort: 443)])
            },
            makeTransport: { transport },
            reconnectDelays: [0.05]
        )
        return (center, api)
    }

    @Test func sendsAuthPacketOnConnect() async throws {
        let transport = FakeTransport()
        let (center, _) = makeCenter(transport: transport)

        center.connect()
        await waitUntil { transport.sentPackets.count >= 1 }

        let first = try #require(transport.sentPackets.first)
        let packets = DanmakuPacketCodec.decode(first)
        #expect(packets.first?.operation == 7)

        let body = try #require(packets.first?.body)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["roomid"] as? Int == 12345)
        #expect(json["protover"] as? Int == 2)
        #expect(json["key"] as? String == "token-abc")

        center.disconnect()
    }

    @Test func becomesConnectedAfterAuthReply() async throws {
        let transport = FakeTransport()
        let (center, _) = makeCenter(transport: transport)

        center.connect()
        await waitUntil { center.state == .connecting }

        transport.push(DanmakuPacketCodec.encode(operation: 8, body: Data(#"{"code":0}"#.utf8)))
        await waitUntil { center.state == .connected }

        #expect(center.state == .connected)
        center.disconnect()
        #expect(center.state == .idle)
    }

    @Test func appendsIncomingDanmaku() async throws {
        let transport = FakeTransport()
        let (center, _) = makeCenter(transport: transport)

        center.connect()
        await waitUntil { transport.sentPackets.count >= 1 }

        let command = Data(#"""
        {"cmd":"DANMU_MSG","info":[[0,1,25,0],"来了",[777,"观众"]]}
        """#.utf8)
        transport.push(DanmakuPacketCodec.encode(operation: 5, body: command))

        await waitUntil { center.items.contains { $0.text == "来了" } }
        let item = try #require(center.items.first { $0.text == "来了" })
        #expect(item.kind == .danmaku)
        #expect(item.uname == "观众")

        center.disconnect()
    }

    @Test func authFailureStopsInsteadOfReconnecting() async throws {
        let transport = FakeTransport()
        let (center, api) = makeCenter(transport: transport)

        center.connect()
        await waitUntil { transport.sentPackets.count >= 1 }

        transport.push(DanmakuPacketCodec.encode(operation: 8, body: Data(#"{"code":-101,"message":"未登录"}"#.utf8)))
        await waitUntil {
            if case .failed = center.state { return true }
            return false
        }

        if case .failed(let message) = center.state {
            #expect(message == "未登录")
        }
        // 认证失败不该重新去取 token
        let callsAfterFailure = api.danmakuServerInfoCalls.count
        try? await Task.sleep(for: .milliseconds(200))
        #expect(api.danmakuServerInfoCalls.count == callsAfterFailure)

        center.disconnect()
    }

    /// 历史消息和实时消息之间要有一条分隔
    @Test func insertsDividerBetweenHistoryAndRealtime() async throws {
        let transport = FakeTransport()
        let api = FakeAPI()
        api.isLoggedIn = true
        api.currentRoomId = "1"
        api.userInfo = UserInfo(mid: 1, uname: "我", face: "", money: 0, level: 1)
        api.danmakuServerInfoResult = .success(
            DanmakuServerInfo(token: "t", hosts: [.init(host: "h", wssPort: 443)])
        )
        api.recentDanmaku = [
            DanmakuChatItem(kind: .danmaku, uid: 5, uname: "老人", text: "旧消息",
                            timestamp: Date().addingTimeInterval(-120))
        ]
        let center = DanmakuCenter(
            api: api,
            serverInfoProvider: { @MainActor _ in DanmakuServerInfo(token: "t", hosts: [.init(host: "h", wssPort: 443)]) },
            makeTransport: { transport },
            reconnectDelays: [0.05]
        )

        center.connect()
        await waitUntil { center.items.contains { $0.text == "旧消息" } }
        await waitUntil { transport.sentPackets.count >= 1 }

        let command = Data(#"{"cmd":"DANMU_MSG","info":[[0,1,25,0],"新消息",[7,"新人"]]}"#.utf8)
        transport.push(DanmakuPacketCodec.encode(operation: 5, body: command))
        await waitUntil { center.items.contains { $0.text == "新消息" } }

        let texts = center.items.map(\.text)
        let old = try #require(texts.firstIndex(of: "旧消息"))
        let divider = try #require(texts.firstIndex(of: "以上为历史弹幕"))
        let new = try #require(texts.firstIndex(of: "新消息"))
        #expect(old < divider)
        #expect(divider < new)

        center.disconnect()
    }

    private func waitUntil(_ condition: () -> Bool, timeout: TimeInterval = 2) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(20))
        }
    }
}

@Suite("弹幕列表")
@MainActor
struct DanmakuCenterBufferTests {

    @Test func capsAtTwoHundred() async throws {
        let transport = FakeTransport()
        let api = FakeAPI()
        api.isLoggedIn = true
        api.currentRoomId = "1"
        api.userInfo = UserInfo(mid: 1, uname: "我", face: "", money: 0, level: 1)
        api.danmakuServerInfoResult = .success(
            DanmakuServerInfo(token: "t", hosts: [.init(host: "h", wssPort: 443)])
        )
        let center = DanmakuCenter(
            api: api,
            serverInfoProvider: { @MainActor _ in DanmakuServerInfo(token: "t", hosts: [.init(host: "h", wssPort: 443)]) },
            makeTransport: { transport },
            reconnectDelays: [0.05]
        )
        center.connect()
        let deadline = Date().addingTimeInterval(2)
        while transport.sentPackets.isEmpty && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }

        for index in 0..<230 {
            let command = Data(#"{"cmd":"DANMU_MSG","info":[[0,1,25,0],"消息\#(index)",[100,"用户\#(index)"]]}"#.utf8)
            transport.push(DanmakuPacketCodec.encode(operation: 5, body: command))
        }

        let deadline2 = Date().addingTimeInterval(3)
        while center.items.count < 200 && Date() < deadline2 {
            try? await Task.sleep(for: .milliseconds(50))
        }

        #expect(center.items.count == 200)
        // 最早的应该被挤掉
        #expect(center.items.last?.text == "消息229")

        center.disconnect()
    }
}
