//
//  ZipEncryption.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import Foundation

class ZipEncryption: ArchiveEncryption {
    
    func create(sourceURLs: [URL], destinationURL: URL, password: String?) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        
        var args = ["-r"]
        
        if let pwd = password, !pwd.isEmpty {
            args.append("-P")
            args.append(pwd)
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
            throw ArchiveError.commandFailed("Zip creation failed: \(errorMsg)")
        }
    }
    
    func extract(sourceURL: URL, destinationURL: URL, password: String?) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        
        var args = ["-o", sourceURL.path, "-d", destinationURL.path]
        if let pwd = password, !pwd.isEmpty {
            args.append("-P")
            args.append(pwd)
        }
        
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

extension ZipEncryption {
    static func createEncryptedZip(sourceURLs: [URL], destinationURL: URL, password: String) throws {
        let instance = ZipEncryption()
        try instance.create(sourceURLs: sourceURLs, destinationURL: destinationURL, password: password)
    }
    
    static func extractEncryptedZip(sourceURL: URL, destinationURL: URL, password: String?) throws {
        let instance = ZipEncryption()
        try instance.extract(sourceURL: sourceURL, destinationURL: destinationURL, password: password)
    }
}
