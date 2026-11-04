//
//  BilibiliErrors.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/9/23.
//

import Foundation

// MARK: - Error Types

enum BilibiliAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError(Error)
    case apiError(Int, String)
    case authenticationRequired
    case networkError(Error)
    case qrCodeExpired
    case qrCodeScanned
    case invalidInput(String)
    case storageError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .invalidResponse:
            return "无效的响应"
        case .decodingError(let error):
            return "数据解析错误: \(error.localizedDescription)"
        case .apiError(let code, let message):
            return "API错误 (\(code)): \(message)"
        case .authenticationRequired:
            return "需要登录验证"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .qrCodeExpired:
            return "二维码已过期"
        case .qrCodeScanned:
            return "二维码已扫描，请确认"
        case .invalidInput(let message):
            return message
        case .storageError(let message):
            return message
        }
    }
}

// MARK: - 开播错误码

/// 开播失败的展示信息。
/// 判定逻辑只认错误码；展示时错误码和 B站 原始文案都要给出来，方便用户反馈、方便排查。
struct BilibiliErrorDisplay {
    let title: String
    let message: String
}

/// 把 B 站开播接口的错误码翻译成用户看得懂的话。
/// 错误码含义参考 bilibili-API-collect 的 `docs/live/manage.md`。
enum BilibiliLiveErrorText {
    
    /// 已知错误码的处理建议；未知返回 nil
    static func advice(for code: Int) -> String? {
        switch code {
        case 60009:
            return "所选分区已经不存在了，请点“刷新分区列表”后重新选择。"
        case 60013:
            return "你所在地区受实名认证限制，暂时无法在该分区开播。"
        case 60024, 60043:
            return "该分区开播需要人脸认证，请在手机客户端完成后再试。"
        case 60034:
            return "B站正在维护，这个时段只允许使用官方直播姬开播，第三方工具暂时不行，稍后再试。"
        case 60037:
            return "网页端开播已经下线，B站现在只认直播姬客户端，请更新到最新版本再试。"
        case 65530:
            return "登录状态已失效，请重新登录。"
        case -400:
            return "请求被拒绝，通常是分区或标题不合规，可以换个分区再试。"
        default:
            return nil
        }
    }
    
    /// 组装弹窗内容：标题带错误码，正文给建议 + B站 原话
    static func display(code: Int, message: String) -> BilibiliErrorDisplay {
        var parts: [String] = []
        if let advice = advice(for: code) {
            parts.append(advice)
        }
        if !message.isEmpty {
            parts.append("B站 返回：\(message)")
        }
        if parts.isEmpty {
            parts.append("没有更多信息了，可以把这个错误码反馈给我。")
        }
        return BilibiliErrorDisplay(
            title: "开播失败（错误码 \(code)）",
            message: parts.joined(separator: "\n\n")
        )
    }
}
