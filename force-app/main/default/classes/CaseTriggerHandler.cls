/**
 * @description Handler for CaseTrigger. Evaluates incoming cases for AI classification eligibility
 *              and invokes the HealthPulse Case Classification Prompt Template via ConnectApi.
 */
public with sharing class CaseTriggerHandler {

    public static final String PROMPT_TEMPLATE_NAME = 'HealthPulse_Case_Classification';

    public static final Set<String> VALID_CASE_TYPES = new Set<String>{
        'Delivery questions',
        'Prescription Status questions',
        'Delivery Issues',
        'Travelers',
        'Address changes',
        'Others'
    };

    @TestVisible
    private static PromptTemplateService promptService = new PromptTemplateService();

    @TestVisible
    private static Set<Id> processedCaseIds = new Set<Id>();

    /**
     * @description Main entry point from CaseTrigger.
     */
    public static void handleTrigger(List<Case> newCases, Map<Id, Case> oldCases, System.TriggerOperation operationType) {
        switch on operationType {
            when AFTER_INSERT {
                handleAfterInsert(newCases);
            }
            when AFTER_UPDATE {
                handleAfterUpdate(newCases, oldCases);
            }
        }
    }

    /**
     * @description Processes cases after insert.
     */
    public static void handleAfterInsert(List<Case> newCases) {
        List<Id> eligibleCaseIds = filterEligibleCaseIds(newCases, null);
        if (!eligibleCaseIds.isEmpty()) {
            enqueueClassification(eligibleCaseIds);
        }
    }

    /**
     * @description Processes cases after update.
     */
    public static void handleAfterUpdate(List<Case> newCases, Map<Id, Case> oldCases) {
        List<Id> eligibleCaseIds = filterEligibleCaseIds(newCases, oldCases);
        if (!eligibleCaseIds.isEmpty()) {
            enqueueClassification(eligibleCaseIds);
        }
    }

    /**
     * @description Evaluates the 4 eligibility criteria:
     *              1. Case must be linked to a Contact (ContactId != null)
     *              2. The Contact should be active (Contact.Active__c == true)
     *              3. The Case should have Origin = 'Email'
     *              4. The Case should have Type = null (or blank)
     */
    public static List<Id> filterEligibleCaseIds(List<Case> cases, Map<Id, Case> oldCases) {
        List<Id> eligibleCaseIds = new List<Id>();
        if (cases == null || cases.isEmpty()) {
            return eligibleCaseIds;
        }

        Set<Id> candidateContactIds = new Set<Id>();
        List<Case> candidateCases = new List<Case>();

        for (Case c : cases) {
            // Check eligibility conditions: ContactId, Origin='Email', Type=null
            if (c.ContactId != null &&
                c.Origin == 'Email' &&
                String.isBlank(c.Type) &&
                !processedCaseIds.contains(c.Id)) {

                // If updating, only process if Type was blank and remains blank
                if (oldCases != null && oldCases.containsKey(c.Id)) {
                    Case oldCase = oldCases.get(c.Id);
                    if (String.isNotBlank(oldCase.Type)) {
                        continue;
                    }
                }

                candidateContactIds.add(c.ContactId);
                candidateCases.add(c);
            }
        }

        if (candidateContactIds.isEmpty()) {
            return eligibleCaseIds;
        }

        // Query related Contacts to check Active__c == true
        Map<Id, Contact> activeContacts = new Map<Id, Contact>([
            SELECT Id, Active__c
            FROM Contact
            WHERE Id IN :candidateContactIds AND Active__c = true
        ]);

        for (Case c : candidateCases) {
            if (activeContacts.containsKey(c.ContactId)) {
                eligibleCaseIds.add(c.Id);
                processedCaseIds.add(c.Id);
            }
        }

        return eligibleCaseIds;
    }

    /**
     * @description Enqueues asynchronous classification job to allow ConnectApi callout.
     */
    private static void enqueueClassification(List<Id> eligibleCaseIds) {
        System.enqueueJob(new CaseClassificationQueueable(eligibleCaseIds));
    }

    /**
     * @description Classifies a single case synchronously.
     */
    public static void classifyCase(Id caseId) {
        if (caseId != null) {
            classifyCases(new List<Id>{ caseId });
        }
    }

    /**
     * @description Classifies a list of cases via the Prompt Template and updates their Type field.
     */
    public static void classifyCases(List<Id> caseIds) {
        if (caseIds == null || caseIds.isEmpty()) {
            return;
        }

        List<Case> casesToClassify = [
            SELECT Id, Subject, Description, Origin, ContactId, Contact.Active__c, Type
            FROM Case
            WHERE Id IN :caseIds
        ];

        List<Case> casesToUpdate = new List<Case>();

        for (Case c : casesToClassify) {
            // Double check eligibility
            if (c.ContactId == null || c.Contact.Active__c != true || c.Origin != 'Email' || String.isNotBlank(c.Type)) {
                continue;
            }

            try {
                Map<String, Object> inputParams = new Map<String, Object>();
                inputParams.put('Input:Case', c.Id);

                Map<String, Object> jsonResponse = promptService.generateJson(PROMPT_TEMPLATE_NAME, inputParams);
                String resolvedType = extractValidType(jsonResponse);

                if (String.isNotBlank(resolvedType)) {
                    casesToUpdate.add(new Case(
                        Id = c.Id,
                        Type = resolvedType
                    ));
                }
            } catch (Exception ex) {
                System.debug(LoggingLevel.ERROR, 'Failed to classify Case ' + c.Id + ': ' + ex.getMessage() + '\n' + ex.getStackTraceString());
            }
        }

        if (!casesToUpdate.isEmpty()) {
            update casesToUpdate;
        }
    }

    /**
     * @description Extracts and validates the Type value from LLM JSON response.
     */
    @TestVisible
    private static String extractValidType(Map<String, Object> jsonResponse) {
        if (jsonResponse == null || jsonResponse.isEmpty()) {
            return 'Others';
        }

        String rawType = null;
        if (jsonResponse.containsKey('Type') && jsonResponse.get('Type') != null) {
            rawType = String.valueOf(jsonResponse.get('Type')).trim();
        } else if (jsonResponse.containsKey('type') && jsonResponse.get('type') != null) {
            rawType = String.valueOf(jsonResponse.get('type')).trim();
        }

        if (String.isBlank(rawType)) {
            return 'Others';
        }

        // Match against valid Case Types (case-insensitive)
        for (String validType : VALID_CASE_TYPES) {
            if (validType.equalsIgnoreCase(rawType)) {
                return validType;
            }
        }

        return 'Others';
    }

    /**
     * @description Queueable class enabling asynchronous ConnectApi LLM callouts.
     */
    public class CaseClassificationQueueable implements Queueable, Database.AllowsCallouts {
        private List<Id> caseIds;

        public CaseClassificationQueueable(List<Id> caseIds) {
            this.caseIds = caseIds;
        }

        public void execute(QueueableContext ctx) {
            CaseTriggerHandler.classifyCases(this.caseIds);
        }
    }
}
