/**
 * GhostLink Privacy Shield - Advanced PII Detector
 * Enhanced PII detection using machine learning and contextual analysis
 */
import { PIIDetectionResult } from '../utils/types';
export declare class AdvancedPIIDetector {
    private contextualPatterns;
    private entityRelationships;
    private confidenceThresholds;
    constructor();
    private initializeAdvancedPatterns;
    /**
     * Advanced PII detection with contextual analysis
     */
    detectAdvancedPII(text: string): Promise<PIIDetectionResult[]>;
    /**
     * Analyze text context to determine what types of PII might be present
     */
    private analyzeContext;
    /**
     * Detect PII within a specific context
     */
    private detectInContext;
    /**
     * Simplified Named Entity Recognition
     */
    private performNER;
    /**
     * Analyze relationships between detected entities
     */
    private analyzeRelationships;
    /**
     * Find relationships between two entities
     */
    private findRelationship;
    /**
     * Determine PII type based on context and pattern
     */
    private determinePIIType;
    /**
     * Calculate confidence based on context
     */
    private calculateContextualConfidence;
    /**
     * Check if context is relevant for PII type
     */
    private isRelevantContext;
    /**
     * Validate format for specific PII types
     */
    private validateFormat;
    /**
     * Get surrounding text for context analysis
     */
    private getSurroundingText;
    /**
     * Check if surrounding text is relevant for PII type
     */
    private hasRelevantSurroundingText;
    /**
     * Check if text is likely a person name
     */
    private isLikelyPersonName;
    /**
     * Remove duplicates and filter by confidence
     */
    private deduplicateAndFilter;
}
