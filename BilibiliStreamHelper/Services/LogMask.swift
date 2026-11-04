//
//  LogMask.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/9/23.
//

import Foundation

/// 把响应里的敏感字段打码后再输出。
///
/// B站 的响应里混着推流码、SESSDATA、csrf_token、人脸认证链接，
/// 这些东西进了日志就等于泄露账号，所以打印前一律先过这里。
enum LogMask {
    
    /// 命中即打码的字段名（不区分大小写）
    private static let sensitiveKeys: Set<String> = [
        "rtmp", "addr", "key", "token", "access_token", "refresh_token",
        "csrf", "csrf_token", "sessdata", "bili_jct", "buvid3", "buvid4",
        "live_key", "sub_session_key", "url", "qrcode_key", "qr",
        "room_id", "uid", "mid", "cookie", "cookies", "cookie_list"
    ]
    
    /// 只在特定父节点下才算敏感的字段
    /// （`code` 顶层是业务状态码，顶层打码会看不到错误原因；只有推流信息里的 `code` 才是密钥）
    private static let contextualKeys: [String: Set<String>] = [
        "code": ["rtmp", "protocols"]
    ]
    
    /// 单条日志的最大长度，超了截断
    private static let maxLength = 300
    
    /// 把任意响应体转成一行可读、已脱敏、已截断的字符串
    static func describe(_ value: Any?) -> String {
        guard let value else { return "nil" }
        
        let redacted = redact(value, parent: nil)
        let text: String
        if JSONSerialization.isValidJSONObject(redacted),
           let data = try? JSONSerialization.data(withJSONObject: redacted, options: [.sortedKeys]),
           let json = String(data: data, encoding: .utf8) {
            text = json
        } else {
            text = String(describing: redacted)
        }
        return truncate(text)
    }
    
    /// 单个值打码：保留头尾各 4 位，中间用 **** 代替
    static func mask(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        guard text.count > 8 else { return "****" }
        return "\(text.prefix(4))****\(text.suffix(4))"
    }
    
    /// 整串 Cookie 打码："SESSDATA=xxx; bili_jct=yyy" -> "SESS****jct=****"
    static func maskCookies(_ cookieString: String) -> String {
        let masked = cookieString.split(separator: ";").map { pair -> String in
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { return "****" }
            return "\(parts[0].trimmingCharacters(in: .whitespaces))=****"
        }
        return truncate(masked.joined(separator: "; "))
    }
    
    // MARK: - Private
    
    private static func redact(_ value: Any, parent: String?) -> Any {
        if let dict = value as? [String: Any] {
            var output: [String: Any] = [:]
            for (key, child) in dict {
                if isSensitive(key, parent: parent) {
                    output[key] = maskLeaf(child, parent: key)
                } else {
                    output[key] = redact(child, parent: key)
                }
            }
            return output
        }
        if let array = value as? [Any] {
            return array.map { redact($0, parent: parent) }
        }
        return value
    }
    
    /// 命中的字段如果还是个容器，就继续往下走（保留结构，只打码叶子）
    private static func maskLeaf(_ value: Any, parent: String) -> Any {
        if value is [String: Any] || value is [Any] {
            return redact(value, parent: parent)
        }
        return mask(String(describing: value))
    }
    
    private static func isSensitive(_ key: String, parent: String?) -> Bool {
        let lowered = key.lowercased()
        if sensitiveKeys.contains(lowered) { return true }
        if let parents = contextualKeys[lowered], let parent {
            return parents.contains(parent.lowercased())
        }
        return false
    }
    
    private static func truncate(_ text: String) -> String {
        text.count > maxLength ? String(text.prefix(maxLength)) + "…" : text
    }
}
