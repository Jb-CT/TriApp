// /**
//  * @class CleverTapHistoricalSyncBatch
//  * @description Batch class to process historical records for CleverTap sync
//  */
// public class CleverTapHistoricalSyncBatch implements Database.Batchable<SObject>, Database.Stateful {
    
//     private String objectName;
//     private String syncConfigId;
//     private Integer recordsProcessed = 0;
//     private Integer recordsSuccess = 0;
//     private Integer recordsFailed = 0;
    
//     /**
//      * @description Constructor for the batch class
//      * @param objectName The name of the object to sync
//      * @param syncConfigId The ID of the sync configuration
//      */
//     public CleverTapHistoricalSyncBatch(String objectName, String syncConfigId) {
//         this.objectName = objectName;
//         this.syncConfigId = syncConfigId;
//     }
    
//     /**
//      * @description Query method to retrieve all records of the specified object type
//      * with all mapped fields
//      * @param bc The batch context
//      * @return Database.QueryLocator The query locator for all records
//      */
//     public Database.QueryLocator start(Database.BatchableContext bc) {
//         // Get the fields that need to be queried based on mappings
//         Set<String> fieldsToQuery = getFieldsFromMappings();
        
//         // Build query with the needed fields
//         String query = buildQueryWithFields(fieldsToQuery);
        
//         // Return the query locator
//         return Database.getQueryLocator(query);
//     }
    
//     /**
//      * @description Gets the fields that need to be queried from the mappings
//      * @return Set<String> Set of field API names to query
//      */
//     private Set<String> getFieldsFromMappings() {
//         Set<String> fields = new Set<String>{'Id'}; // Always include Id
        
//         try {
//             // Query for field mappings for this sync configuration
//             List<CleverTap_Mapping__c> mappings = [
//                 SELECT Salesforce_Field__c 
//                 FROM CleverTap_Mapping__c 
//                 WHERE Sync_Configuration__c = :syncConfigId
//             ];
            
//             // Add each mapped field to our set
//             for (CleverTap_Mapping__c mapping : mappings) {
//                 fields.add(mapping.Salesforce_Field__c);
//             }
//         } catch (Exception e) {
//             System.debug(LoggingLevel.ERROR, 'Error fetching field mappings: ' + e.getMessage());
//         }
        
//         return fields;
//     }
    
//     /**
//      * @description Builds a query string with the specified fields
//      * @param fields Set of field API names to include in the query
//      * @return String The complete SOQL query
//      */
//     private String buildQueryWithFields(Set<String> fields) {
//         String fieldList = String.join(new List<String>(fields), ', ');
//         return 'SELECT ' + fieldList + ' FROM ' + objectName;
//     }
    
//     /**
//      * @description Execute method to process records in batches
//      * @param bc The batch context
//      * @param scope The list of records to process
//      */
//     public void execute(Database.BatchableContext bc, List<SObject> scope) {
//         try {
//             // Keep track of processed records
//             recordsProcessed += scope.size();
            
//             // Use the existing CleverTapIntegrationHandler to process the records
//             // This reuses all the field mapping logic and API integration
//             CleverTapIntegrationHandler.processRecords(scope);
            
//             recordsSuccess += scope.size();
//         } catch (Exception e) {
//             recordsFailed += scope.size();
//             // Log the error but don't stop the batch
//             System.debug(LoggingLevel.ERROR, 'Error processing batch: ' + e.getMessage());
//             System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
//         }
//     }
    
//     /**
//      * @description Finish method to handle completion of the batch process
//      * @param bc The batch context
//      */
//     public void finish(Database.BatchableContext bc) {
//         // Create a log entry for the historical sync
//         CleverTap_Event__c syncLog = new CleverTap_Event__c(
//             Status__c = (recordsFailed == 0) ? 'Success' : 'Failed',
//             Response__c = 'Historical sync completed.\n' +
//                           'Records processed: ' + recordsProcessed + '\n' +
//                           'Records succeeded: ' + recordsSuccess + '\n' +
//                           'Records failed: ' + recordsFailed + '\n' +
//                           'Sync Configuration ID: ' + syncConfigId
//         );
        
//         try {
//             insert syncLog;
//         } catch (Exception e) {
//             System.debug(LoggingLevel.ERROR, 'Error creating sync log: ' + e.getMessage());
//         }
//     }
// }

