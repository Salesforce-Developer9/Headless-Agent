public with sharing class BookController {
    
    @AuraEnabled(cacheable=true)
    public static List<Book__c> getBooks(String searchTerm) {
        try {
            String searchPattern = '';
            if (String.isNotBlank(searchTerm)) {
                searchPattern = '%' + searchTerm + '%';
                return [
                    SELECT Id, Name, Genre__c, Language__c, Price__c
                    FROM Book__c 
                    WHERE Name LIKE :searchPattern
                    ORDER BY Name ASC
                    LIMIT 50
                ];
            } else {
                return [
                    SELECT Id, Name, Genre__c, Language__c, Price__c
                    FROM Book__c 
                    ORDER BY Name ASC
                    LIMIT 50
                ];
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving books: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Book__c> getAllBooks() {
        try {
            return [
                SELECT Id, Name, Genre__c, Language__c, Price__c
                FROM Book__c 
                ORDER BY Name ASC
                LIMIT 50
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving books: ' + e.getMessage());
        }
    }
}