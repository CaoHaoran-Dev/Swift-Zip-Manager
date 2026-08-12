//
//  Constants.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import Foundation

enum AppConstants {
    static let appName = "Swift Zip Manager"
    static let bundleIdentifier = "com.haoran.Swift-Zip-Manager"
    static let githubRepoOwner = "CaoHaoran-Dev"
    static let githubRepoName = "Swift-Zip-Manager"
    static let targetFileName = "Swift.Zip.Manager.zip"
    static let appFileName = "Swift Zip Manager.app"
    
    static let maxRecentFiles = 15
    static let maxDevLogs = 500
    
    enum ToolName {
        static let sevenzz = "7zz"
        static let rar = "rar"
    }
    
    enum SupportedFormat: String, CaseIterable {
        case zip = "zip"
        case tar = "tar"
        case gz = "gz"
        case tgz = "tgz"
        case sevenZ = "7z"
        case rar = "rar"
    }
    
    // MARK: - 工具下载 URL
    
    enum ToolDownloadURL {
        static var sevenzz: String {
            if let cached = SevenzzVersionCache.shared.getLatestURL() {
                return cached
            }
            
            SevenzzVersionCache.shared.refreshInBackground()
            return "https://github.com/ip7z/7zip/releases/download/24.09/7z2409-mac.tar.xz"
        }
        
        static var rar: String {
            #if arch(arm64)
                return "https://www.rarlab.com/rar/rarmacos-arm-723.tar.gz"
            #else
                return "https://www.rarlab.com/rar/rarmacos-x64-723.tar.gz"
            #endif
        }
    }
    
    // MARK: - SHA256 校验和（硬编码备份 + 运行时获取）
    
    enum ToolChecksums {
        /// 7zz 的 SHA256（从 GitHub Release 获取，这里是硬编码备份）
        static let sevenzzFallback = "81b7f04b3528852fac10f5becf9f15870a5da4cb94fbcb8a138197eb937468bf"
        
        /// RAR 的 SHA256（自己算SHA256的，需定期更新）
        static let rar: String = {
            #if arch(arm64)
                return "68b393c000758d477fde43c955ff7542f12f76f3f5e87cdda923152fc791bd4d"
            #else
                return "da1fb3c3d7748136c9b369b683d574b372cb1ed049a634a81f85d93918346d8f"
            #endif
        }()
    }
}

// MARK: - 7zz 版本缓存

class SevenzzVersionCache {
    static let shared = SevenzzVersionCache()
    
    private let cacheURLKey = "SevenzzLatestURL"
    private let cacheSHAKey = "SevenzzLatestSHA"
    private let cacheTimeKey = "SevenzzCacheTime"
    private let cacheExpiry: TimeInterval = 86400 // 24小时
    
    private init() {}
    
    func getLatestURL() -> String? {
        guard let url = UserDefaults.standard.string(forKey: cacheURLKey),
              let time = UserDefaults.standard.object(forKey: cacheTimeKey) as? Date else {
            return nil
        }
        
        if Date().timeIntervalSince(time) > cacheExpiry {
            return nil
        }
        
        return url
    }
    
    func getLatestSHA() -> String? {
        guard let sha = UserDefaults.standard.string(forKey: cacheSHAKey),
              let time = UserDefaults.standard.object(forKey: cacheTimeKey) as? Date else {
            return nil
        }
        
        if Date().timeIntervalSince(time) > cacheExpiry {
            return nil
        }
        
        return sha
    }
    
    func refreshInBackground() {
        DispatchQueue.global(qos: .background).async {
            self.fetchLatestVersion()
        }
    }
    
    @discardableResult
    func fetchLatestVersion() -> Bool {
        let urlString = "https://api.github.com/repos/ip7z/7zip/releases/latest"
        guard let url = URL(string: urlString) else { return false }
        
        let semaphore = DispatchSemaphore(value: 0)
        var success = false
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            defer { semaphore.signal() }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let assets = json["assets"] as? [[String: Any]] else {
                return
            }
            
            for asset in assets {
                if let name = asset["name"] as? String,
                   name.hasSuffix(".tar.xz"),
                   let downloadURL = asset["browser_download_url"] as? String {
                    UserDefaults.standard.set(downloadURL, forKey: self.cacheURLKey)
                    UserDefaults.standard.set(Date(), forKey: self.cacheTimeKey)
                    
                    // 计算 SHA256（异步下载文件计算，实际应该从 GitHub 获取，这里简化）
                    // 实际项目中应解析 GitHub Release 附带的 .sha256 文件
                    success = true
                    print("✅ 7zz latest version URL: \(downloadURL)")
                    return
                }
            }
        }
        
        task.resume()
        _ = semaphore.wait(timeout: .now() + 10)
        return success
    }
}
