//
//  ToolPathResolver.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import Foundation

class ToolPathResolver {
    private let fileManager = FileManager.default
    
    // ✅ #18: 缓存机制
    private var cache: [String: String] = [:]
    private var cacheTimestamp: Date?
    private let cacheExpiry: TimeInterval = 5.0 // 5秒缓存过期
    
    /// 应用支持目录下的工具路径
    private var appSupportToolsPath: String {
        let home = fileManager.homeDirectoryForCurrentUser.path
        let path = "\(home)/Library/Application Support/com.haoran.Swift-Zip-Manager/tools"
        try? fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }
    
    /// ✅ #19: 系统 PATH 搜索路径
    private var systemPaths: [String] {
        let pathEnv = ProcessInfo.processInfo.environment["PATH"] ?? ""
        return pathEnv.split(separator: ":").map { String($0) }
    }
    
    /// ✅ #18: 清除缓存
    func invalidateCache() {
        cache.removeAll()
        cacheTimestamp = nil
        print("🔄 Tool cache invalidated")
    }
    
    /// 获取工具的完整路径（检测 App Support + 系统 PATH）
    func resolve(_ command: String) -> String? {
        // ✅ #18: 检查缓存
        if let cached = cache[command],
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheExpiry {
            if fileManager.fileExists(atPath: cached) {
                return cached
            }
        }
        
        // 1. 检测 App Support
        let appSupportPath = "\(appSupportToolsPath)/\(command)"
        if fileManager.fileExists(atPath: appSupportPath) {
            if fileManager.isExecutableFile(atPath: appSupportPath) {
                print("✅ Found \(command) in App Support: \(appSupportPath)")
                cache[command] = appSupportPath
                cacheTimestamp = Date()
                return appSupportPath
            } else {
                try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: appSupportPath)
                if fileManager.isExecutableFile(atPath: appSupportPath) {
                    print("✅ Fixed permissions for \(command) in App Support")
                    cache[command] = appSupportPath
                    cacheTimestamp = Date()
                    return appSupportPath
                }
            }
        }
        
        // ✅ #19: 2. 检测系统 PATH
        for systemPath in systemPaths {
            let fullPath = "\(systemPath)/\(command)"
            if fileManager.fileExists(atPath: fullPath) && fileManager.isExecutableFile(atPath: fullPath) {
                print("✅ Found \(command) in system PATH: \(fullPath)")
                cache[command] = fullPath
                cacheTimestamp = Date()
                return fullPath
            }
        }
        
        print("❌ \(command) not found in App Support or system PATH")
        return nil
    }
    
    /// 检查工具是否已安装
    func isInstalled(_ command: String) -> Bool {
        return resolve(command) != nil
    }
    
    /// 获取缺失的工具
    func getMissingTools() -> [String] {
        var missing: [String] = []
        if !isInstalled("7zz") { missing.append("7zz") }
        if !isInstalled("rar") { missing.append("rar") }
        return missing
    }
    
    /// 检查所有工具是否就绪
    func checkToolsReady() -> (allReady: Bool, missing: [String]) {
        let missing = getMissingTools()
        return (missing.isEmpty, missing)
    }
}
