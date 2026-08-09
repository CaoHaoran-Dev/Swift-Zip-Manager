//
//  Constants.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import Foundation

enum AppConstants {
    static let appName = "Swift Zip Manager"
    static let bundleIdentifier = "com.haoran.Swift-Zip-Manager"
    static let githubRepoOwner = "CaoHaoran-Dev"
    static let githubRepoName = "Swift-Zip-Manager"
    static let targetFileName = "Swift.Zip.Manager.zip"
    static let appFileName = "Swift Zip Manager.app"
    
    static let maxRecentFiles = 15
    static let maxDevLogs = 500
    
    enum ToolName {
        static let sevenzz = "7zz"
        static let rar = "rar"
    }
    
    enum SupportedFormat: String, CaseIterable {
        case zip = "zip"
        case tar = "tar"
        case gz = "gz"
        case tgz = "tgz"
        case sevenZ = "7z"
        case rar = "rar"
    }
    
    enum ToolDownloadURL {
        static let sevenzz = "https://github.com/ip7z/7zip/releases/download/26.00/7z2600-mac.tar.xz"
        static var rar: String {
            #if arch(arm64)
                return "https://www.rarlab.com/rar/rarmacos-arm-720.tar.gz"
            #else
                return "https://www.rarlab.com/rar/rarmacos-x64-720.tar.gz"
            #endif
        }
    }
}
