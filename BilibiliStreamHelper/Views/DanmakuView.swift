//
//  DanmakuView.swift
//  BilibiliLiveStremCodeSwift
//
//  Created by sosoorin on 2025/9/23.
//

import SwiftUI

struct DanmakuView: View {
    @StateObject private var apiService = APIClient.shared
    @StateObject private var center = DanmakuCenter.shared
    @StateObject private var vm = DanmakuViewModel()

    @State private var autoScroll = true
    /// 用户往上翻了之后，新消息只计数不打扰
    @State private var pendingNew = 0
    @State private var isPreparingSend = false

    private let bottomAnchorID = "chat-bottom-anchor"

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 12) {
                statusBar
                messageList(proxy)
                inputBar
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .task {
            if apiService.isLoggedIn {
                center.connect()
            }
        }
        .onChange(of: apiService.isLoggedIn) { _, loggedIn in
            if loggedIn {
                // 登录回调比 getRoomId 早，先补一次再连，不然会立刻报"还没拿到直播间号"
                Task {
                    if apiService.currentRoomId.isEmpty {
                        try? await apiService.getRoomId()
                    }
                    center.connect()
                }
            } else {
                center.disconnect()
            }
        }
        .alert("发送失败", isPresented: $vm.showError) {
            Button("确定") { }
        } message: {
            Text(vm.errorMessage)
        }
    }

    // MARK: - 状态条

    private var statusBar: some View {
        HStack(spacing: 8) {
            connectionToggle

            if let popularity = center.popularity {
                Text("· 人气 \(popularity)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    /// 状态只读，开关单独一个图标按钮——跟工具栏里那些按钮同一套样子
    private var connectionToggle: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)

            Button {
                center.state.isActive ? center.disconnect() : center.connect()
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.accessoryBar)
            .disabled(!apiService.isLoggedIn && !center.state.isActive)
            .help(center.state.isActive ? "断开弹幕" : "连接弹幕")
            .accessibilityLabel(center.state.isActive ? "断开弹幕" : "连接弹幕")
        }
    }

    private func jumpToBottom(_ proxy: ScrollViewProxy) {
        pendingNew = 0
        autoScroll = true
        if let last = center.items.last {
            withAnimation(.easeOut(duration: 0.15)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private var statusColor: Color {
        switch center.state {
        case .idle: return .gray
        case .connecting: return .orange
        case .connected: return .green
        case .reconnecting: return .orange
        case .failed: return .red
        }
    }

    private var statusText: String {
        switch center.state {
        case .idle: return apiService.isLoggedIn ? "未连接" : "未登录"
        case .connecting: return "连接中…"
        case .connected: return "已连接"
        case .reconnecting(let attempt): return "第 \(attempt) 次重连中…"
        case .failed(let message): return message
        }
    }

    // MARK: - 消息列表

    private func messageList(_ proxy: ScrollViewProxy) -> some View {
        GeometryReader { outer in
            ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if center.items.isEmpty {
                            emptyPlaceholder
                        } else {
                            ForEach(center.items) { item in
                                DanmakuChatRow(item: item)
                                    .id(item.id)
                            }

                            // 底边探针：告诉上面"内容底部现在滚到哪了"
                            Color.clear
                                .frame(height: 1)
                                .id(bottomAnchorID)
                                .background(
                                    GeometryReader { inner in
                                        Color.clear.preference(
                                            key: ChatBottomKey.self,
                                            value: inner.frame(in: .named("chatScroll")).maxY
                                        )
                                    }
                                )
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .coordinateSpace(name: "chatScroll")
                .onPreferenceChange(ChatBottomKey.self) { bottom in
                    // 和上游一样：贴到底部附近就恢复跟随，明显离开了就停
                    let distance = bottom - outer.size.height
                    if distance < 50 {
                        autoScroll = true
                        pendingNew = 0
                    } else if distance > 120 {
                        autoScroll = false
                    }
                }
                .onChange(of: center.items.last?.id) {
                    guard let last = center.items.last else { return }
                    if autoScroll {
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    } else {
                        pendingNew += 1
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if !autoScroll {
                        Button {
                            jumpToBottom(proxy)
                        } label: {
                            if pendingNew > 0 {
                                Label("\(String(pendingNew)) 条新消息", systemImage: "arrow.down")
                            } else {
                                Label("跳至底部", systemImage: "arrow.down")
                            }
                        }
                        .font(.caption)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .padding(12)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(10)
        }
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "message")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(apiService.isLoggedIn ? "等待弹幕…" : "登录后自动连接直播间弹幕")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - 输入条

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("说点什么…", text: $vm.danmakuText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)
                .onSubmit {
                    if !vm.danmakuText.isEmpty {
                        sendDanmaku()
                    }
                }

            Button("发送") {
                sendDanmaku()
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.danmakuText.isEmpty || vm.isSending || !apiService.isLoggedIn)
            .help(center.state.isActive ? "发送弹幕" : "会先连上弹幕服务器再发送")
        }
    }

    /// 没连上就先连——不然发出去的弹幕自己在聊天区里看不到回显
    private func sendDanmaku() {
        guard !isPreparingSend else { return }
        isPreparingSend = true
        Task {
            defer { isPreparingSend = false }

            if !center.state.isActive {
                center.connect()
                let deadline = Date().addingTimeInterval(3)
                while Date() < deadline {
                    if center.state == .connected { break }
                    if case .failed = center.state { return }
                    try? await Task.sleep(for: .milliseconds(100))
                }
                guard center.state == .connected else { return }
            }
            await vm.send()
        }
    }
}

// MARK: - 消息行

struct DanmakuChatRow: View {
    let item: DanmakuChatItem

    @State private var showUserCard = false
    @State private var openTask: Task<Void, Never>?
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        if item.kind == .divider {
            divider
        } else {
            row
        }
    }

    private var divider: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.secondary.opacity(0.25))
                .frame(height: 0.5)
            Text(item.text)
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize()
            Rectangle()
                .fill(Color.secondary.opacity(0.25))
                .frame(height: 0.5)
        }
        .padding(.vertical, 4)
        .onDisappear {
            openTask?.cancel()
            dismissTask?.cancel()
        }
    }

    private var row: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(item.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundColor(.secondary)
                .monospacedDigit()

            if !item.uname.isEmpty {
                Text(item.uname)
                    .font(.caption)
                    .foregroundColor(nameColor)
                    .lineLimit(1)
                    .onHover { hovering in
                        hovering ? scheduleOpen() : cancelOpen()
                    }
                    .popover(isPresented: $showUserCard, arrowEdge: .bottom) {
                        DanmakuUserCard(item: item)
                            .onHover { hovering in
                                hovering ? dismissTask?.cancel() : scheduleDismiss()
                            }
                    }
            }

            Text(item.text)
                .font(.callout)
                .foregroundColor(textColor)
                .textSelection(.enabled)

            Spacer(minLength: 0)
        }
    }

    /// 悬停要停一下才弹，否则鼠标扫过整列弹幕的时候卡片会跟着乱闪
    private func scheduleOpen() {
        dismissTask?.cancel()
        openTask?.cancel()
        openTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            showUserCard = true
        }
    }

    private func cancelOpen() {
        openTask?.cancel()
        openTask = nil
        scheduleDismiss()
    }

    /// 鼠标离开后等一小会儿再收，否则从名字移到浮窗的途中就关了
    private func scheduleDismiss() {
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            showUserCard = false
        }
    }

    private var nameColor: Color {
        item.isSelf ? .accentColor : .secondary
    }

    private var textColor: Color {
        switch item.kind {
        case .danmaku:
            // 用户自定义颜色优先，亮到看不清时退回主文字色
            return Color(bilibiliRGB: item.color) ?? .primary
        case .gift: return .orange
        case .interact: return .secondary
        case .system: return .secondary
        case .divider: return .secondary
        }
    }
}

