//
//  ArchiveEntry.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import Foundation

struct ArchiveEntry: Identifiable, Hashable, Sendable {
    let id = UUID()
    
    /// 完整相对路径（如 "docs/images/photo.jpg"）
    let path: String
    
    /// 文件大小（字节），-1 表示未知（如目录）
    let sizeBytes: Int64
    
    /// 是否为目录
    let isDirectory: Bool
    
    /// 文件名（从 path 提取）
    var name: String {
        (path as NSString).lastPathComponent
    }
    
    /// 是否为系统文件（完整路径检测）
    var isSystemFile: Bool {
        let components = (path as NSString).pathComponents
        return components.contains { component in
            let lower = component.lowercased()
            return lower == ".ds_store" ||
                   lower.hasPrefix("._") ||
                   lower == "__macosx"
        }
    }
    
    /// 格式化文件大小（UI 用）
    var formattedSize: String {
        guard sizeBytes >= 0 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
    
    init(path: String, sizeBytes: Int64 = -1, isDirectory: Bool = false) {
        self.path = path
        self.sizeBytes = sizeBytes
        self.isDirectory = isDirectory
    }
    
    // 兼容旧初始化方法（过渡用）
    init(name: String, size: String, isFolder: Bool = false) {
        self.path = name
        self.sizeBytes = Int64(size) ?? -1
        self.isDirectory = isFolder
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ArchiveEntry, rhs: ArchiveEntry) -> Bool {
        lhs.id == rhs.id
    }
}
