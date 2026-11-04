//
//  LivePageView.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/9/23.
//

import SwiftUI

/// 「直播」页。
///
/// 侧边栏原先把「直播设置」和「推流信息」平铺成两项，但它们是一条流程的两个阶段。
/// 合并成一页之后，开播/停播这个主操作被提到页头常驻，下面的内容跟着直播状态走。
struct LivePageView: View {
    
    private enum Section {
        case settings
        case stream
    }
    
    @StateObject private var apiService = APIClient.shared
    @StateObject private var vm = LiveSettingsViewModel()
    @State private var section: Section = .settings
    @State private var confirmStop = false
    
    var body: some View {
        VStack(spacing: 0) {
            actionBar
            
            if apiService.isLiveActive {
                Picker("", selection: $section) {
                    Text("直播设置").tag(Section.settings)
                    Text("推流信息").tag(Section.stream)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 280)
                .padding(.vertical, 10)
            }
            
            switch activeSection {
            case .settings:
                LiveSettingsView(vm: vm, onShowStreamInfo: { section = .stream })
            case .stream:
                StreamInfoView()
            }
        }
        .onChange(of: apiService.isLiveActive) { isLive in
            // 开播后自动切到推流信息，停了自动回到设置
            section = isLive ? .stream : .settings
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
    
    // MARK: - 页头主操作
    
    private var actionBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Circle()
                    .fill(apiService.isLiveActive ? Color.green : Color.secondary)
                    .frame(width: 9, height: 9)
                Text(apiService.isLiveActive ? "直播中" : "未开播")
                    .font(.headline)
            }
            
            Spacer()
            
            if !apiService.isLiveActive, let reason = vm.startBlockedReason {
                Text(reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if apiService.isLiveActive {
                Button("停止直播") { confirmStop = true }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.large)
                    .disabled(vm.isLoading)
            } else {
                Button("开始直播") {
                    Task { await vm.startLiveWithCurrentSelection() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.large)
                .disabled(!vm.canStartLive)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
    
    /// 没开播时无论选中哪个，都只能看到设置
    private var activeSection: Section {
        apiService.isLiveActive ? section : .settings
    }
}
