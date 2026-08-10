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
    
    private func performStandardExtract(source: URL, target: URL, format: String, password: String?) throws {
        let process = Process()
        // ✅ #1: var → let (不可变)
        var args: [String]
        
        switch format {
        case "zip":
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            args = ["-o", source.path, "-d", target.path]
            if let pwd = password, !pwd.isEmpty {
                args = ["-o", source.path, "-d", target.path, "-P", pwd]  // ⚠️ 这里需要重新赋值，所以不能用 let
            }
            
        case "7z":
            guard let toolPath = toolResolver.resolve("7zz") else {
                throw ArchiveError.toolNotFound("7zz")
            }
            process.executableURL = URL(fileURLWithPath: toolPath)
            args = ["x", source.path, "-o\(target.path)", "-y"]
            if let pwd = password, !pwd.isEmpty {
                args = ["x", source.path, "-o\(target.path)", "-y", "-p\(pwd)"]
            }
            
        case "rar":
            guard let toolPath = toolResolver.resolve("rar") else {
                throw ArchiveError.toolNotFound("rar")
            }
            process.executableURL = URL(fileURLWithPath: toolPath)
            if let pwd = password, !pwd.isEmpty {
                args = ["x", "-p\(pwd)", source.path, target.path]
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
        
        try process.runWithTimeout(seconds: 600)
        
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
    
    // MARK: - 实验性：并行提取
    
    private func performParallelExtract(source: URL, target: URL, format: String, password: String?) throws {
        print("🚀 [Experimental] Parallel extract enabled for \(format)")
        
        guard let toolPath = toolResolver.resolve(format == "7z" ? "7zz" : "rar") else {
            throw ArchiveError.toolNotFound(format == "7z" ? "7zz" : "rar")
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: toolPath)
        
        // ✅ #1: var → let
        let args: [String]
        if format == "7z" {
            if let pwd = password, !pwd.isEmpty {
                args = ["x", source.path, "-o\(target.path)", "-y", "-mmt=on", "-p\(pwd)"]
            } else {
                args = ["x", source.path, "-o\(target.path)", "-y", "-mmt=on"]
            }
        } else {
            if let pwd = password, !pwd.isEmpty {
                args = ["x", "-mmt=on", "-p\(pwd)", source.path, target.path]
            } else {
                args = ["x", "-mmt=on", source.path, target.path]
            }
        }
        
        process.arguments = args
        let errorPipe = Pipe()
        process.standardError = errorPipe
        
        try process.runWithTimeout(seconds: 600)
        
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
    
    // MARK: - 实验性：新提取引擎
    
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
        
        // 有密码时回退到标准提取
        try performStandardExtract(source: source, target: target, format: "zip", password: password)
    }
    
    // MARK: - 实验性：内存提取
    
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
            if lowercasedError.contains("password") || lowercasedError.contains("wrong") || lowercasedError.contains("bad") {
                throw ArchiveError.wrongPassword
            }
            throw ArchiveError.commandFailed(errorMsg)
        }
    }
}