// MARK: - 用户悬浮卡

struct DanmakuUserCard: View {
    let item: DanmakuChatItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                avatar
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.uname)
                        .font(.headline)
                        .textSelection(.enabled)

                    HStack(spacing: 4) {
                        // 前缀只是标签，不参与选择
                        Text("UID")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(item.uid))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }

            if item.medal != nil || item.guardLevel != nil {
                HStack(spacing: 6) {
                    if let medal = item.medal {
                        Text("\(medal.name) \(medal.level)")
                            .font(.caption2)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color(decimalRGB: medal.color))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    if let guardLevel = item.guardLevel {
                        Text(guardName(guardLevel))
                            .font(.caption2)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.85))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
            }

            HStack(spacing: 14) {
                if let level = item.userLevel {
                    Label("用户等级 \(String(level))", systemImage: "person.crop.circle")
                        .font(.caption)
                }
                if let wealth = item.wealthLevel {
                    Label("荣耀等级 \(String(wealth))", systemImage: "diamond")
                        .font(.caption)
                }
            }
            .foregroundColor(.secondary)
        }
        .padding(14)
        .frame(minWidth: 210, alignment: .leading)
    }

    @ViewBuilder
    private var avatar: some View {
        if let faceURL = item.faceURL, let url = URL(string: faceURL) {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    Color.secondary.opacity(0.15)
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 48, height: 48)
        }
    }

    private func guardName(_ level: Int) -> String {
        switch level {
        case 1: return "舰长"
        case 2: return "提督"
        case 3: return "总督"
        default: return "大航海"
        }
    }
}

/// 内容底边在滚动坐标里的位置，用来判断有没有滚到底
private struct ChatBottomKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    DanmakuView()
}
