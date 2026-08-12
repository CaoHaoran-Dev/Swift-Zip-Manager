//
//  ArchiveError.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/11.
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
    case encryptionFailed
    case decryptionFailed
    
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
        case .encryptionFailed:
            return "Encryption failed"
        case .decryptionFailed:
            return "Decryption failed"
        }
    }
    
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
        case (.encryptionFailed, .encryptionFailed):
            return true
        case (.decryptionFailed, .decryptionFailed):
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
