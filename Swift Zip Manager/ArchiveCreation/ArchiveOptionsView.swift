//
//  ArchiveOptionsView.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI

struct ArchiveOptionsView: View {
    @ObservedObject var viewModel: ArchiveCreationViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 名称
            HStack {
                Text("newarchive.name.label".localized)
                    .font(.caption)
                    .frame(width: 50, alignment: .trailing)
                TextField("newarchive.name.placeholder".localized, text: $viewModel.name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 200)
                Text(".\(viewModel.getExtension())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 格式
            HStack {
                Text("newarchive.format.label".localized)
                    .font(.caption)
                    .frame(width: 50, alignment: .trailing)
                
                Picker("", selection: $viewModel.format) {
                    ForEach(viewModel.formats, id: \.self) { format in
                        Text(format.uppercased()).tag(format)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
                
                Text(formatDescription(for: viewModel.format))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
                
                Spacer()
            }
            
            // 目标路径
            HStack {
                Text("newarchive.save.to.label".localized)
                    .font(.caption)
                    .frame(width: 50, alignment: .trailing)
                Text(viewModel.destination?.lastPathComponent ?? "newarchive.not.selected".localized)
                    .font(.caption)
                    .frame(width: 200, alignment: .leading)
                    .foregroundColor(viewModel.destination == nil ? .secondary : .primary)
                Button("newarchive.browse".localized) {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canCreateDirectories = true
                    panel.begin { response in
                        if response == .OK, let url = panel.url {
                            viewModel.destination = url
                            viewModel.saveLastDestination(url)
                        }
                    }
                }
                .buttonStyle(.bordered)
            }
            
            // 加密选项
            if viewModel.supportsEncryption {
                encryptionSection
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Helpers
    
    private func formatDescription(for format: String) -> String {
        // 从 Constants 读取，而不是硬编码
        switch format {
        case "zip": return "newarchive.format.zip".localized
        case "tar": return "newarchive.format.tar".localized
        case "gz": return "newarchive.format.gz".localized
        case "7z": return "newarchive.format.7z".localized
        case "rar": return "newarchive.format.rar".localized
        default: return ""
        }
    }
    
    // MARK: - Encryption Section
    
    @ViewBuilder
    private var encryptionSection: some View {
        Toggle("newarchive.encrypt".localized, isOn: $viewModel.encryptArchive)
            .padding(.top, 8)
            .padding(.leading, 58)
        
        if viewModel.encryptArchive {
            VStack(alignment: .leading, spacing: 8) {
                SecureField("newarchive.password".localized, text: $viewModel.encryptionPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 220)
                
                SecureField("newarchive.confirm.password".localized, text: $viewModel.confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 220)
                
                // 密码强度指示器
                passwordStrengthView
                
                if viewModel.showPasswordMismatch {
                    Text("newarchive.password.mismatch".localized)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding(.leading, 58)
            .padding(.top, 4)
        }
    }
    
    @ViewBuilder
    private var passwordStrengthView: some View {
        if !viewModel.encryptionPassword.isEmpty {
            let strength = viewModel.passwordStrength
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { index in
                    Rectangle()
                        .fill(index < strength ? strengthColor(for: strength) : Color.gray.opacity(0.3))
                        .frame(width: 30, height: 4)
                        .cornerRadius(2)
                }
                Text(strengthText(for: strength))
                    .font(.caption2)
                    .foregroundColor(strengthColor(for: strength))
                    .padding(.leading, 4)
            }
        }
    }
    
    private func strengthColor(for strength: Int) -> Color {
        switch strength {
        case 0: return .gray
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        default: return .gray
        }
    }
    
    private func strengthText(for strength: Int) -> String {
        switch strength {
        case 0: return ""
        case 1: return "archive.password.strength.weak".localized
        case 2: return "archive.password.strength.fair".localized
        case 3: return "archive.password.strength.good".localized
        case 4: return "archive.password.strength.strong".localized
        default: return ""
        }
    }
}
