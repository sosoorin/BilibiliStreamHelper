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
            
            VStack(alignment: .leading, spacing: 8) {
                bullet("填好标题和分区，点右上角 ▶ 开播")
                bullet("开播后下方出现推流地址和密钥，复制进 OBS")
                bullet("下播点右上角 ■，不要在 OBS 里点「停止推流」")
            }
            
            Divider()
            
            Text("在 OBS 里停止推流只会断流，直播间还挂着。")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack {
                Spacer()
                Button("关闭") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(18)
        .frame(width: 300)
    }
    
    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.secondary)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
