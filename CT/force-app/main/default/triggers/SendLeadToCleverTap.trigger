trigger SendLeadToCleverTap on Lead (after insert, after update) {
    // Skip processing in specific contexts that might be causing the duplication
    if (System.isBatch() || System.isFuture() || System.isQueueable()) {
        return;
    }
    
    // Process only when explicit field changes occur (this helps avoid processing system-driven updates)
    List<Lead> leadsToProcess = new List<Lead>();
    
    if (Trigger.isInsert) {
        leadsToProcess = Trigger.new;
    } else if (Trigger.isUpdate) {
        // Only process updates if certain fields changed
        for (Lead lead : Trigger.new) {
            Lead oldLead = Trigger.oldMap.get(lead.Id);
            // Check for changes to fields you care about
            if (lead.Email != oldLead.Email || 
                lead.LastName != oldLead.LastName ||
                lead.Status != oldLead.Status) {
                    leadsToProcess.add(lead);
                }
        }
    }
    
    if (!leadsToProcess.isEmpty()) {
        CleverTapIntegrationHandler.processLeads(leadsToProcess);
    }
}