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
    @EnvironmentObject var languageManager: LanguageManager
    
    @StateObject private var viewModel = ArchiveCreationViewModel()
    @State private var isDropTargeted = false
    @State private var showToolMissingAlert = false
    @State private var isCreating = false
    
    private let toolResolver = ToolPathResolver()
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            
            FileSelectionView(viewModel: viewModel, isDropTargeted: $isDropTargeted)
                .padding(.horizontal)
                .padding(.vertical, 8)
            
            Divider()
                .padding(.vertical, 4)
            
            ArchiveOptionsView(viewModel: viewModel)
                .padding(.horizontal)
            
            Divider()
                .padding(.vertical, 8)
            
            bottomBar
        }
        .frame(width: 600, height: 550)
        .onAppear {
            viewModel.loadLastDestination()
        }
        .alert("settings.tools.install.alert.title".localized, isPresented: $showToolMissingAlert) {
            Button("settings.tools.install.alert.install".localized) {
                // 打开工具设置
                WindowManager.shared.openSettings(
                    appState: AppState(),
                    languageManager: languageManager
                )
                dismiss()
            }
            Button("settings.tools.install.alert.cancel".localized, role: .cancel) {
                showToolMissingAlert = false
            }
        } message: {
            Text(String(format: "error.tool.not.found".localized, viewModel.missingToolName))
        }
        .disabled(isCreating)
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var headerView: some View {
        HStack {
            Image(systemName: "doc.badge.plus")
                .foregroundColor(.blue)
                .font(.title2)
            Text("newarchive.title".localized)
                .font(.title2)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
    
    @ViewBuilder
    private var bottomBar: some View {
        HStack {
            Spacer()
            
            Button("newarchive.cancel".localized) {
                dismiss()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.cancelAction)
            
            Button("newarchive.create".localized) {
                createArchive()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!viewModel.canCreate || isCreating)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
    
    // MARK: - Actions
    
    private func createArchive() {
        guard let dest = viewModel.destination else { return }
        guard validatePassword() else { return }
        
        // ✅ 创建前验证工具
        if !validateTools() {
            return
        }
        
        let archiveName = viewModel.name.isEmpty ? "newarchive.name.placeholder".localized : viewModel.name
        
        viewModel.saveLastDestination(dest)
        
        isCreating = true
        
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
        
        // 延迟关闭，确保操作已提交
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isCreating = false
            self.dismiss()
        }
    }
    
    private func validatePassword() -> Bool {
        if viewModel.encryptArchive {
            if viewModel.encryptionPassword != viewModel.confirmPassword {
                viewModel.showPasswordMismatch = true
                return false
            }
            if viewModel.encryptionPassword.isEmpty {
                return false
            }
        }
        viewModel.showPasswordMismatch = false
        return true
    }
    
    private func validateTools() -> Bool {
        let format = viewModel.format
        
        if format == "7z" {
            guard toolResolver.resolve("7zz") != nil else {
                viewModel.missingToolName = "7zz"
                showToolMissingAlert = true
                return false
            }
        } else if format == "rar" {
            guard toolResolver.resolve("rar") != nil else {
                viewModel.missingToolName = "rar"
                showToolMissingAlert = true
                return false
            }
        }
        return true
    }
}
