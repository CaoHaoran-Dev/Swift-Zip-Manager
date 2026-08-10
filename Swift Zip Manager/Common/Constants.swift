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
    
    enum ToolDownloadURL {
        static var sevenzz: String {
            let defaultURL = "https://github.com/ip7z/7zip/releases/download/24.09/7z2409-mac.tar.xz"
            
            if let cached = SevenzzVersionCache.shared.getLatestURL() {
                return cached
            }
            
            SevenzzVersionCache.shared.refreshInBackground()
            return defaultURL
        }
        
        static var rar: String {
            #if arch(arm64)
                return "https://www.rarlab.com/rar/rarmacos-arm-720.tar.gz"
            #else
                return "https://www.rarlab.com/rar/rarmacos-x64-720.tar.gz"
            #endif
        }
    }
}

// MARK: - 7zz 版本缓存

class SevenzzVersionCache {
    static let shared = SevenzzVersionCache()
    
    private let cacheURLKey = "SevenzzLatestURL"
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
                  let tagName = json["tag_name"] as? String,
                  let assets = json["assets"] as? [[String: Any]] else {
                return
            }
            
            for asset in assets {
                if let name = asset["name"] as? String,
                   name.hasSuffix(".tar.xz"),
                   let downloadURL = asset["browser_download_url"] as? String {
                    UserDefaults.standard.set(downloadURL, forKey: self.cacheURLKey)
                    UserDefaults.standard.set(Date(), forKey: self.cacheTimeKey)
                    success = true
                    print("✅ 7zz latest version: \(tagName) -> \(downloadURL)")
                    return
                }
            }
        }
        
        task.resume()
        // ✅ #2: 使用 _ = 忽略返回值
        _ = semaphore.wait(timeout: .now() + 5)
        return success
    }
}
