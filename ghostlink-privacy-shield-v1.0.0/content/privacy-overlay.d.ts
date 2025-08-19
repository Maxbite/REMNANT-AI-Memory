/**
 * GhostLink Privacy Shield - Privacy Overlay
 * In-page UI overlay for privacy controls and feedback
 */
interface OverlayCallbacks {
    onTogglePrivacy: () => void;
    onShowStats: () => void;
}
export declare class PrivacyOverlay {
    private overlay;
    private callbacks;
    private isVisible;
    private stats;
    /**
     * Set up the privacy overlay
     */
    setup(callbacks: OverlayCallbacks): void;
    /**
     * Create the overlay DOM structure
     */
    private createOverlay;
    /**
     * Get the HTML structure for the overlay
     */
    private getOverlayHTML;
    /**
     * Add CSS styles for the overlay
     */
    private addOverlayStyles;
    /**
     * Attach event listeners to overlay elements
     */
    private attachEventListeners;
    /**
     * Toggle panel visibility
     */
    private togglePanel;
    /**
     * Show the panel
     */
    private showPanel;
    /**
     * Hide the panel
     */
    private hidePanel;
    /**
     * Show the overlay
     */
    showOverlay(): void;
    /**
     * Hide the overlay
     */
    hideOverlay(): void;
    /**
     * Update privacy stats display
     */
    updateStats(stats: {
        piiRemoved: number;
        anonymityScore: number;
        noiseAdded: boolean;
    }): void;
    /**
     * Update privacy status
     */
    updatePrivacyStatus(enabled: boolean): void;
    /**
     * Show processing indicator
     */
    showProcessingIndicator(): void;
    /**
     * Hide processing indicator
     */
    hideProcessingIndicator(): void;
    /**
     * Show notification
     */
    showNotification(message: string, type?: 'success' | 'warning' | 'error'): void;
    /**
     * Show stats modal (placeholder for now)
     */
    showStatsModal(stats: any): void;
    /**
     * Remove overlay from DOM
     */
    private removeOverlay;
    /**
     * Destroy the overlay
     */
    destroy(): void;
}
export {};
