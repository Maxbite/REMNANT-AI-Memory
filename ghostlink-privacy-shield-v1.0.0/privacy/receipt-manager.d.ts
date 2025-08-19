/**
 * GhostLink Privacy Shield - Receipt Manager
 * Manages cryptographic receipts for privacy operations
 */
import { PrivacyReceipt, PrivacyProcessingResult } from '../utils/types';
export declare class ReceiptManager {
    private cryptoUtils;
    private storageManager;
    constructor();
    /**
     * Generate a privacy receipt for a processed query
     */
    generateReceipt(processingResult: PrivacyProcessingResult, site: string, privacyLevel: string): Promise<PrivacyReceipt>;
    /**
     * Store a receipt in local storage
     */
    storeReceipt(receipt: PrivacyReceipt): Promise<void>;
    /**
     * Verify the integrity of a receipt
     */
    verifyReceipt(receipt: PrivacyReceipt): Promise<boolean>;
    /**
     * Get all receipts with optional filtering
     */
    getReceipts(options?: {
        limit?: number;
        site?: string;
        dateFrom?: Date;
        dateTo?: Date;
        privacyLevel?: string;
    }): Promise<PrivacyReceipt[]>;
    /**
     * Get receipt statistics
     */
    getReceiptStats(): Promise<{
        totalReceipts: number;
        receiptsBySite: {
            [site: string]: number;
        };
        receiptsByPrivacyLevel: {
            [level: string]: number;
        };
        averageAnonymityScore: number;
        totalPIIRemoved: number;
        recentActivity: Array<{
            date: string;
            count: number;
        }>;
    }>;
    /**
     * Export receipts in various formats
     */
    exportReceipts(format?: 'json' | 'csv' | 'pdf'): Promise<string | Blob>;
    /**
     * Export receipts as JSON
     */
    private exportAsJSON;
    /**
     * Export receipts as CSV
     */
    private exportAsCSV;
    /**
     * Export receipts as PDF (simplified version)
     */
    private exportAsPDF;
    /**
     * Verify all receipts and return validation results
     */
    verifyAllReceipts(): Promise<{
        totalReceipts: number;
        validReceipts: number;
        invalidReceipts: number;
        verificationResults: Array<{
            receiptId: string;
            isValid: boolean;
            error?: string;
        }>;
    }>;
    /**
     * Clean up old receipts based on retention policy
     */
    cleanupOldReceipts(retentionDays: number): Promise<number>;
    /**
     * Generate a receipt verification report
     */
    generateVerificationReport(): Promise<{
        reportId: string;
        generatedAt: string;
        summary: {
            totalReceipts: number;
            validReceipts: number;
            invalidReceipts: number;
            verificationRate: number;
        };
        details: Array<{
            receiptId: string;
            timestamp: string;
            site: string;
            isValid: boolean;
            anonymityScore?: number;
            piiRemoved?: number;
        }>;
    }>;
}
