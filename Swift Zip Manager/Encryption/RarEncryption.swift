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
    
    func create(sourceURLs: [URL], destinationURL: URL, password: String?) throws {
        guard let toolPath = toolResolver.resolve("rar") else {
            throw ArchiveError.toolNotFound("rar")
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: toolPath)
        
        var args = ["a", "-r"]
        
        if let pwd = password, !pwd.isEmpty {
            var environment = ProcessInfo.processInfo.environment
            environment["RAR_PASSWORD"] = pwd
            process.environment = environment
            args.append("-hp")
        }
        args.append(destinationURL.path)
        args.append(contentsOf: sourceURLs.map { $0.path })
        
        process.arguments = args
        process.currentDirectoryURL = sourceURLs.first?.deletingLastPathComponent()
        
        let errorPipe = Pipe()
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ArchiveError.commandFailed("RAR creation failed: \(errorMsg)")
        }
    }
    
    func extract(sourceURL: URL, destinationURL: URL, password: String?) throws {
        guard let toolPath = toolResolver.resolve("rar") else {
            throw ArchiveError.toolNotFound("rar")
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: toolPath)
        
        var args = ["x"]
        
        if let pwd = password, !pwd.isEmpty {
            var environment = ProcessInfo.processInfo.environment
            environment["RAR_PASSWORD"] = pwd
            process.environment = environment
        }
        args.append(sourceURL.path)
        args.append(destinationURL.path)
        
        process.arguments = args
        
        let errorPipe = Pipe()
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            
            let lowercasedError = errorMsg.lowercased()
            if lowercasedError.contains("password") || lowercasedError.contains("wrong") || lowercasedError.contains("bad") {
                throw ArchiveError.wrongPassword
            }
            throw ArchiveError.commandFailed(errorMsg)
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
