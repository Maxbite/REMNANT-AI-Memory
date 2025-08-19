/**
 * GhostLink Privacy Shield - AI Service Detector
 * Detects and configures integration with various AI services
 */
import { AIServiceConfig } from '../utils/types';
export declare class AIServiceDetector {
    private services;
    constructor();
    /**
     * Detect the current AI service based on URL and DOM
     */
    detectService(): AIServiceConfig | null;
    /**
     * Find the main input field for a service
     */
    findInputField(service: AIServiceConfig): HTMLElement | null;
    /**
     * Find the submit button for a service
     */
    findSubmitButton(service: AIServiceConfig): HTMLElement | null;
    /**
     * Find all input fields that might be relevant
     */
    findAllInputFields(service: AIServiceConfig): HTMLElement[];
    /**
     * Check if an element is a valid input field
     */
    private isValidInputField;
    /**
     * Check if an element is a valid submit button
     */
    private isValidSubmitButton;
    /**
     * Get service configuration by name
     */
    getServiceByName(name: string): AIServiceConfig | null;
    /**
     * Get all supported services
     */
    getAllServices(): AIServiceConfig[];
    /**
     * Add or update a service configuration
     */
    addService(service: AIServiceConfig): void;
    /**
     * Check if current page is a supported AI service
     */
    isAIService(): boolean;
    /**
     * Get service-specific configuration for input monitoring
     */
    getInputMonitoringConfig(service: AIServiceConfig): any;
    /**
     * Wait for service to be ready (useful for SPAs)
     */
    waitForService(maxWaitMs?: number): Promise<AIServiceConfig | null>;
}
