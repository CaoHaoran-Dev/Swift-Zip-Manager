//
//  ArchiveExtractor.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import Foundation

class ArchiveExtractor {
    private let toolResolver = ToolPathResolver()
    private let fileManager = FileManager.default
    
    weak var appState: AppState?
    
    func extract(_ source: URL, to destination: URL, password: String? = nil, completion: @escaping (Result<Void, ArchiveError>) -> Void) {
        let ext = source.pathExtension.lowercased()
        let target = destination.appendingPathComponent(source.deletingPathExtension().lastPathComponent)
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.performExtract(source: source, target: target, format: ext, password: password)
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
    
    private func performExtract(source: URL, target: URL, format: String, password: String?) throws {
        try fileManager.createDirectory(at: target, withIntermediateDirectories: true)
        
        let useParallel = appState?.experimentalParallelExtract ?? false
        let useNewEngine = appState?.experimentalNewExtractor ?? false
        let useMemoryExtract = appState?.unstableMemoryExtract ?? false
        
        if useMemoryExtract && format == "zip" {
            try performMemoryExtract(source: source, target: target, password: password)
            return
        }
        
        if useParallel && (format == "7z" || format == "rar") {
            try performParallelExtract(source: source, target: target, format: format, password: password)
            return
        }
        
        if useNewEngine && format == "zip" {
            try performNewEngineExtract(source: source, target: target, password: password)
            return
        }
        
        try performStandardExtract(source: source, target: target, format: format, password: password)
    }
    
    // MARK: - 标准提取（先无密码，失败后检测是否需要密码）
    
    private func performStandardExtract(source: URL, target: URL, format: String, password: String?) throws {
        let process = Process()
        var environment = ProcessInfo.processInfo.environment
        
        // 如果有密码，设置环境变量
        if let pwd = password, !pwd.isEmpty {
            environment["EXTRACT_PASSWORD"] = pwd
        }
        process.environment = environment
        
        var args: [String] = []
        
        switch format {
        case "zip":
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            // 先尝试无密码解压
            args = ["-o", source.path, "-d", target.path]
            if let pwd = password, !pwd.isEmpty {
                args = ["-o", "-P", pwd, source.path, "-d", target.path]
            }
            
        case "7z":
            guard let toolPath = toolResolver.resolve("7zz") else {
                throw ArchiveError.toolNotFound("7zz")
            }
            process.executableURL = URL(fileURLWithPath: toolPath)
            args = ["x", source.path, "-o\(target.path)", "-y"]
            if let pwd = password, !pwd.isEmpty {
                environment["7Z_PASSWORD"] = pwd
                process.environment = environment
                args.append("-p")
            }
            
        case "rar":
            guard let toolPath = toolResolver.resolve("rar") else {
                throw ArchiveError.toolNotFound("rar")
            }
            process.executableURL = URL(fileURLWithPath: toolPath)
            if let pwd = password, !pwd.isEmpty {
                environment["RAR_PASSWORD"] = pwd
                process.environment = environment
                args = ["x", source.path, target.path]
            } else {
                args = ["x", source.path, target.path]
            }
            
        case "tar", "gz", "tgz":
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            args = ["-xf", source.path, "-C", target.path]
            
        default:
            throw ArchiveError.unsupportedFormat
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
            
            // ✅ 检测是否需要密码（只有没传密码时才检测，传了密码还报密码错误说明密码错误）
            if password == nil || password?.isEmpty == true {
                if lowercasedError.contains("password") ||
                   lowercasedError.contains("encrypted") {
                    throw ArchiveError.passwordRequired
                }
            } else {
                // 已经传了密码但还是报密码错误 → 密码错误
                if lowercasedError.contains("password") ||
                   lowercasedError.contains("wrong") ||
                   lowercasedError.contains("bad") {
                    throw ArchiveError.wrongPassword
                }
            }
            
            throw ArchiveError.commandFailed(errorMsg)
        }
    }
    
    // MARK: - 实验性方法（保持不变）
    
    private func performParallelExtract(source: URL, target: URL, format: String, password: String?) throws {
        print("🚀 [Experimental] Parallel extract enabled for \(format)")
        
        guard let toolPath = toolResolver.resolve(format == "7z" ? "7zz" : "rar") else {
            throw ArchiveError.toolNotFound(format == "7z" ? "7zz" : "rar")
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: toolPath)
        
        var environment = ProcessInfo.processInfo.environment
        if let pwd = password, !pwd.isEmpty {
            environment["7Z_PASSWORD"] = pwd
            environment["RAR_PASSWORD"] = pwd
        }
        process.environment = environment
        
        let args: [String]
        if format == "7z" {
            args = ["x", source.path, "-o\(target.path)", "-y", "-mmt=on"]
        } else {
            args = ["x", "-mmt=on", source.path, target.path]
        }
        
        process.arguments = args
        let errorPipe = Pipe()
        process.standardError = errorPipe
        
        try process.runWithTimeout(seconds: 600)
        
        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            
            let lowercasedError = errorMsg.lowercased()
            if password == nil || password?.isEmpty == true {
                if lowercasedError.contains("password") || lowercasedError.contains("encrypted") {
                    throw ArchiveError.passwordRequired
                }
            } else {
                if lowercasedError.contains("password") || lowercasedError.contains("wrong") {
                    throw ArchiveError.wrongPassword
                }
            }
            throw ArchiveError.commandFailed(errorMsg)
        }
    }
    
    private func performNewEngineExtract(source: URL, target: URL, password: String?) throws {
        print("🚀 [Experimental] New extractor engine enabled")
        
        guard let pwd = password, !pwd.isEmpty else {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-x", "-k", source.path, target.path]
            
            let errorPipe = Pipe()
            process.standardError = errorPipe
            
            try process.runWithTimeout(seconds: 600)
            
            if process.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                throw ArchiveError.commandFailed(errorMsg)
            }
            return
        }
        
        try performStandardExtract(source: source, target: target, format: "zip", password: password)
    }
    
    private func performMemoryExtract(source: URL, target: URL, password: String?) throws {
        print("⚠️ [Unstable] Memory extract enabled - may cause high memory usage")
        
        guard let password = password else {
            throw ArchiveError.passwordRequired
        }
        
        let zipData = try Data(contentsOf: source)
        print("📦 Loaded \(zipData.count) bytes into memory")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", "-", "-d", target.path, "-P", password]
        
        let inputPipe = Pipe()
        process.standardInput = inputPipe
        let errorPipe = Pipe()
        process.standardError = errorPipe
        
        try process.run()
        
        inputPipe.fileHandleForWriting.write(zipData)
        try inputPipe.fileHandleForWriting.close()
        
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            
            let lowercasedError = errorMsg.lowercased()
            if lowercasedError.contains("password") || lowercasedError.contains("wrong") {
                throw ArchiveError.wrongPassword
            }
            throw ArchiveError.commandFailed(errorMsg)
        }
    }
}
