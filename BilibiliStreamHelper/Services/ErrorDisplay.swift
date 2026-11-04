//
//  ErrorDisplay.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/9/23.
//

import Foundation

/// 开播失败的展示内容。
///
/// 只呈现 B站 自己给的东西：错误码 + 原始 message。
/// 不再补充任何自定义建议——建议会过时，也会让用户误以为那是 B站 的原话。
struct ErrorDisplay {
    let title: String
    let message: String
}

enum LiveErrorText {
    
    /// 标题带错误码，正文是 B站 原文
    static func display(code: Int, message: String) -> ErrorDisplay {
        ErrorDisplay(
            title: "开播失败（错误码 \(code)）",
            message: message.isEmpty ? "B站 未返回具体错误信息。" : message
        )
    }
}
