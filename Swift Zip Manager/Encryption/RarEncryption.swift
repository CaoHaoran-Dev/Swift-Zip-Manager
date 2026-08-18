//
//  RarEncryption.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import Foundation

class RarEncryption: ArchiveEncryption {
    private let toolResolver: ToolPathResolver
    
    init(toolResolver: ToolPathResolver = ToolPathResolver()) {
        self.toolResolver = toolResolver
    }
    
    // MARK: - 创建加密 RAR 归档
    
    func create(sourceURLs: [URL], destinationURL: URL, password: String?) throws {
        guard let toolPath = toolResolver.resolve("rar") else {
            throw ArchiveError.toolNotFound("rar")
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: toolPath)
        
        // ✅ rar a 参数：a = add, -r = 递归添加子目录
        var args = ["a", "-r"]
        
        // ✅ 密码：使用 -hp密码 参数（-hp 加密文件头，比 -p 更安全）
        if let pwd = password, !pwd.isEmpty {
            args.append("-hp\(pwd)")
        }
        
        args.append(destinationURL.path)
        args.append(contentsOf: sourceURLs.map { $0.path })
        
        process.arguments = args
        process.currentDirectoryURL = sourceURLs.first?.deletingLastPathComponent()
        
        let errorPipe = Pipe()
        process.standardError = errorPipe
        
        print("🔍 [RarEncryption] Creating RAR archive")
        print("🔍 [RarEncryption] Has password: \(password != nil && !password!.isEmpty)")
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ArchiveError.commandFailed("RAR creation failed: \(errorMsg)")
        }
    }
    
    // MARK: - 提取加密 RAR 归档
    
    func extract(sourceURL: URL, destinationURL: URL, password: String?) throws {
        guard let toolPath = toolResolver.resolve("rar") else {
            throw ArchiveError.toolNotFound("rar")
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: toolPath)
        
        // ✅ rar x 参数：x = 保留路径解压
        var args = ["x"]
        
        // ✅ 密码：使用 -p密码 参数（提取时用 -p，不需要 -hp）
        if let pwd = password, !pwd.isEmpty {
            args.append("-p\(pwd)")
        }
        
        args.append(sourceURL.path)
        args.append(destinationURL.path)
        
        process.arguments = args
        
        let errorPipe = Pipe()
        process.standardError = errorPipe
        
        print("🔍 [RarEncryption] Extracting RAR archive")
        print("🔍 [RarEncryption] Has password: \(password != nil && !password!.isEmpty)")
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            
            let lowercasedError = errorMsg.lowercased()
            if lowercasedError.contains("password") ||
               lowercasedError.contains("wrong") ||
               lowercasedError.contains("bad") {
                throw ArchiveError.wrongPassword
            }
            throw ArchiveError.commandFailed("RAR extraction failed: \(errorMsg)")
        }
    }
}

// MARK: - 静态便捷方法（向后兼容）

extension RarEncryption {
    static func createEncryptedRar(sourceURLs: [URL], destinationURL: URL, password: String, toolPath: String) throws {
        let instance = RarEncryption()
        try instance.create(sourceURLs: sourceURLs, destinationURL: destinationURL, password: password)
    }
    
    static func extractEncryptedRar(sourceURL: URL, destinationURL: URL, password: String?, toolPath: String) throws {
        let instance = RarEncryption()
        try instance.extract(sourceURL: sourceURL, destinationURL: destinationURL, password: password)
    }
}
