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
    
    /// 内部缓存（线程安全）
    private var cachedFiles: [RecentFile] = []
    private let queue = DispatchQueue(label: "com.haoran.SwiftZipManager.recentFiles", attributes: .concurrent)
    private let lock = NSLock()
    
    init() {
        loadData()
    }
    
    // MARK: - 加载
    
    func loadData() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            if let data = UserDefaults.standard.data(forKey: self.key),
               let files = try? JSONDecoder().decode([RecentFile].self, from: data) {
                self.lock.lock()
                self.cachedFiles = files
                self.lock.unlock()
                
                DispatchQueue.main.async {
                    self.recentFiles = files
                }
            }
        }
    }
    
    // MARK: - 添加
    
    func add(_ url: URL) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            self.lock.lock()
            var files = self.cachedFiles
            files.removeAll { $0.url.path == url.path }
            let newFile = RecentFile(url: url)
            files.insert(newFile, at: 0)
            if files.count > self.maxCount {
                files = Array(files.prefix(self.maxCount))
            }
            self.cachedFiles = files
            self.lock.unlock()
            
            DispatchQueue.main.async {
                self.recentFiles = files
            }
            self.saveData(files)
        }
    }
    
    // MARK: - 删除
    
    func remove(at indexSet: IndexSet) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            self.lock.lock()
            var files = self.cachedFiles
            files.remove(atOffsets: indexSet)
            self.cachedFiles = files
            self.lock.unlock()
            
            DispatchQueue.main.async {
                self.recentFiles = files
            }
            self.saveData(files)
        }
    }
    
    // MARK: - 清空
    
    func clear() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            self.lock.lock()
            self.cachedFiles = []
            self.lock.unlock()
            
            DispatchQueue.main.async {
                self.recentFiles = []
            }
            UserDefaults.standard.removeObject(forKey: self.key)
        }
    }
    
    // MARK: - 刷新
    
    func refresh() {
        loadData()
    }
    
    // MARK: - 保存
    
    private func saveData(_ files: [RecentFile]) {
        if let data = try? JSONEncoder().encode(files) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
