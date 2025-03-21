/**
 * @class EventLogController
 * @description Controller class for handling CleverTap event log operations.
 */
public with sharing class EventLogController {
    
    /**
     * @description Gets event logs with optional filtering
     * @param limit The maximum number of records to return
     * @param status Filter by status (optional)
     * @param days Number of days to look back (optional)
     * @return List of CleverTap_Event__c records
     */
    @AuraEnabled(cacheable=true)
    public static List<CleverTap_Event__c> getEventLogs(Integer recordLimit, String status, Integer days) {
        // Check CRUD permissions
        if (!Schema.SObjectType.CleverTap_Event__c.isAccessible()) {
            throw new AuraHandledException('You do not have access to event logs');
        }
        
        // Start building the query
        String query = 'SELECT Id, Name, Status__c, Response__c, CreatedDate, Lead__c, Lead__r.Name, Contact__c, Contact__r.Name';
        query += ' FROM CleverTap_Event__c';
        
        // Add WHERE clauses
        List<String> whereConditions = new List<String>();
        
        // Filter by status if provided
        if (String.isNotBlank(status)) {
            whereConditions.add('Status__c = :status');
        }
        
        // Filter by date if days is provided
        if (days != null && days > 0) {
            DateTime filterDate = DateTime.now().addDays(-days);
            whereConditions.add('CreatedDate >= :filterDate');
        }
        
        // Combine WHERE clauses
        if (!whereConditions.isEmpty()) {
            query += ' WHERE ' + String.join(whereConditions, ' AND ');
        }
        
        // Add ORDER BY and LIMIT
        query += ' ORDER BY CreatedDate DESC';
        query += ' LIMIT :recordLimit';
        
        // Execute the query
        return Database.query(query);
    }
    
    /**
     * @description Gets the details of a specific event log
     * @param recordId The ID of the event log record
     * @return CleverTap_Event__c The event log record with details
     */
    @AuraEnabled
    public static CleverTap_Event__c getEventDetails(Id recordId) {
        // Check CRUD permissions
        if (!Schema.SObjectType.CleverTap_Event__c.isAccessible()) {
            throw new AuraHandledException('You do not have access to event logs');
        }
        
        // Query the record
        List<CleverTap_Event__c> events = [
            SELECT Id, Name, Status__c, Response__c, CreatedDate, 
                   Lead__c, Lead__r.Name, Contact__c, Contact__r.Name
            FROM CleverTap_Event__c
            WHERE Id = :recordId
            LIMIT 1
        ];
        
        if (events.isEmpty()) {
            throw new AuraHandledException('Event log not found');
        }
        
        return events[0];
    }
}