public with sharing class ItemService {
    public ItemService() {

    }
        @AuraEnabled(cacheable=true)
    public static List<Item__c> getItems(String family, String type, String searchTerm) {
        String query = 'SELECT Id, Name, Description__c, Family__c, Type__c, Price__c, Quantity_In_Stock__c, Image_URL__c FROM Item__c WHERE Quantity_In_Stock__c > 0';
        if (String.isNotBlank(family)) {
            query += ' AND Family__c = :family';
        }
        if (String.isNotBlank(type)) {
            query += ' AND Type__c = :type';
        }
        if (String.isNotBlank(searchTerm)) {
            String likeTerm = '%' + searchTerm + '%';
            query += ' AND (Name LIKE :likeTerm OR Description__c LIKE :likeTerm)';
        }
        query += ' ORDER BY Name';
        return Database.query(query);
    }
}