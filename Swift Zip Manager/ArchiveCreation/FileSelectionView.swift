//
//  FileSelectionView.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI
import UniformTypeIdentifiers

struct FileSelectionView: View {
    @ObservedObject var viewModel: ArchiveCreationViewModel
    @Binding var isDropTargeted: Bool
    
    @State private var showFilePicker = false
    @State private var showFolderPicker = false
    @State private var dropError: String?
    @State private var showDropError = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 工具栏
            HStack {
                Button("newarchive.add.files".localized) {
                    showFilePicker = true
                }
                .buttonStyle(.bordered)
                
                Button("newarchive.add.folder".localized) {
                    showFolderPicker = true
                }
                .buttonStyle(.bordered)
                
                if !viewModel.files.isEmpty {
                    Button("newarchive.clear.all".localized) {
                        viewModel.clearFiles()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
                
                Spacer()
                Text(String(format: "newarchive.files.count".localized, viewModel.files.count))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 文件列表或拖放区域
            if !viewModel.files.isEmpty {
                fileList
            } else {
                dropZone
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.data],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                viewModel.addFiles(urls)
            }
        }
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                // 获取文件夹内容
                let fm = FileManager.default
                if let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
                    viewModel.addFiles(contents)
                }
            }
        }
        .alert("filebrowser.drop.error".localized, isPresented: $showDropError) {
            Button("alert.ok".localized) { }
        } message: {
            Text(dropError ?? "Unknown error")
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var fileList: some View {
        List(viewModel.files, id: \.self) { file in
            HStack {
                Image(systemName: "doc")
                    .foregroundColor(.blue)
                Text(file.lastPathComponent)
                    .lineLimit(1)
                Spacer()
                Text(viewModel.fileSize(file))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button {
                    viewModel.removeFile(file)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 100)
    }
    
    @ViewBuilder
    private var dropZone: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 30))
                .foregroundColor(isDropTargeted ? .accentColor : .secondary)
            Text(isDropTargeted ? "newarchive.drop.here".localized : "newarchive.drop.hint".localized)
                .font(.caption)
                .foregroundColor(isDropTargeted ? .accentColor : .secondary)
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isDropTargeted ? Color.accentColor : Color.gray.opacity(0.3),
                        style: StrokeStyle(lineWidth: isDropTargeted ? 2 : 1, dash: [5]))
                .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        )
        .cornerRadius(8)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
    }
    
    // MARK: - Drag & Drop
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        var loadedUrls: [URL] = []
        var errorMessage: String?
        
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, error in
                defer { group.leave() }
                
                if let error = error {
                    errorMessage = error.localizedDescription
                    return
                }
                
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    loadedUrls.append(url)
                }
            }
        }
        
        group.notify(queue: .main) {
            if let error = errorMessage {
                dropError = error
                showDropError = true
                return
            }
            
            if !loadedUrls.isEmpty {
                viewModel.addFiles(loadedUrls)
            }
        }
        
        return true
    }
}
