//
//  SevenZipEncryption.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import Foundation

class SevenZipEncryption: ArchiveEncryption {
    private let toolResolver: ToolPathResolver
    
    init(toolResolver: ToolPathResolver = ToolPathResolver()) {
        self.toolResolver = toolResolver
    }
    
    // MARK: - 创建加密 7z 归档
    
    func create(sourceURLs: [URL], destinationURL: URL, password: String?) throws {
        guard let toolPath = toolResolver.resolve("7zz") else {
            throw ArchiveError.toolNotFound("7zz")
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: toolPath)
        
        // ✅ 7zz a 参数：a = add, -t7z = 7z 格式, -mx=9 = 最大压缩
        var args = ["a", "-t7z", "-mx=9"]
        
        // ✅ 密码：直接传递 -p密码（环境变量方式无效）
        // ✅ -mhe=on 加密文件头（更安全）
        if let pwd = password, !pwd.isEmpty {
            args.append("-p\(pwd)")
            args.append("-mhe=on")
        }
        
        args.append(destinationURL.path)
        args.append(contentsOf: sourceURLs.map { $0.path })
        
        process.arguments = args
        process.currentDirectoryURL = sourceURLs.first?.deletingLastPathComponent()
        
        let errorPipe = Pipe()
        process.standardError = errorPipe
        
        print("🔍 [SevenZipEncryption] Creating 7z archive")
        print("🔍 [SevenZipEncryption] Has password: \(password != nil && !password!.isEmpty)")
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ArchiveError.commandFailed("7z creation failed: \(errorMsg)")
        }
    }
    
    // MARK: - 提取加密 7z 归档
    
    func extract(sourceURL: URL, destinationURL: URL, password: String?) throws {
        guard let toolPath = toolResolver.resolve("7zz") else {
            throw ArchiveError.toolNotFound("7zz")
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: toolPath)
        
        // ✅ 7zz x 参数：x = 解压（保留路径）, -y = 自动确认
        var args = ["x", sourceURL.path, "-o\(destinationURL.path)", "-y"]
        
        // ✅ 密码：直接传递 -p密码（环境变量方式无效）
        if let pwd = password, !pwd.isEmpty {
            args.append("-p\(pwd)")
        }
        
        process.arguments = args
        
        let errorPipe = Pipe()
        process.standardError = errorPipe
        
        print("🔍 [SevenZipEncryption] Extracting 7z archive")
        print("🔍 [SevenZipEncryption] Has password: \(password != nil && !password!.isEmpty)")
        
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
            throw ArchiveError.commandFailed("7z extraction failed: \(errorMsg)")
        }
    }
}

// MARK: - 静态便捷方法（向后兼容）

extension SevenZipEncryption {
    static func createEncrypted7z(sourceURLs: [URL], destinationURL: URL, password: String, toolPath: String) throws {
        let instance = SevenZipEncryption()
        try instance.create(sourceURLs: sourceURLs, destinationURL: destinationURL, password: password)
    }
    
    static func extractEncrypted7z(sourceURL: URL, destinationURL: URL, password: String?, toolPath: String) throws {
        let instance = SevenZipEncryption()
        try instance.extract(sourceURL: sourceURL, destinationURL: destinationURL, password: password)
    }
}
