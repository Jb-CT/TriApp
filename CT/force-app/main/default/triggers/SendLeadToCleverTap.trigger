trigger SendLeadToCleverTap on Lead (after insert, after update) {

    // Skip processing in test context if bypass flag is set
    if (Test.isRunningTest() && CleverTapTestUtils.bypassTriggers) {
        return;
    }

    // Skip processing in batch, future, or queueable contexts
    if (System.isBatch() || System.isFuture() || System.isQueueable()) {
        return;
    }

    // Leads to process
    List<Lead> leadsToProcess = new List<Lead>();

    if (Trigger.isInsert) {
        // Process all new Leads
        leadsToProcess = Trigger.new;
    } else if (Trigger.isUpdate) {
        for (Lead lead : Trigger.new) {
            Lead oldLead = Trigger.oldMap.get(lead.Id);

            if (
                lead.FirstName != oldLead.FirstName ||
                lead.LastName != oldLead.LastName ||
                lead.Salutation != oldLead.Salutation ||
                lead.Name != oldLead.Name ||
                lead.Phone != oldLead.Phone ||
                lead.MobilePhone != oldLead.MobilePhone ||
                lead.Fax != oldLead.Fax ||
                lead.Title != oldLead.Title ||
                lead.Email != oldLead.Email ||
                lead.Company != oldLead.Company ||
                lead.Website != oldLead.Website ||
                lead.Industry != oldLead.Industry ||
                lead.Status != oldLead.Status ||
                lead.AnnualRevenue != oldLead.AnnualRevenue ||
                lead.Rating != oldLead.Rating ||
                lead.NumberOfEmployees != oldLead.NumberOfEmployees ||
                lead.OwnerId != oldLead.OwnerId ||
                lead.LeadSource != oldLead.LeadSource ||
                lead.Street != oldLead.Street ||
                lead.City != oldLead.City ||
                lead.PostalCode != oldLead.PostalCode ||
                lead.State != oldLead.State ||
                lead.Country != oldLead.Country ||
                lead.Description != oldLead.Description
            ) {
                leadsToProcess.add(lead);
            }
        }
    }

    if (!leadsToProcess.isEmpty()) {
        CleverTapIntegrationHandler.processLeads(leadsToProcess);
    }
}
