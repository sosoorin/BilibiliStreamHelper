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
    @StateObject private var vm = LoginViewModel()
    
    // 日期格式化器
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack(spacing: 30) {
            // 标题：macOS 的登录界面是左对齐的表单，不是居中的欢迎页
            VStack(alignment: .leading, spacing: 4) {
                Text("B站直播助手")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("快速获取 B 站直播推流码")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // 根据是否有保存的登录信息和强制显示状态决定界面
            if let savedLoginInfo = apiService.getSavedLoginInfoFull(), !savedLoginInfo.userName.isEmpty, !vm.forceShowLoginInterface {
                // 有保存的登录信息且未强制显示登录界面：显示用户资料和登录按钮
                savedUserLoginView(loginInfo: savedLoginInfo)
            } else {
                // 没有保存的登录信息或强制显示登录界面：显示完整的登录界面
                newUserLoginView()
            }
            
        }
        .padding(24)
        .frame(width: 408)
        .onAppear {
            // 测试宿主里不要启动登录流程：会发真实网络请求
            guard !AppEnvironment.isRunningTests else { return }
            // 是否真的需要拉二维码，由 ViewModel 自己判断
            Task { await vm.generateQRCode() }
        }
        .onDisappear {
            // 界面消失时停止轮询
            vm.stopPolling()
        }
        .alert("登录错误", isPresented: $vm.showError) {
            Button("确定") { }
        } message: {
            Text(vm.errorMessage)
        }
    }
    
    // MARK: - 视图组件
    
    private func savedUserLoginView(loginInfo: LoginInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 账号信息就是信息，不做成可点区域
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: loginInfo.userAvatar)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.gray)
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(loginInfo.userName)
                        .font(.headline)
                    Text("用户 ID \(loginInfo.userId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let savedDate = apiService.getLoginInfoSavedDate() {
                Text("上次登录 \(savedDate, formatter: dateFormatter)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 对话框的惯例：主按钮在右下，次要按钮在它左边
            HStack(spacing: 10) {
                Spacer()
                
                Button("切换账号") {
                    // 不动已保存的凭据：新账号登录成功后会自动覆盖，
                    // 中途放弃的话原来的账号还在。
                    vm.showManualLogin = false
                    vm.forceShowLoginInterface = true
                    Task { await vm.generateQRCode() }
                }
                .buttonStyle(.bordered)
                
                Button("继续") {
                    Task { await vm.autoLogin() }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func newUserLoginView() -> some View {
        VStack(spacing: 30) {
            // 如果有保存的登录信息，显示返回按钮
            if apiService.hasStoredLoginInfo() && vm.forceShowLoginInterface {
                HStack {
                    Button("← 返回") {
                        vm.forceShowLoginInterface = false
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Spacer()
                }
            }
            
            // 登录方式切换
            Picker("登录方式", selection: $vm.showManualLogin) {
                Text("扫码登录").tag(false)
                Text("手动输入").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: vm.showManualLogin) { _, newValue in
                if newValue {
                    // 切换到手动登录时停止二维码轮询
                    vm.stopPolling()
                } else {
                    // 切换到扫码登录时重新生成二维码
                    Task {
                        await vm.generateQRCode()
                    }
                }
            }
            
            // 登录区域
            if vm.showManualLogin {
                // 手动输入区域
                manualLoginView
            } else {
                // 二维码登录区域
                qrCodeLoginView
            }
            
            // 操作按钮
            if vm.showManualLogin {
                Button(vm.isSavingManualLogin ? "保存中..." : "保存设置") {
                    Task {
                        await vm.saveManualLogin()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.manualRoomId.isEmpty || vm.manualCookies.isEmpty || vm.manualCSRF.isEmpty || vm.isSavingManualLogin)
                
                HStack {
                    // 清空按钮
                    if !vm.manualRoomId.isEmpty || !vm.manualCookies.isEmpty || !vm.manualCSRF.isEmpty {
                        Button("清空输入") {
                            vm.manualRoomId = ""
                            vm.manualCookies = ""
                            vm.manualCSRF = ""
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                }
            } else {
                Button("刷新二维码") {
                    Task {
                        await vm.generateQRCode()
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
                            await vm.autoLogin()
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
            if let qrImage = vm.qrCodeImage {
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
            
            Text(vm.statusMessage)
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
                    TextField("请输入直播间ID", text: $vm.manualRoomId)
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
                    // Cookie 里含 SESSDATA，属于凭据，按 HIG 用安全输入框
                    SecureField("请输入完整的Cookie字符串", text: $vm.manualCookies)
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
                    // CSRF token 同样是凭据
                    SecureField("请输入bili_jct的值", text: $vm.manualCSRF)
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
            }
        }
    }
    
    private var loginStatusColor: Color {
        switch vm.loginStatus {
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
    
    
    
    
    
    
    private func loadSavedLoginInfo() {
        vm.fillManualFieldsFromSaved()
    }
    
}

#Preview {
    LoginView()
}
