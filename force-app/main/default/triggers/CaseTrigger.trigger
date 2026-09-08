trigger CaseTrigger on Case (after insert, after update) {
    CaseTriggerHandler.handleTrigger(Trigger.new, Trigger.oldMap, Trigger.operationType);
}
