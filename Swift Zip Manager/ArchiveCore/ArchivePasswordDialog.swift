//
//   ArchivePasswordDialog.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI

struct ArchivePasswordDialog: View {
    @Binding var isPresented: Bool
    @Binding var password: String
    let fileName: String?
    let onConfirm: (String) -> Void
    
    @State private var inputPassword = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.largeTitle)
                .foregroundColor(.blue)
            
            Text("archive.password.required".localized)
                .font(.headline)
            
            if let fileName = fileName {
                Text(fileName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            SecureField("archive.password.placeholder".localized, text: $inputPassword)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)
            
            HStack(spacing: 20) {
                Button("archive.password.cancel".localized) {
                    isPresented = false
                    inputPassword = ""
                }
                .buttonStyle(.bordered)
                
                Button("archive.password.extract".localized) {
                    password = inputPassword
                    onConfirm(inputPassword)
                    isPresented = false
                    inputPassword = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputPassword.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 350, height: 280)
    }
}
