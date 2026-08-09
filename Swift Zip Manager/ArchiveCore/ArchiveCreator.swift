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
    
    func create(files: [URL], format: String, name: String, destination: URL, password: String?, completion: @escaping (Result<Void, ArchiveError>) -> Void) {
        let ext = ["zip": "zip", "tar": "tar", "gz": "tar.gz", "7z": "7z", "rar": "rar"][format] ?? "zip"
        let fileName = name.hasSuffix(".\(ext)") ? name : "\(name).\(ext)"
        let targetPath = destination.appendingPathComponent(fileName)
        
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
        
        // 复制文件到临时目录
        for file in files {
            let destURL = tempDir.appendingPathComponent(file.lastPathComponent)
            try fileManager.copyItem(at: file, to: destURL)
        }
        
        let process = Process()
        var args: [String] = []
        
        switch format {
        case "zip":
            process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            args = ["-r"]
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
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw ArchiveError.commandFailed("Process exited with code \(process.terminationStatus)")
        }
    }
}
