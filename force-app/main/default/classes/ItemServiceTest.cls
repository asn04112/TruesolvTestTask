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
private class ItemServiceTest {

    @testSetup static void setup() {
        insert new Account(Name = 'Test Account');
        insert new List<Item__c>{
            new Item__c(
                Name = 'Test Item A', Description__c = 'First item', Family__c = 'Hardware',
                Type__c = 'Tool', Price__c = 10, AvailableQuantity__c = 100, Image__c = null
            ),
            new Item__c(
                Name = 'Test Item B', Description__c = 'Second item', Family__c = 'Software',
                Type__c = 'App', Price__c = 20, AvailableQuantity__c = 5, Image__c = null
            ),
            new Item__c(
                Name = 'Test Item C', Description__c = 'Third item', Family__c = 'Hardware',
                Type__c = 'Gadget', Price__c = 30, AvailableQuantity__c = 0, Image__c = null
            )
        };
    }

    @isTest static void testGetItems_NoFilters() {
        List<Item__c> items = ItemService.getItems('', '', '');
        System.assertEquals(3, items.size(), 'Should return all items');
    }

    @isTest static void testGetItems_FamilyFilter() {
        List<Item__c> items = ItemService.getItems('Hardware', '', '');
        System.assertEquals(2, items.size(), 'Should return two Hardware items');
        for (Item__c it : items) {
            System.assertEquals('Hardware', it.Family__c, 'Family should match');
        }
    }

    @isTest static void testGetItems_TypeFilter() {
        List<Item__c> items = ItemService.getItems('', 'Tool', '');
        System.assertEquals(1, items.size(), 'Should return only Tool');
        System.assertEquals('Test Item A', items[0].Name);
    }

    @isTest static void testGetItems_SearchByName() {
        List<Item__c> items = ItemService.getItems('', '', 'Item A');
        System.assertEquals(1, items.size(), 'Should find by name');
        System.assertEquals('Test Item A', items[0].Name);
    }

    @isTest static void testGetItems_SearchByDescription() {
        List<Item__c> items = ItemService.getItems('', '', 'Second');
        System.assertEquals(1, items.size(), 'Should find by description');
        System.assertEquals('Test Item B', items[0].Name);
    }

    @isTest static void testGetItems_CombinedFilters() {
        List<Item__c> items = ItemService.getItems('Hardware', 'Gadget', 'Third');
        System.assertEquals(1, items.size(), 'Should return only Test Item C');
    }

    @isTest static void testCreateItem_Success() {
        Test.setMock(HttpCalloutMock.class, new UnsplashMock());

        Test.startTest();
        Id newItemId = ItemService.createItem('New Item', 'Desc', 'Type1', 'Family1', 50, 10);
        Test.stopTest();

        Item__c created = [SELECT Id, Name, Description__c, Type__c, Family__c, Price__c,
                                  AvailableQuantity__c, Image__c
                           FROM Item__c WHERE Id = :newItemId];
        System.assertEquals('New Item', created.Name);
        System.assertEquals('Desc', created.Description__c);
        System.assertEquals('Type1', created.Type__c);
        System.assertEquals('Family1', created.Family__c);
        System.assertEquals(50, created.Price__c);
        System.assertEquals(10, created.AvailableQuantity__c);
        System.assertEquals('https://images.unsplash.com/photo-12345', created.Image__c);
    }

    @isTest static void testCheckout_Success() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Item__c itemA = [SELECT Id, AvailableQuantity__c, Price__c FROM Item__c WHERE Name = 'Test Item A'];
        Item__c itemB = [SELECT Id, AvailableQuantity__c FROM Item__c WHERE Name = 'Test Item B'];

        List<Map<String, Object>> cart = new List<Map<String, Object>>{
            new Map<String, Object>{'itemId' => itemA.Id, 'quantity' => 5, 'unitCost' => itemA.Price__c},
            new Map<String, Object>{'itemId' => itemB.Id, 'quantity' => 2, 'unitCost' => 20}
        };

        Test.startTest();
        Id purchaseId = ItemService.checkout(acc.Id, cart);
        Test.stopTest();

        Purchase__c purchase = [SELECT Id, ClientId__c, TotalItems__c, GrandTotal__c FROM Purchase__c WHERE Id = :purchaseId];
        System.assertEquals(acc.Id, purchase.ClientId__c);
        System.assertEquals(2, purchase.TotalItems__c, 'Trigger should count 2 lines');
        System.assertEquals(90, purchase.GrandTotal__c, 'Grand total should be 90');

        List<PurchaseLine__c> lines = [SELECT Id, PurchaseId__c, ItemId__c, Amount__c, UnitCost__c
                                       FROM PurchaseLine__c WHERE PurchaseId__c = :purchaseId];
        System.assertEquals(2, lines.size(), 'Two lines should exist');

        itemA = [SELECT AvailableQuantity__c FROM Item__c WHERE Id = :itemA.Id];
        itemB = [SELECT AvailableQuantity__c FROM Item__c WHERE Id = :itemB.Id];
        System.assertEquals(95, itemA.AvailableQuantity__c, 'ItemA stock should be 95');
        System.assertEquals(3, itemB.AvailableQuantity__c, 'ItemB stock should be 3');
    }

    @isTest static void testCheckout_InsufficientStock() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Item__c itemC = [SELECT Id, AvailableQuantity__c FROM Item__c WHERE Name = 'Test Item C']; // stock 0

        List<Map<String, Object>> cart = new List<Map<String, Object>>{
            new Map<String, Object>{'itemId' => itemC.Id, 'quantity' => 1, 'unitCost' => 30}
        };

        Test.startTest();
        try {
            ItemService.checkout(acc.Id, cart);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Insufficient stock'), 'Exception message should mention stock');
        }
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Purchase__c], 'No purchase should exist');
    }

    private class UnsplashMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"results":[{"urls":{"regular":"https://images.unsplash.com/photo-12345"}}]}');
            return res;
        }
    }
}