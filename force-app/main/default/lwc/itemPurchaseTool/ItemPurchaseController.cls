public with sharing class ItemPurchaseController {

    @AuraEnabled
    public static Account getAccountInfo(Id accountId) {
        return [SELECT Id, Name, AccountNumber, Industry FROM Account WHERE Id = :accountId LIMIT 1];
    }

    @AuraEnabled
    public static List<Item__c> getItems(String family, String type, String searchKey) {
        String query = 'SELECT Id, Name, Description__c, Type__c, Family__c, Image__c, Price__c, AvailableQuantity__c FROM Item__c WHERE AvailableQuantity__c > 0';
        if (!String.isEmpty(family)) {
            query += ' AND Family__c = :family';
        }
        if (!String.isEmpty(type)) {
            query += ' AND Type__c = :type';
        }
        if (!String.isEmpty(searchKey)) {
            String likeStr = '%' + searchKey + '%';
            query += ' AND (Name LIKE :likeStr OR Description__c LIKE :likeStr)';
        }
        query += ' ORDER BY Name';
        return Database.query(query);
    }

    @AuraEnabled
    public static Id checkout(Id accountId, List<Map<String, Object>> cartItems) {
        // cartItems: [{itemId, quantity, unitCost}, ...]
        // Validate stock first
        Set<Id> itemIds = new Set<Id>();
        Map<Id, Decimal> requestedQty = new Map<Id, Decimal>();
        for (Map<String, Object> ci : cartItems) {
            Id itemId = (Id)ci.get('itemId');
            Decimal qty = (Decimal)ci.get('quantity');
            itemIds.add(itemId);
            requestedQty.put(itemId, (requestedQty.containsKey(itemId) ? requestedQty.get(itemId) + qty : qty));
        }

        List<Item__c> items = [SELECT Id, AvailableQuantity__c FROM Item__c WHERE Id IN :itemIds];
        for (Item__c it : items) {
            if (it.AvailableQuantity__c < requestedQty.get(it.Id)) {
                throw new AuraHandledException('Insufficient stock for ' + it.Id);
            }
        }

        Purchase__c p = new Purchase__c(
            ClientId__c = accountId,
            Name = 'Purchase ' + DateTime.now().format() // or auto‑number
        );
        insert p;

        List<PurchaseLine__c> lines = new List<PurchaseLine__c>();
        for (Map<String, Object> ci : cartItems) {
            Id itemId = (Id)ci.get('itemId');
            Decimal qty = (Decimal)ci.get('quantity');
            Decimal unitCost = (Decimal)ci.get('unitCost');
            lines.add(new PurchaseLine__c(
                PurchaseId__c = p.Id,
                ItemId__c = itemId,
                Amount__c = qty,
                UnitCost__c = unitCost
            ));
            Item__c it = [SELECT AvailableQuantity__c FROM Item__c WHERE Id = :itemId];
            it.AvailableQuantity__c -= qty;
            update it;
        }
        insert lines;

        return p.Id;
    }

    public static Map<String, List<String>> getPicklistValues() {
        Map<String, List<String>> result = new Map<String, List<String>>();
        result.put('Family', getPicklistOptions('Item__c', 'Family__c'));
        result.put('Type', getPicklistOptions('Item__c', 'Type__c'));
        return result;
    }

    private static List<String> getPicklistOptions(String objName, String fieldName) {
        List<String> options = new List<String>();
        Schema.DescribeFieldResult field = Schema.getGlobalDescribe().get(objName).getDescribe().fields.getMap().get(fieldName).getDescribe();
        for (Schema.PicklistEntry e : field.getPicklistValues()) {
            if (e.isActive()) options.add(e.getValue());
        }
        return options;
    }
}