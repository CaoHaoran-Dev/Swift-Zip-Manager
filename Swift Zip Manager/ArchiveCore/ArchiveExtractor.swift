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
        
        let process = Process()
        var args: [String] = []
        
        switch format {
        case "zip":
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            args = ["-o", source.path, "-d", target.path]
            if let pwd = password, !pwd.isEmpty {
                args.append("-P")
                args.append(pwd)
            }
            
        case "7z":
            guard let toolPath = toolResolver.resolve("7zz") else {
                throw ArchiveError.toolNotFound("7zz")
            }
            process.executableURL = URL(fileURLWithPath: toolPath)
            args = ["x", source.path, "-o\(target.path)", "-y"]
            if let pwd = password, !pwd.isEmpty {
                args.append("-p\(pwd)")
            }
            
        case "rar":
            guard let toolPath = toolResolver.resolve("rar") else {
                throw ArchiveError.toolNotFound("rar")
            }
            process.executableURL = URL(fileURLWithPath: toolPath)
            args = ["x"]
            if let pwd = password, !pwd.isEmpty {
                args.append("-p\(pwd)")
            }
            args.append(source.path)
            args.append(target.path)
            
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
            throw ArchiveError.commandFailed(errorMsg)
        }
    }
}
