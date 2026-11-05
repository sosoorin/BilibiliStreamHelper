//
//  SectionCard.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/9/23.
//

import SwiftUI

/// 带标题栏的卡片容器。
///
/// 六个视图里原来各自重复着同一套结构：标题行 + 彩色底 + 内容区 + 圆角阴影。
/// 抽出来之后，圆角、阴影、内边距只有一处定义。
struct SectionCard<Content: View, Trailing: View>: View {
    
    let icon: String
    let title: String
    var accent: Color
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content
    
    init(
        icon: String,
        title: String,
        accent: Color = .blue,
        @ViewBuilder trailing: @escaping () -> Trailing,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.accent = accent
        self.trailing = trailing
        self.content = content
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(accent)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                trailing()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(accent.opacity(0.1))
            
            // 内容区不再重复铺背景：外层整卡已经是同一个颜色
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

extension SectionCard where Trailing == EmptyView {
    
    init(
        icon: String,
        title: String,
        accent: Color = .blue,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(icon: icon, title: title, accent: accent, trailing: { EmptyView() }, content: content)
    }
}
