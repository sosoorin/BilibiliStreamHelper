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

    private var streamInfo: StreamInfo? { apiService.streamInfo }

    /// 推流码默认遮起来，要看再点眼睛
    @State private var revealCode = false

    var body: some View {
        VStack(spacing: 24) {
            SectionCard(icon: "server.rack", title: "推流信息", accent: .teal) {
                // 按钮常驻，没值时禁用：它比标题字高，一出现就会把标题栏撑高
                Button {
                    copyAllInfo()
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(streamInfo == nil)
                .help("复制服务器地址和推流码")
                .accessibilityLabel("复制全部")
            } content: {
                VStack(alignment: .leading, spacing: 14) {
                    FormRow("服务器地址") {
                        valueText(streamInfo?.rtmpAddr)
                        // 复制按钮一直占位，只在没值时禁用——不然开播时这一行会被撑高
                        CopyIconButton(value: streamInfo?.rtmpAddr ?? "", label: "复制服务器地址")
                            .opacity(streamInfo?.rtmpAddr == nil ? 0 : 1)
                            .disabled(streamInfo?.rtmpAddr == nil)
                    }

                    FormRow("推流码") {
                        valueText(maskedCode)
                        Button {
                            revealCode.toggle()
                        } label: {
                            Image(systemName: revealCode ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                        .opacity(streamInfo == nil ? 0 : 1)
                        .disabled(streamInfo == nil)
                        .help(revealCode ? "隐藏推流码" : "显示推流码")
                        .accessibilityLabel(revealCode ? "隐藏推流码" : "显示推流码")

                        CopyIconButton(value: streamInfo?.rtmpCode ?? "", label: "复制推流码")
                            .opacity(streamInfo?.rtmpCode == nil ? 0 : 1)
                            .disabled(streamInfo?.rtmpCode == nil)
                    }

                    Divider()

                    Text(streamInfo == nil
                         ? "开播后这里会显示推流地址和密钥。"
                         : "填进 OBS 的「服务器」和「串流密钥」。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var maskedCode: String? {
        guard let code = streamInfo?.rtmpCode else { return nil }
        return revealCode ? code : String(repeating: "•", count: min(code.count, 40))
    }

    /// 占位和真值用同样的结构，开播时卡片高度不变，下面的内容不会跳
    @ViewBuilder
    private func valueText(_ value: String?) -> some View {
        Text(value ?? "—")
            .font(.system(.body, design: .monospaced))
            .lineLimit(1)
            .truncationMode(.middle)
            .foregroundStyle(value == nil ? Color.secondary : Color.primary)
            .textSelection(.enabled)
    }

    // MARK: - 复制

    /// 一次把服务器和推流码都复制走，省得在 OBS 里分两次粘
    private func copyAllInfo() {
        guard let info = apiService.streamInfo else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("服务器: \(info.rtmpAddr)\n推流码: \(info.rtmpCode)", forType: .string)
    }
}

#Preview {
    StreamInfoView()
}
