//
//  ToolPathResolver.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import Foundation

class ToolPathResolver {
    private let fileManager = FileManager.default
    
    /// 缓存机制
    private var cache: [String: String] = [:]
    private var cacheTimestamp: Date?
    /// 缓存过期时间：60 秒
    private let cacheExpiry: TimeInterval = 60.0
    
    /// 应用支持目录下的工具路径
    private var appSupportToolsPath: String {
        let home = fileManager.homeDirectoryForCurrentUser.path
        let path = "\(home)/Library/Application Support/com.haoran.Swift-Zip-Manager/tools"
        try? fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }
    
    /// 系统 PATH 搜索路径
    private var systemPaths: [String] {
        let pathEnv = ProcessInfo.processInfo.environment["PATH"] ?? ""
        return pathEnv.split(separator: ":").map { String($0) }
    }
    
    /// 清除缓存
    func invalidateCache() {
        cache.removeAll()
        cacheTimestamp = nil
        print("🔄 Tool cache invalidated")
    }
    
    /// 获取工具的完整路径
    func resolve(_ command: String, customPath: String? = nil) -> String? {
        // 1. 自定义路径
        if let custom = customPath, !custom.isEmpty {
            if fileManager.fileExists(atPath: custom) && fileManager.isExecutableFile(atPath: custom) {
                print("✅ Found \(command) at custom path: \(custom)")
                return custom
            }
        }
        
        // 2. 检查缓存
        if let cached = cache[command],
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheExpiry {
            if fileManager.fileExists(atPath: cached) {
                return cached
            }
        }
        
        // 3. 检测 App Support
        let appSupportPath = "\(appSupportToolsPath)/\(command)"
        if fileManager.fileExists(atPath: appSupportPath) {
            if fileManager.isExecutableFile(atPath: appSupportPath) {
                print("✅ Found \(command) in App Support: \(appSupportPath)")
                updateCache(command: command, path: appSupportPath)
                return appSupportPath
            } else {
                try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: appSupportPath)
                if fileManager.isExecutableFile(atPath: appSupportPath) {
                    print("✅ Fixed permissions for \(command) in App Support")
                    updateCache(command: command, path: appSupportPath)
                    return appSupportPath
                }
            }
        }
        
        // 4. 检测系统 PATH
        for systemPath in systemPaths {
            let fullPath = "\(systemPath)/\(command)"
            if fileManager.fileExists(atPath: fullPath) && fileManager.isExecutableFile(atPath: fullPath) {
                print("✅ Found \(command) in system PATH: \(fullPath)")
                updateCache(command: command, path: fullPath)
                return fullPath
            }
        }
        
        print("❌ \(command) not found")
        return nil
    }
    
    private func updateCache(command: String, path: String) {
        cache[command] = path
        cacheTimestamp = Date()
    }
    
    func isInstalled(_ command: String, customPath: String? = nil) -> Bool {
        return resolve(command, customPath: customPath) != nil
    }
    
    func getMissingTools(customPaths: [String: String] = [:]) -> [String] {
        var missing: [String] = []
        if !isInstalled("7zz", customPath: customPaths["7zz"]) { missing.append("7zz") }
        if !isInstalled("rar", customPath: customPaths["rar"]) { missing.append("rar") }
        return missing
    }
    
    func checkToolsReady(customPaths: [String: String] = [:]) -> (allReady: Bool, missing: [String]) {
        let missing = getMissingTools(customPaths: customPaths)
        return (missing.isEmpty, missing)
    }
}
