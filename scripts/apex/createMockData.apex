/**
 * @description Idempotent Apex script to seed mock demo records for the HealthPulse Case Email Drafting POC.
 * Run in target org: sf apex run --file scripts/apex/createMockData.apex --target-org demo_org
 *
 * CONFIGURATION — set this before running:
 */
String patientEmail = null; // TODO: Set this to the patient's email address before running, e.g. 'patient@example.com'

if (String.isBlank(patientEmail)) {
    throw new IllegalArgumentException(
        'patientEmail must be set to a valid email address before running this script. ' +
        'Update the variable at the top of createMockData.apex and re-run.'
    );
}

System.debug('--- START SEEDING MOCK DATA FOR HEALTHPULSE POC ---');

// 1. Resolve Person Account Record Type
List<RecordType> personAccRecordTypes = [
    SELECT Id, DeveloperName, Name
    FROM RecordType
    WHERE SObjectType = 'Account' AND IsPersonType = true
    LIMIT 1
];

Id personAccRecordTypeId = !personAccRecordTypes.isEmpty() ? personAccRecordTypes[0].Id : null;
System.debug('Person Account RecordTypeId: ' + personAccRecordTypeId);

// 2. Query or Create Patient Person Account
List<Account> existingAccounts = [
    SELECT Id, Name, PersonEmail
    FROM Account
    WHERE PersonEmail = :patientEmail
    LIMIT 1
];

Account patient;
if (!existingAccounts.isEmpty()) {
    patient = [
        SELECT Id, Name, PersonEmail, PersonContactId
        FROM Account
        WHERE Id = :existingAccounts[0].Id
        LIMIT 1
    ];
    System.debug('Existing Patient Person Account found: ' + patient.Id);
} else {
    patient = new Account();
    if (personAccRecordTypeId != null) {
        patient.RecordTypeId = personAccRecordTypeId;
    }
    patient.FirstName = 'Sarah Jenkins';
    patient.LastName = 'HealthPulse Patient';
    patient.PersonEmail = patientEmail;
    patient.PersonMobilePhone = '(555) 234-5678';
    patient.BillingCountry = 'United States';
    patient.BillingStreet = '123 Some Street';
    patient.BillingCity = 'Springfield';
    patient.BillingState = 'New York';
    patient.BillingPostalCode = '12345';
    insert patient;
    
    // Re-query to retrieve the auto-generated PersonContactId
    patient = [
        SELECT Id, Name, PersonEmail, PersonContactId
        FROM Account
        WHERE Id = :patient.Id
        LIMIT 1
    ];
    System.debug('Created Patient Person Account: ' + patient.Id + ' with PersonContactId: ' + patient.PersonContactId);
}

Id patientContactId = patient.PersonContactId;

// 3. Create or Update Mock Order
List<Order> existingOrders = [
    SELECT Id, OrderNumber, Current_Status__c
    FROM Order
    WHERE AccountId = :patient.Id
    ORDER BY CreatedDate DESC
    LIMIT 1
];

Order mockOrder;
if (!existingOrders.isEmpty()) {
    mockOrder = existingOrders[0];
    mockOrder.Current_Status__c = 'In transit';
    mockOrder.Expected_ETA__c = Date.today().addDays(3);
    mockOrder.Carrier__c = 'FedEx Priority Health';
    mockOrder.Tracking_Number__c = 'FX-9920184712';
    update mockOrder;
    System.debug('Updated existing Order: ' + mockOrder.Id);
} else {
    mockOrder = new Order(
        AccountId = patient.Id,
        EffectiveDate = Date.today(),
        Status = 'Draft',
        Current_Status__c = 'In transit',
        Expected_ETA__c = Date.today().addDays(3),
        Carrier__c = 'FedEx Priority Health',
        Tracking_Number__c = 'FX-9920184712'
    );
    insert mockOrder;
    System.debug('Created new Order: ' + mockOrder.Id);
}

