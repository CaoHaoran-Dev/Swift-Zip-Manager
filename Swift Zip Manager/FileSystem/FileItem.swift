//
//  FileItem.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import Foundation

struct FileItem: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    let name: String
    let isDirectory: Bool
    let isArchive: Bool
    let size: Int64?
    let modificationDate: Date?
    
    var sizeFormatted: String {
        guard let size = size else { return "--" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var dateFormatted: String {
        guard let date = modificationDate else { return "--" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
