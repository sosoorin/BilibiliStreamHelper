//
//  BilibiliLiveStremCodeSwiftApp.swift
//  BilibiliLiveStremCodeSwift
//
//  Created by sosoorin on 2025/9/23.
//

import SwiftUI

@main
struct BilibiliLiveStremCodeSwiftApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .commands {
            CommandGroup(replacing: .help) {
                Button("B站直播助手 使用说明") {
                    HelpCenter.shared.show()
                }
            }
        }
    }
}
