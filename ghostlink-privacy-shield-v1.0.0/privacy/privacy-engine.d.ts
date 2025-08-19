/**
 * GhostLink Privacy Shield - Privacy Processing Engine
 * Main engine for anonymizing and protecting user queries
 */
import { PrivacyConfig, PrivacyProcessingResult } from '../utils/types';
export declare class PrivacyEngine {
    private piiDetector;
    private semanticGeneralizer;
    private differentialPrivacy;
    private receiptManager;
    private cryptoUtils;
    constructor();
    /**
     * Process a query through the privacy pipeline
     */
    processQuery(originalQuery: string, config: PrivacyConfig, site: string): Promise<PrivacyProcessingResult>;
    /**
     * Remove PII from text based on detection results
     */
    private removePII;
    /**
     * Generate appropriate replacement for detected PII
     */
    private generateReplacement;
    /**
     * Generate name replacement based on privacy level
     */
    private generateNameReplacement;
    /**
     * Generate email replacement based on privacy level
     */
    private generateEmailReplacement;
    /**
     * Generate phone replacement based on privacy level
     */
    private generatePhoneReplacement;
    /**
     * Generate address replacement based on privacy level
     */
    private generateAddressReplacement;
    /**
     * Generate date replacement with differential privacy
     */
    private generateDateReplacement;
    /**
     * Calculate overall anonymity score
     */
    private calculateAnonymityScore;
    /**
     * Calculate text similarity using simple character-based comparison
     */
    private calculateTextSimilarity;
    /**
     * Calculate Levenshtein distance between two strings
     */
    private levenshteinDistance;
    /**
     * Validate privacy configuration
     */
    validateConfig(config: PrivacyConfig): boolean;
    /**
     * Get privacy recommendations based on query content
     */
    getPrivacyRecommendations(query: string): string[];
}
