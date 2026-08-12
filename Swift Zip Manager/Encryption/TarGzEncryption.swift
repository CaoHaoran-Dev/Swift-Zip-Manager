//
//  TarGzHandler.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import Foundation

/// TAR / GZ / TGZ 格式处理器
/// 注意：TAR 和 GZ 格式本身不支持密码加密
class TarGzHandler {
    
    // MARK: - TAR
    
    /// 创建 TAR 归档
    static func createTar(sourceURLs: [URL], destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-cf", destinationURL.path] + sourceURLs.map { $0.path }
        process.currentDirectoryURL = sourceURLs.first?.deletingLastPathComponent()
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw ArchiveError.commandFailed("Tar creation failed with code \(process.terminationStatus)")
        }
    }
    
    /// 提取 TAR 归档
    static func extractTar(sourceURL: URL, destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-xf", sourceURL.path, "-C", destinationURL.path]
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw ArchiveError.commandFailed("Tar extraction failed with code \(process.terminationStatus)")
        }
    }
    
    // MARK: - GZIP
    
    /// 压缩为 GZIP
    static func createGzip(sourceURL: URL, destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/gzip")
        process.arguments = ["-c", sourceURL.path]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        
        try process.run()
        process.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        try outputData.write(to: destinationURL)
        
        if process.terminationStatus != 0 {
            throw ArchiveError.commandFailed("Gzip compression failed with code \(process.terminationStatus)")
        }
    }
    
    /// 解压 GZIP
    static func extractGzip(sourceURL: URL, destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/gunzip")
        process.arguments = ["-c", sourceURL.path]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        
        try process.run()
        process.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        try outputData.write(to: destinationURL)
        
        if process.terminationStatus != 0 {
            throw ArchiveError.commandFailed("Gunzip extraction failed with code \(process.terminationStatus)")
        }
    }
    
    // MARK: - TGZ (TAR + GZIP)
    
    /// 创建 TGZ 归档 (tar.gz)
    static func createTgz(sourceURLs: [URL], destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-czf", destinationURL.path] + sourceURLs.map { $0.path }
        process.currentDirectoryURL = sourceURLs.first?.deletingLastPathComponent()
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw ArchiveError.commandFailed("TGZ creation failed with code \(process.terminationStatus)")
        }
    }
    
    /// 提取 TGZ 归档 (tar.gz)
    static func extractTgz(sourceURL: URL, destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-xzf", sourceURL.path, "-C", destinationURL.path]
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw ArchiveError.commandFailed("TGZ extraction failed with code \(process.terminationStatus)")
        }
    }
}
