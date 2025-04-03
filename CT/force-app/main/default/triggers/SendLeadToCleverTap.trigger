trigger SendLeadToCleverTap on Lead (after insert, after update) {
    // Skip processing in test context if bypass flag is set
    if (Test.isRunningTest() && CleverTapTestUtils.bypassTriggers) {
        return;
    }
    
    // Skip processing in specific contexts that might be causing the duplication
    if (System.isBatch() || System.isFuture() || System.isQueueable()) {
        return;
    }
    
    List<Lead> leadsToProcess = new List<Lead>();
    
    if (Trigger.isInsert) {
        // Process all new leads
        leadsToProcess = Trigger.new;
    } else if (Trigger.isUpdate) {
        // Process all updated leads - no field filtering
        leadsToProcess = Trigger.new;
    }
    
    if (!leadsToProcess.isEmpty()) {
        CleverTapIntegrationHandler.processLeads(leadsToProcess);
    }
}