//
//  LoginView.swift
//  BilibiliLiveStremCodeSwift
//
//  Created by sosoorin on 2025/9/23.
//

import SwiftUI
import CoreImage.CIFilterBuiltins
import AppKit

struct LoginView: View {
    @StateObject private var apiService = APIClient.shared
    @State private var qrCodeInfo: QRCodeInfo?
    @State private var qrCodeImage: NSImage?
    @State private var isPolling = false
    @State private var statusMessage = "请扫描二维码登录"
    @State private var showError = false
    @State private var errorMessage = ""
    
    // 手动输入相关状态
    @State private var showManualLogin = false
    @State private var manualRoomId = ""
    @State private var manualCookies = ""
    @State private var manualCSRF = ""
    @State private var isSavingManualLogin = false
    @State private var forceShowLoginInterface = false
    
    // 登录状态
    enum LoginStatus {
        case idle
        case waitingForScan
        case scanned
        case success
        case failed
        case expired
    }
    @State private var loginStatus: LoginStatus = .idle
    
    // 日期格式化器
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack(spacing: 30) {
            // 标题
            VStack(spacing: 8) {
                Image(systemName: "tv.and.mediabox")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                
                Text("B站推流码获取工具")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("快速获取B站直播推流码")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            
            // 根据是否有保存的登录信息和强制显示状态决定界面
            if let savedLoginInfo = apiService.getSavedLoginInfoFull(), !savedLoginInfo.userName.isEmpty, !forceShowLoginInterface {
                // 有保存的登录信息且未强制显示登录界面：显示用户资料和登录按钮
                savedUserLoginView(loginInfo: savedLoginInfo)
            } else {
                // 没有保存的登录信息或强制显示登录界面：显示完整的登录界面
                newUserLoginView()
            }
            
            Spacer()
            
        }
        .padding()
        .onAppear {
            // 只有在没有保存登录信息或强制显示登录界面时才生成二维码
            if apiService.getSavedLoginInfoFull()?.userName.isEmpty != false || forceShowLoginInterface {
                Task {
                    await generateQRCode()
                }
            }
        }
        .onDisappear {
            // 界面消失时停止轮询
            stopPolling()
        }
        .alert("登录错误", isPresented: $showError) {
            Button("确定") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - 视图组件
    
    private func savedUserLoginView(loginInfo: LoginInfo) -> some View {
        VStack(spacing: 30) {
            // 大尺寸头像和用户信息
            VStack(spacing: 20) {
                // 头像
                AsyncImage(url: URL(string: loginInfo.userAvatar)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.gray)
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.blue.opacity(0.3), lineWidth: 3)
                )
                
                // 用户信息
                VStack(spacing: 8) {
                    Text(loginInfo.userName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("用户ID: \(loginInfo.userId)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // 登录按钮
            VStack(spacing: 15) {
                Button("自动登录") {
                    Task {
                        await autoLogin()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: 200)
                
                Button("重新登录") {
                    // 退出登录并切换到扫码登录页面
                    apiService.logout()
                    showManualLogin = false  // 默认显示扫码登录
                    forceShowLoginInterface = true
                    
                    // 刷新二维码
                    Task {
                        await generateQRCode()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(maxWidth: 200)
                .foregroundColor(.red)
            }
            
            // 上次登录时间
            if let savedDate = apiService.getLoginInfoSavedDate() {
                Text("上次登录: \(savedDate, formatter: dateFormatter)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 20)
            }
        }
        .padding()
    }
    
    private func newUserLoginView() -> some View {
        VStack(spacing: 30) {
            // 如果有保存的登录信息，显示返回按钮
            if apiService.hasStoredLoginInfo() && forceShowLoginInterface {
                HStack {
                    Button("← 返回") {
                        forceShowLoginInterface = false
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Spacer()
                }
                .padding(.horizontal)
            }
            
            // 登录方式切换
            Picker("登录方式", selection: $showManualLogin) {
                Text("扫码登录").tag(false)
                Text("手动输入").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .onChange(of: showManualLogin) { newValue in
                if newValue {
                    // 切换到手动登录时停止二维码轮询
                    stopPolling()
                } else {
                    // 切换到扫码登录时重新生成二维码
                    Task {
                        await generateQRCode()
                    }
                }
            }
            
            // 登录区域
            if showManualLogin {
                // 手动输入区域
                manualLoginView
            } else {
                // 二维码登录区域
                qrCodeLoginView
            }
            
            // 操作按钮
            if showManualLogin {
                Button(isSavingManualLogin ? "保存中..." : "保存设置") {
                    Task {
                        await saveManualSettings()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(manualRoomId.isEmpty || manualCookies.isEmpty || manualCSRF.isEmpty || isSavingManualLogin)
                
                HStack {
                    // 清空按钮
                    if !manualRoomId.isEmpty || !manualCookies.isEmpty || !manualCSRF.isEmpty {
                        Button("清空输入") {
                            manualRoomId = ""
                            manualCookies = ""
                            manualCSRF = ""
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                }
            } else {
                Button("刷新二维码") {
                    Task {
                        await generateQRCode()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private func userProfileView(loginInfo: LoginInfo) -> some View {
        VStack(spacing: 15) {
            HStack(spacing: 15) {
                // 头像
                AsyncImage(url: URL(string: loginInfo.userAvatar)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.gray)
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
                
                    // 用户信息（简化显示）
                    VStack(alignment: .leading, spacing: 5) {
                        Text(loginInfo.userName)
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text("用户ID: \(loginInfo.userId)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                
                Spacer()
                
                // 操作按钮
                VStack(spacing: 8) {
                    Button("自动登录") {
                        Task {
                            await autoLogin()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    
                    Button("退出登录") {
                        apiService.logout()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.red)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // 上次登录时间
            if let savedDate = apiService.getLoginInfoSavedDate() {
                Text("上次登录: \(savedDate, formatter: dateFormatter)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var qrCodeLoginView: some View {
        VStack(spacing: 20) {
            if let qrImage = qrCodeImage {
                Image(nsImage: qrImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(radius: 5)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 200, height: 200)
                    .overlay(
                        ProgressView()
                            .scaleEffect(1.5)
                    )
            }
            
            Text(statusMessage)
                .font(.headline)
                .foregroundColor(loginStatusColor)
                .multilineTextAlignment(.center)
        }
    }
    
    private var manualLoginView: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 15) {
                HStack(spacing: 4) {
                    Text("账户信息设置")
                        .font(.headline)
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.blue)
                        .help("获取步骤：\n1. 打开浏览器登录B站，进入你的直播间\n2. 右键点击页面，选择\"检查\"打开开发者工具\n3. 切换到\"网络\"标签\n4. 在直播间发送一条弹幕（不开播也可以）\n5. 在网络请求中找到名为\"send\"的请求并点击\n6. 在请求详情中复制Cookie和csrf参数")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Room ID输入
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 2) {
                        Text("直播间ID")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "questionmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .help("直播间ID获取方法：\n1. 登录B站后点击右上角头像\n2. 进入\"个人中心\"\n3. 点击左侧\"我的直播间\"\n4. 进入\"开播设置\"\n5. 在页面中找到\"直播间ID\"或\"房间号\"\n\n注意：直播间ID是纯数字，通常为6-8位数字")
                    }
                    TextField("请输入直播间ID", text: $manualRoomId)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Cookies输入
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 2) {
                        Text("Cookies")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "questionmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .help("Cookie获取详细步骤：\n1. 在直播间右键点击页面，选择\"检查\"打开开发者工具\n2. 切换到\"网络\"(Network)标签\n3. 发送一条弹幕触发网络请求\n4. 在请求列表中找到\"send\"请求并点击\n5. 在右侧面板找到\"请求标头\"(Request Headers)\n6. 找到\"Cookie:\"字段，复制冒号后面的完整内容\n\n注意：Cookie内容很长，包含多个键值对，请完整复制")
                    }
                    TextField("请输入完整的Cookie字符串", text: $manualCookies)
                        .textFieldStyle(.roundedBorder)
                }
                
                // CSRF输入
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 2) {
                        Text("CSRF Token")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "questionmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .help("CSRF Token获取详细步骤：\n1. 在同一个\"send\"请求中，切换到下方的\"负载\"(Payload)标签\n2. 在\"表单数据\"(Form Data)部分查找\n3. 找到\"csrf\"或\"bili_jct\"字段\n4. 复制该字段对应的值（通常是32位随机字符串）\n\n注意：csrf和bili_jct是同一个值的不同名称，找到其中任何一个即可")
                    }
                    TextField("请输入bili_jct的值", text: $manualCSRF)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            // 显示保存时间信息
            if let savedDate = apiService.getLoginInfoSavedDate() {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                    Text("上次保存: \(savedDate, formatter: dateFormatter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var loginStatusColor: Color {
        switch loginStatus {
        case .idle:
            return .primary
        case .waitingForScan:
            return .blue
        case .scanned:
            return .orange
        case .success:
            return .green
        case .failed:
            return .red
        case .expired:
            return .red
        }
    }
    
    // MARK: - 私有方法
    
    private func generateQRCode() async {
        // 如果已经有保存的登录信息且未强制显示登录界面，则不生成二维码
        if let savedLoginInfo = apiService.getSavedLoginInfoFull(),
           !savedLoginInfo.userName.isEmpty,
           !forceShowLoginInterface {
            return
        }
        
        // 先停止当前的轮询（如果有的话）
        await MainActor.run {
            self.isPolling = false
            self.loginStatus = .idle
        }
        
        do {
            let qrInfo = try await apiService.getQRCode()
            self.qrCodeInfo = qrInfo
            
            // 生成二维码图片
            await MainActor.run {
                self.qrCodeImage = generateQRCodeImage(from: qrInfo.url)
                self.statusMessage = "请使用B站客户端扫描二维码"
                
                // 开始轮询登录状态
                startPolling()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        }
    }
    
    private func generateQRCodeImage(from string: String) -> NSImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        guard let data = string.data(using: .utf8) else { return nil }
        
        filter.message = data
        filter.correctionLevel = "M"
        
        guard let outputImage = filter.outputImage else { return nil }
        
        // 放大二维码
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        
        return NSImage(cgImage: cgImage, size: scaledImage.extent.size)
    }
    
    private func startPolling() {
        guard let qrInfo = qrCodeInfo, !isPolling else { return }
        
        isPolling = true
        loginStatus = .waitingForScan
        statusMessage = "请使用B站客户端扫描二维码"
        
        Task {
            while isPolling {
                do {
                    let loginSuccess = try await apiService.checkQRLogin(qrcodeKey: qrInfo.qrcodeKey)
                    
                    if loginSuccess {
                        await MainActor.run {
                            self.loginStatus = .success
                            self.statusMessage = "登录成功！"
                            self.isPolling = false
                        }
                        break
                    }
                    
                    // 等待1.5秒后继续轮询
                    try await Task.sleep(nanoseconds: 1_500_000_000)
                    
                } catch {
                    await MainActor.run {
                        if let apiError = error as? BilibiliAPIError {
                            switch apiError {
                            case .qrCodeExpired:
                                // 二维码已失效
                                self.loginStatus = .expired
                                self.statusMessage = "二维码已失效，请点击刷新"
                                self.isPolling = false
                            case .qrCodeScanned:
                                // 已扫描，等待确认 - 继续轮询，不停止，不显示错误
                                self.loginStatus = .scanned
                                self.statusMessage = "已扫描，请在手机上确认登录"
                                // 注意：不设置 isPolling = false，继续轮询
                                // 注意：不设置 showError = true，这不是错误状态
                            default:
                                self.loginStatus = .failed
                                self.errorMessage = error.localizedDescription
                                self.showError = true
                                self.isPolling = false
                            }
                        } else {
                            self.loginStatus = .failed
                            self.errorMessage = error.localizedDescription
                            self.showError = true
                            self.isPolling = false
                        }
                    }
                    
                    // 如果是失效错误，停止轮询
                    if let apiError = error as? BilibiliAPIError,
                       case .qrCodeExpired = apiError {
                        break
                    }
                }
            }
        }
    }
    
    private func stopPolling() {
        isPolling = false
        loginStatus = .idle
        statusMessage = "已停止扫描"
    }
    
    private func saveManualSettings() async {
        // 停止任何正在进行的二维码轮询
        await MainActor.run {
            stopPolling()
            self.isSavingManualLogin = true
        }
        
        defer {
            Task {
                await MainActor.run {
                    self.isSavingManualLogin = false
                }
            }
        }
        
        // 验证输入
        guard !manualRoomId.isEmpty else {
            await MainActor.run {
                self.errorMessage = "请输入直播间ID"
                self.showError = true
            }
            return
        }
        
        guard !manualCookies.isEmpty else {
            await MainActor.run {
                self.errorMessage = "请输入Cookies信息"
                self.showError = true
            }
            return
        }
        
        guard !manualCSRF.isEmpty else {
            await MainActor.run {
                self.errorMessage = "请输入CSRF Token"
                self.showError = true
            }
            return
        }
        
        do {
            // 调用API服务保存手动登录信息
            try await apiService.saveManualLogin(
                roomId: manualRoomId,
                cookies: manualCookies,
                csrf: manualCSRF
            )
            
            await MainActor.run {
                // 登录成功，无需显示任何消息，因为主界面会自动切换
                print("手动登录成功")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        }
    }
    
    private func loadSavedLoginInfo() {
        if let savedInfo = apiService.getSavedLoginInfo() {
            manualRoomId = savedInfo.roomId
            manualCookies = savedInfo.cookies
            manualCSRF = savedInfo.csrf
        } else {
            errorMessage = "没有找到已保存的登录信息"
            showError = true
        }
    }
    
    private func autoLogin() async {
        // 停止任何正在进行的二维码轮询
        await MainActor.run {
            stopPolling()
        }
        
        do {
            try await apiService.loadSavedLogin()
            await MainActor.run {
                print("自动登录成功")
            }
        } catch {
            await MainActor.run {
                // 检查是否是认证失败错误（cookie失效）
                if let apiError = error as? BilibiliAPIError,
                   case .authenticationRequired = apiError {
                    // Cookie失效，清除保存的登录信息并提示用户重新登录
                    apiService.logout()
                    self.errorMessage = "登录信息已过期，请重新登录"
                    self.showError = true
                    
                    // 自动切换到登录界面
                    self.forceShowLoginInterface = true
                    self.showManualLogin = false  // 默认显示扫码登录
                    
                    // 生成新的二维码
                    Task {
                        await generateQRCode()
                    }
                } else {
                    // 其他错误
                    self.errorMessage = "自动登录失败: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
}

#Preview {
    LoginView()
}
