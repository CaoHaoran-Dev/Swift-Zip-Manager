//
//  TarGzEncryption.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import Foundation

class TarGzEncryption {
    static func createTar(from sourceURLs: [URL], destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-cf", destinationURL.path] + sourceURLs.map { $0.path }
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw NSError(domain: "TarError", code: Int(process.terminationStatus))
        }
    }
    
    static func extractTar(sourceURL: URL, destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-xf", sourceURL.path, "-C", destinationURL.path]
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw NSError(domain: "UntarError", code: Int(process.terminationStatus))
        }
    }
    
    static func createGzip(from sourceURL: URL, destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/gzip")
        process.arguments = ["-c", sourceURL.path]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        try process.run()
        process.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        try outputData.write(to: destinationURL)
        
        if process.terminationStatus != 0 {
            throw NSError(domain: "GzipError", code: Int(process.terminationStatus))
        }
    }
    
    static func extractGzip(sourceURL: URL, destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/gunzip")
        process.arguments = ["-c", sourceURL.path]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        try process.run()
        process.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        try outputData.write(to: destinationURL)
        
        if process.terminationStatus != 0 {
            throw NSError(domain: "GunzipError", code: Int(process.terminationStatus))
        }
    }
}
