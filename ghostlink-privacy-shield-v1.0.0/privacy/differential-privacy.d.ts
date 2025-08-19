/**
 * GhostLink Privacy Shield - Differential Privacy Engine
 * Adds calibrated noise to protect against statistical inference attacks
 */
export declare class DifferentialPrivacy {
    private readonly DEFAULT_EPSILON;
    private readonly MIN_EPSILON;
    private readonly MAX_EPSILON;
    /**
     * Add differential privacy noise to text
     */
    addNoise(text: string, epsilon?: number): Promise<{
        text: string;
        noiseAdded: boolean;
    }>;
    /**
     * Add noise to numeric values using Laplace mechanism
     */
    private addNumericNoise;
    /**
     * Add noise to temporal references
     */
    private addTemporalNoise;
    /**
     * Add noise to categorical data through randomized response
     */
    private addCategoricalNoise;
    /**
     * Generate Laplace noise for differential privacy
     */
    private generateLaplaceNoise;
    /**
     * Round values appropriately based on context
     */
    private roundBasedOnContext;
    /**
     * Escape special regex characters
     */
    private escapeRegex;
    /**
     * Calculate privacy budget consumption
     */
    calculatePrivacyBudget(queries: number, epsilon: number): number;
    /**
     * Recommend epsilon value based on sensitivity level
     */
    recommendEpsilon(sensitivityLevel: 'low' | 'medium' | 'high'): number;
    /**
     * Validate epsilon parameter
     */
    validateEpsilon(epsilon: number): boolean;
    /**
     * Get privacy guarantee explanation
     */
    getPrivacyGuarantee(epsilon: number): string;
    /**
     * Estimate utility loss from noise addition
     */
    estimateUtilityLoss(epsilon: number): number;
}
