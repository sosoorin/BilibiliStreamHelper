//
//  Color+RGB.swift
//  BilibiliStreamHelper
//

import SwiftUI

extension Color {

    /// B站弹幕颜色是十进制 RGB。
    ///
    /// 太亮的颜色（纯白、浅黄）在浅色聊天区里根本看不清，
    /// 所以按亮度兜底回主文字色——网页端是黑底白字，我们不是。
    /// 不过滤亮度的版本，给徽章底色用
    init(decimalRGB rgb: UInt32) {
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }

    init?(bilibiliRGB rgb: UInt32?) {
        guard let rgb else { return nil }

        let red = Double((rgb >> 16) & 0xFF) / 255
        let green = Double((rgb >> 8) & 0xFF) / 255
        let blue = Double(rgb & 0xFF) / 255

        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        guard luminance < 0.82 else { return nil }

        self.init(red: red, green: green, blue: blue)
    }
}
