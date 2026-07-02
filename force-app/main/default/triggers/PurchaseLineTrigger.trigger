trigger PurchaseLineTrigger on PurchaseLine__c (after insert, after update, after delete, after undelete) {
    Set<Id> purchaseIds = new Set<Id>();

    if (Trigger.isInsert || Trigger.isUndelete) {
        for (PurchaseLine__c pl : Trigger.new) {
            purchaseIds.add(pl.PurchaseId__c);
        }
    }
    if (Trigger.isUpdate || Trigger.isDelete) {
        for (PurchaseLine__c pl : (Trigger.isUpdate ? Trigger.new : Trigger.old)) {
            purchaseIds.add(pl.PurchaseId__c);
        }
    }

    if (!purchaseIds.isEmpty()) {
        Map<Id, Integer> totalItemsMap = new Map<Id, Integer>();
        Map<Id, Decimal> grandTotalMap = new Map<Id, Decimal>();

        // Initialise totals to zero for every affected purchase
        for (Id pId : purchaseIds) {
            totalItemsMap.put(pId, 0);
            grandTotalMap.put(pId, 0.0);
        }

        // Query all lines for the affected purchases
        List<PurchaseLine__c> lines = [
            SELECT Id, Amount__c, UnitCost__c, PurchaseId__c
            FROM PurchaseLine__c
            WHERE PurchaseId__c IN :purchaseIds
        ];

        // Accumulate counts and grand totals in Apex
        for (PurchaseLine__c line : lines) {
            Id pId = line.PurchaseId__c;
            totalItemsMap.put(pId, totalItemsMap.get(pId) + 1);
            Decimal amt = line.Amount__c != null ? line.Amount__c : 0;
            Decimal cost = line.UnitCost__c != null ? line.UnitCost__c : 0;
            grandTotalMap.put(pId, grandTotalMap.get(pId) + (amt * cost));
        }

        // Prepare Purchase updates
        List<Purchase__c> toUpdate = new List<Purchase__c>();
        for (Id pId : purchaseIds) {
            toUpdate.add(new Purchase__c(
                Id = pId,
                TotalItems__c = totalItemsMap.get(pId),
                GrandTotal__c = grandTotalMap.get(pId)
            ));
        }

        update toUpdate;
    }
}