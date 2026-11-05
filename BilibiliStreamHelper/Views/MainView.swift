//
//  MainView.swift
//  BilibiliLiveStremCodeSwift
//
//  Created by sosoorin on 2025/9/23.
//

import SwiftUI
import AppKit

// MARK: - 侧边栏菜单项
enum SidebarItem: String, CaseIterable, Identifiable {
    case live = "直播"
    case danmaku = "弹幕"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .live: return "tv"
        case .danmaku: return "message"
        }
    }
}

struct MainView: View {
    @StateObject private var apiService = APIClient.shared
    @StateObject private var vm = MainViewModel()
    @State private var selectedItem: SidebarItem = .live
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // 侧边栏
            SidebarView(selectedItem: $selectedItem)
                .navigationSplitViewColumnWidth(min: 260, ideal: 280, max: 320)
        } detail: {
            // 主内容区域
            DetailView(selectedItem: selectedItem, selectedSidebarItem: $selectedItem)
                .frame(minWidth: 600)
        }
        .navigationSplitViewStyle(.balanced)
        .navigationTitle("B站直播助手")
        .onAppear {
            Task { await vm.prefetchPartitions() }
        }
    }
}

// MARK: - 侧边栏视图
struct SidebarView: View {
    @Binding var selectedItem: SidebarItem
    @StateObject private var apiService = APIClient.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // 主要功能菜单
            VStack(spacing: 0) {
                
                ForEach(SidebarItem.allCases) { item in
                    SidebarMenuButton(
                        item: item,
                        isSelected: selectedItem == item
                    ) {
                        selectedItem = item
                    }
                }
            }
            
            Spacer()
            
            // 底部用户信息区域
              if let userInfo = apiService.userInfo {
                  VStack(spacing: 0) {
                      // 透明模糊渐变分界线
                      LinearGradient(
                          gradient: Gradient(stops: [
                              .init(color: Color(NSColor.controlBackgroundColor).opacity(0), location: 0),
                              .init(color: Color(NSColor.controlBackgroundColor).opacity(0.3), location: 0.3),
                              .init(color: Color(NSColor.controlBackgroundColor).opacity(0.8), location: 0.7),
                              .init(color: Color(NSColor.controlBackgroundColor), location: 1)
                          ]),
                          startPoint: .top,
                          endPoint: .bottom
                      )
                      .frame(height: 20)
                      .padding(.horizontal, 16)
                      
                      UserInfoCard(userInfo: userInfo)
                          .padding(.horizontal, 16)
                          .padding(.vertical, 16)
                          .background(Color(NSColor.controlBackgroundColor))
                  }
              } else {
                  VStack(spacing: 0) {
                      // 透明模糊渐变分界线
                      LinearGradient(
                          gradient: Gradient(stops: [
                              .init(color: Color(NSColor.controlBackgroundColor).opacity(0), location: 0),
                              .init(color: Color(NSColor.controlBackgroundColor).opacity(0.3), location: 0.3),
                              .init(color: Color(NSColor.controlBackgroundColor).opacity(0.8), location: 0.7),
                              .init(color: Color(NSColor.controlBackgroundColor), location: 1)
                          ]),
                          startPoint: .top,
                          endPoint: .bottom
                      )
                      .frame(height: 20)
                      .padding(.horizontal, 16)
                      
                      HStack {
                          Text("未登录")
                              .font(.caption)
                              .foregroundColor(.secondary)
                          Spacer()
                      }
                      .padding(.horizontal, 20)
                      .padding(.vertical, 16)
                      .background(Color(NSColor.controlBackgroundColor))
                  }
              }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - 侧边栏菜单按钮
struct SidebarMenuButton: View {
    let item: SidebarItem
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                    .frame(width: 20)
                
                Text(item.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }
}

// MARK: - 用户信息卡片
struct UserInfoCard: View {
    let userInfo: UserInfo
    @StateObject private var apiService = APIClient.shared
    @State private var showUserDetail = false
    
    var body: some View {
        Button(action: { showUserDetail = true }) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: userInfo.face)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 16))
                        )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(userInfo.uname)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    /*
                    Text("点击查看详情")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                     */
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showUserDetail) {
            UserDetailView(userInfo: userInfo, onLogout: logout)
        }
    }
    
    private func logout() {
        showUserDetail = false
        apiService.logout()
    }
}



// MARK: - 详情视图
struct DetailView: View {
    let selectedItem: SidebarItem
    @Binding var selectedSidebarItem: SidebarItem

    // 开播/停播是窗口级的操作，跟当前停在哪一页无关，
    // 所以放在工具栏——收起侧边栏也不影响。
    @StateObject private var liveVM = LiveSettingsViewModel()
    @StateObject private var apiService = APIClient.shared
    @State private var confirmStop = false
    
    var body: some View {
        // 详情栏套一层 NavigationStack，工具栏项才会按 macOS 惯例排到右侧；
        // 直接挂在 NavigationSplitView 的 detail 上会全部挤到左边。
        NavigationStack {
            Group {
                switch selectedItem {
                case .live:
                    LivePageView(vm: liveVM)
                case .danmaku:
                    DanmakuView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.textBackgroundColor))
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    liveActionButton
                }
            }
            .alert("确定要停止直播吗？", isPresented: $confirmStop) {
                Button("取消", role: .cancel) { }
                Button("停止直播", role: .destructive) {
                    Task { await liveVM.stopLive() }
                }
            } message: {
                Text("停止后推流会立刻中断，OBS 那边也会断开。")
            }
        }
    }

    @ViewBuilder
    private var liveActionButton: some View {
        if apiService.isLiveActive {
            Button { confirmStop = true } label: {
                ZStack {
                    Image(systemName: "stop.fill")
                        .foregroundStyle(.red)
                        .opacity(liveVM.activity == .stopLive ? 0 : liveVM.isLoading ? 0.35 : 1)
                    ProgressView()
                        .controlSize(.small)
                        .opacity(liveVM.activity == .stopLive ? 1 : 0)
                }
            }
            .disabled(liveVM.isLoading)
            .help("停止直播")
            .accessibilityLabel("停止直播")
        } else {
            Button {
                Task { await liveVM.startLiveWithCurrentSelection() }
            } label: {
                ZStack {
                    Image(systemName: "record.circle")
                        .foregroundStyle(.red)
                        .opacity(liveVM.activity == .startLive ? 0 : liveVM.canStartLive ? 1 : 0.35)
                    ProgressView()
                        .controlSize(.small)
                        .opacity(liveVM.activity == .startLive ? 1 : 0)
                }
            }
            .disabled(!liveVM.canStartLive)
            .help(liveVM.startBlockedReason ?? "开始直播")
            .accessibilityLabel("开始直播")
        }
    }
}

#Preview {
    MainView()
}
