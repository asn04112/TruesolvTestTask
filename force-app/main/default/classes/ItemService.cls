public with sharing class ItemService {
    public ItemService() {

    }
@AuraEnabled
public static List<Item__c> getItems(String family, String type, String searchTerm) {
    String query = 'SELECT Id, Name, Description__c, Family__c, Type__c, Price__c, Image__c FROM Item__c';
    List<String> conditions = new List<String>();
    
    if (String.isNotBlank(family)) {
        conditions.add('Family__c = :family');
    }
    if (String.isNotBlank(type)) {
        conditions.add('Type__c = :type');
    }
    if (String.isNotBlank(searchTerm)) {
        String likeTerm = '%' + searchTerm + '%';
        conditions.add('(Name LIKE :likeTerm OR Description__c LIKE :likeTerm)');
    }
    
    if (!conditions.isEmpty()) {
        query += ' WHERE ' + String.join(conditions, ' AND ');
    }
    query += ' ORDER BY Name';
    return Database.query(query);
}

@AuraEnabled
    public static Id createItem(String name, String description, String type, String family, Decimal price, Decimal availableQty) {
        String imageUrl = UnsplashService.getImageUrl(name);
        
        Item__c newItem = new Item__c(
            Name = name,
            Description__c = description,
            Type__c = type,
            Family__c = family,
            Image__c = imageUrl,
            Price__c = price,
            AvailableQuantity__c = availableQty
        );
        insert newItem;
        return newItem.Id;
    }
    }