//
//  MainViewModel.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/9/23.
//

import Combine
import Foundation

/// 主容器：启动时预热数据、退出登录。
@MainActor
final class MainViewModel: ObservableObject {
    
    private let api: any BilibiliAPI
    
    init(api: any BilibiliAPI = APIClient.shared) {
        self.api = api
    }
    
    /// 启动时预拉分区列表，失败不提示（页面各自还会再拉一次）
    func prefetchPartitions() async {
        // 登录弹窗还没关掉时不必预热
        guard api.isLoggedIn else { return }
        _ = try? await api.getPartitions()
    }
    
    func logout() {
        api.logout()
    }
}
