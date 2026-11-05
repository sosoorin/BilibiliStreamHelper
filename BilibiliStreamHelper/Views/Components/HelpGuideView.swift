//
//  HelpGuideView.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/9/23.
//

import SwiftUI

/// 使用说明：只讲界面上看不出来的事，其余交给界面本身。
struct HelpGuideView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("怎么用")
                .font(.headline)

            paragraph(
                "看对方资料",
                "鼠标停在用户名上，会弹出这个人的头像、粉丝牌和等级。"
            )

            paragraph(
                "弹幕连接",
                "切到「弹幕」页会自动连上当前直播间；断了点顶部状态重连。"
            )

            Divider()

            HStack {
                Spacer()
                Button("关闭") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(18)
        .frame(width: 340)
    }

    private func paragraph(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
