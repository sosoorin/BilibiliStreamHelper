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
    /// 需要人脸认证。qrURL 为 nil 表示 B站 没给可用的认证链接。
    /// message 保留 B站 返回的原文，不做任何改写。
    case faceAuthRequired(code: Int, qrURL: String?, message: String)
    
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
        case .faceAuthRequired(_, _, let message):
            return message.isEmpty ? "需要人脸认证" : message
        }
    }
}

// MARK: - 开播错误展示

/// 开播失败的展示内容。
///
/// 只呈现 B站 自己给的东西：错误码 + 原始 message。
/// 不再补充任何自定义建议——建议会过时，也会让用户误以为那是 B站 的原话。
struct BilibiliErrorDisplay {
    let title: String
    let message: String
}

enum BilibiliLiveErrorText {
    
    /// 标题带错误码，正文是 B站 原文
    static func display(code: Int, message: String) -> BilibiliErrorDisplay {
        BilibiliErrorDisplay(
            title: "开播失败（错误码 \(code)）",
            message: message.isEmpty ? "B站 未返回具体错误信息。" : message
        )
    }
}
