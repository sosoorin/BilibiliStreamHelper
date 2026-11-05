//
//  FormRow.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/11/5.
//

import SwiftUI

/// 表单里的一行：固定宽度的标签 + 内容 + 行尾操作。
///
/// 卡片里每个字段都走这个结构，标签竖着对齐成一条线。
struct FormRow<Content: View>: View {
    
    let label: String
    @ViewBuilder var content: () -> Content
    
    init(_ label: String, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.content = content
    }
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .frame(width: 72, alignment: .leading)
                .foregroundColor(.secondary)
            content()
            Spacer(minLength: 0)
        }
    }
}
