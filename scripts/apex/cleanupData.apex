System.debug('--- STARTING DEMO DATA CLEANUP ---');

// 1. Delete Cases
List<Case> casesToDelete = [SELECT Id FROM Case LIMIT 10000];
if (!casesToDelete.isEmpty()) {
    delete casesToDelete;
    System.debug('Deleted ' + casesToDelete.size() + ' Case records.');
}

// 2. Delete Prescriptions
List<Prescription__c> rxToDelete = [SELECT Id FROM Prescription__c LIMIT 10000];
if (!rxToDelete.isEmpty()) {
    delete rxToDelete;
    System.debug('Deleted ' + rxToDelete.size() + ' Prescription__c records.');
}

// 3. Draft & Delete Orders (Set Activated orders to Draft first if needed)
List<Order> ordersToDelete = [SELECT Id, Status FROM Order LIMIT 10000];
if (!ordersToDelete.isEmpty()) {
    List<Order> activatedOrders = new List<Order>();
    for (Order o : ordersToDelete) {
        if (o.Status == 'Activated') {
            o.Status = 'Draft';
            activatedOrders.add(o);
        }
    }
    if (!activatedOrders.isEmpty()) {
        update activatedOrders;
    }
    delete ordersToDelete;
    System.debug('Deleted ' + ordersToDelete.size() + ' Order records.');
}

// 4. Delete Accounts (Person Accounts and Business Accounts)
List<Account> accountsToDelete = [SELECT Id FROM Account LIMIT 10000];
if (!accountsToDelete.isEmpty()) {
    delete accountsToDelete;
    System.debug('Deleted ' + accountsToDelete.size() + ' Account records.');
}

System.debug('--- DEMO DATA CLEANUP COMPLETED SUCCESSFULLY ---');
