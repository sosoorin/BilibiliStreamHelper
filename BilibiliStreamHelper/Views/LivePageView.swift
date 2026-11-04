//
//  LivePageView.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/9/23.
//

import SwiftUI

/// 「直播」页。
///
/// 原来侧边栏里「直播设置」和「推流信息」是两项，但它们是一条流程的两个阶段：
/// 没开播时只有设置有意义，开播后只有推流信息有意义。
/// 合并成一页之后，内容跟着直播状态走，不再需要用户自己在两项之间切。
struct LivePageView: View {
    
    private enum Section {
        case settings
        case stream
    }
    
    @StateObject private var apiService = APIClient.shared
    @State private var section: Section = .settings
    
    var body: some View {
        VStack(spacing: 0) {
            // 只有开播后才有两个子页，平时不显示切换条
            if apiService.isLiveActive {
                Picker("", selection: $section) {
                    Text("直播设置").tag(Section.settings)
                    Text("推流信息").tag(Section.stream)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 280)
                .padding(.vertical, 10)
            }
            
            switch activeSection {
            case .settings:
                LiveSettingsView(onNavigateToStreamInfo: { section = .stream })
            case .stream:
                StreamInfoView()
            }
        }
        .onChange(of: apiService.isLiveActive) { isLive in
            // 开播后自动切到推流信息，省掉原来那个「是否跳转」的弹窗
            section = isLive ? .stream : .settings
        }
    }
    
    /// 没开播时无论选中哪个，都只能看到设置
    private var activeSection: Section {
        apiService.isLiveActive ? section : .settings
    }
}
