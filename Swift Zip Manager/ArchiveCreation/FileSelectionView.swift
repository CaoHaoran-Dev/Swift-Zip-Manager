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
    
    @State private var showPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("newarchive.add.files".localized) {
                    showPicker = true
                }
                .buttonStyle(.bordered)
                
                Button("newarchive.add.folder".localized) {
                    showPicker = true
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
            
            if !viewModel.files.isEmpty {
                List(viewModel.files, id: \.self) { file in
                    HStack {
                        Image(systemName: "doc")
                            .foregroundColor(.blue)
                        Text(file.lastPathComponent)
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
            } else {
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
        }
        .fileImporter(
            isPresented: $showPicker,
            allowedContentTypes: [.data, .folder],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                viewModel.addFiles(urls)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var loadedUrls: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, error in
                defer { group.leave() }
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    loadedUrls.append(url)
                }
            }
        }
        
        group.notify(queue: .main) {
            if !loadedUrls.isEmpty {
                viewModel.addFiles(loadedUrls)
            }
        }
        
        return true
    }
}
