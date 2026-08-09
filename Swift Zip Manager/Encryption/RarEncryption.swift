//
//  RarEncryption.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import Foundation

class RarEncryption {
    static func createEncryptedRar(sourceURLs: [URL], destinationURL: URL, password: String, toolPath: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: toolPath)
        
        var args = ["a", "-r"]
        if !password.isEmpty {
            args.append("-hp\(password)")
        }
        args.append(destinationURL.path)
        args.append(contentsOf: sourceURLs.map { $0.path })
        
        process.arguments = args
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw NSError(domain: "RarError", code: Int(process.terminationStatus))
        }
    }
    
    static func extractEncryptedRar(sourceURL: URL, destinationURL: URL, password: String?, toolPath: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: toolPath)
        
        var args = ["x"]
        if let pwd = password, !pwd.isEmpty {
            args.append("-p\(pwd)")
        }
        args.append(sourceURL.path)
        args.append(destinationURL.path)
        
        process.arguments = args
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw NSError(domain: "RarError", code: Int(process.terminationStatus))
        }
    }
}
