/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
private class ItemPusrchaseControllerTestSuite {

    @TestSetup
    static void setup() {
        Account acct = new Account(Name = 'Test Account');
        insert acct;

        Item__c item1 = new Item__c(
            Name = 'Widget A', Description__c = 'A widget', Type__c = 'Widget',
            Family__c = 'Hardware', Price__c = 10, AvailableQuantity__c = 100, Image__c = 'img1'
        );
        Item__c item2 = new Item__c(
            Name = 'Widget B', Description__c = 'Another widget', Type__c = 'Widget',
            Family__c = 'Hardware', Price__c = 20, AvailableQuantity__c = 50
        );
        Item__c item3 = new Item__c(
            Name = 'Gadget X', Description__c = 'Cool gadget', Type__c = 'Gadget',
            Family__c = 'Electronics', Price__c = 30, AvailableQuantity__c = 10
        );
        // Zero quantity – should not appear in getItems
        Item__c item4 = new Item__c(
            Name = 'Gadget Y', Description__c = 'Popular gadget', Type__c = 'Gadget',
            Family__c = 'Electronics', Price__c = 40, AvailableQuantity__c = 0
        );
        Item__c item5 = new Item__c(
            Name = 'Part Z', Description__c = 'Spare part', Type__c = 'Part',
            Family__c = 'Hardware', Price__c = 5, AvailableQuantity__c = 200
        );
        insert new List<Item__c>{ item1, item2, item3, item4, item5 };
    }

