//
//  ArchiveCreator.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//  修复 7z/RAR 创建，加密密码正确传递
//

import Foundation

class ArchiveCreator {
    private let toolResolver = ToolPathResolver()
    private let fileManager = FileManager.default
    
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
        
        // 验证工具是否存在
        if format == "7z" || format == "rar" {
            let toolName = format == "7z" ? "7zz" : "rar"
            guard toolResolver.resolve(toolName) != nil else {
                completion(.failure(.toolNotFound(toolName)))
                return
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
        let process = Process()
        var args: [String] = []
        let environment = ProcessInfo.processInfo.environment
        
        let filePaths = files.map { $0.path }
        let currentDir = files.first?.deletingLastPathComponent() ?? URL(fileURLWithPath: "/")
        
        switch format {
        case "zip":
            process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            args = ["-r"]
            if let pwd = password, !pwd.isEmpty {
                args.append("-P")
                args.append(pwd)
            }
            args.append(targetPath.path)
            args.append(contentsOf: filePaths.map { ($0 as NSString).lastPathComponent })
            process.currentDirectoryURL = currentDir
            
        case "tar":
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            args = ["-cf", targetPath.path]
            args.append(contentsOf: filePaths.map { ($0 as NSString).lastPathComponent })
            process.currentDirectoryURL = currentDir
            
        case "gz":
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            args = ["-czf", targetPath.path]
            args.append(contentsOf: filePaths.map { ($0 as NSString).lastPathComponent })
            process.currentDirectoryURL = currentDir
            
        case "7z":
            guard let toolPath = toolResolver.resolve("7zz") else {
                throw ArchiveError.toolNotFound("7zz")
            }
            process.executableURL = URL(fileURLWithPath: toolPath)
            
            // 7zz a 参数：a = add, -t7z = 7z 格式, -mx=9 = 最大压缩
            args = ["a", "-t7z", "-mx=9"]
            
            // ✅ 密码：直接传递 -p密码（不依赖环境变量）
            if let pwd = password, !pwd.isEmpty {
                args.append("-p\(pwd)")
                args.append("-mhe=on")  // 加密文件头
            }
            
            args.append(targetPath.path)
            args.append(contentsOf: filePaths.map { ($0 as NSString).lastPathComponent })
            process.currentDirectoryURL = currentDir
            
        case "rar":
            guard let toolPath = toolResolver.resolve("rar") else {
                throw ArchiveError.toolNotFound("rar")
            }
            process.executableURL = URL(fileURLWithPath: toolPath)
            
            // rar a 参数：a = add, -r = 递归
            args = ["a", "-r"]
            
            // 密码：直接传递 -hp密码
            if let pwd = password, !pwd.isEmpty {
                args.append("-hp\(pwd)")
            }
            
            args.append(targetPath.path)
            args.append(contentsOf: filePaths.map { ($0 as NSString).lastPathComponent })
            process.currentDirectoryURL = currentDir
            
        default:
            throw ArchiveError.unsupportedFormat
        }
        
        process.arguments = args
        process.environment = environment
        
        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()
        
        print("🔍 [ArchiveCreator] Creating \(format) archive")
        print("🔍 [ArchiveCreator] Tool: \(process.executableURL?.path ?? "unknown")")
        print("🔍 [ArchiveCreator] Args: \(args)")
        print("🔍 [ArchiveCreator] Target: \(targetPath.path)")
        print("🔍 [ArchiveCreator] Has password: \(password != nil && !password!.isEmpty)")
        
        try process.run()
        process.waitUntilExit()
        
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorMsg = String(data: errorData, encoding: .utf8) ?? ""
        
        print("🔍 [ArchiveCreator] Exit code: \(process.terminationStatus)")
        if !errorMsg.isEmpty {
            print("🔍 [ArchiveCreator] Error: \(errorMsg)")
        }
        
        if process.terminationStatus != 0 {
            throw ArchiveError.commandFailed("Creation failed: \(errorMsg)")
        }
    }
}
