public with sharing class CaseAIEmailDraftController {

    public class EmailDraftDTO {
        @AuraEnabled public String subject { get; set; }
        @AuraEnabled public String htmlBody { get; set; }
        @AuraEnabled public String caseType { get; set; }
    }

    @AuraEnabled(cacheable=false)
    public static EmailDraftDTO getAIEmailDraftData(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('Case ID is required.');
        }

        Case caseRec = [
            SELECT Id, CaseNumber, Subject, Type, Description, AccountId
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        // 1. Prepare input parameters for PromptTemplateService
        Map<String, Object> inputParams = new Map<String, Object>();
        inputParams.put('Input:Case', caseRec.Id);

        // Ground ONLY the specific record relevant to the case type
        if (caseRec.AccountId != null) {
            if (caseRec.Type == 'Delivery questions' || caseRec.Type == 'Delivery Issues') {
                List<Order> orders = [
                    SELECT Id, OrderNumber, Current_Status__c, Expected_ETA__c, Carrier__c, Tracking_Number__c
                    FROM Order
                    WHERE AccountId = :caseRec.AccountId
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];
                if (!orders.isEmpty()) {
                    inputParams.put('Input:Order', orders[0].Id);
                }
            } else if (caseRec.Type == 'Prescription Status questions') {
                List<Prescription__c> prescriptions = [
                    SELECT Id, Name, Prescription_Number__c, Medication_Name__c, Prescribing_Doctor__c, Status__c, Expiration_Date__c, Refills_Remaining__c
                    FROM Prescription__c
                    WHERE Account__c = :caseRec.AccountId
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];
                if (!prescriptions.isEmpty()) {
                    inputParams.put('Input:Prescription', prescriptions[0].Id);
                }
            }
        }

        // 2. Invoke prompt template via PromptTemplateService
        PromptTemplateService service = new PromptTemplateService();
        String generatedResponse = service.generate('HealthPulse_Customer_Email_Draft', inputParams);

        EmailDraftDTO dto = new EmailDraftDTO();
        dto.caseType = caseRec.Type;
        dto.htmlBody = generatedResponse;
        dto.subject = 'Re: ' + caseRec.subject; // 'HealthPulse Support: Update regarding ' + (String.isNotBlank(caseRec.Subject) ? caseRec.Subject : ('Case #' + caseRec.CaseNumber));

        return dto;
    }
}
