public with sharing class ItemService {
    public ItemService() {

    }
@AuraEnabled
public static List<Item__c> getItems(String family, String type, String searchTerm) {
    String query = 'SELECT Id, Name, Description__c, Family__c, Type__c, Price__c, Image__c, AvailableQuantity__c FROM Item__c';
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
@AuraEnabled
public static Id checkout(Id accountId, List<Map<String, Object>> cartItems) {
    Set<Id> itemIds = new Set<Id>();
    Map<Id, Integer> requestedQty = new Map<Id, Integer>();
    Map<Id, Decimal> unitCostMap = new Map<Id, Decimal>();

    for (Map<String, Object> ci : cartItems) {
        Id itemId = (Id) ci.get('itemId');
        Integer quantity = ((Decimal) ci.get('quantity')).intValue();
        Decimal unitCost = (Decimal) ci.get('unitCost');

        itemIds.add(itemId);
        requestedQty.put(itemId, quantity);
        unitCostMap.put(itemId, unitCost);
    }

    // Lock and fetch items
    List<Item__c> items = [SELECT Id, Name, AvailableQuantity__c, Price__c FROM Item__c WHERE Id IN :itemIds FOR UPDATE];

    // Validate stock
    for (Item__c item : items) {
        Integer reqQty = requestedQty.get(item.Id);
        if (reqQty == null || item.AvailableQuantity__c < reqQty) {
            throw new AuraHandledException('Insufficient stock for ' + item.Name);
        }
    }

    // Create Purchase
    Purchase__c purchase = new Purchase__c(
        ClientId__c = accountId,
        Name = 'Purchase ' + DateTime.now().format()
    );
    insert purchase;

    // Create PurchaseLines and update inventory
    List<PurchaseLine__c> lines = new List<PurchaseLine__c>();
    for (Map<String, Object> ci : cartItems) {
        Id itemId = (Id) ci.get('itemId');
        Integer quantity = ((Decimal) ci.get('quantity')).intValue();
        Decimal unitCost = (Decimal) ci.get('unitCost');

        lines.add(new PurchaseLine__c(
            PurchaseId__c = purchase.Id,
            ItemId__c = itemId,          // verify your field name (Item__c or ItemId__c)
            Amount__c = quantity,
            UnitCost__c = unitCost
        ));

        // Decrement inventory
        for (Item__c it : items) {
            if (it.Id == itemId) {
                it.AvailableQuantity__c -= quantity;
                break;
            }
        }
    }
    insert lines;
    update items;

    return purchase.Id;
}
    }