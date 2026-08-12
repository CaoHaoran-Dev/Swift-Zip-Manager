//
//  ArchiveCreationViewModel.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI

class ArchiveCreationViewModel: ObservableObject {
    @Published var files: [URL] = []
    @Published var format = "zip" {
        didSet {
            updateNameSuggestion()
        }
    }
    @Published var name = ""
    @Published var destination: URL?
    @Published var encryptArchive = false
    @Published var encryptionPassword = ""
    @Published var confirmPassword = ""
    @Published var showPasswordMismatch = false
    @Published var showToolMissingAlert = false
    @Published var missingToolName = ""
    
    let formats = ["zip", "tar", "gz", "7z", "rar"]
    private let lastDestinationKey = "LastArchiveDestination"
    
    /// 文件大小缓存（避免重复读取）
    private var fileSizeCache: [URL: Int64] = [:]
    
    var supportsEncryption: Bool {
        format == "zip" || format == "7z" || format == "rar"
    }
    
    /// 创建按钮启用条件（唯一验证入口）
    var canCreate: Bool {
        guard !files.isEmpty, destination != nil else {
            return false
        }
        
        if encryptArchive {
            guard !encryptionPassword.isEmpty else {
                return false
            }
            guard encryptionPassword == confirmPassword else {
                return false
            }
        }
        
        return true
    }
    
    /// 密码强度（0-4）
    var passwordStrength: Int {
        let pwd = encryptionPassword
        guard !pwd.isEmpty else { return 0 }
        
        var score = 0
        if pwd.count >= 8 { score += 1 }
        if pwd.rangeOfCharacter(from: .uppercaseLetters) != nil { score += 1 }
        if pwd.rangeOfCharacter(from: .decimalDigits) != nil { score += 1 }
        if pwd.rangeOfCharacter(from: .symbols) != nil { score += 1 }
        return score
    }
    
    // MARK: - 文件管理
    
    func addFiles(_ urls: [URL]) {
        files.append(contentsOf: urls)
        // 预计算文件大小
        for url in urls {
            if fileSizeCache[url] == nil {
                let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
                fileSizeCache[url] = size
            }
        }
        updateNameSuggestion()
    }
    
    func removeFile(_ url: URL) {
        files.removeAll { $0 == url }
        fileSizeCache.removeValue(forKey: url)
        updateNameSuggestion()
    }
    
    func clearFiles() {
        files.removeAll()
        fileSizeCache.removeAll()
        name = ""
    }
    
    func fileSize(_ url: URL) -> String {
        let size = fileSizeCache[url] ?? 0
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    func getExtension() -> String {
        switch format {
        case "zip": return "zip"
        case "tar": return "tar"
        case "gz": return "tar.gz"
        case "7z": return "7z"
        case "rar": return "rar"
        default: return "zip"
        }
    }
    
    // MARK: - 名称自动建议
    
    private func updateNameSuggestion() {
        if name.isEmpty && !files.isEmpty {
            if files.count == 1 {
                name = files.first?.deletingPathExtension().lastPathComponent ?? "Archive"
            } else {
                // 多文件：使用父目录名
                let parent = files.first?.deletingLastPathComponent().lastPathComponent
                name = parent ?? "Archive"
            }
        }
    }
    
    // MARK: - 保存/加载上次路径
    
    func saveLastDestination(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: lastDestinationKey)
    }
    
    func loadLastDestination() {
        if let path = UserDefaults.standard.string(forKey: lastDestinationKey),
           !path.isEmpty {
            let url = URL(fileURLWithPath: path)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                destination = url
            }
        }
        
        if destination == nil {
            destination = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        }
    }
}
