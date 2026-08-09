//
//  UnstableSettingsView.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI

struct UnstableSettingsView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("developer.unstable.async".localized, isOn: $appState.unstableAsyncWrite)
                    
                    Text("developer.unstable.async.desc".localized)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.leading, 24)
                    
                    Divider()
                    
                    Toggle("developer.unstable.memory".localized, isOn: $appState.unstableMemoryExtract)
                    
                    Text("developer.unstable.memory.desc".localized)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.leading, 24)
                    
                    Divider()
                    
                    Toggle("developer.unstable.skip.permissions".localized, isOn: $appState.unstableSkipPermissions)
                    
                    Text("developer.unstable.skip.permissions.desc".localized)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.leading, 24)
                }
                .padding()
            } label: {
                Label("developer.unstable.title".localized, systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            }
            
            VStack {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("developer.unstable.warning".localized)
                        .font(.caption)
                }
            }
            .foregroundColor(.red)
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
        }
    }
}
