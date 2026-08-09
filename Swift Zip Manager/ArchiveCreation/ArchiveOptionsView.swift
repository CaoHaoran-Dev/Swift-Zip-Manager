//
//  ArchiveOptionsView..swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI

struct ArchiveOptionsView: View {
    @ObservedObject var viewModel: ArchiveCreationViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
            
            if viewModel.supportsEncryption {
                encryptionToggle
            }
        }
    }
    
    private func formatDescription(for format: String) -> String {
        switch format {
        case "zip": return "newarchive.format.zip".localized
        case "tar": return "newarchive.format.tar".localized
        case "gz": return "newarchive.format.gz".localized
        case "7z": return "newarchive.format.7z".localized
        case "rar": return "newarchive.format.rar".localized
        default: return ""
        }
    }
    
    @ViewBuilder
    private var encryptionToggle: some View {
        Toggle("newarchive.encrypt".localized, isOn: $viewModel.encryptArchive)
            .padding(.top, 8)
            .padding(.leading, 58)
        
        if viewModel.encryptArchive {
            VStack(alignment: .leading, spacing: 8) {
                SecureField("newarchive.password".localized, text: $viewModel.encryptionPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 200)
                SecureField("newarchive.confirm.password".localized, text: $viewModel.confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 200)
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
}
