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

@isTest
private class ItemServiceTest {

    // Mock HTTP callout for UnsplashService
    private class UnsplashMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('{"urls":{"raw":"https://example.com/image.jpg"}}');
            return response;
        }
    }

    @isTest
    static void testGetItems_allFilters() {
        Item__c item1 = new Item__c(
            Name = 'Test Item 1',
            Description__c = 'Desc 1',
            Family__c = 'Electronics',
            Type__c = 'Laptop',
            Price__c = 1000,
            AvailableQuantity__c = 10,
            Image__c = 'dummy.jpg'
        );
        Item__c item2 = new Item__c(
            Name = 'Test Item 2',
            Description__c = 'Another desc',
            Family__c = 'Furniture',
            Type__c = 'Chair',
            Price__c = 200,
            AvailableQuantity__c = 5,
            Image__c = 'dummy.jpg'
        );
        insert new List<Item__c>{item1, item2};

        Test.startTest();
        List<Item__c> results = ItemService.getItems('Electronics', null, null);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return only Electronics items');
        System.assertEquals('Test Item 1', results[0].Name);

        Test.startTest();
        results = ItemService.getItems(null, 'Chair', null);
        Test.stopTest();
        System.assertEquals(1, results.size());
        System.assertEquals('Test Item 2', results[0].Name);

        Test.startTest();
        results = ItemService.getItems(null, null, 'Another');
        Test.stopTest();
        System.assertEquals(1, results.size());
        System.assertEquals('Test Item 2', results[0].Name);

        Test.startTest();
        results = ItemService.getItems('Electronics', 'Laptop', 'Item');
        Test.stopTest();
        System.assertEquals(1, results.size());
        System.assertEquals('Test Item 1', results[0].Name);

        Test.startTest();
        results = ItemService.getItems(null, null, null);
        Test.stopTest();
        System.assertEquals(2, results.size());
        System.assertEquals('Test Item 1', results[0].Name);
        System.assertEquals('Test Item 2', results[1].Name);
    }

    @isTest
    static void testCreateItem() {
        Test.setMock(HttpCalloutMock.class, new UnsplashMock());

        Test.startTest();
        Id itemId = ItemService.createItem(
            'New Laptop',
            'Powerful laptop',
            'Laptop',
            'Electronics',
            1500.00,
            25
        );
        Test.stopTest();

        Item__c created = [SELECT Id, Name, Description__c, Type__c, Family__c, Price__c, AvailableQuantity__c, Image__c FROM Item__c WHERE Id = :itemId];
        System.assertEquals('New Laptop', created.Name);
        System.assertEquals('Powerful laptop', created.Description__c);
        System.assertEquals('Laptop', created.Type__c);
        System.assertEquals('Electronics', created.Family__c);
        System.assertEquals(1500.00, created.Price__c);
        System.assertEquals(25, created.AvailableQuantity__c);
        System.assertNotEquals(null, created.Image__c, 'Image URL should be set from Unsplash');
        System.assert(created.Image__c.contains('example.com/image.jpg'));
    }

    @isTest
    static void testCheckoutSuccess() {
        // Create account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Item__c item1 = new Item__c(
            Name = 'Item A',
            AvailableQuantity__c = 10,
            Price__c = 50.00,
            Image__c = 'dummy.jpg'
        );
        Item__c item2 = new Item__c(
            Name = 'Item B',
            AvailableQuantity__c = 5,
            Price__c = 30.00,
            Image__c = 'dummy.jpg'
        );
        insert new List<Item__c>{item1, item2};

        List<Map<String, Object>> cartItems = new List<Map<String, Object>>();
        Map<String, Object> ci1 = new Map<String, Object>{
            'itemId' => item1.Id,
            'quantity' => 2,
            'unitCost' => 50.00
        };
        Map<String, Object> ci2 = new Map<String, Object>{
            'itemId' => item2.Id,
            'quantity' => 1,
            'unitCost' => 30.00
        };
        cartItems.add(ci1);
        cartItems.add(ci2);

        Test.startTest();
        Id purchaseId = ItemService.checkout(acc.Id, cartItems);
        Test.stopTest();

        Purchase__c purchase = [SELECT Id, ClientId__c, Name FROM Purchase__c WHERE Id = :purchaseId];
        System.assertEquals(acc.Id, purchase.ClientId__c);
        System.assert(purchase.Name.startsWith('Purchase '));

        List<PurchaseLine__c> lines = [SELECT PurchaseId__c, ItemId__c, Amount__c, UnitCost__c FROM PurchaseLine__c WHERE PurchaseId__c = :purchaseId ORDER BY ItemId__c];
        System.assertEquals(2, lines.size());

        Item__c updatedItem1 = [SELECT Id, AvailableQuantity__c FROM Item__c WHERE Id = :item1.Id];
        Item__c updatedItem2 = [SELECT Id, AvailableQuantity__c FROM Item__c WHERE Id = :item2.Id];
        System.assertEquals(8, updatedItem1.AvailableQuantity__c);
        System.assertEquals(4, updatedItem2.AvailableQuantity__c);
    }

    @isTest
    static void testCheckoutInsufficientStock() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Item__c item = new Item__c(
            Name = 'Low Stock Item',
            AvailableQuantity__c = 2,
            Price__c = 100.00,
            Image__c = 'dummy.jpg'
        );
        insert item;

        List<Map<String, Object>> cartItems = new List<Map<String, Object>>();
        Map<String, Object> ci = new Map<String, Object>{
            'itemId' => item.Id,
            'quantity' => 5,
            'unitCost' => 100.00
        };
        cartItems.add(ci);

        Test.startTest();
        try {
            ItemService.checkout(acc.Id, cartItems);
            System.assert(false, 'Expected exception was not thrown');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Insufficient stock for Low Stock Item'));
        }
        Test.stopTest();

        List<Purchase__c> purchases = [SELECT Id FROM Purchase__c WHERE ClientId__c = :acc.Id];
        System.assertEquals(0, purchases.size());

        Item__c unchanged = [SELECT AvailableQuantity__c FROM Item__c WHERE Id = :item.Id];
        System.assertEquals(2, unchanged.AvailableQuantity__c);
    }

    @isTest
    static void testCheckoutEmptyCart() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        List<Map<String, Object>> emptyCart = new List<Map<String, Object>>();

        Test.startTest();
        Id purchaseId = ItemService.checkout(acc.Id, emptyCart);
        Test.stopTest();

        Purchase__c purchase = [SELECT Id, (SELECT Id FROM PurchaseLines__r) FROM Purchase__c WHERE Id = :purchaseId];
        System.assertNotEquals(null, purchase.Id);
        System.assertEquals(0, purchase.PurchaseLines__r.size());
    }

}
}