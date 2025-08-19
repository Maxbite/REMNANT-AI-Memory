/**
 * GhostLink Privacy Shield - Input Interceptor
 * Intercepts user input to AI services and applies privacy protection
 */
import { AIServiceConfig } from '../utils/types';
interface InterceptorCallbacks {
    onQueryIntercept: (query: string, inputElement: HTMLElement) => Promise<string>;
    onQueryProcessed: (originalQuery: string, processedQuery: string) => void;
}
export declare class InputInterceptor {
    private isActive;
    private currentService;
    private callbacks;
    private interceptedElements;
    private originalSubmitHandlers;
    private debounceTimers;
    /**
     * Set up input interception for a specific AI service
     */
    setup(service: AIServiceConfig, callbacks: InterceptorCallbacks): void;
    /**
     * Disable input interception
     */
    disable(): void;
    /**
     * Clean up all event listeners and intercepted elements
     */
    private cleanup;
    /**
     * Set up interception for input fields
     */
    private setupInputFieldInterception;
    /**
     * Set up interception for submit buttons
     */
    private setupSubmitButtonInterception;
    /**
     * Set up keyboard interception (Enter key, shortcuts)
     */
    private setupKeyboardInterception;
    /**
     * Find input fields for the current service
     */
    private findInputFields;
    /**
     * Find submit buttons for the current service
     */
    private findSubmitButtons;
    /**
     * Create submit handler for a button
     */
    private createSubmitHandler;
    /**
     * Handle keyboard events
     */
    private handleKeyDown;
    /**
     * Handle global keyboard events
     */
    private handleGlobalKeyDown;
    /**
     * Handle Enter key submission
     */
    private handleEnterKeySubmit;
    /**
     * Handle paste events
     */
    private handlePaste;
    /**
     * Extract text content from an element
     */
    private extractTextFromElement;
    /**
     * Update input field with processed text
     */
    private updateInputField;
    /**
     * Find the input field associated with a submit button
     */
    private findAssociatedInputField;
    /**
     * Trigger original submit behavior
     */
    private triggerOriginalSubmit;
    /**
     * Trigger Enter key submit
     */
    private triggerEnterKeySubmit;
    /**
     * Check if Enter key should be intercepted for this element
     */
    private shouldInterceptEnterKey;
    /**
     * Validate input field
     */
    private isValidInputField;
    /**
     * Validate submit button
     */
    private isValidSubmitButton;
}
export {};
