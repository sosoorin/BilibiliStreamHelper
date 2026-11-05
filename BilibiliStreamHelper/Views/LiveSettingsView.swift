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
    
    
    var body: some View {
            VStack(spacing: 24) {
                // 基础信息卡片
                SectionCard(icon: "gear", title: "基础信息", accent: .blue) {
                    Button {
                        Task { await vm.refreshAll() }
                    } label: {
                        // 两者始终都在，只切透明度：ZStack 的尺寸恒为较大者的尺寸
                        ZStack {
                            Image(systemName: "arrow.clockwise")
                                .opacity(vm.activity == .refresh ? 0 : 1)
                            ProgressView()
                                .controlSize(.small)
                                .opacity(vm.activity == .refresh ? 1 : 0)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(vm.isLoading)
                    .help("刷新分区列表和房间信息")
                    .accessibilityLabel("刷新")
                } content: {
                    VStack(alignment: .leading, spacing: 14) {
                        FormRow("直播间 ID") {
                            Text(roomIdText)
                                .textSelection(.enabled)
                            CopyIconButton(value: roomIdText)
                        }
                        
                        FormRow("直播间链接") {
                            Link(destination: roomURL) {
                                Text(roomURL.absoluteString)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            CopyIconButton(value: roomURL.absoluteString)
                        }
                        
                        Divider()
                        
                        FormRow("直播标题") {
                            TextField("输入直播标题", text: $vm.liveTitle)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    if !vm.liveTitle.isEmpty {
                                        Task { await vm.updateTitle(vm.liveTitle) }
                                    }
                                }
                                .overlay(alignment: .trailing) {
                                    Text("\(vm.liveTitle.count)/30")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.trailing, 8)
                                }
                            Button("保存") {
                                Task { await vm.updateTitle(vm.liveTitle) }
                            }
                            .buttonStyle(.borderless)
                            .disabled(!vm.titleChanged || vm.liveTitle.isEmpty || vm.isLoading)
                        }
                        
                        Divider()
                        
                        FormRow("主分区") {
                            Picker("主分区", selection: $vm.selectedMainArea) {
                                Text("请选择分区").tag(nil as LivePartition?)
                                ForEach(apiService.partitions, id: \.id) { partition in
                                    Text(partition.name).tag(partition as LivePartition?)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 220, alignment: .leading)
                            .onChange(of: vm.selectedMainArea) { _, newValue in
                                // 手动换主分区时清掉子分区；
                                // 但回填房间信息时会先设主分区再设子分区，
                                // 这种情况下子分区本来就属于新主分区，不能清。
                                if let sub = vm.selectedSubArea,
                                   newValue?.list?.contains(where: { $0.id == sub.id }) == true {
                                    return
                                }
                                vm.selectedSubArea = nil
                            }
                        }
                        
                        FormRow("子分区") {
                            if let mainArea = vm.selectedMainArea,
                               let subAreas = mainArea.list,
                               !subAreas.isEmpty {
                                Picker("子分区", selection: $vm.selectedSubArea) {
                                    Text("请选择子分区").tag(nil as LiveSubPartition?)
                                    ForEach(subAreas, id: \.id) { subArea in
                                        Text(subArea.isLocked ? "\(subArea.name)（需权限）" : subArea.name)
                                            .tag(subArea as LiveSubPartition?)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 220, alignment: .leading)
                            } else {
                                Picker("子分区", selection: .constant(nil as LiveSubPartition?)) {
                                    Text("请先选择主分区").tag(nil as LiveSubPartition?)
                                }
                                .labelsHidden()
                                .disabled(true)
                                .frame(width: 220, alignment: .leading)
                            }
                            
                            Button("保存") {
                                if let id = vm.selectedSubArea?.id {
                                    Task { await vm.updateArea(areaId: id) }
                                }
                            }
                            .buttonStyle(.borderless)
                            .disabled(!vm.areaChanged || vm.selectedSubArea == nil || vm.isLoading)
                        }
                    }
                    .animation(.easeInOut(duration: 0.15), value: vm.titleChanged)
                }
                
                // 推流信息常驻，开播前显示空态，开播后直接换成地址和密钥
                StreamInfoView()

                VStack(spacing: 4) {
                    Text("下播请点击工具栏的方块，OBS 停流不算下播。")
                    Text("推流码每次开播需要重新取。")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
            }
        .onAppear {
            setupInitialValues()
        }
        .onChange(of: apiService.isLoggedIn) { _, isLoggedIn in
            // 主界面是常驻的，登录弹窗关掉之后 onAppear 不会再触发，
            // 所以登录成功要在这里补一次拉取。
            if isLoggedIn {
                setupInitialValues()
            }
        }
            .alert(vm.errorTitle, isPresented: $vm.showError) {
                Button("确定") { }
            } message: {
                Text(vm.errorMessage)
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
    
    
    
    
    // MARK: - 直播间信息
    
    private var roomIdText: String {
        apiService.currentRoomId.isEmpty
            ? (apiService.userInfo.map { String($0.uid) } ?? "—")
            : apiService.currentRoomId
    }
    
    private var roomURL: URL {
        URL(string: "https://live.bilibili.com/\(roomIdText)") ?? URL(string: "https://live.bilibili.com")!
    }
    
    private func setupInitialValues() {
        // 没登录时主界面在登录弹窗后面，此时发请求只会拿到鉴权失败
        guard apiService.isLoggedIn else { return }
        
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
    
    
}

// MARK: - 步骤视图组件

#Preview {
    LiveSettingsView(vm: LiveSettingsViewModel())
}
