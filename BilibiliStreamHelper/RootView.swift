//
//  RootView.swift
//  BilibiliLiveStremCodeSwift
//
//  Created by sosoorin on 2025/9/23.
//

import SwiftUI

struct RootView: View {
    @StateObject private var apiService = APIClient.shared
    
    var body: some View {
        ZStack {
            MainView()
                .disabled(!apiService.isLoggedIn)
            
            if !apiService.isLoggedIn {
                // 用覆盖层而不是 .sheet：sheet 会建立窗口级模态会话，
                // 登录窗口挂着的时候连退出 App 都会被挡住。
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                
                LoginView()
                    // 用不透明的窗口底色而不是 material：半透明材质在按钮边缘会
                    // 形成一圈光晕，看着像按钮自带重阴影
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(NSColor.windowBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.primary.opacity(0.08))
                    )
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: apiService.isLoggedIn)
    }

}
