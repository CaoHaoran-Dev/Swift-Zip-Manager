//
//  ArchiveLoader.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import Foundation

// MARK: - ArchiveError 定义（唯一来源）

enum ArchiveError: LocalizedError, Equatable {
    case unsupportedFormat
    case toolNotFound(String)
    case commandFailed(String)
    case passwordRequired
    case timeout
    case wrongPassword
    
    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Unsupported archive format"
        case .toolNotFound(let tool):
            return "Required tool not found: \(tool)"
        case .commandFailed(let msg):
            return "Command failed: \(msg)"
        case .passwordRequired:
            return "Password required for this archive"
        case .timeout:
            return "Operation timed out"
        case .wrongPassword:
            return "Wrong password"
        }
    }
    
    // Equatable 实现
    static func == (lhs: ArchiveError, rhs: ArchiveError) -> Bool {
        switch (lhs, rhs) {
        case (.unsupportedFormat, .unsupportedFormat):
            return true
        case (.toolNotFound(let l), .toolNotFound(let r)):
            return l == r
        case (.commandFailed(let l), .commandFailed(let r)):
            return l == r
        case (.passwordRequired, .passwordRequired):
            return true
        case (.timeout, .timeout):
            return true
        case (.wrongPassword, .wrongPassword):
            return true
        default:
            return false
        }
    }
    
    var isPasswordError: Bool {
        if case .wrongPassword = self {
            return true
        }
        return false
    }
}

class ArchiveLoader {
    private let toolResolver = ToolPathResolver()
    
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
    
    private func loadEntries(from url: URL, format: String) throws -> [ArchiveEntry] {
        switch format {
        case "zip", "7z", "rar":
            return try loadWith7zz(url)
        case "tar", "gz", "tgz":
            return try loadWithTar(url)
        default:
            throw ArchiveError.unsupportedFormat
        }
    }
    
    private func loadWith7zz(_ url: URL) throws -> [ArchiveEntry] {
        guard let toolPath = toolResolver.resolve("7zz") else {
            throw ArchiveError.toolNotFound("7zz")
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: toolPath)
        process.arguments = ["l", "-slt", url.path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        try process.run()
        process.waitUntilExit()
        
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return parse7zzDetailedOutput(output)
    }
    
    private func parse7zzDetailedOutput(_ output: String) -> [ArchiveEntry] {
        var entries: [ArchiveEntry] = []
        let lines = output.split(separator: "\n")
        
        var currentEntry: (name: String, size: String, isFolder: Bool)?
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("Path = ") {
                let name = String(trimmed.dropFirst(7))
                if !name.isEmpty && name != "." && name != ".." {
                    currentEntry = (name: name, size: "0", isFolder: false)
                }
            } else if trimmed.hasPrefix("Size = ") && currentEntry != nil {
                let size = String(trimmed.dropFirst(7))
                currentEntry?.size = size
            } else if trimmed.hasPrefix("Folder = ") && currentEntry != nil {
                let isFolder = trimmed.dropFirst(9) == "+"
                currentEntry?.isFolder = isFolder
            } else if trimmed.isEmpty && currentEntry != nil {
                if let entry = currentEntry {
                    entries.append(ArchiveEntry(
                        name: entry.name,
                        size: entry.size,
                        isFolder: entry.isFolder
                    ))
                }
                currentEntry = nil
            }
        }
        
        if let entry = currentEntry {
            entries.append(ArchiveEntry(
                name: entry.name,
                size: entry.size,
                isFolder: entry.isFolder
            ))
        }
        
        return entries.filter { !$0.isSystemFile }
    }
    
    private func loadWithTar(_ url: URL) throws -> [ArchiveEntry] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["tvf", url.path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        try process.run()
        process.waitUntilExit()
        
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return parseTarDetailedOutput(output)
    }
    
    private func parseTarDetailedOutput(_ output: String) -> [ArchiveEntry] {
        var entries: [ArchiveEntry] = []
        let lines = output.split(separator: "\n")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            let components = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard components.count >= 6 else { continue }
            
            let sizeString = String(components[3])
            let fileName = String(components.last ?? "")
            let isFolder = fileName.hasSuffix("/")
            let cleanName = isFolder ? String(fileName.dropLast()) : fileName
            
            if !cleanName.isEmpty && cleanName != "." && cleanName != ".." {
                entries.append(ArchiveEntry(
                    name: cleanName,
                    size: sizeString,
                    isFolder: isFolder
                ))
            }
        }
        
        return entries.filter { !$0.isSystemFile }
    }
}
