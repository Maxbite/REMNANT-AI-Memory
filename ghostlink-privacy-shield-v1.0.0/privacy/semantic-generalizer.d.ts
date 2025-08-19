/**
 * GhostLink Privacy Shield - Semantic Generalization Engine
 * Generalizes specific terms and concepts while preserving meaning
 */
export declare class SemanticGeneralizer {
    private generalizations;
    private contextPatterns;
    constructor();
    private initializeGeneralizations;
    /**
     * Generalize text based on privacy level
     */
    generalize(text: string, privacyLevel: string): Promise<{
        text: string;
        changesCount: number;
    }>;
    /**
     * Determine if a term should be generalized based on context
     */
    private shouldGeneralize;
    /**
     * Apply additional semantic transformations
     */
    private applyAdditionalTransformations;
    /**
     * Generalize specific numbers that could be identifying
     */
    private generalizeNumbers;
    /**
     * Generalize temporal references
     */
    private generalizeTemporalReferences;
    /**
     * Generalize relationship terms
     */
    private generalizeRelationships;
    /**
     * Escape special regex characters
     */
    private escapeRegex;
    /**
     * Get available privacy levels
     */
    getAvailablePrivacyLevels(): string[];
    /**
     * Preview generalizations for a given text and privacy level
     */
    previewGeneralizations(text: string, privacyLevel: string): Array<{
        original: string;
        generalized: string;
    }>;
}
