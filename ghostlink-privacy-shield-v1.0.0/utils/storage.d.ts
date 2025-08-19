/**
 * GhostLink Privacy Shield - Storage Manager
 * Handles all browser storage operations with encryption
 */
import { PrivacyConfig, PrivacyReceipt, PrivacyStats, UserPreferences } from './types';
export declare class StorageManager {
    private readonly STORAGE_KEYS;
    /**
     * Get privacy configuration
     */
    getPrivacyConfig(): Promise<PrivacyConfig | null>;
    /**
     * Set privacy configuration
     */
    setPrivacyConfig(config: PrivacyConfig): Promise<void>;
    /**
     * Store a privacy receipt
     */
    storeReceipt(receipt: PrivacyReceipt): Promise<void>;
    /**
     * Get privacy receipts
     */
    getReceipts(limit?: number): Promise<PrivacyReceipt[]>;
    /**
     * Clear all receipts
     */
    clearReceipts(): Promise<void>;
    /**
     * Get user preferences
     */
    getUserPreferences(): Promise<UserPreferences | null>;
    /**
     * Set user preferences
     */
    setUserPreferences(preferences: UserPreferences): Promise<void>;
    /**
     * Get privacy statistics
     */
    getPrivacyStats(): Promise<PrivacyStats | null>;
    /**
     * Update privacy statistics
     */
    updatePrivacyStats(stats: Partial<PrivacyStats>): Promise<void>;
    /**
     * Export all data for backup/portability
     */
    exportData(): Promise<any>;
    /**
     * Import data from backup
     */
    importData(data: any): Promise<void>;
    /**
     * Clear all extension data
     */
    clearAllData(): Promise<void>;
}
