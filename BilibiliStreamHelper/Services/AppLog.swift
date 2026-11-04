//
//  AppLog.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/9/23.
//

import Foundation
import os

/// 统一日志出口。
///
/// 用 `os.Logger` 而不是 `print`：可以在 Console.app 里按 subsystem / category 过滤，
/// 也不会在 Release 包里把明文一直往终端吐。
enum AppLog {
    private static let subsystem = "com.sosoorin.bilistreamhelper"
    
    static let network = Logger(subsystem: subsystem, category: "network")
    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let live = Logger(subsystem: subsystem, category: "live")
}

// MARK: - 日志脱敏

/// 把响应里的敏感字段打码后再输出。
///
/// B站 的响应里混着推流码、SESSDATA、csrf_token、人脸认证链接，
/// 这些东西进了日志就等于泄露账号，所以打印前一律先过这里。
