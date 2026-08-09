//
//  SevenZipEncryption.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import Foundation

class SevenZipEncryption {
    static func createEncrypted7z(sourceURLs: [URL], destinationURL: URL, password: String, toolPath: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: toolPath)
        
        var args = ["a", destinationURL.path]
        if !password.isEmpty {
            args.append("-p\(password)")
            args.append("-mhe=on")
        }
        args.append(contentsOf: sourceURLs.map { $0.path })
        
        process.arguments = args
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw NSError(domain: "SevenZipError", code: Int(process.terminationStatus))
        }
    }
    
    static func extractEncrypted7z(sourceURL: URL, destinationURL: URL, password: String?, toolPath: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: toolPath)
        
        var args = ["x", sourceURL.path, "-o\(destinationURL.path)", "-y"]
        if let pwd = password, !pwd.isEmpty {
            args.append("-p\(pwd)")
        }
        
        process.arguments = args
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw NSError(domain: "SevenZipError", code: Int(process.terminationStatus))
        }
    }
}
