//
//  AvatarCache.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/9/23.
//

import Foundation
import os

// MARK: - Avatar Cache Manager

class AvatarCache {
    private static let cacheDirectory: URL = {
        let urls = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheDir = urls[0].appendingPathComponent("AvatarCache")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        return cacheDir
    }()
    
    static func cacheAvatar(from url: String, userId: String, forceRefresh: Bool = false) async -> URL? {
        guard let imageURL = URL(string: url) else { return nil }
        
        let cacheFileName = "\(userId)_avatar.jpg"
        let cacheFileURL = cacheDirectory.appendingPathComponent(cacheFileName)
        
        // 如果不强制刷新且已经缓存了，直接返回
        if !forceRefresh && FileManager.default.fileExists(atPath: cacheFileURL.path) {
            AppLog.network.debug("使用已缓存的头像: \(cacheFileURL.path, privacy: .public)")
            return cacheFileURL
        }
        
        do {
            // 下载新头像
            let (data, _) = try await URLSession.shared.data(from: imageURL)
            
            // 如果已存在旧文件，先删除
            if FileManager.default.fileExists(atPath: cacheFileURL.path) {
                try FileManager.default.removeItem(at: cacheFileURL)
                AppLog.network.debug("已删除旧的头像缓存")
            }
            
            // 保存新头像
            try data.write(to: cacheFileURL)
            AppLog.network.debug("头像已更新缓存到: \(cacheFileURL.path, privacy: .public)")
            return cacheFileURL
        } catch {
            AppLog.network.debug("头像缓存失败: \(error, privacy: .public)")
            return nil
        }
    }
    
    static func getCachedAvatarURL(for userId: String) -> URL? {
        let cacheFileName = "\(userId)_avatar.jpg"
        let cacheFileURL = cacheDirectory.appendingPathComponent(cacheFileName)
        
        return FileManager.default.fileExists(atPath: cacheFileURL.path) ? cacheFileURL : nil
    }
    
    static func clearAvatarCache(for userId: String) {
        let cacheFileName = "\(userId)_avatar.jpg"
        let cacheFileURL = cacheDirectory.appendingPathComponent(cacheFileName)
        try? FileManager.default.removeItem(at: cacheFileURL)
    }
}
