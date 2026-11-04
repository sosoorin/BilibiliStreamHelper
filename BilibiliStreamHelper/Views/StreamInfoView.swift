//
//  StreamInfoView.swift
//  BilibiliLiveStremCodeSwift
//
//  Created by sosoorin on 2025/9/23.
//

import SwiftUI
import os
import AppKit

struct StreamInfoView: View {
    @StateObject private var apiService = APIClient.shared
    @StateObject private var vm = StreamInfoViewModel()
    @State private var copyToastMessage = ""
    @State private var showCopyToast = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let streamInfo = apiService.streamInfo {
                    // 推流信息卡片
                    SectionCard(icon: "server.rack", title: "推流信息", accent: .blue) {
                        Button("复制全部") {
                            copyAllInfo()
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } content: {
                        VStack(spacing: 20) {
                            // 服务器地址
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "server.rack")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    Text("服务器地址")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Button("复制") {
                                        copyToClipboard(streamInfo.rtmpAddr, type: "服务器地址")
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .font(.caption)
                                }
                                
                                Text(streamInfo.rtmpAddr)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .padding(12)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                    .textSelection(.enabled)
                            }
                            
                            Divider()
                            
                            // 推流码
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "key.fill")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    Text("推流码")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Button("复制") {
                                        copyToClipboard(streamInfo.rtmpCode, type: "推流码")
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .font(.caption)
                                }
                                
                                Text(streamInfo.rtmpCode)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .padding(12)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                    .textSelection(.enabled)
                            }
                            
                        }
                    }
                        
                }
                
                // OBS 使用说明卡片
                SectionCard(icon: "desktopcomputer", title: "OBS 设置说明", accent: .green) {
                } content: {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            InstructionRow(step: "1", text: "打开 OBS Studio")
                            InstructionRow(step: "2", text: "点击\"设置\" → \"推流\"")
                            InstructionRow(step: "3", text: "服务选择\"自定义\"")
                            InstructionRow(step: "4", text: "将上方的服务器地址复制到\"服务器\"框")
                            InstructionRow(step: "5", text: "将上方的推流码复制到\"串流密钥\"框")
                            InstructionRow(step: "6", text: "点击\"应用\"后即可开始推流")
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(NSColor.controlBackgroundColor))
            .refreshable {
                // 这里可以添加刷新逻辑
            }
            .overlay(
                // Toast 提示
                VStack {
                    Spacer()
                    if showCopyToast {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(copyToastMessage)
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(NSColor.windowBackgroundColor))
                        .cornerRadius(25)
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0), value: showCopyToast)
                    }
                }
                .padding(.bottom, 50)
                , alignment: .bottom
            )
        .alert("操作失败", isPresented: $vm.showError) {
            Button("确定") { }
        } message: {
            Text(vm.errorMessage)
        }
    }
    
    // MARK: - 私有方法
    
    private func copyToClipboard(_ text: String, type: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        // 添加调试信息
        
        _ = pasteboard.setString(text, forType: .string)
        
        // 验证复制是否成功
        if let copiedText = pasteboard.string(forType: .string) {
            AppLog.live.debug("验证复制成功，获取到的文本: \(copiedText, privacy: .public)")
            showToast("\(type)已复制")
        } else {
            AppLog.live.debug("复制验证失败")
            vm.errorMessage = "复制失败，请检查系统权限或重试"
            vm.showError = true
        }
    }
    
    private func copyAllInfo() {
        guard let streamInfo = apiService.streamInfo else { return }
        
        let fullInfo = """
        B站直播推流信息
        
        服务器地址: \(streamInfo.rtmpAddr)
        推流码: \(streamInfo.rtmpCode)
        
        生成时间: \(Date().formatted(date: .abbreviated, time: .shortened))
        """
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        _ = pasteboard.setString(fullInfo, forType: .string)
        
        // 验证复制是否成功
        if let copiedText = pasteboard.string(forType: .string) {
            AppLog.live.debug("完整信息复制成功，长度: \(copiedText.count, privacy: .public)")
            showToast("完整推流信息已复制")
        } else {
            AppLog.live.debug("完整信息复制失败")
            DispatchQueue.main.async {
                self.vm.errorMessage = "复制失败，请检查系统权限或重试"
                self.vm.showError = true
            }
        }
    }
    
    
    private func showToast(_ message: String) {
        DispatchQueue.main.async {
            self.copyToastMessage = message
            self.showCopyToast = true
            
            // 2秒后自动隐藏
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    self.showCopyToast = false
                }
            }
        }
    }
}

// MARK: - 步骤说明行（用于获取推流信息步骤）
// MARK: - 说明步骤行
struct InstructionRow: View {
    let step: String
    let text: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(step)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.blue)
                .clipShape(Circle())
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

#Preview {
    StreamInfoView()
}
