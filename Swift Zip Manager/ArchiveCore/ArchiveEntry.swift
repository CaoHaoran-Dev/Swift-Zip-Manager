//
//  ArchiveEntry.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import Foundation

struct ArchiveEntry: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let size: String
    let isFolder: Bool
    let isSystemFile: Bool
    
    init(name: String, size: String, isFolder: Bool = false) {
        self.name = name
        self.size = size
        self.isFolder = isFolder
        self.isSystemFile = name.lowercased() == ".ds_store" || name.hasPrefix("._") || name.contains("__MACOSX")
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ArchiveEntry, rhs: ArchiveEntry) -> Bool {
        lhs.id == rhs.id
    }
}
