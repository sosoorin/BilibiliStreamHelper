//
//  HelpCenter.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/9/23.
//

import Combine
import Foundation

/// 使用说明的显示状态。
///
/// 放在一个共享对象里，是因为打开它的入口有两个：菜单栏的 Help 菜单，
/// 以及页面里的按钮——两边得看到同一份状态。
@MainActor
final class HelpCenter: ObservableObject {
    
    static let shared = HelpCenter()
    
    @Published var isPresented = false
    
    private init() {}
    
    func show() {
        isPresented = true
    }
}
