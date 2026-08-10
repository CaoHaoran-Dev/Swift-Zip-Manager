//
//  Extensions.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import Foundation
import SwiftUI

extension URL {
    var isArchive: Bool {
        let ext = pathExtension.lowercased()
        return ["zip", "7z", "rar", "tar", "gz", "tgz"].contains(ext)
    }
    
    var fileSize: Int64? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path) else { return nil }
        return attrs[.size] as? Int64
    }
    
    var modificationDate: Date? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path) else { return nil }
        return attrs[.modificationDate] as? Date
    }
}

extension String {
    var isSystemFile: Bool {
        let lower = lowercased()
        return lower == ".ds_store" || hasPrefix("._") || contains("__macosx")
    }
}

extension Bundle {
    var appVersion: String {
        let shortVersion = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(shortVersion) (Build \(build))"
    }
}

extension ByteCountFormatter {
    static func string(fromByteCount count: Int64) -> String {
        return ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
    }
}

// MARK: - Process 超时扩展

extension Process {
    /// 带超时的 run，超时后自动终止进程
    func runWithTimeout(seconds: TimeInterval = 120) throws {
        try run()
        
        let startTime = Date()
        while isRunning {
            if Date().timeIntervalSince(startTime) > seconds {
                terminate()
                waitUntilExit()
                throw ArchiveError.timeout
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
    }
}
