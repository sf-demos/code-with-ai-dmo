public with sharing class CaseEmailDraftController {

    /**
     * TOGGLE MODE:
     * - true: Uses Salesforce EmailTemplate records via Messaging.renderStoredEmailTemplate
     * - false: Uses Apex-generated dynamic HTML templates
     */
    public static final Boolean USE_EMAIL_TEMPLATES = true;

    public class EmailDraftDTO {
        @AuraEnabled public String subject { get; set; }
        @AuraEnabled public String htmlBody { get; set; }
        @AuraEnabled public String caseType { get; set; }
    }

    @AuraEnabled(cacheable=false)
    public static EmailDraftDTO getEmailDraftData(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('Case ID is required.');
        }

        Case caseRec = [
            SELECT Id, CaseNumber, Subject, Type, AccountId, ContactId,
                   Account.Name, Account.FirstName, Account.LastName, Account.PersonContactId,
                   Contact.Name, Contact.FirstName, Contact.LastName
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        EmailDraftDTO dto = new EmailDraftDTO();
        dto.caseType = caseRec.Type;

        Id whoId = (caseRec.ContactId != null)
            ? caseRec.ContactId
            : (caseRec.Account != null ? caseRec.Account.PersonContactId : null);

        String greetingName = resolveGreetingName(caseRec);

        if (caseRec.Type == 'Delivery questions') {
            if (USE_EMAIL_TEMPLATES) {
                renderDeliveryFromTemplate(dto, caseRec, whoId);
            } else {
                renderDeliveryFromApex(dto, caseRec, greetingName);
            }
        } else if (caseRec.Type == 'Prescription Status questions') {
            if (USE_EMAIL_TEMPLATES) {
                renderPrescriptionFromTemplate(dto, caseRec, whoId);
            } else {
                renderPrescriptionFromApex(dto, caseRec, greetingName);
            }
        } else {
            // Other types: blank body and subject for agent free-text entry
            dto.subject = '';
            dto.htmlBody = '';
        }

        return dto;
    }

    // =========================================================================
    // MODE 1: EMAIL TEMPLATES APPROACH (Messaging.renderStoredEmailTemplate)
    // =========================================================================

    private static void renderDeliveryFromTemplate(EmailDraftDTO dto, Case caseRec, Id whoId) {
        Order relatedOrder = queryLatestOrder(caseRec.AccountId);
        Id templateId = getTemplateId('Case_Delivery_Questions');
        Id whatId = (relatedOrder != null) ? relatedOrder.Id : caseRec.Id;

        if (templateId != null && whoId != null) {
            Messaging.SingleEmailMessage rendered = Messaging.renderStoredEmailTemplate(templateId, whoId, whatId);
            // dto.subject = rendered.getSubject();
            dto.subject = 'Re: ' + caseRec.subject;
            dto.htmlBody = rendered.getHtmlBody();
        } else {
            // Fallback to Apex if template is not found in org
            renderDeliveryFromApex(dto, caseRec, resolveGreetingName(caseRec));
        }
    }

    private static void renderPrescriptionFromTemplate(EmailDraftDTO dto, Case caseRec, Id whoId) {
        Prescription__c relatedRx = queryLatestPrescription(caseRec.AccountId);
        Id templateId = getTemplateId('Case_Prescription_Status');
        Id whatId = (relatedRx != null) ? relatedRx.Id : caseRec.Id;

        if (templateId != null && whoId != null) {
            Messaging.SingleEmailMessage rendered = Messaging.renderStoredEmailTemplate(templateId, whoId, whatId);
            dto.subject = 'Re: ' + caseRec.subject; //rendered.getSubject();
            dto.htmlBody = rendered.getHtmlBody();
        } else {
            // Fallback to Apex if template is not found in org
            renderPrescriptionFromApex(dto, caseRec, resolveGreetingName(caseRec));
        }
    }

    // =========================================================================
    // MODE 2: APEX DYNAMIC HTML APPROACH
    // =========================================================================

    private static void renderDeliveryFromApex(EmailDraftDTO dto, Case caseRec, String greetingName) {
        Order relatedOrder = queryLatestOrder(caseRec.AccountId);

        String orderNum = (relatedOrder != null && String.isNotBlank(relatedOrder.OrderNumber)) ? relatedOrder.OrderNumber : 'Pending';
        String currentStatus = (relatedOrder != null && String.isNotBlank(relatedOrder.Current_Status__c)) ? relatedOrder.Current_Status__c : 'In transit';
        String carrier = (relatedOrder != null && String.isNotBlank(relatedOrder.Carrier__c)) ? relatedOrder.Carrier__c : 'FedEx Priority Health';
        String trackingNumber = (relatedOrder != null && String.isNotBlank(relatedOrder.Tracking_Number__c)) ? relatedOrder.Tracking_Number__c : 'FX-9920184712';
        String formattedEta = (relatedOrder != null && relatedOrder.Expected_ETA__c != null)
            ? DateTime.newInstance(relatedOrder.Expected_ETA__c, Time.newInstance(0, 0, 0, 0)).format('MMMM d, yyyy')
            : DateTime.now().addDays(3).format('MMMM d, yyyy');

        dto.subject = 'Update regarding your HealthPulse Order #' + orderNum + ' - Delivery Status & ETA';

        dto.htmlBody = '<p>Dear ' + escapeHtml(greetingName) + ',</p>' +
            '<p>Thank you for contacting HealthPulse Support regarding your shipment.</p>' +
            '<p>Here are the latest details on your active order:</p>' +
            '<ul>' +
            '  <li><strong>Order Number:</strong> ' + escapeHtml(orderNum) + '</li>' +
            '  <li><strong>Current Status:</strong> ' + escapeHtml(currentStatus) + '</li>' +
            '  <li><strong>Expected Delivery Date (ETA):</strong> ' + escapeHtml(formattedEta) + '</li>' +
            '  <li><strong>Carrier:</strong> ' + escapeHtml(carrier) + '</li>' +
            '  <li><strong>Tracking Number:</strong> ' + escapeHtml(trackingNumber) + '</li>' +
            '</ul>' +
            '<p>Your package is on its way and scheduled to arrive by the estimated delivery date above.</p>' +
            '<p>If you have any further questions or need address modifications, please reply directly to this email.</p>' +
            '<p>Best regards,<br/><strong>HealthPulse Customer Support Team</strong></p>';
    }

    private static void renderPrescriptionFromApex(EmailDraftDTO dto, Case caseRec, String greetingName) {
        Prescription__c relatedRx = queryLatestPrescription(caseRec.AccountId);

        String rxNum = (relatedRx != null && String.isNotBlank(relatedRx.Prescription_Number__c))
            ? relatedRx.Prescription_Number__c
            : (relatedRx != null && String.isNotBlank(relatedRx.Name) ? relatedRx.Name : 'RX-440192');
        String medName = (relatedRx != null && String.isNotBlank(relatedRx.Medication_Name__c))
            ? relatedRx.Medication_Name__c
            : 'HealthPulse Pro Continuous Health Monitoring System (3-Month Supply)';
        String doctor = (relatedRx != null && String.isNotBlank(relatedRx.Prescribing_Doctor__c))
            ? relatedRx.Prescribing_Doctor__c
            : 'Dr. Robert Vance, MD (Endocrinology)';
        String status = (relatedRx != null && String.isNotBlank(relatedRx.Status__c)) ? relatedRx.Status__c : 'Expired';
        String formattedExpDate = (relatedRx != null && relatedRx.Expiration_Date__c != null)
            ? DateTime.newInstance(relatedRx.Expiration_Date__c, Time.newInstance(0, 0, 0, 0)).format('MMMM d, yyyy')
            : DateTime.now().addDays(-10).format('MMMM d, yyyy');

        dto.subject = 'Action Required: HealthPulse Prescription #' + rxNum + ' Status Update';

        dto.htmlBody = '<p>Dear ' + escapeHtml(greetingName) + ',</p>' +
            '<p>Thank you for reaching out to HealthPulse Support regarding your prescription status.</p>' +
            '<p>We reviewed your account records and found the following details:</p>' +
            '<ul>' +
            '  <li><strong>Prescription Number:</strong> ' + escapeHtml(rxNum) + '</li>' +
            '  <li><strong>Medication / Device:</strong> ' + escapeHtml(medName) + '</li>' +
            '  <li><strong>Prescribing Physician:</strong> ' + escapeHtml(doctor) + '</li>' +
            '  <li><strong>Current Status:</strong> <span style="color: #c23934; font-weight: bold;">' + escapeHtml(status) + '</span></li>' +
            '  <li><strong>Expiration Date:</strong> ' + escapeHtml(formattedExpDate) + '</li>' +
            '</ul>' +
            '<p>Because this prescription has expired, a renewal from your healthcare provider is required before your next HealthPulse sensor order can be processed. We recommend contacting <strong>' + escapeHtml(doctor) + '</strong> to request an updated prescription.</p>' +
            '<p>Please let us know if you have any questions or if you would like our team to assist with doctor outreach.</p>' +
            '<p>Warm regards,<br/><strong>HealthPulse Clinical Support Team</strong></p>';
    }

    // =========================================================================
    // HELPER METHODS
    // =========================================================================

    private static Order queryLatestOrder(Id accountId) {
        if (accountId == null) return null;
        List<Order> orders = [
            SELECT Id, OrderNumber, Current_Status__c, Expected_ETA__c, Carrier__c, Tracking_Number__c
            FROM Order
            WHERE AccountId = :accountId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return !orders.isEmpty() ? orders[0] : null;
    }

    private static Prescription__c queryLatestPrescription(Id accountId) {
        if (accountId == null) return null;
        List<Prescription__c> prescriptions = [
            SELECT Id, Name, Prescription_Number__c, Medication_Name__c, Prescribing_Doctor__c, Status__c, Expiration_Date__c, Refills_Remaining__c
            FROM Prescription__c
            WHERE Account__c = :accountId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return !prescriptions.isEmpty() ? prescriptions[0] : null;
    }

    private static Id getTemplateId(String developerName) {
        List<EmailTemplate> templates = [
            SELECT Id
            FROM EmailTemplate
            WHERE DeveloperName = :developerName
            LIMIT 1
        ];
        return !templates.isEmpty() ? templates[0].Id : null;
    }

    private static String resolveGreetingName(Case caseRec) {
        if (caseRec.Account != null && String.isNotBlank(caseRec.Account.FirstName)) {
            return caseRec.Account.FirstName;
        } else if (caseRec.Account != null && String.isNotBlank(caseRec.Account.Name)) {
            return caseRec.Account.Name;
        } else if (caseRec.Contact != null && String.isNotBlank(caseRec.Contact.FirstName)) {
            return caseRec.Contact.FirstName;
        } else if (caseRec.Contact != null && String.isNotBlank(caseRec.Contact.Name)) {
            return caseRec.Contact.Name;
        }
        return 'Valued Customer';
    }

    private static String escapeHtml(String input) {
        if (String.isBlank(input)) {
            return '';
        }
        return input.escapeHtml4();
    }
}
