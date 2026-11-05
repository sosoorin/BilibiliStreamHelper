//
//  DanmakuEvent.swift
//  BilibiliStreamHelper
//

import Foundation

/// 聊天流里一行消息的性质。
nonisolated enum DanmakuChatKind: Sendable, Equatable {
    case danmaku    // 普通弹幕
    case gift       // 礼物
    case interact   // 进场 / 关注 / 分享
    case system     // 客户端自己产生的提示
    case divider    // 历史消息和实时消息之间的分隔
}

/// 粉丝勋章。
nonisolated struct DanmakuMedal: Sendable, Hashable {
    let name: String
    let level: Int
    /// 勋章底色，十进制 RGB
    let color: UInt32
}

/// 一条直播间消息。
nonisolated struct DanmakuChatItem: Identifiable, Sendable, Hashable {
    let id: UUID
    let kind: DanmakuChatKind
    let uid: UInt64
    let uname: String
    let text: String
    let faceURL: String?
    /// 弹幕颜色，B站用十进制 RGB（例如 16777215 是白色）
    let color: UInt32?
    /// 表情名 → 图片地址，来自 DANMU_MSG 的 extra.emots
    let emots: [String: String]
    /// 用户等级（原 info[4][0]）
    let userLevel: Int?
    /// 粉丝勋章，没牌子就是 nil
    let medal: DanmakuMedal?
    /// 大航海：1 舰长 / 2 提督 / 3 总督
    let guardLevel: Int?
    /// 财富等级
    let wealthLevel: Int?
    let isSelf: Bool
    let timestamp: Date

    init(
        id: UUID = UUID(),
        kind: DanmakuChatKind,
        uid: UInt64 = 0,
        uname: String,
        text: String,
        faceURL: String? = nil,
        color: UInt32? = nil,
        emots: [String: String] = [:],
        userLevel: Int? = nil,
        medal: DanmakuMedal? = nil,
        guardLevel: Int? = nil,
        wealthLevel: Int? = nil,
        isSelf: Bool = false,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.uid = uid
        self.uname = uname
        self.text = text
        self.faceURL = faceURL
        self.color = color
        self.emots = emots
        self.userLevel = userLevel
        self.medal = medal
        self.guardLevel = guardLevel
        self.wealthLevel = wealthLevel
        self.isSelf = isSelf
        self.timestamp = timestamp
    }
}

/// 弹幕连接向外吐的事件。
nonisolated enum DanmakuEvent: Sendable {
    case chat(DanmakuChatItem)
    case popularity(Int)
    case system(String)
    case state(DanmakuConnectionState)
}

nonisolated enum DanmakuConnectionState: Equatable, Sendable {
    case idle
    case connecting
    case connected
    case reconnecting(attempt: Int)
    case failed(String)

    var isActive: Bool {
        switch self {
        case .connecting, .connected, .reconnecting: return true
        case .idle, .failed: return false
        }
    }
}

/// getDanmuInfo 的返回，只留连接需要的字段。
nonisolated struct DanmakuServerInfo: Sendable {
    struct Host: Sendable {
        let host: String
        let wssPort: Int
    }

    let token: String
    let hosts: [Host]
}
