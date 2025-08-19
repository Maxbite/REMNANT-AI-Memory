/**
 * GhostLink Privacy Shield - PII Detection Engine
 * Advanced detection of personally identifiable information
 */
import { PIIDetectionResult } from '../utils/types';
export declare class PIIDetector {
    private patterns;
    private contextualPatterns;
    constructor();
    private initializePatterns;
    /**
     * Detect PII in the given text
     */
    detectPII(text: string): PIIDetectionResult[];
    /**
     * Calculate confidence score for a PII match
     */
    private calculateConfidence;
    /**
     * Get surrounding text for context analysis
     */
    private getSurroundingText;
    /**
     * Validate email format
     */
    private isValidEmail;
    /**
     * Validate phone number format
     */
    private isValidPhoneNumber;
    /**
     * Check if text is likely a real name
     */
    private isLikelyName;
    /**
     * Validate SSN format and checksum
     */
    private isValidSSN;
    /**
     * Validate credit card using Luhn algorithm
     */
    private isValidCreditCard;
    /**
     * Get PII statistics for a text
     */
    getPIIStats(text: string): {
        [key: string]: number;
    };
    /**
     * Check if text contains sensitive information
     */
    containsSensitiveInfo(text: string): boolean;
}