// 4. Create or Update Mock Prescription (Custom Object)
List<Prescription__c> existingRx = [
    SELECT Id, Name, Status__c
    FROM Prescription__c
    WHERE Account__c = :patient.Id
    ORDER BY CreatedDate DESC
    LIMIT 1
];

Prescription__c mockRx;
if (!existingRx.isEmpty()) {
    mockRx = existingRx[0];
    mockRx.Prescription_Number__c = 'RX-440192';
    mockRx.Medication_Name__c = 'HealthPulse Pro Continuous Health Monitoring System (3-Month Supply)';
    mockRx.Prescribing_Doctor__c = 'Dr. John Doe, MD (Endocrinology)';
    mockRx.Status__c = 'Expired';
    mockRx.Expiration_Date__c = Date.today().addDays(-10);
    mockRx.Refills_Remaining__c = 0;
    update mockRx;
    System.debug('Updated existing Prescription: ' + mockRx.Id);
} else {
    mockRx = new Prescription__c(
        Account__c = patient.Id,
        Name = 'RX-440192',
        Prescription_Number__c = 'RX-440192',
        Medication_Name__c = 'HealthPulse Pro Continuous Health Monitoring System (3-Month Supply)',
        Prescribing_Doctor__c = 'Dr. John Doe, MD (Endocrinology)',
        Status__c = 'Expired',
        Expiration_Date__c = Date.today().addDays(-10),
        Refills_Remaining__c = 0
    );
    insert mockRx;
    System.debug('Created new Prescription: ' + mockRx.Id);
}

// 5. Clean up old demo Cases for this patient to prevent clutter
delete [SELECT Id FROM Case WHERE AccountId = :patient.Id];

// 6. Create Demo Cases
List<Case> demoCases = new List<Case>();

// Case 1: Delivery Questions
demoCases.add(new Case(
    AccountId = patient.Id,
    ContactId = patientContactId,
    Subject = 'Where is my replacement sensor shipment? Need ETA',
    Type = 'Delivery questions',
    Status = 'New',
    Priority = 'Medium',
    Origin = 'Email',
    Description = 'Hi HealthPulse Support Team,\n\n' +
        'I recently ordered a replacement HealthPulse sensor and wanted to check on the delivery status. My current sensor has only one day left before expiration.\n\n' +
        'Could you please provide an update on the tracking details and estimated arrival date?\n\n' +
        'Thank you for your help,\nSarah Jenkins'
));

// Case 2: Prescription Status Questions
demoCases.add(new Case(
    AccountId = patient.Id,
    ContactId = patientContactId,
    Subject = 'Pharmacy says my sensor prescription is expired - please check',
    Type = 'Prescription Status questions',
    Status = 'New',
    Priority = 'High',
    Origin = 'Email',
    Description = 'Hello HealthPulse Team,\n\n' +
        'I attempted to reorder my 3-month supply of HealthPulse continuous health monitoring sensors yesterday, but the pharmacy notified me that my prescription is showing as expired.\n\n' +
        'Could you please verify the status of my prescription.\n\n' +
        'Thanks,\nSarah Jenkins'
));

// Case 3: Other Case Type (Address changes)
demoCases.add(new Case(
    AccountId = patient.Id,
    ContactId = patientContactId,
    Subject = 'Need to update home address for future orders',
    Type = 'Address changes',
    Status = 'New',
    Priority = 'Low',
    Origin = 'Email',
    Description = 'Hello Support,\n\n' +
        'I am moving at the end of this month and would like to update my primary shipping address for all future HealthPulse sensor deliveries.\n\n' +
        'Please let me know how I can confirm my new address and ensure future automated refills are shipped to the correct location.\n\n' +
        'Best regards,\nSarah Jenkins'
));

insert demoCases;

System.debug('--- DEMO SEEDING COMPLETED SUCCESSFULLY ---');
for (Case c : demoCases) {
    System.debug('Created Demo Case ID: ' + c.Id + ' | Type: ' + c.Type + ' | Subject: ' + c.Subject);
}