    @isTest
    static void testGetAccountInfo() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];

        Test.startTest();
        Account result = ItemPurchaseController.getAccountInfo(acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Account should be returned');
        System.assertEquals('Test Account', result.Name);
        System.assertEquals(acc.Id, result.Id);
    }

    @isTest
    static void testGetItemsNoFilters() {
        Test.startTest();
        List<Item__c> items = ItemPurchaseController.getItems(null, null, null);
        Test.stopTest();

        // Excludes Gadget Y (quantity 0) → 4 items
        System.assertEquals(4, items.size());
        Set<String> names = new Set<String>();
        for (Item__c it : items) {
            names.add(it.Name);
        }
        System.assert(names.contains('Widget A'));
        System.assert(names.contains('Widget B'));
        System.assert(names.contains('Gadget X'));
        System.assert(names.contains('Part Z'));
        System.assert(!names.contains('Gadget Y'));
    }

    @isTest
    static void testGetItemsEmptyStringsAsFilters() {
        Test.startTest();
        List<Item__c> items = ItemPurchaseController.getItems('', '', '');
        Test.stopTest();

        System.assertEquals(4, items.size());
    }

    @isTest
    static void testGetItemsFilterFamily() {
        Test.startTest();
        List<Item__c> items = ItemPurchaseController.getItems('Hardware', null, null);
        Test.stopTest();

        System.assertEquals(3, items.size());
        for (Item__c it : items) {
            System.assertEquals('Hardware', it.Family__c);
        }
    }

    @isTest
    static void testGetItemsFilterType() {
        Test.startTest();
        List<Item__c> items = ItemPurchaseController.getItems(null, 'Gadget', null);
        Test.stopTest();

        System.assertEquals(1, items.size());
        System.assertEquals('Gadget', items[0].Type__c);
        System.assertEquals('Gadget X', items[0].Name);
    }

    @isTest
    static void testGetItemsSearchKey() {
        Test.startTest();
        List<Item__c> items = ItemPurchaseController.getItems(null, null, 'widget');
        Test.stopTest();
        System.assertEquals(2, items.size());
        Set<String> names = new Set<String>();
        for (Item__c it : items) names.add(it.Name);
        System.assert(names.contains('Widget A'));
        System.assert(names.contains('Widget B'));

        Test.startTest();
        items = ItemPurchaseController.getItems(null, null, 'spare');
        Test.stopTest();
        System.assertEquals(1, items.size());
        System.assertEquals('Part Z', items[0].Name);
    }

    @isTest
    static void testGetItemsCombinedFilters() {
        Test.startTest();
        List<Item__c> items = ItemPurchaseController.getItems('Electronics', 'Gadget', 'cool');
        Test.stopTest();

        System.assertEquals(1, items.size());
        System.assertEquals('Gadget X', items[0].Name);
    }

    @isTest
    static void testGetItemsNoResults() {
        Test.startTest();
        List<Item__c> items = ItemPurchaseController.getItems('Hardware', 'Gadget', null);
        Test.stopTest();

        System.assertEquals(0, items.size());
    }

    @isTest
    static void testCheckoutSuccess() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Account'];
        List<Item__c> items = [SELECT Id, AvailableQuantity__c, Price__c
                               FROM Item__c WHERE Name IN ('Widget A', 'Gadget X')];
        Id itemId1 = items[0].Id; // Widget A
        Id itemId2 = items[1].Id; // Gadget X

        List<Map<String, Object>> cart = new List<Map<String, Object>>{
            new Map<String, Object>{ 'itemId' => itemId1, 'quantity' => 10, 'unitCost' => 10 },
            new Map<String, Object>{ 'itemId' => itemId2, 'quantity' => 2, 'unitCost' => 30 }
        };

        Test.startTest();
        Id purchaseId = ItemPurchaseController.checkout(acc.Id, cart);
        Test.stopTest();

        System.assertNotEquals(null, purchaseId);
        Purchase__c p = [SELECT ClientId__c FROM Purchase__c WHERE Id = :purchaseId];
        System.assertEquals(acc.Id, p.ClientId__c);

        List<PurchaseLine__c> lines = [SELECT ItemId__c, Amount__c, UnitCost__c
                                       FROM PurchaseLine__c WHERE PurchaseId__c = :purchaseId];
        System.assertEquals(2, lines.size());

        // Verify stock deduction
        Item__c updated1 = [SELECT AvailableQuantity__c FROM Item__c WHERE Id = :itemId1];
        Item__c updated2 = [SELECT AvailableQuantity__c FROM Item__c WHERE Id = :itemId2];
        System.assertEquals(90, updated1.AvailableQuantity__c);  // 100 - 10
        System.assertEquals(8, updated2.AvailableQuantity__c);   // 10 - 2
    }

    @isTest
    static void testCheckoutInsufficientStock() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Account'];
        Item__c item = [SELECT Id, AvailableQuantity__c FROM Item__c WHERE Name = 'Widget A'];

        List<Map<String, Object>> cart = new List<Map<String, Object>>{
            new Map<String, Object>{ 'itemId' => item.Id, 'quantity' => 200, 'unitCost' => 10 }
        };

        Test.startTest();
        try {
            ItemPurchaseController.checkout(acc.Id, cart);
            System.assert(false, 'AuraHandledException was expected');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Insufficient stock'));
        }
        Test.stopTest();

        // Verify no purchase was created
        System.assertEquals(0, [SELECT COUNT() FROM Purchase__c]);
    }

    @isTest
    static void testCheckoutMultipleSameItem() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Account'];
        Item__c item = [SELECT Id, AvailableQuantity__c FROM Item__c WHERE Name = 'Widget A'];

        List<Map<String, Object>> cart = new List<Map<String, Object>>{
            new Map<String, Object>{ 'itemId' => item.Id, 'quantity' => 10, 'unitCost' => 10 },
            new Map<String, Object>{ 'itemId' => item.Id, 'quantity' => 5, 'unitCost' => 10 }
        };

        Test.startTest();
        Id purchaseId = ItemPurchaseController.checkout(acc.Id, cart);
        Test.stopTest();

        List<PurchaseLine__c> lines = [SELECT Amount__c FROM PurchaseLine__c WHERE PurchaseId__c = :purchaseId];
        System.assertEquals(2, lines.size());
        Decimal total = 0;
        for (PurchaseLine__c line : lines) {
            total += line.Amount__c;
        }
        System.assertEquals(15, total);

        Item__c updated = [SELECT AvailableQuantity__c FROM Item__c WHERE Id = :item.Id];
        System.assertEquals(85, updated.AvailableQuantity__c); // 100 - 15
    }

    @isTest
    static void testCheckoutEmptyCart() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Account'];
        List<Map<String, Object>> cart = new List<Map<String, Object>>();

        Test.startTest();
        Id purchaseId = ItemPurchaseController.checkout(acc.Id, cart);
        Test.stopTest();

        System.assertNotEquals(null, purchaseId);
        // A purchase record exists, but with no lines
        System.assertEquals(1, [SELECT COUNT() FROM Purchase__c]);
        System.assertEquals(0, [SELECT COUNT() FROM PurchaseLine__c WHERE PurchaseId__c = :purchaseId]);
    }

    @isTest
    static void testGetPicklistValues() {
        Test.startTest();
        Map<String, List<String>> result = ItemPurchaseController.getPicklistValues();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result map should not be null');
        System.assert(result.containsKey('Family'), 'Map should contain Family key');
        System.assert(result.containsKey('Type'), 'Map should contain Type key');
        System.assert(result.get('Family') != null, 'Family list should not be null');
        System.assert(result.get('Type') != null, 'Type list should not be null');
    }
}