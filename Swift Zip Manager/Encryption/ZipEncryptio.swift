//
//  ZipEncryptio.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import Foundation

class ZipEncryption {
    static func createEncryptedZip(sourceURLs: [URL], destinationURL: URL, password: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        
        var args = ["-r"]
        if !password.isEmpty {
            args.append("-P")
            args.append(password)
        }
        args.append(destinationURL.path)
        args.append(contentsOf: sourceURLs.map { $0.path })
        
        process.arguments = args
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw NSError(domain: "ZipError", code: Int(process.terminationStatus))
        }
    }
    
    static func extractEncryptedZip(sourceURL: URL, destinationURL: URL, password: String?) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        
        var args = ["-o", sourceURL.path, "-d", destinationURL.path]
        if let pwd = password, !pwd.isEmpty {
            args.append("-P")
            args.append(pwd)
        }
        
        process.arguments = args
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw NSError(domain: "UnzipError", code: Int(process.terminationStatus))
        }
    }
}
