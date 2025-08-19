/**
 * GhostLink Privacy Shield - Type Definitions
 */
export interface RelayConfig {
    enabled: boolean;
    apiKey?: string;
    timeoutMs?: number;
}
export interface PrivacyConfig {
    enabled: boolean;
    privacyLevel: 'minimal' | 'balanced' | 'maximum';
    enablePIIDetection: boolean;
    enableDifferentialPrivacy: boolean;
    enableSemanticGeneralization: boolean;
    enableCryptoReceipts: boolean;
    enableRelayRouting: boolean;
    supportedSites: string[];
    customRules: PrivacyRule[];
    noiseLevel: number;
    retentionDays: number;
}
export interface PrivacyRule {
    id: string;
    name: string;
    pattern: string;
    replacement: string;
    enabled: boolean;
    type: 'regex' | 'keyword' | 'semantic';
}
export interface PrivacyReceipt {
    id: string;
    timestamp: number;
    originalHash: string;
    processedHash: string;
    site: string;
    piiRemoved?: number;
    noiseAdded?: boolean;
    anonymityScore?: number;
    privacyLevel: string;
    signature?: string;
}
export interface ExtensionMessage {
    type: string;
    data?: any;
    tabId?: number;
}
export type PIIType = 'name' | 'email' | 'phone' | 'address' | 'ssn' | 'credit_card' | 'national_id' | 'date_of_birth' | 'ip_address' | 'custom';
export interface PIIDetectionResult {
    type: PIIType;
    value: string;
    start: number;
    end: number;
    confidence: number;
}
export interface PrivacyProcessingResult {
    processedQuery: string;
    originalQuery: string;
    piiDetected: PIIDetectionResult[];
    piiRemoved: number;
    noiseAdded: boolean;
    semanticChanges: number;
    anonymityScore: number;
    processingTime: number;
}
export interface PrivacyStats {
    totalQueries: number;
    totalPIIRemoved: number;
    avgAnonymityScore: number;
    lastQuery: number | null;
    queriesByDay: {
        [date: string]: number;
    };
    piiByType: {
        [type: string]: number;
    };
}
export interface AIServiceConfig {
    name: string;
    domain: string;
    selectors: {
        inputField: string;
        submitButton: string;
        chatContainer?: string;
    };
    enabled: boolean;
}
export interface RelayConfig {
    enabled: boolean;
    endpoint: string;
    apiKey?: string;
    timeout: number;
    retries: number;
}
export interface UserPreferences {
    theme: 'light' | 'dark' | 'auto';
    notifications: boolean;
    autoUpdate: boolean;
    telemetry: boolean;
    language: string;
}
