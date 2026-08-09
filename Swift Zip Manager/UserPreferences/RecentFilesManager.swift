//
//  RecentFilesManager.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI

class RecentFilesManager: ObservableObject {
    @Published var recentFiles: [RecentFile] = []
    private let maxCount = AppConstants.maxRecentFiles
    private let key = "RecentFiles"
    
    init() {
        loadData()
    }
    
    func loadData() {
        if let data = UserDefaults.standard.data(forKey: key),
           let files = try? JSONDecoder().decode([RecentFile].self, from: data) {
            DispatchQueue.main.async {
                self.recentFiles = files
            }
        }
    }
    
    func add(_ url: URL) {
        var files = recentFiles
        files.removeAll { $0.url.path == url.path }
        let newFile = RecentFile(url: url)
        files.insert(newFile, at: 0)
        if files.count > maxCount {
            files = Array(files.prefix(maxCount))
        }
        
        DispatchQueue.main.async {
            self.recentFiles = files
        }
        saveData(files)
    }
    
    func remove(at indexSet: IndexSet) {
        var files = recentFiles
        files.remove(atOffsets: indexSet)
        
        DispatchQueue.main.async {
            self.recentFiles = files
        }
        saveData(files)
    }
    
    func clear() {
        DispatchQueue.main.async {
            self.recentFiles = []
        }
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    func refresh() {
        loadData()
    }
    
    private func saveData(_ files: [RecentFile]) {
        if let data = try? JSONEncoder().encode(files) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
