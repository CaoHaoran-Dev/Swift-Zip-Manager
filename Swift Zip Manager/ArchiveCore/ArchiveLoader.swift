//
//  ArchiveLoader.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import Foundation

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
        process.arguments = ["l", url.path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        try process.run()
        process.waitUntilExit()
        
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return parse7zzOutput(output)
    }
    
    private func parse7zzOutput(_ output: String) -> [ArchiveEntry] {
        var entries: [ArchiveEntry] = []
        let lines = output.split(separator: "\n")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            let components = trimmed.split(separator: " ", maxSplits: 3)
            if components.count >= 4 {
                let size = String(components[2])
                var fileName = String(components[3])
                let isFolder = fileName.hasSuffix("/")
                if isFolder {
                    fileName = String(fileName.dropLast())
                }
                if !fileName.isEmpty && fileName != "." && fileName != ".." {
                    entries.append(ArchiveEntry(name: fileName, size: size, isFolder: isFolder))
                }
            }
        }
        
        return entries.filter { !$0.isSystemFile }
    }
    
    private func loadWithTar(_ url: URL) throws -> [ArchiveEntry] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["tf", url.path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        try process.run()
        process.waitUntilExit()
        
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return parseTarOutput(output)
    }
    
    private func parseTarOutput(_ output: String) -> [ArchiveEntry] {
        var entries: [ArchiveEntry] = []
        let lines = output.split(separator: "\n")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            let isFolder = trimmed.hasSuffix("/")
            let fileName = isFolder ? String(trimmed.dropLast()) : trimmed
            if !fileName.isEmpty && fileName != "." && fileName != ".." {
                entries.append(ArchiveEntry(name: fileName, size: "--", isFolder: isFolder))
            }
        }
        
        return entries.filter { !$0.isSystemFile }
    }
}

enum ArchiveError: LocalizedError {
    case unsupportedFormat
    case toolNotFound(String)
    case commandFailed(String)
    case passwordRequired
    
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
        }
    }
}
