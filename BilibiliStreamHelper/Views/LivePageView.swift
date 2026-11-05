//
//  LivePageView.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/9/23.
//

import SwiftUI

/// 「直播」页。
///
/// 原来是侧边栏里的两项，但它们是同一条流程的两个阶段，所以合成一页：
/// 页头常驻开播/停播，内容区固定是「基础信息 → 推流信息（开播后）→ 使用说明」。
struct LivePageView: View {
    
    @ObservedObject var vm: LiveSettingsViewModel

    @StateObject private var apiService = APIClient.shared
    @StateObject private var help = HelpCenter.shared
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LiveSettingsView(vm: vm)
                    .padding(16)
            }
            .background(Color(NSColor.controlBackgroundColor))
        }
        .sheet(isPresented: $help.isPresented) {
            HelpGuideView()
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    openLiveSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
                .disabled(apiService.userInfo == nil)
                .help("B站开播设置")
                .accessibilityLabel("打开 B 站开播设置")
            }
        }
    }
    
    // MARK: - 打开网页
    
    private func openLiveSettings() {
        guard let url = URL(string: "https://link.bilibili.com/p/center/index#/my-room/start-live") else { return }
        NSWorkspace.shared.open(url)
    }
    
}
