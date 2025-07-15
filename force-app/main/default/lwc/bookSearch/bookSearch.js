import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getBooks from '@salesforce/apex/BookController.getBooks';
import getAllBooks from '@salesforce/apex/BookController.getAllBooks';
import getSessionInfo from '@salesforce/apex/HeadlessAgentService.getSessionInfo';
import invokeAgent from '@salesforce/apex/HeadlessAgentService.invokeAgent';

export default class BookSearch extends LightningElement {
    @track books = [];
    @track searchTerm = '';
    @track isLoading = false;
    @track favoriteBooks = new Set();
    @track sessionInfo = null;
    @track showRecommendations = false;
    @track recommendations = '';
    @track selectedBookName = '';

    // Wire method to get all books on component load
    @wire(getAllBooks)
    wiredBooks({ error, data }) {
        if (data) {
            this.books = data.map(book => ({
                ...book,
                isFavorite: false,
                priceFormatted: this.formatPrice(book.Price__c)
            }));
        } else if (error) {
            this.showToast('Error', 'Failed to load books', 'error');
        }
    }

    // Initialize session info on component load
    async connectedCallback() {
        try {
            this.sessionInfo = await getSessionInfo();
            console.log('Session Info initialized:', JSON.stringify(this.sessionInfo));
        } catch (error) {
            console.error('Error initializing session:', error);
            this.showToast('Error', 'Failed to initialize recommendation service', 'error');
        }
    }

    // Handle search input change
    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        // Debounce search to avoid too many server calls
        clearTimeout(this.delayTimeout);
        this.delayTimeout = setTimeout(() => {
            this.performSearch();
        }, 300);
    }

    // Perform the search operation
    async performSearch() {
        this.isLoading = true;
        try {
            const result = await getBooks({ searchTerm: this.searchTerm });
            this.books = result.map(book => ({
                ...book,
                isFavorite: this.favoriteBooks.has(book.Id),
                priceFormatted: this.formatPrice(book.Price__c)
            }));
        } catch (error) {
            this.showToast('Error', 'Failed to search books', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Handle favorite toggle
    async handleFavoriteToggle(event) {
        const bookId = event.currentTarget.dataset.bookId;
        const book = this.books.find(b => b.Id === bookId);
        
        if (book) {
            book.isFavorite = !book.isFavorite;
            
            // Update the button icon and variant
            const button = event.currentTarget;
            if (book.isFavorite) {
                button.iconName = 'utility:favorite';
                button.variant = 'brand';
                this.favoriteBooks.add(bookId);
                this.showToast('Success', `${book.Name} added to favorites`, 'success');
                
                // Get recommendations for favorited book
                await this.getRecommendations(book);
            } else {
                button.iconName = 'utility:favorite_alt';
                button.variant = 'border-filled';
                this.favoriteBooks.delete(bookId);
                this.showToast('Success', `${book.Name} removed from favorites`, 'success');
            }
        }
    }

    // Get recommendations for a favorited book
    async getRecommendations(book) {
        if (!this.sessionInfo) {
            this.showToast('Error', 'Recommendation service not initialized', 'error');
            return;
        }

        try {
            // Prepare the message for the agent
            const message = `Find Recommended Books similar to ${book.Name}, language ${book.Language__c} and Genre ${book.Genre__c}`;
            
            this.selectedBookName = book.Name;
            this.isLoading = true;
            
            // Call the agent service
            const recommendations = await invokeAgent({
                accessToken: this.sessionInfo.accessToken,
                sessionId: this.sessionInfo.sessionId,
                Message: message
            });
            
            this.recommendations = recommendations || 'No recommendations available at this time.';
            this.showRecommendations = true;
            
        } catch (error) {
            console.error('Error getting recommendations:', error);
            this.showToast('Error', 'Failed to get book recommendations', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Format price for display
    formatPrice(price) {
        if (price) {
            return `$${price.toFixed(2)}`;
        }
        return '$0.00';
    }

    // Show toast message
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    // Handle clear search
    handleClearSearch() {
        this.searchTerm = '';
        this.template.querySelector('lightning-input').value = '';
        this.performSearch();
    }

    // Getter for search placeholder
    get searchPlaceholder() {
        return 'Search books by name...';
    }

    // Handle close recommendations modal
    handleCloseRecommendations() {
        this.showRecommendations = false;
        this.recommendations = '';
        this.selectedBookName = '';
    }

    // Getter to check if books exist
    get hasBooks() {
        return this.books && this.books.length > 0;
    }

    // Getter to check if recommendations exist
    get hasRecommendations() {
        return this.recommendations && this.recommendations.trim().length > 0;
    }
} 