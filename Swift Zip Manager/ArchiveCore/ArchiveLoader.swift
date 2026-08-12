//
//  ArchiveLoader.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//  使用 -ba 简化输出，固定列解析
//

import Foundation

class ArchiveLoader {
    private let toolResolver = ToolPathResolver()
    
    // MARK: - 公开接口
    
    func loadArchive(_ url: URL, completion: @escaping (Result<[ArchiveEntry], ArchiveError>) -> Void) {
        let ext = url.pathExtension.lowercased()
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let entries = try self.loadEntries(from: url, format: ext)
                DispatchQueue.main.async {
                    completion(.success(entries))
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
    
    // MARK: - 带密码加载
    
    func loadArchiveWithPassword(_ url: URL, password: String, completion: @escaping (Result<[ArchiveEntry], ArchiveError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let entries = try self.loadEntriesWithPassword(from: url, format: url.pathExtension.lowercased(), password: password)
                DispatchQueue.main.async {
                    completion(.success(entries))
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
    
    // MARK: - 主入口
    
    private func loadEntries(from url: URL, format: String) throws -> [ArchiveEntry] {
        switch format {
        case "zip":
            return try loadWithUnzip(url, password: nil)
        case "7z", "rar":
            return try loadWith7zz(url, password: nil)
        case "tar", "gz", "tgz":
            return try loadWithTar(url)
        default:
            throw ArchiveError.unsupportedFormat
        }
    }
    
    private func loadEntriesWithPassword(from url: URL, format: String, password: String) throws -> [ArchiveEntry] {
        switch format {
        case "zip":
            return try loadWithUnzip(url, password: password)
        case "7z", "rar":
            return try loadWith7zz(url, password: password)
        default:
            throw ArchiveError.unsupportedFormat
        }
    }
    
    // MARK: - ZIP
    
    private func loadWithUnzip(_ url: URL, password: String?) throws -> [ArchiveEntry] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        
        var args = ["-l"]
        if let pwd = password, !pwd.isEmpty {
            args.append("-P")
            args.append(pwd)
        }
        args.append(url.path)
        process.arguments = args
        
        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        if let errorMsg = String(data: errorData, encoding: .utf8) {
            let lowercased = errorMsg.lowercased()
            if lowercased.contains("password") || lowercased.contains("encrypted") {
                if password == nil || password?.isEmpty == true {
                    throw ArchiveError.passwordRequired
                } else {
                    throw ArchiveError.wrongPassword
                }
            }
        }
        
        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: outputData, encoding: .utf8) else {
            throw ArchiveError.commandFailed("Failed to decode unzip output")
        }
        
        if process.terminationStatus != 0 {
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ArchiveError.commandFailed("unzip failed: \(errorMsg)")
        }
        
        return parseUnzipOutput(output)
    }
    
    private func parseUnzipOutput(_ output: String) -> [ArchiveEntry] {
        var entries: [ArchiveEntry] = []
        let lines = output.split(separator: "\n")
        var inFileList = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            if trimmed.contains("Length") && trimmed.contains("Name") {
                inFileList = true
                continue
            }
            
            if trimmed.hasPrefix("---------") || trimmed.contains("files") || trimmed.contains("-------") {
                continue
            }
            
            if inFileList {
                let components = trimmed.split(separator: " ", omittingEmptySubsequences: true)
                if components.count >= 4 {
                    let sizeStr = String(components[0])
                    let fileName = components.dropFirst(3).joined(separator: " ")
                    
                    if fileName.isEmpty || fileName == "Name" {
                        continue
                    }
                    
                    let size = Int64(sizeStr) ?? -1
                    let isFolder = fileName.hasSuffix("/")
                    let cleanName = isFolder ? String(fileName.dropLast()) : fileName
                    
                    entries.append(ArchiveEntry(
                        path: cleanName,
                        sizeBytes: size,
                        isDirectory: isFolder
                    ))
                }
            }
        }
        
        return entries.filter { !$0.isSystemFile }
    }
    
    // MARK: - 7z/RAR（使用 -ba 简化输出）
    
    private func loadWith7zz(_ url: URL, password: String?) throws -> [ArchiveEntry] {
        guard let toolPath = toolResolver.resolve("7zz") else {
            throw ArchiveError.toolNotFound("7zz")
        }
        
        print("🔍 [7zz] Loading: \(url.lastPathComponent)")
        print("🔍 [7zz] Password provided: \(password != nil && !password!.isEmpty)")
        
        // 如果有密码，直接带密码加载
        if let pwd = password, !pwd.isEmpty {
            return try loadWith7zzWithPassword(url, toolPath: toolPath, password: pwd)
        }
        
        // 无密码：使用 -pdummy 检测加密
        return try loadWith7zzDetect(url, toolPath: toolPath)
    }
    
    // MARK: - 检测加密（使用 -pdummy + -ba）
    
    private func loadWith7zzDetect(_ url: URL, toolPath: String) throws -> [ArchiveEntry] {
        print("🔍 [7zz] Detecting encryption with -pdummy...")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: toolPath)
        // ✅ 使用 -ba 简化输出，-pdummy 检测加密
        process.arguments = ["l", "-ba", "-pdummy", url.path]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorMsg = String(data: errorData, encoding: .utf8) ?? ""
        let lowercasedError = errorMsg.lowercased()
        
        print("🔍 [7zz] Detect exit code: \(process.terminationStatus)")
        print("🔍 [7zz] Detect error: \(errorMsg)")
        
        // 检测是否是加密归档
        if lowercasedError.contains("wrong") || lowercasedError.contains("bad") || lowercasedError.contains("password") {
            print("🔐 [7zz] Archive is encrypted")
            throw ArchiveError.passwordRequired
        }
        
        if process.terminationStatus != 0 {
            throw ArchiveError.commandFailed("7zz failed: \(errorMsg)")
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: outputData, encoding: .utf8) else {
            throw ArchiveError.commandFailed("Failed to decode 7zz output")
        }
        
        let entries = parse7zzBAOutput(output)
        print("✅ [7zz] Parsed \(entries.count) entries")
        
        if entries.isEmpty {
            throw ArchiveError.commandFailed("No entries found in archive")
        }
        
        return entries
    }
    
    // MARK: - 带密码加载（使用 -ba）
    
    private func loadWith7zzWithPassword(_ url: URL, toolPath: String, password: String) throws -> [ArchiveEntry] {
        print("🔍 [7zz] Loading with real password...")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: toolPath)
        // ✅ 使用 -ba 简化输出，-p密码 带真实密码
        process.arguments = ["l", "-ba", "-p\(password)", url.path]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorMsg = String(data: errorData, encoding: .utf8) ?? ""
        let lowercasedError = errorMsg.lowercased()
        
        print("🔍 [7zz] Password exit code: \(process.terminationStatus)")
        print("🔍 [7zz] Password error: \(errorMsg)")
        
        if lowercasedError.contains("wrong") || lowercasedError.contains("bad") {
            print("❌ [7zz] Wrong password")
            throw ArchiveError.wrongPassword
        }
        
        if process.terminationStatus != 0 {
            throw ArchiveError.commandFailed("7zz failed with code \(process.terminationStatus): \(errorMsg)")
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: outputData, encoding: .utf8) else {
            throw ArchiveError.commandFailed("Failed to decode 7zz output")
        }
        
        print("🔍 [7zz] Output length: \(output.count) bytes")
        let preview = output.prefix(500)
        print("🔍 [7zz] Output preview: \(preview)")
        
        let entries = parse7zzBAOutput(output)
        print("✅ [7zz] Parsed \(entries.count) entries with password")
        
        if entries.isEmpty {
            if output.lowercased().contains("encrypted") || output.lowercased().contains("password") {
                throw ArchiveError.wrongPassword
            }
            throw ArchiveError.commandFailed("No entries found in archive")
        }
        
        return entries
    }
    
