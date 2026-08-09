//
//  ToolPathResolver.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import Foundation

class ToolPathResolver {
    private let fileManager = FileManager.default
    
    func resolve(_ command: String) -> String? {
        // 1. 检查开发者自定义路径
        if let customPath = getCustomPath(for: command), !customPath.isEmpty {
            if fileManager.fileExists(atPath: customPath) {
                return customPath
            }
        }
        
        // 2. 检查应用支持目录
        if let appPath = getAppSupportPath(for: command) {
            return appPath
        }
        
        // 3. 检查系统路径
        return getSystemPath(for: command)
    }
    
    private func getCustomPath(for command: String) -> String? {
        let key = command == "7zz" ? "CustomToolPath7zz" : "CustomToolPathRar"
        guard UserDefaults.standard.bool(forKey: "UseCustomToolPaths") else { return nil }
        return UserDefaults.standard.string(forKey: key)
    }
    
    private func getAppSupportPath(for command: String) -> String? {
        let home = fileManager.homeDirectoryForCurrentUser.path
        let path = "\(home)/Library/Application Support/com.haoran.Swift-Zip-Manager/tools/\(command)"
        return fileManager.fileExists(atPath: path) ? path : nil
    }
    
    private func getSystemPath(for command: String) -> String? {
        #if arch(arm64)
            let paths = ["/opt/local/bin/\(command)", "/usr/local/bin/\(command)"]
        #else
            let paths = ["/usr/local/bin/\(command)"]
        #endif
        return paths.first { fileManager.fileExists(atPath: $0) }
    }
    
    func isInstalled(_ command: String) -> Bool {
        return resolve(command) != nil
    }
}
