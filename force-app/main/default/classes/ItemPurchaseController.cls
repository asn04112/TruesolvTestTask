public with sharing class ItemPurchaseController {

    @AuraEnabled
    public static Account getAccountInfo(Id accountId) {
        return [SELECT Id, Name, AccountNumber, Industry FROM Account WHERE Id = :accountId LIMIT 1];
    }
    public ItemPurchaseController() {
        
    }
}