//
//  RecentFile.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import Foundation

struct RecentFile: Identifiable, Hashable, Codable {
    let id: UUID
    let url: URL
    let name: String
    let path: String
    
    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.name = url.lastPathComponent
        self.path = url.path
    }
    
    // MARK: - Codable 自定义实现
    
    enum CodingKeys: String, CodingKey {
        case id, name, path
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.path = try container.decode(String.self, forKey: .path)
        self.url = URL(fileURLWithPath: path)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(path, forKey: .path)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: RecentFile, rhs: RecentFile) -> Bool {
        lhs.id == rhs.id
    }
}
