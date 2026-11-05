//
//  DanmakuCommandParser.swift
//  BilibiliStreamHelper
//

import Foundation

/// 把一条 JSON 命令翻译成聊天流里的一行。
///
/// 只认参考项目处理的那几种命令，其余静默丢弃——直播间每秒几十条命令，
/// 每条都记日志没意义。
nonisolated enum DanmakuCommandParser {

    static func parse(_ json: [String: Any], selfUID: UInt64) -> DanmakuEvent? {
        guard let raw = json["cmd"] as? String else { return nil }
        let cmd = raw.split(separator: ":").first.map(String.init) ?? raw

        switch cmd {
        case "DANMU_MSG":
            return parseDanmaku(json, selfUID: selfUID)
        case "SEND_GIFT":
            return parseGift(json, combo: false, selfUID: selfUID)
        case "COMBO_SEND":
            return parseGift(json, combo: true, selfUID: selfUID)
        case "INTERACT_WORD":
            return parseInteract(json, selfUID: selfUID)
        case "INTERACT_WORD_V2":
            return parseInteractV2(json, selfUID: selfUID)
        case "ENTRY_EFFECT":
            return parseEntryEffect(json)
        default:
            return nil
        }
    }

    // MARK: - DANMU_MSG

    /// info 是个混合数组：info[0] 元信息、info[1] 正文、info[2] = [uid, 昵称, ...]。
    ///
    /// 从真实抓包里确认过的位置：
    /// - 颜色 info[0][3]，十进制 RGB（16777215 = 白色）
    /// - 头像 info[0][15]["user"]["base"]["face"]
    /// - 表情 info[0][15]["extra"]，是一段 JSON 字符串，里面的 `emots` 是"表情名 → 图片地址"
    private static func parseDanmaku(_ json: [String: Any], selfUID: UInt64) -> DanmakuEvent? {
        guard let info = json["info"] as? [Any],
              info.count > 2,
              let text = info[1] as? String,
              let user = info[2] as? [Any],
              user.count >= 2,
              let uid = uint64(user[0]),
              let uname = user[1] as? String else { return nil }

        var faceURL: String?
        var color: UInt32?
        var emots: [String: String] = [:]
        var userLevel: Int?
        var medal: DanmakuMedal?
        var guardLevel: Int?
        var wealthLevel: Int?

        if let meta = info[0] as? [Any] {
            if meta.count > 3, let rgb = uint64(meta[3]) {
                color = UInt32(truncatingIfNeeded: rgb)
            }
            if meta.count > 15, let extra = meta[15] as? [String: Any] {
                if let userInfo = extra["user"] as? [String: Any] {
                    if let base = userInfo["base"] as? [String: Any] {
                        faceURL = base["face"] as? String
                    }
                    if let raw = userInfo["medal"] as? [String: Any],
                       let name = raw["name"] as? String, !name.isEmpty,
                       let level = raw["level"] as? Int, level > 0 {
                        medal = DanmakuMedal(
                            name: name,
                            level: level,
                            color: UInt32(truncatingIfNeeded: uint64(raw["color"]) ?? 0)
                        )
                    }
                    if let guardInfo = userInfo["guard"] as? [String: Any],
                       let level = guardInfo["level"] as? Int, level > 0 {
                        guardLevel = level
                    }
                    if let wealth = userInfo["wealth"] as? [String: Any],
                       let level = wealth["level"] as? Int, level > 0 {
                        wealthLevel = level
                    }
                }
                if let raw = extra["extra"] as? String,
                   raw.contains("\"emots\""),
                   let data = raw.data(using: .utf8),
                   let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let dict = parsed["emots"] as? [String: Any] {
                    for (name, value) in dict {
                        if let entry = value as? [String: Any], let url = entry["url"] as? String {
                            emots[name] = url
                        }
                    }
                }
            }
        }

        // 真实抓包确认：
        //   info[4]  = [11, 0, 6406234, ">50000", 0]  → 用户等级
        //   info[16] = [11]                            → 荣耀（财富）等级
        if info.count > 4, let levelInfo = info[4] as? [Any], let level = levelInfo.first as? Int {
            userLevel = level
        }
        if info.count > 16, let wealthInfo = info[16] as? [Any], let level = wealthInfo.first as? Int {
            wealthLevel = level
        }

        return .chat(
            DanmakuChatItem(
                kind: .danmaku,
                uid: uid,
                uname: uname,
                text: text,
                faceURL: faceURL?.isEmpty == false ? faceURL : nil,
                color: color,
                emots: emots,
                userLevel: userLevel,
                medal: medal,
                guardLevel: guardLevel,
                wealthLevel: wealthLevel,
                isSelf: selfUID != 0 && uid == selfUID
            )
        )
    }

    // MARK: - 礼物

    private static func parseGift(_ json: [String: Any], combo: Bool, selfUID: UInt64) -> DanmakuEvent? {
        guard let data = json["data"] as? [String: Any],
              let uname = data["uname"] as? String else { return nil }

        let giftName = (data["giftName"] as? String) ?? (data["gift_name"] as? String) ?? "礼物"
        let count = combo
            ? (data["combo_num"] as? Int ?? 1)
            : (data["num"] as? Int ?? 1)
        let action = (data["action"] as? String) ?? "投喂"
        let uid = uint64(data["uid"]) ?? 0
        let face = data["face"] as? String

        return .chat(
            DanmakuChatItem(
                kind: .gift,
                uid: uid,
                uname: uname,
                text: "\(action) \(giftName) ×\(count)",
                faceURL: face?.isEmpty == false ? face : nil,
                isSelf: selfUID != 0 && uid == selfUID
            )
        )
    }

    // MARK: - 进场 / 关注 / 分享

    private static func parseInteract(_ json: [String: Any], selfUID: UInt64) -> DanmakuEvent? {
        guard let data = json["data"] as? [String: Any],
              let uname = data["uname"] as? String,
              let text = interactText(data["msg_type"]) else { return nil }
        let uid = uint64(data["uid"]) ?? 0

        return .chat(
            DanmakuChatItem(
                kind: .interact,
                uid: uid,
                uname: uname,
                text: text,
                isSelf: selfUID != 0 && uid == selfUID
            )
        )
    }

    /// 新版本把同样的信息放进 protobuf，字段含义一致。
    private static func parseInteractV2(_ json: [String: Any], selfUID: UInt64) -> DanmakuEvent? {
        guard let data = json["data"] as? [String: Any],
              let pb = data["pb"] as? String,
              let bytes = Data(base64Encoded: pb),
              let decoded = DanmakuProtobuf.decodeInteractWordV2(bytes),
              !decoded.uname.isEmpty,
              let text = interactText(Int(decoded.msgType)) else { return nil }

        return .chat(
            DanmakuChatItem(
                kind: .interact,
                uid: decoded.uid,
                uname: decoded.uname,
                text: text,
                isSelf: selfUID != 0 && decoded.uid == selfUID
            )
        )
    }

    private static func interactText(_ raw: Any?) -> String? {
        let type: Int
        if let value = raw as? Int {
            type = value
        } else if let value = uint64(raw) {
            type = Int(value)
        } else {
            return nil
        }

        switch type {
        case 1: return "进入直播间"
        case 2: return "关注了直播间"
        case 3: return "分享了直播间"
        default: return nil
        }
    }

    // MARK: - 进场特效

    /// copy_writing 形如 `<%张三%> 来了`，把占位符剥掉就是能直接显示的一句话。
    private static func parseEntryEffect(_ json: [String: Any]) -> DanmakuEvent? {
        guard let data = json["data"] as? [String: Any],
              let copyWriting = data["copy_writing"] as? String else { return nil }
        let text = copyWriting
            .replacingOccurrences(of: "<%", with: "")
            .replacingOccurrences(of: "%>", with: "")
        guard !text.isEmpty else { return nil }

        return .chat(
            DanmakuChatItem(
                kind: .interact,
                uid: uint64(data["uid"]) ?? 0,
                uname: "",
                text: text
            )
        )
    }

    // MARK: - 工具

    /// JSONSerialization 出来的数字可能是 Int / NSNumber / Double，统一收口。
    private static func uint64(_ value: Any?) -> UInt64? {
        switch value {
        case let number as NSNumber: return number.uint64Value
        case let int as Int: return UInt64(int)
        case let string as String: return UInt64(string)
        default: return nil
        }
    }
}
