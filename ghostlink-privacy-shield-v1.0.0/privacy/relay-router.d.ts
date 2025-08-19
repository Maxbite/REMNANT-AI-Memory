/**
 * GhostLink Privacy Shield - Relay Router
 * Routes queries through privacy-preserving relays for enhanced anonymity
 */
import { RelayConfig } from '../utils/types';
export declare class RelayRouter {
    private relayEndpoints;
    private currentRelayIndex;
    private failedRelays;
    constructor();
    /**
     * Route a query through a privacy relay
     */
    routeQuery(processedQuery: string, targetSite: string, config: RelayConfig): Promise<{
        success: boolean;
        response?: any;
        error?: string;
    }>;
    /**
     * Select the best available relay
     */
    private selectRelay;
    /**
     * Send query through a specific relay
     */
    private sendThroughRelay;
    /**
     * Generate a random user agent for additional anonymity
     */
    private generateRandomUserAgent;
    /**
     * Test relay connectivity
     */
    testRelayConnectivity(): Promise<{
        [relay: string]: boolean;
    }>;
    /**
     * Get relay statistics
     */
    getRelayStats(): {
        totalRelays: number;
        availableRelays: number;
        failedRelays: number;
        currentRelay: string | null;
    };
    /**
     * Add a custom relay endpoint
     */
    addRelay(endpoint: string): void;
    /**
     * Remove a relay endpoint
     */
    removeRelay(endpoint: string): void;
    /**
     * Reset failed relays
     */
    resetFailedRelays(): void;
    /**
     * Check if relay routing is recommended for a query
     */
    isRelayRecommended(query: string, anonymityScore: number): boolean;
    /**
     * Estimate relay routing overhead
     */
    estimateRoutingOverhead(): {
        latencyMs: number;
        bandwidthOverhead: number;
        privacyGain: number;
    };
}
