//
//  LiveSettingsView.swift
//  BilibiliLiveStremCodeSwift
//
//  Created by sosoorin on 2025/9/23.
//

import SwiftUI
import os
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

struct LiveSettingsView: View {
    @StateObject private var apiService = APIClient.shared
    @ObservedObject var vm: LiveSettingsViewModel
    
    /// 「推流信息」按钮把页面滚到推流区（由 LivePageView 处理）
    var onShowStreamInfo: () -> Void = {}
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 基础设置卡片
                SectionCard(icon: "gear", title: "基础设置", accent: .blue) {
                    Button {
                        Task { await vm.refreshAll() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(vm.isLoading)
                    .help("刷新分区列表和房间信息")
                    .accessibilityLabel("刷新")
                } content: {
                    VStack(spacing: 16) {
                        // 直播标题
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("直播标题")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                if !vm.liveTitle.isEmpty {
                                    Text("\(vm.liveTitle.count)/80")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            TextField("输入直播标题", text: $vm.liveTitle)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    if !vm.liveTitle.isEmpty {
                                        Task { await vm.updateTitle(vm.liveTitle) }
                                    }
                                }
                            
                            Button("更新标题") {
                                Task { await vm.updateTitle(vm.liveTitle) }
                            }
                            .buttonStyle(.bordered)
                            .disabled(vm.liveTitle.isEmpty || vm.isLoading)
                        }
                        
                        Divider()
                        
                        // 分区选择
                        VStack(alignment: .leading, spacing: 8) {
                            Text("分区设置")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            HStack(spacing: 4) {
                                // 主分区
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("主分区")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Picker("主分区", selection: $vm.selectedMainArea) {
                                        Text("请选择分区").tag(nil as LivePartition?)
                                        ForEach(apiService.partitions, id: \.id) { partition in
                                            Text(partition.name).tag(partition as LivePartition?)
                                        }
                                    }
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(maxWidth: .infinity)
                                .onChange(of: vm.selectedMainArea) { newValue in
                                    // 手动换主分区时清掉子分区；
                                    // 但回填房间信息时会先设主分区再设子分区，
                                    // 这种情况下子分区本来就属于新主分区，不能清。
                                    if let sub = vm.selectedSubArea,
                                       newValue?.list?.contains(where: { $0.id == sub.id }) == true {
                                        return
                                    }
                                    vm.selectedSubArea = nil
                                }
                                
                                // 子分区
                                if let mainArea = vm.selectedMainArea,
                                   let subAreas = mainArea.list,
                                   !subAreas.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("子分区")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Picker("子分区", selection: $vm.selectedSubArea) {
                                            Text("请选择子分区").tag(nil as LiveSubPartition?)
                                            ForEach(subAreas, id: \.id) { subArea in
                                                Text(subArea.isLocked ? "\(subArea.name)（需权限）" : subArea.name)
                                                    .tag(subArea as LiveSubPartition?)
                                            }
                                        }
                                        .labelsHidden()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .frame(maxWidth: .infinity)
                                } else {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("子分区")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("请先选择主分区")
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 12)
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(8)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            
                            HStack(spacing: 12) {
                                Button("更新分区") {
                                    Task { if let id = vm.selectedSubArea?.id { await vm.updateArea(areaId: id) } }
                                }
                                .buttonStyle(.bordered)
                                .disabled(vm.selectedSubArea == nil || vm.isLoading)
                            }
                        }
                    }
                }
                
                // 直播控制卡片
                SectionCard(
                    icon: apiService.isLiveActive ? "dot.radiowaves.left.and.right" : "play.circle",
                    title: "直播状态",
                    accent: apiService.isLiveActive ? .green : .orange
                ) {
                    if apiService.isLiveActive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("直播中")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                } content: {
                    VStack(spacing: 12) {
                        Text(apiService.isLiveActive
                             ? "直播进行中。开始和停止直播请用页面顶部的主按钮。"
                             : "填写好标题和分区后，用页面顶部的「开始直播」开播。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Divider()
                        
                        // 快速操作
                        HStack(spacing: 12) {
                            Button("进入直播间") {
                                openLiveRoom()
                            }
                            .buttonStyle(.bordered)
                            .disabled(apiService.userInfo == nil)
                            
                            Spacer()
                            
                            Button("推流信息") {
                                onShowStreamInfo()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                
                // 使用说明卡片
                SectionCard(icon: "questionmark.circle", title: "使用说明", accent: .purple) {
                } content: {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("直播流程")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            StepView(number: "1", title: "设置直播标题", description: "输入吸引观众的标题")
                            StepView(number: "2", title: "选择直播分区", description: "选择合适的主分区和子分区")
                            StepView(number: "3", title: "开始直播", description: "点击开始直播按钮")
                            StepView(number: "4", title: "获取推流信息", description: "在推流信息页面复制推流地址")
                            StepView(number: "5", title: "配置推流软件", description: "在OBS等软件中配置推流")
                            StepView(number: "6", title: "结束直播", description: "直播结束后记得停止直播")
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            setupInitialValues()
        }
        .alert("操作成功", isPresented: $vm.showSuccess) {
            Button("确定") { }
            } message: {
                Text(vm.successMessage)
            }
            .alert(vm.errorTitle, isPresented: $vm.showError) {
                Button("确定") { }
            } message: {
                Text(vm.errorMessage)
            }
            .overlay {
                if vm.isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay(
                            ProgressView("处理中...")
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .shadow(radius: 5)
                        )
                }
            }
            .overlay {
                if vm.showFaceVerification {
                    faceVerificationOverlay
                }
            }
    }
    
    // MARK: - 人脸认证视图
    
    private var faceVerificationOverlay: some View {
        Color.black.opacity(0.5)
            .ignoresSafeArea()
            .overlay(
                VStack(spacing: 20) {
                    // 标题
                    Text("需要人脸认证")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    // 说明文字
                    Text("请使用B站手机客户端扫描下方二维码进行人脸认证")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    
                    // 二维码
                    if let qrImage = vm.faceVerificationQRImage {
                        Image(nsImage: qrImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 200, height: 200)
                            .background(Color.white)
                            .cornerRadius(12)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 200, height: 200)
                            .cornerRadius(12)
                            .overlay(
                                ProgressView("生成二维码中...")
                            )
                    }
                    
                    // 确认按钮
                    Button("确认") {
                        vm.showFaceVerification = false
                        vm.faceVerificationQRImage = nil
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(30)
                .background(Color(NSColor.windowBackgroundColor))
                .cornerRadius(16)
                .shadow(radius: 20)
                .frame(maxWidth: 350)
            )
    }
    
    // MARK: - 私有方法
    
    
    
    
    private func setupInitialValues() {
        Task {
            // 分区列表是下拉框选中项的依据：列表还没到时回填会找不到对应项，
            // 所以先把它拉齐再谈回填。
            if apiService.partitions.isEmpty {
                _ = try? await apiService.getPartitions()
            }
            
            if let liveInfo = apiService.liveInfo {
                vm.applyLiveInfo(liveInfo)
            } else if !apiService.hasLoadedInitialLiveInfo {
                if let info = await vm.loadInitialLiveInfo() {
                    vm.applyLiveInfo(info)
                }
            }
            
            // 仍然没有选中项时，默认选第一个主分区
            if vm.selectedMainArea == nil {
                vm.selectedMainArea = apiService.partitions.first
            }
        }
    }
    
    
    private func openLiveRoom() {
        guard let userInfo = apiService.userInfo else { return }
        
        // 获取roomId，如果没有则使用uid作为fallback
        let roomIdentifier = apiService.currentRoomId.isEmpty ? String(userInfo.uid) : apiService.currentRoomId
        
        if let url = URL(string: "https://live.bilibili.com/\(roomIdentifier)") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - 步骤视图组件
struct StepView: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 步骤编号
            Text(number)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.purple)
                .clipShape(Circle())
            
            // 步骤内容
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    LiveSettingsView(vm: LiveSettingsViewModel())
}