/**
 * @class CleverTapHistoricalSyncBatch
 * @description Batch class to process historical records for CleverTap sync
 */
public class CleverTapHistoricalSyncBatch implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {
    
    private String objectName;
    private String syncConfigId;
    private Integer recordsProcessed = 0;
    private Integer recordsSuccess = 0;
    private Integer recordsFailed = 0;
    
    /**
     * @description Constructor for the batch class
     * @param objectName The name of the object to sync
     * @param syncConfigId The ID of the sync configuration
     */
    public CleverTapHistoricalSyncBatch(String objectName, String syncConfigId) {
        this.objectName = objectName;
        this.syncConfigId = syncConfigId;
    }
    
    /**
     * @description Query method to retrieve all records of the specified object type
     * with all mapped fields
     * @param bc The batch context
     * @return Database.QueryLocator The query locator for all records
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Get the fields that need to be queried based on mappings
        Set<String> fieldsToQuery = getFieldsFromMappings();
        
        // Build query with the needed fields
        String query = buildQueryWithFields(fieldsToQuery);
        
        // Return the query locator
        return Database.getQueryLocator(query);
    }
    
    /**
     * @description Gets the fields that need to be queried from the mappings
     * @return Set<String> Set of field API names to query
     */
    private Set<String> getFieldsFromMappings() {
        Set<String> fields = new Set<String>{'Id'}; // Always include Id
        
        try {
            // Query for field mappings for this sync configuration
            List<CleverTap_Mapping__c> mappings = [
                SELECT Salesforce_Field__c 
                FROM CleverTap_Mapping__c 
                WHERE Sync_Configuration__c = :syncConfigId
            ];
            
            // Add each mapped field to our set
            for (CleverTap_Mapping__c mapping : mappings) {
                fields.add(mapping.Salesforce_Field__c);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error fetching field mappings: ' + e.getMessage());
        }
        
        return fields;
    }
    
    /**
     * @description Builds a query string with the specified fields
     * @param fields Set of field API names to include in the query
     * @return String The complete SOQL query
     */
    private String buildQueryWithFields(Set<String> fields) {
        String fieldList = String.join(new List<String>(fields), ', ');
        return 'SELECT ' + fieldList + ' FROM ' + objectName;
    }
    
    /**
     * @description Execute method to process records in batches
     * @param bc The batch context
     * @param scope The list of records to process
     */
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        // Process each record individually to avoid mixing DML and callouts
        for (SObject record : scope) {
            try {
                recordsProcessed++;
                
                // Process a single record at a time to avoid DML conflicts
                processSingleRecord(record);
                
                recordsSuccess++;
            } catch (Exception e) {
                recordsFailed++;
                // Log the error but don't stop the batch
                System.debug(LoggingLevel.ERROR, 'Error processing record ' + record.Id + ': ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            }
        }
    }
    
    /**
     * @description Process a single record to avoid DML conflicts with callouts
     * @param record The record to process
     */
    private void processSingleRecord(SObject record) {
        // Determine the record type
        String recordTypeName = objectName;
        
        // Use CleverTapService directly to avoid mixing DML and callouts
        if (recordTypeName == 'Lead') {
            CleverTapService.sendLeadToCleverTap((Lead)record);
        } else if (recordTypeName == 'Contact') {
            CleverTapService.sendContactToCleverTap((Contact)record);
        } else if (recordTypeName == 'Account') {
            CleverTapService.sendAccountToCleverTap((Account)record);
        } else if (recordTypeName == 'Opportunity') {
            CleverTapService.sendOpportunityToCleverTap((Opportunity)record);
        }
    }
    
    /**
     * @description Finish method to handle completion of the batch process
     * @param bc The batch context
     */
    public void finish(Database.BatchableContext bc) {
        // Create a log entry for the historical sync
        CleverTap_Event__c syncLog = new CleverTap_Event__c(
            Status__c = (recordsFailed == 0) ? 'Success' : 'Failed',
            Response__c = 'Historical sync completed.\n' +
                          'Records processed: ' + recordsProcessed + '\n' +
                          'Records succeeded: ' + recordsSuccess + '\n' +
                          'Records failed: ' + recordsFailed + '\n' +
                          'Sync Configuration ID: ' + syncConfigId
        );
        
        try {
            insert syncLog;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error creating sync log: ' + e.getMessage());
        }
    }
}