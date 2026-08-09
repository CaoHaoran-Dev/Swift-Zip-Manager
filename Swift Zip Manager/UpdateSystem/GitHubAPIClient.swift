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
            urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases?per_page=10"
        } else {
            urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        }
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        if includePrerelease {
            let jsonArray = try JSONDecoder().decode([Release].self, from: data)
            return jsonArray
        } else {
            let release = try JSONDecoder().decode(Release.self, from: data)
            return [release]
        }
    }
}

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
    
    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
        case size
    }
}
