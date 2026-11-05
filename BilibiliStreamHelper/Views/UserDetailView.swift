//
//  UserDetailView.swift
//  BilibiliLiveStremCodeSwift
//
//  Created by sosoorin on 2025/09/23.
//

import SwiftUI
import AppKit

// MARK: - 用户详情弹窗

struct UserDetailView: View {
    let userInfo: UserInfo
    let onLogout: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            Form {
                Section {
                    row("等级", icon: "chart.bar", value: "Lv.\(String(userInfo.level))")
                    row("硬币", icon: "bitcoinsign.circle", value: formattedCoins(userInfo.money))
                }

                Section("统计") {
                    row("关注", icon: "person.badge.plus", value: String(userInfo.following ?? 0))
                    row("粉丝", icon: "person.2", value: String(userInfo.follower ?? 0))
                    row("动态", icon: "square.grid.2x2", value: String(userInfo.dynamicCount ?? 0))
                }
            }
            .formStyle(.grouped)

            Divider()

            footer
        }
        .frame(width: 360, height: 460)
    }

    private func row(_ title: String, icon: String, value: String) -> some View {
        LabeledContent {
            Text(value)
                .monospacedDigit()
        } label: {
            HStack(spacing: 8) {
                // SF Symbol 宽度各不相同，固定列宽文字才排得齐
                Image(systemName: icon)
                    .frame(width: 16, alignment: .center)
                Text(title)
            }
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: 14) {
            avatar

            VStack(alignment: .leading, spacing: 3) {
                Text(userInfo.uname)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .textSelection(.enabled)
                Text("UID \(String(userInfo.mid))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private var avatar: some View {
        AsyncImage(url: URL(string: userInfo.face)) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            Image(systemName: "person.fill")
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.secondary.opacity(0.12))
        }
        .frame(width: 64, height: 64)
        .clipShape(Circle())
    }

    // MARK: - 底部

    private var footer: some View {
        HStack {
            Button("退出登录", role: .destructive) {
                onLogout()
            }
            .foregroundStyle(.red)

            Spacer()

            Button("关闭") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(16)
    }

    // MARK: - 格式化

    /// B站的硬币可能带一位小数（4034.5），整数就不显示小数点
    func formattedCoins(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }
}

#Preview {
    UserDetailView(
        userInfo: UserInfo(
            mid: 8434593,
            uname: "汪汪Ame小小苏",
            face: "https://i0.hdslb.com/bfs/face/default.jpg",
            money: 4034.5,
            level: 6,
            follower: 2023,
            following: 462,
            dynamicCount: 76
        ),
        onLogout: {}
    )
}
