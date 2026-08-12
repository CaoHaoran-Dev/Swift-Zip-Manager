//
//  CryptoManager.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import Foundation
import CryptoKit

class CryptoManager {
    static let shared = CryptoManager()
    private init() {}
    
    // MARK: - 文件加密
    
    func encryptFile(at sourceURL: URL, to destinationURL: URL, with password: String) throws {
        let data = try Data(contentsOf: sourceURL)
        let encryptedData = try encryptData(data, with: password)
        try encryptedData.write(to: destinationURL)
    }
    
    func decryptFile(at sourceURL: URL, to destinationURL: URL, with password: String) throws {
        let data = try Data(contentsOf: sourceURL)
        let decryptedData = try decryptData(data, with: password)
        try decryptedData.write(to: destinationURL)
    }
    
    func encryptData(_ data: Data, with password: String) throws -> Data {
        let salt = generateSalt()
        let key = deriveKey(from: password, salt: salt)
        let iv = generateIV()
        
        let encrypted = try AES.GCM.seal(data, using: key, nonce: AES.GCM.Nonce(data: iv))
        
        var result = Data()
        result.append(salt)
        result.append(iv)
        result.append(encrypted.ciphertext)
        result.append(encrypted.tag)
        
        return result
    }
    
    func decryptData(_ data: Data, with password: String) throws -> Data {
        guard data.count > 64 else { throw CryptoError.invalidData }
        
        let salt = data.prefix(32)
        let iv = data.subdata(in: 32..<48)
        let tag = data.suffix(16)
        let ciphertext = data.subdata(in: 48..<data.count - 16)
        
        let key = deriveKey(from: password, salt: salt)
        let sealedBox = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: iv), ciphertext: ciphertext, tag: tag)
        
        return try AES.GCM.open(sealedBox, using: key)
    }
    
    // MARK: - Helper
    
    private func generateSalt() -> Data {
        var salt = Data(count: 32)
        _ = salt.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 32, bytes.baseAddress!)
        }
        return salt
    }
    
    private func generateIV() -> Data {
        var iv = Data(count: 12)
        _ = iv.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 12, bytes.baseAddress!)
        }
        return iv
    }
    
    private func deriveKey(from password: String, salt: Data) -> SymmetricKey {
        let passwordData = password.data(using: .utf8)!
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: passwordData),
            salt: salt,
            outputByteCount: 32
        )
    }
    
    // MARK: - ✅ 改进：isEncryptedFile 判断
    
    /// 检查文件是否为此加密器加密（启发式判断）
    func isEncryptedFile(at url: URL) -> Bool {
        guard let fileHandle = FileHandle(forReadingAtPath: url.path) else {
            return false
        }
        defer { try? fileHandle.close() }
        
        // 1. 检查文件大小至少为 64 字节
        guard let size = try? fileHandle.seekToEnd(),
              size >= 64 else {
            return false
        }
        try? fileHandle.seek(toOffset: 0)
        
        // 2. 读取前 32 字节检查
        guard let headerData = try? fileHandle.read(upToCount: 32),
              headerData.count == 32 else {
            return false
        }
        
        // 3. 排除常见文件格式的 magic bytes
        let magicBytes: [[UInt8]] = [
            [0x50, 0x4B],           // ZIP
            [0x1F, 0x8B],           // GZIP
            [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C], // 7z
            [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07], // RAR
            [0xFF, 0xD8, 0xFF],     // JPEG
            [0x89, 0x50, 0x4E, 0x47], // PNG
            [0x25, 0x50, 0x44, 0x46], // PDF
            [0x7B, 0x5C, 0x72, 0x74, 0x66], // RTF
            [0x3C, 0x3F, 0x78, 0x6D, 0x6C], // XML
            [0x2F, 0x2F, 0x2F],     // 注释开头
        ]
        
        let headerBytes = [UInt8](headerData)
        for magic in magicBytes {
            if headerBytes.starts(with: magic) {
                return false
            }
        }
        
        // 4. 检查熵值（随机数据的熵通常 > 6.0）
        let entropy = calculateEntropy(headerBytes)
        if entropy < 6.0 {
            return false
        }
        
        // 5. 检查 iv（第 32-44 字节），看起来像随机数据
        try? fileHandle.seek(toOffset: 32)
        guard let ivData = try? fileHandle.read(upToCount: 12),
              ivData.count == 12 else {
            return false
        }
        let ivEntropy = calculateEntropy([UInt8](ivData))
        return ivEntropy > 5.0
    }
    
    /// 计算数据的熵值（0-8，越高越随机）
    private func calculateEntropy(_ data: [UInt8]) -> Double {
        guard !data.isEmpty else { return 0 }
        
        var frequency: [UInt8: Int] = [:]
        for byte in data {
            frequency[byte, default: 0] += 1
        }
        
        var entropy = 0.0
        for count in frequency.values {
            let probability = Double(count) / Double(data.count)
            entropy -= probability * log2(probability)
        }
        return entropy
    }
}

enum CryptoError: Error {
    case invalidData
    case decryptionFailed
}
