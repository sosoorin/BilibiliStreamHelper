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
        Group {
            if apiService.isLoggedIn {
                MainView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.5), value: apiService.isLoggedIn)
    }
}

#Preview {
    RootView()
}
