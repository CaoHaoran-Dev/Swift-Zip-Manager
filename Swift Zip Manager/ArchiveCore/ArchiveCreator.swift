//
//  ArchiveCreator.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import Foundation

class ArchiveCreator {
    private let toolResolver = ToolPathResolver()
    private let fileManager = FileManager.default
    
    // ✅ #21: 获取 AppState 的引用
    weak var appState: AppState?
    
    private let formatExtensions: [String: String] = [
        "zip": "zip",
        "tar": "tar",
        "gz": "tar.gz",
        "7z": "7z",
        "rar": "rar"
    ]
    
    func create(files: [URL], format: String, name: String, destination: URL, password: String?, completion: @escaping (Result<Void, ArchiveError>) -> Void) {
        guard let ext = formatExtensions[format] else {
            completion(.failure(.unsupportedFormat))
            return
        }
        
        let fileName = name.hasSuffix(".\(ext)") ? name : "\(name).\(ext)"
        let targetPath = destination.appendingPathComponent(fileName)
        
        if let pwd = password, !pwd.isEmpty {
            if format == "7z" || format == "rar" {
                let toolName = format == "7z" ? "7zz" : "rar"
                guard toolResolver.resolve(toolName) != nil else {
                    completion(.failure(.toolNotFound(toolName)))
                    return
                }
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.createArchive(files: files, format: format, targetPath: targetPath, password: password)
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch let error as ArchiveError {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.commandFailed(error.localizedDescription)))
                }
            }
        }
    }
    
    private func createArchive(files: [URL], format: String, targetPath: URL, password: String?) throws {
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer { try? fileManager.removeItem(at: tempDir) }
        
        for file in files {
            let destURL = tempDir.appendingPathComponent(file.lastPathComponent)
            try fileManager.copyItem(at: file, to: destURL)
        }
        
        // ✅ #21: 检查实验性功能
        let useFastZip = appState?.experimentalFastZip ?? false
        let useAsyncWrite = appState?.unstableAsyncWrite ?? false
        
        if useAsyncWrite {
            print("⚠️ [Unstable] Async write enabled - may cause data loss if interrupted")
        }
        
        let process = Process()
        var args: [String] = []
        var environment = ProcessInfo.processInfo.environment
        if let pwd = password, !pwd.isEmpty {
            environment["ARCHIVE_PASSWORD"] = pwd
        }
        process.environment = environment
        
        switch format {
        case "zip":
            process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            args = ["-r"]
            
            // ✅ #21: 实验性：快速 ZIP（仅存储，不压缩）
            if useFastZip {
                args.append("-0")  // 仅存储
                print("🚀 [Experimental] Fast ZIP enabled (store only, no compression)")
            }
            
            if let pwd = password, !pwd.isEmpty {
                args.append("-P")
                args.append(pwd)
            }
            args.append(targetPath.path)
            let fileList = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            args.append(contentsOf: fileList.map { $0.lastPathComponent })
            process.currentDirectoryURL = tempDir
            
        case "tar":
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            args = ["-cf", targetPath.path, "-C", tempDir.path, "."]
            
        case "gz":
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            args = ["-czf", targetPath.path, "-C", tempDir.path, "."]
            
        case "7z":
            guard let toolPath = toolResolver.resolve("7zz") else {
                throw ArchiveError.toolNotFound("7zz")
            }
            process.executableURL = URL(fileURLWithPath: toolPath)
            args = ["a", targetPath.path, "."]
            
            // ✅ #21: 实验性：快速 7z（更低的压缩级别）
            if useFastZip {
                args.append("-mx=1")  // 最低压缩
                print("🚀 [Experimental] Fast 7Z enabled (lowest compression)")
            }
            
            if let pwd = password, !pwd.isEmpty {
                args.append("-p\(pwd)")
                args.append("-mhe=on")
            }
            process.currentDirectoryURL = tempDir
            
        case "rar":
            guard let toolPath = toolResolver.resolve("rar") else {
                throw ArchiveError.toolNotFound("rar")
            }
            process.executableURL = URL(fileURLWithPath: toolPath)
            args = ["a", "-r"]
            
            // ✅ #21: 实验性：快速 RAR（不压缩）
            if useFastZip {
                args.append("-m0")  // 不压缩
                print("🚀 [Experimental] Fast RAR enabled (no compression)")
            }
            
            if let pwd = password, !pwd.isEmpty {
                args.append("-hp\(pwd)")
            }
            args.append(targetPath.path)
            args.append(".")
            process.currentDirectoryURL = tempDir
            
        default:
            throw ArchiveError.unsupportedFormat
        }
        
        process.arguments = args
        
        // ✅ #21: 实验性：异步写入（不等待进程完成）
        if useAsyncWrite {
            print("⚠️ [Unstable] Async write enabled - running in background")
            try process.run()
            // 不等待，立即返回
            return
        }
        
        try process.runWithTimeout(seconds: 600)
        
        if process.terminationStatus != 0 {
            throw ArchiveError.commandFailed("Process exited with code \(process.terminationStatus)")
        }
    }
}
