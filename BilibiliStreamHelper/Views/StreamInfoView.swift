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
                // 推流状态卡片
                SectionCard(
                    icon: apiService.isLiveActive ? "dot.radiowaves.left.and.right" : "stop.circle",
                    title: "推流状态",
                    accent: apiService.isLiveActive ? .green : .gray
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
                    VStack(spacing: 16) {
                        // 推流状态指示器
                        VStack(spacing: 15) {
                            Circle()
                                .fill(apiService.isLiveActive ? Color.green : Color.gray)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: apiService.isLiveActive ? "dot.radiowaves.left.and.right" : "stop.circle")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                )
                                .shadow(radius: 5)
                            
                            Text(apiService.isLiveActive ? "直播进行中" : "直播未开始")
                                .font(.headline)
                                .foregroundColor(apiService.isLiveActive ? .green : .secondary)
                        }
                    }
                }
                    
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
                            
                            Divider()
                            
                            // 操作按钮
                            HStack(spacing: 12) {
                                Button("停止直播") {
                                    Task {
                                        if await vm.stopLive() {
                                            copyToastMessage = "直播已停止"
                                            showCopyToast = true
                                        }
                                    }
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(.red)
                                
                                Spacer()
                            }
                        }
                    }
                        
                } else {
                    // 无推流信息时的提示卡片
                    SectionCard(icon: "info.circle", title: "获取推流信息", accent: .orange) {
                    } content: {
                        VStack(spacing: 20) {
                            VStack(spacing: 15) {
                                Image(systemName: "tv.slash")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                
                                Text("暂无推流信息")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                
                                Text("请先开始直播以获取推流信息")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("获取推流码的步骤")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    StepInstructionRow(step: "1", text: "前往\"直播设置\"页面")
                                    StepInstructionRow(step: "2", text: "设置直播标题和分区")
                                    StepInstructionRow(step: "3", text: "点击\"开始直播\"按钮")
                                    StepInstructionRow(step: "4", text: "回到此页面查看推流信息")
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
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
struct StepInstructionRow: View {
    let step: String
    let text: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(step)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.orange)
                .clipShape(Circle())
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

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
