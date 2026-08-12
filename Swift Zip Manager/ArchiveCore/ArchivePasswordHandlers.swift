//
//  ArchivePasswordHandlers.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/10.
//

import SwiftUI

class ArchivePasswordHandler: ObservableObject {
    @Published var showPasswordDialog = false
    @Published var pendingFileName: String?
    @Published var pendingDestination: URL?
    @Published var pendingIsExtractAll = false
    @Published var pendingEntry: ArchiveEntry?
    @Published var passwordInput = ""
    
    func clearPendingState() {
        pendingFileName = nil
        pendingDestination = nil
        pendingIsExtractAll = false
        pendingEntry = nil
        passwordInput = ""
    }
}
