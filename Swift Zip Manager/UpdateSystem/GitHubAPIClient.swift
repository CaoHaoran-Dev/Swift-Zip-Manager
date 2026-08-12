//
//  GitHubAPIClient.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import Foundation

class GitHubAPIClient {
    private let repoOwner = AppConstants.githubRepoOwner
    private let repoName = AppConstants.githubRepoName
    
    func fetchReleases(includePrerelease: Bool) async throws -> [Release] {
        let urlString: String
        
        if includePrerelease {
            urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases?per_page=1"
        } else {
            urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        }
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        request.setValue("Swift-Zip-Manager/\(appVersion) (macOS)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        let session = URLSession(configuration: config)
        
        let (data, _) = try await session.data(for: request)
        
        if includePrerelease {
            let jsonArray = try JSONDecoder().decode([Release].self, from: data)
            print("📡 [GitHub] Beta/RC channel: found \(jsonArray.count) release(s)")
            return jsonArray
        } else {
            let release = try JSONDecoder().decode(Release.self, from: data)
            print("📡 [GitHub] Stable channel: latest release: \(release.tagName)")
            return [release]
        }
    }
}

// MARK: - Models

struct Release: Decodable {
    let tagName: String
    let body: String
    let prerelease: Bool
    let assets: [Asset]
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case body
        case prerelease
        case assets
    }
}

struct Asset: Decodable {
    let name: String
    let browserDownloadURL: URL
    let size: Int64
    let digest: String?  // ✅ GitHub 自动计算的 SHA256，格式: "sha256:xxxxx"
    
    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
        case size
        case digest
    }
    
    /// 获取纯 SHA256 值（去掉 "sha256:" 前缀）
    var sha256: String? {
        guard let digest = digest,
              digest.hasPrefix("sha256:"),
              let hash = digest.split(separator: ":").last else {
            return nil
        }
        return String(hash)
    }
}
