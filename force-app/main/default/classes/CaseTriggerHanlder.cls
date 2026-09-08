/**
 * @description Alias class for CaseTriggerHandler to support the alternative spelling "CaseTriggerHanlder".
 *              Delegates all calls directly to CaseTriggerHandler.
 */
public with sharing class CaseTriggerHanlder {

    public static void handleTrigger(List<Case> newCases, Map<Id, Case> oldCases, System.TriggerOperation operationType) {
        CaseTriggerHandler.handleTrigger(newCases, oldCases, operationType);
    }

    public static void handleAfterInsert(List<Case> newCases) {
        CaseTriggerHandler.handleAfterInsert(newCases);
    }

    public static void handleAfterUpdate(List<Case> newCases, Map<Id, Case> oldCases) {
        CaseTriggerHandler.handleAfterUpdate(newCases, oldCases);
    }

    public static List<Id> filterEligibleCaseIds(List<Case> cases, Map<Id, Case> oldCases) {
        return CaseTriggerHandler.filterEligibleCaseIds(cases, oldCases);
    }

    public static void classifyCase(Id caseId) {
        CaseTriggerHandler.classifyCase(caseId);
    }

    public static void classifyCases(List<Id> caseIds) {
        CaseTriggerHandler.classifyCases(caseIds);
    }
}
