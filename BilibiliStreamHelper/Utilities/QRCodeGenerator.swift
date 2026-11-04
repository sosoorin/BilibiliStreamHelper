//
//  QRCodeGenerator.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/9/23.
//

import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// 生成二维码图片。
///
/// 登录扫码和人脸认证扫码用的是同一套东西，之前两个视图各写了一份。
enum QRCodeGenerator {
    
    /// 把字符串编码成二维码图片；编码失败返回 nil
    /// - Parameter scale: 放大倍数，默认 10（原始输出只有几十像素）
    static func image(from string: String, scale: CGFloat = 10) -> NSImage? {
        guard let data = string.data(using: .utf8) else { return nil }
        
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"
        
        guard let output = filter.outputImage else { return nil }
        
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        
        return NSImage(cgImage: cgImage, size: scaled.extent.size)
    }
}
