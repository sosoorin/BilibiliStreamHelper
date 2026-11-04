//
//  LiveSettingsView.swift
//  BilibiliLiveStremCodeSwift
//
//  Created by sosoorin on 2025/9/23.
//

import SwiftUI
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

struct LiveSettingsView: View {
    @StateObject private var apiService = BilibiliAPIService.shared
    @State private var liveTitle = "我的直播间"
    @State private var selectedMainArea: LivePartition?
    @State private var selectedSubArea: LiveSubPartition?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var successMessage = ""
    @State private var isLoading = false
    @State private var isLoadingInitialData = false
    @State private var showNavigationConfirm = false
    @State private var showFaceVerification = false
    @State private var faceVerificationQRUrl = ""
    @State private var faceVerificationQRImage: NSImage?
    
    // 添加用于控制侧边栏选择的回调
    var onNavigateToStreamInfo: (() -> Void)?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 基础设置卡片
                VStack(spacing: 0) {
                    // 卡片标题
                    HStack {
                        Image(systemName: "gear")
                            .foregroundColor(.blue)
                        Text("基础设置")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                        Button("刷新信息") {
                            Task { await loadCurrentLiveInfo() }
                        }
                        .font(.caption)
                        .disabled(isLoading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.1))
                    
                    // 卡片内容
                    VStack(spacing: 16) {
                        // 直播标题
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("直播标题")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                if !liveTitle.isEmpty {
                                    Text("\(liveTitle.count)/80")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            TextField("输入直播标题", text: $liveTitle)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    if !liveTitle.isEmpty {
                                        Task { await updateTitle() }
                                    }
                                }
                            
                            Button("更新标题") {
                                Task { await updateTitle() }
                            }
                            .buttonStyle(.bordered)
                            .disabled(liveTitle.isEmpty || isLoading)
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
                                    Picker("主分区", selection: $selectedMainArea) {
                                        Text("请选择分区").tag(nil as LivePartition?)
                                        ForEach(apiService.partitions, id: \.id) { partition in
                                            Text(partition.name).tag(partition as LivePartition?)
                                        }
                                    }
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(maxWidth: .infinity)
                                .onChange(of: selectedMainArea) { newValue in
                                    if !isLoadingInitialData {
                                        selectedSubArea = nil
                                    }
                                }
                                
                                // 子分区
                                if let mainArea = selectedMainArea,
                                   let subAreas = mainArea.list,
                                   !subAreas.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("子分区")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Picker("子分区", selection: $selectedSubArea) {
                                            Text("请选择子分区").tag(nil as LiveSubPartition?)
                                            ForEach(subAreas, id: \.id) { subArea in
                                                Text(subArea.name).tag(subArea as LiveSubPartition?)
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
                                    Task { await updateArea() }
                                }
                                .buttonStyle(.bordered)
                                .disabled(selectedSubArea == nil || isLoading)
                                
                                Button("刷新分区列表") {
                                    Task { await refreshPartitions() }
                                }
                                .buttonStyle(.bordered)
                                .disabled(isLoading)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(NSColor.windowBackgroundColor))
                }
                .background(Color(NSColor.windowBackgroundColor))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                
                // 直播控制卡片
                VStack(spacing: 0) {
                    // 卡片标题
                    HStack {
                        Image(systemName: apiService.isLiveActive ? "dot.radiowaves.left.and.right" : "play.circle")
                            .foregroundColor(apiService.isLiveActive ? .green : .orange)
                        Text("直播控制")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
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
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background((apiService.isLiveActive ? Color.green : Color.orange).opacity(0.1))
                    
                    // 卡片内容
                    VStack(spacing: 16) {
                        if !apiService.isLiveActive {
                            // 开始直播区域
                            VStack(spacing: 12) {
                                Text("准备开始直播")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                // 检查清单
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Image(systemName: liveTitle.isEmpty ? "xmark.circle" : "checkmark.circle")
                                            .foregroundColor(liveTitle.isEmpty ? .red : .green)
                                        Text("直播标题已设置")
                                            .font(.caption)
                                    }
                                    
                                    HStack {
                                        Image(systemName: selectedSubArea == nil ? "xmark.circle" : "checkmark.circle")
                                            .foregroundColor(selectedSubArea == nil ? .red : .green)
                                        Text("直播分区已选择")
                                            .font(.caption)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(8)
                                
                                Button("开始直播") {
                                    Task { await startLive() }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .disabled(liveTitle.isEmpty || selectedSubArea == nil || isLoading)
                            }
                        } else {
                            // 直播进行中区域
                            VStack(spacing: 12) {
                                Text("直播进行中")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                                
                                Text("直播已开始，请在推流信息页面获取推流地址和密钥")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Button("停止直播") {
                                    Task { await stopLive() }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                                .foregroundColor(.red)
                                .disabled(isLoading)
                            }
                        }
                        
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
                                onNavigateToStreamInfo?()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(16)
                    .background(Color(NSColor.windowBackgroundColor))
                }
                .background(Color(NSColor.windowBackgroundColor))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                
                // 使用说明卡片
                VStack(spacing: 0) {
                    // 卡片标题
                    HStack {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.purple)
                        Text("使用说明")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.purple.opacity(0.1))
                    
                    // 卡片内容
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
                    .padding(16)
                    .background(Color(NSColor.windowBackgroundColor))
                }
                .background(Color(NSColor.windowBackgroundColor))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            }
            .padding(16)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            setupInitialValues()
        }
        .alert("操作成功", isPresented: $showSuccess) {
            Button("确定") { }
            } message: {
                Text(successMessage)
            }
            .alert("操作失败", isPresented: $showError) {
                Button("确定") { }
            } message: {
                Text(errorMessage)
            }
            .alert("开始直播成功", isPresented: $showNavigationConfirm) {
                Button("取消", role: .cancel) { }
                Button("确定") {
                    onNavigateToStreamInfo?()
                }
            } message: {
                Text("是否跳转到推流界面？")
            }
            .overlay {
                if isLoading {
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
                if showFaceVerification {
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
                    if let qrImage = faceVerificationQRImage {
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
                        showFaceVerification = false
                        faceVerificationQRUrl = ""
                        faceVerificationQRImage = nil
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
    
    private func handleAPIError(_ error: Error) {
        // 检查是否是BilibiliAPIError
        if let apiError = error as? BilibiliAPIError {
            switch apiError {
            case .authenticationRequired:
                // Cookie失效
                apiService.logout()
                self.errorMessage = "Cookie失效，请重新登录"
                self.showError = true
                
            case .apiError(let code, let message):
                switch code {
                case 60024, 60043:
                    // 需要人脸认证（60024 接口给链接，60043 客户端自己拼）
                    handleFaceVerificationError(message)
                case 3:
                    apiService.logout()
                    self.errorMessage = "Cookie失效，请重新登录"
                    self.showError = true
                default:
                    // 其他API错误：翻译成人话，同时保留原始信息
                    self.errorMessage = BilibiliLiveErrorText.userFacing(code: code, fallback: message)
                    self.showError = true
                }
            default:
                // 其他BilibiliAPIError类型
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        } else {
            // 其他类型的错误
            self.errorMessage = error.localizedDescription
            self.showError = true
        }
    }
    
    private func handleFaceVerificationError(_ message: String) {
        // 从错误消息中提取二维码URL
        // 根据BilibiliAPI.swift中的逻辑，消息格式是"需要进行人脸认证: URL"
        var qrUrl = ""
        
        // 从消息中提取URL
        if message.contains("需要进行人脸认证: ") {
            let components = message.components(separatedBy: "需要进行人脸认证: ")
            if components.count > 1 {
                qrUrl = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        if !qrUrl.isEmpty {
            // 保存二维码URL并生成二维码图片
            self.faceVerificationQRUrl = qrUrl
            self.generateQRCodeImage(from: qrUrl)
            self.showFaceVerification = true
        } else {
            // 没有二维码URL的情况，只显示提示
            self.errorMessage = "需要进行人脸认证，请在B站手机客户端完成认证后重试"
            self.showError = true
        }
    }
    
    private func generateQRCodeImage(from string: String) {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        guard let data = string.data(using: .utf8) else { 
            print("无法将字符串转换为数据")
            return 
        }
        
        filter.message = data
        filter.correctionLevel = "M"
        
        guard let outputImage = filter.outputImage else { 
            print("无法生成二维码图像")
            return 
        }
        
        // 放大二维码
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { 
            print("无法创建CGImage")
            return 
        }
        
        self.faceVerificationQRImage = NSImage(cgImage: cgImage, size: scaledImage.extent.size)
    }
    
    private func setupInitialValues() {
        // 设置默认值
        if !apiService.partitions.isEmpty && selectedMainArea == nil {
            selectedMainArea = apiService.partitions.first
        }
        
        // 如果已经有直播间信息，先显示出来
        if let liveInfo = apiService.liveInfo {
            updateUIWithLiveInfo(liveInfo)
        }
        
        // 只有在首次登录且未加载过直播间信息时才自动获取
        if !apiService.hasLoadedInitialLiveInfo {
            Task {
                await loadCurrentLiveInfo()
            }
        }
    }
    
    private func updateUIWithLiveInfo(_ liveInfo: LiveInfo) {
        // 更新直播标题
        self.liveTitle = liveInfo.title
        
        // 根据当前分区ID找到对应的分区和子分区
        if let mainArea = apiService.partitions.first(where: { partition in
            partition.list?.contains(where: { $0.id == liveInfo.areaId }) == true
        }),
        let subArea = mainArea.list?.first(where: { $0.id == liveInfo.areaId }) {
            // 先设置主分区
            self.selectedMainArea = mainArea
            // 使用DispatchQueue.main.async确保子分区设置在下一个RunLoop周期
            DispatchQueue.main.async {
                self.selectedSubArea = subArea
                // print("成功映射分区: \(mainArea.name) -> \(subArea.name)")
            }
        } else {
            print("未找到匹配的分区，areaId: \(liveInfo.areaId)")
            // 打印可用分区信息用于调试
            print("可用分区:")
            for partition in apiService.partitions {
                print("- \(partition.name) (id: \(partition.id))")
                if let subAreas = partition.list {
                    for subArea in subAreas {
                        print("  - \(subArea.name) (id: \(subArea.id))")
                    }
                }
            }
        }
    }
    
    private func loadCurrentLiveInfo() async {
        do {
            await MainActor.run {
                self.isLoadingInitialData = true
            }
            
            // 确保分区信息已加载
            if apiService.partitions.isEmpty {
                try await apiService.getPartitions()
            }
            
            let liveInfo = try await apiService.getLiveRoomInfo()
            await MainActor.run {
                self.updateUIWithLiveInfo(liveInfo)
                self.isLoadingInitialData = false
            }
        } catch {
            await MainActor.run {
                self.isLoadingInitialData = false
                handleAPIError(error)
            }
        }
    }
    
    private func updateTitle() async {
        isLoading = true
        
        do {
            try await apiService.updateLiveTitle(liveTitle)
            await MainActor.run {
                // 更新保存的直播间信息
                if var currentLiveInfo = apiService.liveInfo {
                    currentLiveInfo = LiveInfo(
                        roomId: currentLiveInfo.roomId,
                        title: self.liveTitle, // 使用新的标题
                        areaId: currentLiveInfo.areaId,
                        areaName: currentLiveInfo.areaName,
                        parentAreaId: currentLiveInfo.parentAreaId,
                        parentAreaName: currentLiveInfo.parentAreaName,
                        liveStatus: currentLiveInfo.liveStatus
                    )
                    apiService.liveInfo = currentLiveInfo
                }
                
                self.successMessage = "直播标题更新成功"
                self.showSuccess = true
            }
        } catch {
            await MainActor.run {
                handleAPIError(error)
            }
        }
        
        isLoading = false
    }
    
    private func updateArea() async {
        guard let subArea = selectedSubArea,
              let mainArea = selectedMainArea else { return }
        
        isLoading = true
        
        do {
            try await apiService.updateLiveArea(subArea.id)
            await MainActor.run {
                // 更新保存的直播间信息
                if var currentLiveInfo = apiService.liveInfo {
                    currentLiveInfo = LiveInfo(
                        roomId: currentLiveInfo.roomId,
                        title: currentLiveInfo.title,
                        areaId: subArea.id, // 使用新的子分区ID
                        areaName: subArea.name, // 使用新的子分区名称
                        parentAreaId: mainArea.id, // 使用新的主分区ID
                        parentAreaName: mainArea.name, // 使用新的主分区名称
                        liveStatus: currentLiveInfo.liveStatus
                    )
                    apiService.liveInfo = currentLiveInfo
                }
                
                self.successMessage = "直播分区更新成功"
                self.showSuccess = true
            }
        } catch {
            await MainActor.run {
                handleAPIError(error)
            }
        }
        
        isLoading = false
    }
    
    private func refreshPartitions() async {
        isLoading = true
        
        do {
            try await apiService.getPartitions()
            await MainActor.run {
                self.successMessage = "分区列表刷新成功"
                self.showSuccess = true
            }
        } catch {
            await MainActor.run {
                handleAPIError(error)
            }
        }
        
        isLoading = false
    }
    
    private func startLive() async {
        guard let subArea = selectedSubArea else { return }
        
        isLoading = true
        
        do {
            let _ = try await apiService.startLive(title: liveTitle, areaId: subArea.id)
            await MainActor.run {
                self.showNavigationConfirm = true
            }
        } catch {
            await MainActor.run {
                handleAPIError(error)
            }
        }
        
        isLoading = false
    }
    
    private func stopLive() async {
        isLoading = true
        
        do {
            try await apiService.stopLive()
            await MainActor.run {
                self.successMessage = "直播已停止"
                self.showSuccess = true
            }
        } catch {
            await MainActor.run {
                handleAPIError(error)
            }
        }
        
        isLoading = false
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
    LiveSettingsView()
}
