//
//  AppEnvironment.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/9/23.
//

import Foundation

enum AppEnvironment {
    
    /// 是否运行在测试宿主里。
    ///
    /// 单元测试会启动整个 App，而 App 启动时会去读钥匙串、拉二维码。
    /// 这两个副作用在测试里都是有害的：
    /// - 钥匙串：ad-hoc 签名每次构建都变，系统会弹窗要密码
    /// - 网络：让测试变慢且不稳定
    static var isRunningTests: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["XCTestConfigurationFilePath"] != nil
            || env["XCTestBundlePath"] != nil
            || env["XCTestSessionIdentifier"] != nil
    }
}
