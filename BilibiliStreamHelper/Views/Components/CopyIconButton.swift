//
//  CopyIconButton.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/11/5.
//

import SwiftUI
import AppKit

/// 行尾的复制图标：点完变成对勾，1.5 秒后恢复，不弹窗。
struct CopyIconButton: View {
    
    let value: String
    var label: String = "复制"
    
    @State private var copied = false
    
    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
            copied = true
            
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                copied = false
            }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
        }
        .buttonStyle(.borderless)
        .foregroundColor(copied ? .secondary : .accentColor)
        .help(copied ? "已复制" : label)
        .accessibilityLabel(copied ? "已复制" : label)
    }
}
