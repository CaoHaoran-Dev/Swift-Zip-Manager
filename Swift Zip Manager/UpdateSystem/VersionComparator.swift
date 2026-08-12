//
//  VersionComparator.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import Foundation

/// 构建号版本
/// 格式: MainBuild.Revision
/// - 正式版: 1000.0 (Revision = 0)
/// - 测试版: 1000.1, 1000.2 (Revision > 0)
/// - Tag 支持: v1000.0 或 1000.0（带 v 和不带 v 都支持）
struct BuildVersion {
    let mainBuild: Int
    let revision: Int
    
    init(_ string: String) {
        // ✅ 去掉可选的 "v" 前缀（支持带 v 和不带 v）
        let clean = string.hasPrefix("v") ? String(string.dropFirst()) : string
        let parts = clean.split(separator: ".")
        self.mainBuild = Int(parts[0]) ?? 0
        self.revision = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
    }
    
    /// 判断当前版本是否应更新到目标版本
    func shouldUpdate(to target: BuildVersion) -> Bool {
        // 相同版本不更新
        if mainBuild == target.mainBuild && revision == target.revision {
            return false
        }
        
        if target.revision == 0 {
            // 目标是正式版：Main Build 更大才更新
            return target.mainBuild > mainBuild
        } else {
            // 目标是测试版
            if target.mainBuild > mainBuild {
                return true
            } else if target.mainBuild == mainBuild {
                return target.revision > revision
            } else {
                return false
            }
        }
    }
}

class VersionComparator {
    static func shouldUpdate(current: String, latest: String) -> Bool {
        let currentVer = BuildVersion(current)
        let latestVer = BuildVersion(latest)
        return currentVer.shouldUpdate(to: latestVer)
    }
}
