/**
 * @class CleverTapSyncQueueable
 * @description A generic Queueable class that processes Salesforce records and sends them to CleverTap.
 */
@SuppressWarnings('PMD.QueueableWithoutFinalizer')
public class CleverTapSyncQueueable implements Queueable, Database.AllowsCallouts {
    private List<SObject> records;
    private String objectType;

    /**
     * @description Constructor for processing a single SObject record.
     * @param record A single Salesforce record.
     */
    public CleverTapSyncQueueable(SObject record) {
        this.records = new List<SObject>{record};
        this.objectType = record.getSObjectType().getDescribe().getName();
    }

    /**
     * @description Constructor for processing multiple SObject records.
     * @param records A list of Salesforce records of the same type.
     */
    public CleverTapSyncQueueable(List<SObject> records) {
        if (records == null || records.isEmpty()) {
            this.records = new List<SObject>();
            this.objectType = '';
        } else {
            this.records = records;
            this.objectType = records[0].getSObjectType().getDescribe().getName();
        }
    }

    /**
     * @description Executes the job to send each record to CleverTap.
     * @param context The Queueable context.
     */
public void execute(QueueableContext context) {
    if (records.isEmpty()) {
        return;
    }
    
    // Process one record at a time to avoid mixing callouts and DML
    SObject record = records[0];
    List<SObject> remainingRecords = new List<SObject>(records);
    remainingRecords.remove(0);
    
    // Process the first record based on its type
    switch on objectType {
        when 'Lead' {
            CleverTapService.sendLeadToCleverTap((Lead)record);
        }
        when 'Contact' {
            CleverTapService.sendContactToCleverTap((Contact)record);
        }
        when 'Account' {
            CleverTapService.sendAccountToCleverTap((Account)record);
        }
        when 'Opportunity' {
            CleverTapService.sendOpportunityToCleverTap((Opportunity)record);
        }
    }
    
    // Enqueue the next batch if there are more records
    if (!remainingRecords.isEmpty()) {
        System.enqueueJob(new CleverTapSyncQueueable(remainingRecords));
    }
}
}