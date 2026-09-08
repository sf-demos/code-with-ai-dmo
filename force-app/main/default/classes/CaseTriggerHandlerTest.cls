@IsTest
private class CaseTriggerHandlerTest {

    private class MockPromptTemplateService extends PromptTemplateService {
        private String mockType;

        public MockPromptTemplateService(String mockType) {
            this.mockType = mockType;
        }

        public override Map<String, Object> generateJson(String templateApiName, Map<String, Object> inputParams) {
            Map<String, Object> result = new Map<String, Object>();
            result.put('Type', this.mockType);
            return result;
        }
    }

    @IsTest
    static void testEligibleCaseTriggerQueueable() {
        // Setup Active Contact
        Contact activeContact = new Contact(
            FirstName = 'Sarah',
            LastName = 'Jenkins',
            Active__c = true
        );
        insert activeContact;

        // Set mock LLM service
        CaseTriggerHandler.promptService = new MockPromptTemplateService('Delivery questions');
        CaseTriggerHandler.processedCaseIds.clear();

        Test.startTest();
        Case testCase = new Case(
            Subject = 'Where is my HealthPulse sensor?',
            Description = 'Tracking says in transit but delivery date is missing.',
            Origin = 'Email',
            ContactId = activeContact.Id,
            Type = null
        );
        insert testCase;
        Test.stopTest();

        Case updatedCase = [SELECT Id, Type FROM Case WHERE Id = :testCase.Id];
        System.assertEquals('Delivery questions', updatedCase.Type, 'Eligible case should be classified as Delivery questions.');
    }

    @IsTest
    static void testIneligibleCasesExcluded() {
        // Setup Inactive Contact
        Contact inactiveContact = new Contact(
            FirstName = 'Inactive',
            LastName = 'Patient',
            Active__c = false
        );
        insert inactiveContact;

        // Setup Active Contact for other tests
        Contact activeContact = new Contact(
            FirstName = 'Active',
            LastName = 'Patient',
            Active__c = true
        );
        insert activeContact;

        List<Case> cases = new List<Case>();

        // Case 1: No Contact
        cases.add(new Case(
            Subject = 'No Contact Linked',
            Description = 'Missing ContactId',
            Origin = 'Email',
            ContactId = null,
            Type = null
        ));

        // Case 2: Inactive Contact
        cases.add(new Case(
            Subject = 'Inactive Contact Case',
            Description = 'Linked to inactive contact',
            Origin = 'Email',
            ContactId = inactiveContact.Id,
            Type = null
        ));

        // Case 3: Non-Email Origin
        cases.add(new Case(
            Subject = 'Phone Inbound',
            Description = 'Origin is Phone',
            Origin = 'Phone',
            ContactId = activeContact.Id,
            Type = null
        ));

        // Case 4: Pre-set Type
        cases.add(new Case(
            Subject = 'Already Classified',
            Description = 'Already has a Type',
            Origin = 'Email',
            ContactId = activeContact.Id,
            Type = 'Travelers'
        ));

        CaseTriggerHandler.processedCaseIds.clear();

        Test.startTest();
        insert cases;
        Test.stopTest();

        List<Id> eligibleIds = CaseTriggerHandler.filterEligibleCaseIds(cases, null);
        System.assertEquals(0, eligibleIds.size(), 'None of the ineligible cases should be eligible for classification.');
    }

    @IsTest
    static void testSynchronousClassifyCases() {
        Contact activeContact = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Active__c = true
        );
        insert activeContact;

        Case c = new Case(
            Subject = 'Need prescription renewal for continuous health monitoring',
            Description = 'My prescription expired 2 days ago',
            Origin = 'Email',
            ContactId = activeContact.Id,
            Type = null
        );
        insert c;

        CaseTriggerHandler.promptService = new MockPromptTemplateService('Prescription Status questions');
        CaseTriggerHandler.classifyCase(c.Id);

        Case updated = [SELECT Id, Type FROM Case WHERE Id = :c.Id];
        System.assertEquals('Prescription Status questions', updated.Type, 'Case Type should be updated by classifyCase.');
    }

    @IsTest
    static void testExtractValidTypeFallbacks() {
        // Exact match
        System.assertEquals('Delivery Issues', CaseTriggerHandler.extractValidType(new Map<String, Object>{ 'Type' => 'Delivery Issues' }));
        // Case-insensitive match
        System.assertEquals('Address changes', CaseTriggerHandler.extractValidType(new Map<String, Object>{ 'Type' => 'address changes' }));
        // Lowercase "type" key
        System.assertEquals('Travelers', CaseTriggerHandler.extractValidType(new Map<String, Object>{ 'type' => 'Travelers' }));
        // Unrecognized type defaults to Others
        System.assertEquals('Others', CaseTriggerHandler.extractValidType(new Map<String, Object>{ 'Type' => 'Unknown Type' }));
        // Blank or null defaults to Others
        System.assertEquals('Others', CaseTriggerHandler.extractValidType(null));
        System.assertEquals('Others', CaseTriggerHandler.extractValidType(new Map<String, Object>()));
    }

    @IsTest
    static void testCaseTriggerHanlderAlias() {
        Contact activeContact = new Contact(
            FirstName = 'Alias',
            LastName = 'Test',
            Active__c = true
        );
        insert activeContact;

        Case c = new Case(
            Subject = 'Test Case',
            Description = 'Testing alias class',
            Origin = 'Email',
            ContactId = activeContact.Id,
            Type = null
        );
        insert c;

        CaseTriggerHandler.promptService = new MockPromptTemplateService('Others');
        CaseTriggerHanlder.classifyCases(new List<Id>{ c.Id });

        Case updated = [SELECT Id, Type FROM Case WHERE Id = :c.Id];
        System.assertEquals('Others', updated.Type, 'CaseTriggerHanlder alias should work seamlessly.');
    }
}
