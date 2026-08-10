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
    
    // ✅ #9: 使用串行队列保证线程安全
    private let queue = DispatchQueue(label: "com.haoran.SwiftZipManager.recentFiles")
    
    init() {
        loadData()
    }
    
    func loadData() {
        queue.async {
            if let data = UserDefaults.standard.data(forKey: self.key),
               let files = try? JSONDecoder().decode([RecentFile].self, from: data) {
                DispatchQueue.main.async {
                    self.recentFiles = files
                }
            }
        }
    }
    
    func add(_ url: URL) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            var files = self.recentFiles
            // 去重（按路径）
            files.removeAll { $0.url.path == url.path }
            let newFile = RecentFile(url: url)
            files.insert(newFile, at: 0)
            if files.count > self.maxCount {
                files = Array(files.prefix(self.maxCount))
            }
            
            DispatchQueue.main.async {
                self.recentFiles = files
            }
            self.saveData(files)
        }
    }
    
    func remove(at indexSet: IndexSet) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            var files = self.recentFiles
            files.remove(atOffsets: indexSet)
            
            DispatchQueue.main.async {
                self.recentFiles = files
            }
            self.saveData(files)
        }
    }
    
    func clear() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.recentFiles = []
            }
            UserDefaults.standard.removeObject(forKey: self.key)
        }
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
