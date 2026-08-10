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
    
    // MARK: - 文件加密（新增 #9）
    
    /// 加密文件（使用 AES-256-GCM）
    func encryptFile(at sourceURL: URL, to destinationURL: URL, with password: String) throws {
        let data = try Data(contentsOf: sourceURL)
        let encryptedData = try encryptData(data, with: password)
        try encryptedData.write(to: destinationURL)
    }
    
    /// 解密文件
    func decryptFile(at sourceURL: URL, to destinationURL: URL, with password: String) throws {
        let data = try Data(contentsOf: sourceURL)
        let decryptedData = try decryptData(data, with: password)
        try decryptedData.write(to: destinationURL)
    }
    
    /// 加密 Data
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
    
    /// 解密 Data
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
    
    // MARK: - Helper 方法
    
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
    
    // MARK: - 便捷方法（检查文件是否已加密）
    
    func isEncryptedFile(at url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe),
              data.count > 64 else { return false }
        // 检查是否有有效的 salt/iv/tag 结构
        return true
    }
}

enum CryptoError: Error {
    case invalidData
    case decryptionFailed
}
