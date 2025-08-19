/**
 * GhostLink Privacy Shield - Cryptographic Utilities
 * Handles hashing, signing, and verification of privacy receipts
 */
export declare class CryptoUtils {
    /**
     * Generate SHA-256 hash of input string
     */
    generateHash(input: string): Promise<string>;
    /**
     * Generate a unique receipt ID
     */
    generateReceiptId(): string;
    /**
     * Create a privacy receipt with cryptographic proof
     */
    createPrivacyReceipt(originalQuery: string, processedQuery: string, site: string, privacyLevel: string, metadata?: any): Promise<any>;
    /**
     * Sign receipt data for integrity verification
     */
    private signReceipt;
    /**
     * Verify receipt signature
     */
    verifyReceipt(receipt: any): Promise<boolean>;
    /**
     * Generate secure random bytes for noise injection
     */
    generateSecureRandom(length?: number): Uint8Array;
    /**
     * Generate differential privacy noise
     */
    generateDifferentialPrivacyNoise(epsilon?: number): number;
    /**
     * Secure string comparison to prevent timing attacks
     */
    secureCompare(a: string, b: string): boolean;
    /**
     * Generate anonymization key for consistent replacements
     */
    generateAnonymizationKey(input: string, salt?: string): Promise<string>;
    /**
     * Encrypt sensitive data for storage
     */
    encryptData(data: string, key: string): Promise<string>;
    /**
     * Decrypt sensitive data from storage
     */
    decryptData(encryptedData: string, key: string): Promise<string>;
}
