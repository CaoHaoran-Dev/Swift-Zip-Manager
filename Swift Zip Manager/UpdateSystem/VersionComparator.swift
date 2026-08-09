//
//  VersionComparator.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import Foundation

struct BuildVersion {
    let mainBuild: Int
    let revision: Int
    
    init(_ string: String) {
        let parts = string.split(separator: ".")
        self.mainBuild = Int(parts[0]) ?? 0
        self.revision = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
    }
    
    func shouldUpdate(to latest: BuildVersion) -> Bool {
        if latest.revision == 0 {
            // 最新版是正式版
            if latest.mainBuild >= mainBuild {
                return true
            } else {
                return false
            }
        } else {
            // 最新版是测试版
            if latest.mainBuild > mainBuild {
                return true
            } else if latest.mainBuild == mainBuild && latest.revision > revision {
                return true
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
