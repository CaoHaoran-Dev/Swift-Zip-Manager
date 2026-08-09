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
            // 格式变化时自动更新名称后缀
            updateNameSuggestion()
        }
    }
    @Published var name = ""
    @Published var destination: URL?
    @Published var encryptArchive = false
    @Published var encryptionPassword = ""
    @Published var confirmPassword = ""
    @Published var showPasswordMismatch = false
    
    let formats = ["zip", "tar", "gz", "7z", "rar"]
    private let lastDestinationKey = "LastArchiveDestination"
    
    var supportsEncryption: Bool {
        format == "zip" || format == "7z" || format == "rar"
    }
    
    var canCreate: Bool {
        !files.isEmpty && destination != nil && (!encryptArchive || !encryptionPassword.isEmpty)
    }
    
    init() {
        // 如果有文件，自动生成名称
        updateNameSuggestion()
    }
    
    func validatePassword() -> Bool {
        if encryptArchive {
            if encryptionPassword != confirmPassword {
                showPasswordMismatch = true
                return false
            }
            if encryptionPassword.isEmpty {
                return false
            }
        }
        return true
    }
    
    func addFiles(_ urls: [URL]) {
        files.append(contentsOf: urls)
        updateNameSuggestion()
    }
    
    func removeFile(_ url: URL) {
        files.removeAll { $0 == url }
        updateNameSuggestion()
    }
    
    func clearFiles() {
        files.removeAll()
        name = ""
    }
    
    func fileSize(_ url: URL) -> String {
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
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
            let firstFileName = files.first?.deletingPathExtension().lastPathComponent ?? "Archive"
            name = firstFileName
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
        
        // 如果没有保存的路径或路径无效，使用桌面
        if destination == nil {
            destination = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        }
    }
}
