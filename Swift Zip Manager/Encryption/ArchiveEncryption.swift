//
//  ArchiveEncryption.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import Foundation

/// 归档加密协议
protocol ArchiveEncryption {
    /// 创建加密归档
    func create(
        sourceURLs: [URL],
        destinationURL: URL,
        password: String?
    ) throws
    
    /// 提取加密归档
    func extract(
        sourceURL: URL,
        destinationURL: URL,
        password: String?
    ) throws
}

/// 加密协议提供者
protocol EncryptionProvider {
    func encryptor(for format: String) -> ArchiveEncryption?
}

class DefaultEncryptionProvider: EncryptionProvider {
    private let toolResolver: ToolPathResolver
    
    init(toolResolver: ToolPathResolver = ToolPathResolver()) {
        self.toolResolver = toolResolver
    }
    
    func encryptor(for format: String) -> ArchiveEncryption? {
        switch format {
        case "zip":
            return ZipEncryption()
        case "7z":
            guard toolResolver.resolve("7zz") != nil else { return nil }
            return SevenZipEncryption(toolResolver: toolResolver)
        case "rar":
            guard toolResolver.resolve("rar") != nil else { return nil }
            return RarEncryption(toolResolver: toolResolver)
        default:
            return nil
        }
    }
}
