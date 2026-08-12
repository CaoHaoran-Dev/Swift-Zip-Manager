//
//  PasswordCache.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import Foundation
import AppKit

/// 密码缓存管理器
/// 用于缓存 7z/RAR 归档的密码，一次使用后自动删除
class PasswordCache {
    static let shared = PasswordCache()
    
    private var cache: [String: String] = [:]
    private let lock = NSLock()
    
    private init() {
        // 监听 App 退出，清空缓存
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearAll),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }
    
    /// 存储密码
    func setPassword(_ password: String, for archivePath: String) {
        lock.lock()
        defer { lock.unlock() }
        cache[archivePath] = password
        let fileName = (archivePath as NSString).lastPathComponent
        print("🔑 [PasswordCache] Stored password for: \(fileName)")
    }
    
    /// 获取并移除密码（一次性使用）
    func getAndRemovePassword(for archivePath: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        let password = cache.removeValue(forKey: archivePath)
        if password != nil {
            let fileName = (archivePath as NSString).lastPathComponent
            print("🔑 [PasswordCache] Retrieved and removed password for: \(fileName)")
        }
        return password
    }
    
    /// 获取密码（不删除）
    func peekPassword(for archivePath: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return cache[archivePath]
    }
    
    /// 清除所有缓存
    @objc func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        let count = cache.count
        cache.removeAll()
        print("🔑 [PasswordCache] Cleared all \(count) cached passwords")
    }
    
    /// 清除特定归档的密码
    func clearPassword(for archivePath: String) {
        lock.lock()
        defer { lock.unlock() }
        cache.removeValue(forKey: archivePath)
        let fileName = (archivePath as NSString).lastPathComponent
        print("🔑 [PasswordCache] Cleared password for: \(fileName)")
    }
    
    /// 检查是否有缓存
    func hasPassword(for archivePath: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return cache[archivePath] != nil
    }
}