    // MARK: - 解析 -ba 输出（每行一个条目，从第 54 字符后提取文件名）
    
    private func parse7zzBAOutput(_ output: String) -> [ArchiveEntry] {
        var entries: [ArchiveEntry] = []
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            // 跳过标题行和统计行
            if trimmed.contains("Date") || trimmed.contains("Time") ||
               trimmed.contains("files") || trimmed.contains("folders") ||
               trimmed.contains("Compressed") || trimmed.contains("Physical Size") {
                continue
            }
            
            // 检查是否是文件/目录行（包含日期格式 "2026-08-10"）
            if !trimmed.contains("-") {
                continue
            }
            
            // ✅ 从第 54 个字符后提取文件名（固定列宽）
            // 格式：日期 时间 属性 大小 压缩后 名称
            // 名称在第 54 列之后开始
            let columns = trimmed.components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
            
            // 至少需要 6 列：日期 时间 属性 大小 压缩后 名称
            if columns.count >= 6 {
                let sizeStr = columns[3]
                let size = Int64(sizeStr) ?? -1
                
                // 文件名从第 6 列开始（索引 5），可能包含空格
                let nameParts = columns[5...].joined(separator: " ")
                let isFolder = nameParts.hasSuffix("/") || columns[2].contains("D")
                let cleanName = isFolder ? String(nameParts.dropLast()) : nameParts
                
                if !cleanName.isEmpty && cleanName != "." && cleanName != ".." {
                    entries.append(ArchiveEntry(
                        path: cleanName,
                        sizeBytes: size,
                        isDirectory: isFolder
                    ))
                }
            } else if columns.count >= 5 {
                // 备用解析：某些格式可能只有 5 列
                let sizeStr = columns[3]
                let size = Int64(sizeStr) ?? -1
                let name = columns[4]
                let isFolder = name.hasSuffix("/")
                let cleanName = isFolder ? String(name.dropLast()) : name
                
                if !cleanName.isEmpty && cleanName != "." && cleanName != ".." {
                    entries.append(ArchiveEntry(
                        path: cleanName,
                        sizeBytes: size,
                        isDirectory: isFolder
                    ))
                }
            }
        }
        
        return entries.filter { !$0.isSystemFile && $0.path != "." && $0.path != ".." }
    }
    
    // MARK: - TAR
    
    private func loadWithTar(_ url: URL) throws -> [ArchiveEntry] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["tvf", url.path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        try process.run()
        process.waitUntilExit()
        
        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: outputData, encoding: .utf8) else {
            return []
        }
        
        return parseTarOutput(output)
    }
    
    private func parseTarOutput(_ output: String) -> [ArchiveEntry] {
        var entries: [ArchiveEntry] = []
        let lines = output.split(separator: "\n")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            let components = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard components.count >= 6 else { continue }
            
            let sizeStr = String(components[3])
            let fileName = String(components.last ?? "")
            let isFolder = fileName.hasSuffix("/")
            let cleanName = isFolder ? String(fileName.dropLast()) : fileName
            
            if !cleanName.isEmpty && cleanName != "." && cleanName != ".." {
                let size = Int64(sizeStr) ?? -1
                entries.append(ArchiveEntry(
                    path: cleanName,
                    sizeBytes: size,
                    isDirectory: isFolder
                ))
            }
        }
        
        return entries.filter { !$0.isSystemFile }
    }
}
