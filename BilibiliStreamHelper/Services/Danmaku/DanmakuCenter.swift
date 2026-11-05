//
//  DanmakuCenter.swift
//  BilibiliStreamHelper
//

import Foundation
import Combine

/// 弹幕连接的宿主。
///
/// 连接挂在这里而不是 View 上：切到直播页、弹幕页来回切，连接都不断。
/// View 只读 `items` / `state` / `popularity`。
@MainActor
final class DanmakuCenter: ObservableObject {

    static let shared = DanmakuCenter()

    @Published private(set) var items: [DanmakuChatItem] = []
    @Published private(set) var state: DanmakuConnectionState = .idle
    @Published private(set) var popularity: Int?

    private let api: any BilibiliAPI
    private let connection: DanmakuConnection
    private var consumeTask: Task<Void, Never>?
    private var historyTask: Task<Void, Never>?
    private var hasLoadedHistory = false

    /// 同一条弹幕可能以 `DANMU_MSG` 和带版本后缀的形式各来一遍，用短窗口去重。
    private var recentKeys: [(key: String, date: Date)] = []
    private let maxItems = 200
    private let dedupeWindow: TimeInterval = 3

    init(
        api: any BilibiliAPI = APIClient.shared,
        serverInfoProvider: DanmakuConnection.ServerInfoProvider? = nil,
        makeTransport: DanmakuConnection.TransportFactory? = nil,
        reconnectDelays: [TimeInterval] = [5, 10, 20, 40, 60]
    ) {
        self.api = api
        let provider: DanmakuConnection.ServerInfoProvider = serverInfoProvider ?? { @MainActor roomId in
            try await APIClient.shared.getDanmakuServerInfo(roomId: roomId)
        }
        self.connection = DanmakuConnection(
            provider: provider,
            makeTransport: makeTransport ?? { WebSocketTransport() },
            reconnectDelays: reconnectDelays
        )
    }

    // MARK: - 生命周期

    func connect() {
        guard api.isLoggedIn else {
            state = .failed("请先登录")
            return
        }
        guard !api.currentRoomId.isEmpty else {
            state = .failed("还没拿到直播间号")
            return
        }
        if state.isActive { return }

        let roomId = api.currentRoomId
        let uid = UInt64(api.userInfo?.uid ?? 0)
        state = .connecting

        consumeTask?.cancel()
        consumeTask = Task { [weak self] in
            guard let self else { return }
            // 历史弹幕单独拉，失败也不影响长连接；只在第一次连的时候拉一次
            if !hasLoadedHistory {
                hasLoadedHistory = true
                historyTask = Task { [weak self] in
                    guard let self else { return }
                    if let history = try? await self.api.getRecentDanmaku(roomId: roomId) {
                        self.mergeHistory(history)
                    }
                }
            }
            let stream = await self.connection.start(roomId: roomId, uid: uid)
            for await event in stream {
                self.handle(event)
            }
        }
    }

    func disconnect() {
        consumeTask?.cancel()
        consumeTask = nil
        historyTask?.cancel()
        historyTask = nil
        state = .idle
        let connection = self.connection
        Task { await connection.stop() }
    }

    func clear() {
        items.removeAll()
        recentKeys.removeAll()
        hasLoadedHistory = false
    }

    /// 历史消息可能比实时消息晚到，插进来之后按时间重排一次。
    private func mergeHistory(_ history: [DanmakuChatItem]) {
        guard !history.isEmpty else { return }
        var seen = Set(items.map { "\($0.uid)|\($0.text)|\($0.timestamp.timeIntervalSince1970)" })
        let fresh = history.filter { item in
            let key = "\(item.uid)|\(item.text)|\(item.timestamp.timeIntervalSince1970)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
        guard !fresh.isEmpty else { return }

        // 分隔条的时间取最后一条历史消息之后一点点，
        // 这样实时消息先到、历史后到时，排序也能把它夹在两者中间。
        let boundary = (fresh.map(\.timestamp).max() ?? Date()).addingTimeInterval(0.001)
        items.append(contentsOf: fresh)
        if !items.contains(where: { $0.kind == .divider }) {
            items.append(
                DanmakuChatItem(kind: .divider, uname: "", text: "以上为历史弹幕", timestamp: boundary)
            )
        }
        items.sort { $0.timestamp < $1.timestamp }
        if items.count > maxItems {
            items.removeFirst(items.count - maxItems)
        }
    }

    // MARK: - 事件处理

    private func handle(_ event: DanmakuEvent) {
        switch event {
        case .chat(let item):
            guard !isDuplicate(item) else { return }
            append(item)

        case .popularity(let value):
            popularity = value

        case .system(let text):
            append(
                DanmakuChatItem(kind: .system, uname: "系统", text: text)
            )

        case .state(let newState):
            state = newState
        }
    }

    private func append(_ item: DanmakuChatItem) {
        items.append(item)
        if items.count > maxItems {
            items.removeFirst(items.count - maxItems)
        }
    }

    private func isDuplicate(_ item: DanmakuChatItem) -> Bool {
        guard item.kind != .system else { return false }

        let now = Date()
        recentKeys.removeAll { now.timeIntervalSince($0.date) > dedupeWindow }
        let key = "\(item.uid)|\(item.text)"
        if recentKeys.contains(where: { $0.key == key }) {
            return true
        }
        recentKeys.append((key, now))
        return false
    }
}
