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
    
    var body: some View {
            VStack(spacing: 24) {
                if let streamInfo = apiService.streamInfo {
                    // 推流信息卡片
                    SectionCard(icon: "server.rack", title: "推流信息", accent: .teal) {
                        Button("复制全部") {
                            copyAllInfo()
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } content: {
                        VStack(alignment: .leading, spacing: 14) {
                            FormRow("服务器地址") {
                                Text(streamInfo.rtmpAddr)
                                    .font(.system(.body, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .textSelection(.enabled)
                                CopyIconButton(value: streamInfo.rtmpAddr, label: "复制服务器地址")
                            }
                            
                            FormRow("推流码") {
                                Text(streamInfo.rtmpCode)
                                    .font(.system(.body, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .textSelection(.enabled)
                                CopyIconButton(value: streamInfo.rtmpCode, label: "复制推流码")
                            }
                            
                            Divider()
                            
                            Text("填进 OBS 的「服务器」和「串流密钥」，步骤见菜单栏「帮助 → 使用说明」")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                }
            }
        }
    }

    // MARK: - 复制
    
    /// 一次把服务器和推流码都复制走，省得在 OBS 里分两次粘
    private func copyAllInfo() {
        guard let info = apiService.streamInfo else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("服务器: \(info.rtmpAddr)\n推流码: \(info.rtmpCode)", forType: .string)
    }
}

// MARK: - 步骤说明行（用于获取推流信息步骤）
// MARK: - 说明步骤行
#Preview {
    StreamInfoView()
}
