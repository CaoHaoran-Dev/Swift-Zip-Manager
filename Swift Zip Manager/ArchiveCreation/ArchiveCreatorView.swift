//
//  ArchiveCreatorView.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI

struct ArchiveCreatorView: View {
    @ObservedObject var manager: ArchiveManager
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var viewModel = ArchiveCreationViewModel()
    @State private var isDropTargeted = false
    
    var body: some View {
        VStack {
            Text("newarchive.title".localized)
                .font(.title2)
                .padding()
            
            FileSelectionView(viewModel: viewModel, isDropTargeted: $isDropTargeted)
                .padding(.horizontal)
            
            Divider()
                .padding(.vertical, 8)
            
            ArchiveOptionsView(viewModel: viewModel)
                .padding(.horizontal)
            
            Divider()
                .padding(.vertical, 8)
            
            HStack {
                Button("newarchive.cancel".localized) {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("newarchive.create".localized) {
                    createArchive()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.canCreate)
            }
            .padding()
        }
        .frame(width: 600, height: 550)
        .onAppear {
            viewModel.loadLastDestination()
        }
    }
    
    private func createArchive() {
        guard let dest = viewModel.destination else { return }
        guard viewModel.validatePassword() else { return }
        
        let archiveName = viewModel.name.isEmpty ? "newarchive.name.placeholder".localized : viewModel.name
        
        viewModel.saveLastDestination(dest)
        
        if viewModel.encryptArchive {
            manager.createArchiveWithEncryption(
                files: viewModel.files,
                format: viewModel.format,
                name: archiveName,
                destination: dest,
                password: viewModel.encryptionPassword
            )
        } else {
            manager.createArchive(
                files: viewModel.files,
                format: viewModel.format,
                name: archiveName,
                destination: dest
            )
        }
        dismiss()
    }
}
