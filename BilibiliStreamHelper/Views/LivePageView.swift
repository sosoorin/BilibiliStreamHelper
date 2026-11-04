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
/// 页头常驻开播/停播，下面按状态排内容——开播后推流信息在最上面，
/// 设置永远在下面，随时能改标题和分区。
struct LivePageView: View {
    
    @StateObject private var apiService = APIClient.shared
    @StateObject private var vm = LiveSettingsViewModel()
    @State private var confirmStop = false
    
    var body: some View {
        VStack(spacing: 0) {
            actionBar
            
            ScrollView {
                VStack(spacing: 24) {
                    // 开播后推流信息在最上面——那是这一刻唯一要做的事
                    if apiService.isLiveActive {
                        StreamInfoView()
                    }
                    LiveSettingsView(vm: vm)
                }
                .padding(16)
            }
            .background(Color(NSColor.controlBackgroundColor))
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
            
            // 次要操作
            Button("进入直播间") {
                openLiveRoom()
            }
            .buttonStyle(.bordered)
            .disabled(apiService.userInfo == nil)
            
            if apiService.isLiveActive {
                Button { confirmStop = true } label: {
                    Image(systemName: "stop.fill")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
                .disabled(vm.isLoading)
                .help("停止直播")
                .accessibilityLabel("停止直播")
            } else {
                Button {
                    Task { await vm.startLiveWithCurrentSelection() }
                } label: {
                    Image(systemName: "play.fill")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.large)
                .disabled(!vm.canStartLive)
                .help("开始直播")
                .accessibilityLabel("开始直播")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
    
    private func openLiveRoom() {
        guard let userInfo = apiService.userInfo else { return }
        let id = apiService.currentRoomId.isEmpty ? String(userInfo.uid) : apiService.currentRoomId
        guard let url = URL(string: "https://live.bilibili.com/\(id)") else { return }
        NSWorkspace.shared.open(url)
    }
    
}
