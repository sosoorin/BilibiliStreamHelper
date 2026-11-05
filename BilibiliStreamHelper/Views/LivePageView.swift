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
    
    @StateObject private var apiService = APIClient.shared
    @StateObject private var vm = LiveSettingsViewModel()
    @State private var confirmStop = false
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
            // 备忘录里「新建」是单独一块、落在最左边，
            // 靠的是它属于导航区（leading），而不是混在右侧的工具组里。
            ToolbarItem(placement: .navigation) {
                primaryActionButton
            }
            
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
        .alert("确定要停止直播吗？", isPresented: $confirmStop) {
            Button("取消", role: .cancel) { }
            Button("停止直播", role: .destructive) {
                Task { await vm.stopLive() }
            }
        } message: {
            Text("停止后推流会立刻中断，OBS 那边也会断开。")
        }
    }
    
    // MARK: - 工具栏内容
    
    @ViewBuilder
    private var primaryActionButton: some View {
        // 抄系统默认工具栏的样子：不加任何自定义底，跟旁边按钮同组同尺寸，
        // 强调只靠图标颜色。
        if apiService.isLiveActive {
            Button { confirmStop = true } label: {
                ZStack {
                    Image(systemName: "stop.fill")
                        .opacity(vm.activity == .stopLive ? 0 : 1)
                    ProgressView()
                        .controlSize(.small)
                        .opacity(vm.activity == .stopLive ? 1 : 0)
                }
            }
            .disabled(vm.isLoading)
            .help("停止直播")
            .accessibilityLabel("停止直播")
        } else {
            Button {
                Task { await vm.startLiveWithCurrentSelection() }
            } label: {
                ZStack {
                    Image(systemName: "play.fill")
                        .opacity(vm.activity == .startLive ? 0 : 1)
                    ProgressView()
                        .controlSize(.small)
                        .opacity(vm.activity == .startLive ? 1 : 0)
                }
            }
            .disabled(!vm.canStartLive)
            .help(vm.startBlockedReason ?? "开始直播")
            .accessibilityLabel("开始直播")
        }
    }
    
    // MARK: - 打开网页
    
    private func openLiveSettings() {
        guard let url = URL(string: "https://link.bilibili.com/p/center/index#/my-room/start-live") else { return }
        NSWorkspace.shared.open(url)
    }
    
}
