/**
 * GhostLink Privacy Shield - Privacy Analytics
 * Advanced analytics and insights for privacy protection
 */
export interface PrivacyInsight {
    id: string;
    type: 'warning' | 'info' | 'success' | 'recommendation';
    title: string;
    description: string;
    actionable: boolean;
    action?: string;
    priority: 'low' | 'medium' | 'high';
    timestamp: number;
}
export interface PrivacyTrend {
    metric: string;
    values: Array<{
        date: string;
        value: number;
    }>;
    trend: 'increasing' | 'decreasing' | 'stable';
    changePercent: number;
}
export interface PrivacyRiskAssessment {
    overallRisk: 'low' | 'medium' | 'high';
    riskScore: number;
    factors: Array<{
        factor: string;
        impact: 'low' | 'medium' | 'high';
        description: string;
    }>;
    recommendations: string[];
}
export declare class PrivacyAnalytics {
    private storageManager;
    constructor();
    /**
     * Generate comprehensive privacy insights
     */
    generateInsights(): Promise<PrivacyInsight[]>;
    /**
     * Analyze recent privacy activity
     */
    private analyzeRecentActivity;
    /**
     * Analyze PII detection patterns
     */
    private analyzePIIPatterns;
    /**
     * Analyze privacy effectiveness
     */
    private analyzePrivacyEffectiveness;
    /**
     * Analyze site-specific patterns
     */
    private analyzeSitePatterns;
    /**
     * Analyze configuration effectiveness
     */
    private analyzeConfiguration;
    /**
     * Generate privacy trends
     */
    generateTrends(days?: number): Promise<PrivacyTrend[]>;
    /**
     * Assess privacy risk
     */
    assessPrivacyRisk(): Promise<PrivacyRiskAssessment>;
    /**
     * Calculate variance of an array of numbers
     */
    private calculateVariance;
    /**
     * Calculate trend direction
     */
    private calculateTrend;
    /**
     * Calculate percentage change
     */
    private calculateChangePercent;
}
