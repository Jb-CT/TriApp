/**
 * @class CleverTapDataMapper
 * @description Helper class for mapping Salesforce records to CleverTap format.
 */
public with sharing class CleverTapDataMapper {
    
    /**
     * @description Inner class to hold connection mappings
     */
    public class ConnectionMapping {
        public String connectionId { get; set; }
        public Map<String, Object> payload { get; set; }
    }
    
    /**
     * @description Maps a Salesforce record to CleverTap format
     * @param record The Salesforce record to map
     * @param recordType The type of record
     * @return The mapped record in CleverTap format
     */
    public static Map<String, Object> mapToCleverTap(SObject record, String recordType) {
        if (record == null) {
            return null;
        }
        
        try {
            // Use the multi-connection method but return only the first result
            List<ConnectionMapping> mappings = mapToMultipleConnections(record, recordType);
            if (!mappings.isEmpty()) {
                return mappings[0].payload;
            }
            return null;
        } catch (Exception e) {
            //System.debug(LoggingLevel.ERROR, 'Error mapping ' + recordType + ' to CleverTap: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Maps a Salesforce record to CleverTap format for all active connections
     * @param record The Salesforce record to map
     * @param recordType The type of record
     * @return List of mapped records with their corresponding configurations
     */
    public static List<ConnectionMapping> mapToMultipleConnections(SObject record, String recordType) {
        if (record == null) {
            return new List<ConnectionMapping>();
        }
        
        List<ConnectionMapping> allMappings = new List<ConnectionMapping>();
        
        try {
            // Get all active sync configurations for this record type
            List<CleverTap_Sync_Configuration__c> syncConfigs = getAllSyncConfigurations(recordType);
            if (syncConfigs.isEmpty()) {
                return allMappings;
            }
            
            // Process each sync configuration
            for (CleverTap_Sync_Configuration__c syncConfig : syncConfigs) {
                // Get the field mappings for this configuration
                List<CleverTap_Mapping__c> fieldMappings = getFieldMappingsForConfig(syncConfig.Id);
                if (fieldMappings.isEmpty()) {
                    continue;
                }
                
                // Find the identity mapping
                CleverTap_Mapping__c identityMapping = findIdentityMapping(fieldMappings);
                if (identityMapping == null) {
                    continue;
                }
                
                // Get identity value
                String identityValue = getIdentityValue(record, identityMapping);
                if (String.isBlank(identityValue)) {
                    continue;
                }
                
                // Get event name mapping (if exists)
                CleverTap_Mapping__c eventNameMapping = findEventNameMapping(fieldMappings);
                String eventName = (eventNameMapping != null) ? 
                    String.valueOf(eventNameMapping.Salesforce_Field__c) : null;
                
                // Determine if this is an event or profile update
                Boolean isEvent = (syncConfig.CleverTap_Entity__c == 'event');
                
                // Create profile data
                Map<String, Object> profileData = createProfileData(record, fieldMappings);
                
                // Create the CleverTap payload
                Map<String, Object> payload = createFinalPayload(identityValue, profileData, eventName, isEvent);
                
                // Add to the list of mappings
                ConnectionMapping mapping = new ConnectionMapping();
                mapping.connectionId = syncConfig.ConnectionId__c;
                mapping.payload = payload;
                allMappings.add(mapping);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error mapping ' + recordType + ' to CleverTap: ' + e.getMessage());
        }
        
        return allMappings;
    }
    
    /**
     * @description Gets all active sync configurations for a record type
     * @param recordType The record type
     * @return List of sync configurations
     */
    private static List<CleverTap_Sync_Configuration__c> getAllSyncConfigurations(String recordType) {
        // Check CRUD permissions
        if (!CleverTap_Sync_Configuration__c.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).isAccessible()) {
            return new List<CleverTap_Sync_Configuration__c>();
        }
        
        return [
            SELECT Id, CleverTap_Entity__c, ConnectionId__c
            FROM CleverTap_Sync_Configuration__c
            WHERE Salesforce_Entity__c = :recordType
            AND Status__c = 'Active'
        ];
    }
    
    /**
     * @description Gets the field mappings for a specific configuration
     * @param configId The configuration ID
     * @return List of field mappings
     */
    private static List<CleverTap_Mapping__c> getFieldMappingsForConfig(Id configId) {
        // Check CRUD permissions
        if (!CleverTap_Mapping__c.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).isAccessible()) {
            return new List<CleverTap_Mapping__c>();
        }
        
        return [
            SELECT Id, CleverTap_Field__c, Salesforce_Field__c, 
                   Data_Type__c, Is_Mandatory__c
            FROM CleverTap_Mapping__c
            WHERE Sync_Configuration__c = :configId
        ];
    }
    
    /**
     * @description Gets the field mappings for a record type (legacy method for backward compatibility)
     * @param recordType The record type
     * @return List of field mappings
     */
    private static List<CleverTap_Mapping__c> getFieldMappings(String recordType) {
        // Check CRUD permissions
        if (!CleverTap_Mapping__c.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).isAccessible() || 
            !CleverTap_Sync_Configuration__c.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).isAccessible()) {
            return new List<CleverTap_Mapping__c>();
        }
        
        return [
            SELECT Id, CleverTap_Field__c, Salesforce_Field__c, 
                   Data_Type__c, Is_Mandatory__c
            FROM CleverTap_Mapping__c
            WHERE Sync_Configuration__c IN (
                SELECT Id FROM CleverTap_Sync_Configuration__c 
                WHERE Salesforce_Entity__c = :recordType 
                AND Status__c = 'Active'
            )
        ];
    }
    
    /**
     * @description Gets the active sync configuration for a record type (legacy method for backward compatibility)
     * @param recordType The record type
     * @return The sync configuration
     */
    private static CleverTap_Sync_Configuration__c getSyncConfiguration(String recordType) {
        // Check CRUD permissions
        if (!CleverTap_Sync_Configuration__c.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).isAccessible()) {
            return null;
        }
        
        List<CleverTap_Sync_Configuration__c> configs = [
            SELECT Id, CleverTap_Entity__c
            FROM CleverTap_Sync_Configuration__c
            WHERE Salesforce_Entity__c = :recordType
            AND Status__c = 'Active'
            LIMIT 1
        ];
        
        return configs.isEmpty() ? null : configs[0];
    }
    
    /**
     * @description Finds the identity mapping (customer_id)
     * @param fieldMappings The list of field mappings
     * @return The identity mapping
     */
    private static CleverTap_Mapping__c findIdentityMapping(List<CleverTap_Mapping__c> fieldMappings) {
        for (CleverTap_Mapping__c mapping : fieldMappings) {
            if (mapping.Is_Mandatory__c && mapping.CleverTap_Field__c == 'customer_id') {
                return mapping;
            }
        }
        return null;
    }
    
    /**
     * @description Finds the event name mapping (evtName)
     * @param fieldMappings The list of field mappings
     * @return The event name mapping
     */
    private static CleverTap_Mapping__c findEventNameMapping(List<CleverTap_Mapping__c> fieldMappings) {
        for (CleverTap_Mapping__c mapping : fieldMappings) {
            if (mapping.Is_Mandatory__c && mapping.CleverTap_Field__c == 'evtName') {
                return mapping;
            }
        }
        return null;
    }
    
    /**
     * @description Gets the identity value from the record
     * @param record The Salesforce record
     * @param identityMapping The identity mapping
     * @return The identity value
     */
    private static String getIdentityValue(SObject record, CleverTap_Mapping__c identityMapping) {
        return String.valueOf(record.get(identityMapping.Salesforce_Field__c));
    }
    
    /**
     * @description Creates the profile data map
     * @param record The Salesforce record
     * @param fieldMappings The field mappings
     * @return The profile data map
     */
    private static Map<String, Object> createProfileData(SObject record, List<CleverTap_Mapping__c> fieldMappings) {
        Map<String, Object> profileData = new Map<String, Object>();
        
        // Process only the explicitly mapped fields
        for (CleverTap_Mapping__c mapping : fieldMappings) {
            // Skip mandatory fields (handled separately)
            if (mapping.Is_Mandatory__c || 
                mapping.CleverTap_Field__c == 'customer_id' || 
                mapping.CleverTap_Field__c == 'evtName') {
                continue;
            }
            
            // Skip if the field value is null
            Object fieldValue = record.get(mapping.Salesforce_Field__c);
            if (fieldValue == null) {
                continue;
            }
            
            // Convert and add the field value to the profile data
            Object convertedValue = CleverTapDataConverter.convertFieldValue(
                fieldValue, mapping.Data_Type__c
            );
            profileData.put(mapping.CleverTap_Field__c, convertedValue);
        }
        
        return profileData;
    }
    
    /**
     * @description Creates the final payload
     * @param identityValue The identity value
     * @param profileData The profile data
     * @param eventName The event name (if provided)
     * @param isEvent Whether this should be sent as an event
     * @return The final payload
     */
    private static Map<String, Object> createFinalPayload(String identityValue, Map<String, Object> profileData, 
                                                         String eventName, Boolean isEvent) {
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('identity', identityValue);
        
        // Only send as event if both conditions are met:
        // 1. The sync configuration target entity is 'event'
        // 2. An event name is provided
        if (isEvent && String.isNotBlank(eventName)) {
            payload.put('type', 'event');
            payload.put('evtName', eventName);
            payload.put('evtData', profileData);
        } else {
            payload.put('type', 'profile');
            payload.put('profileData', profileData);
        }
        
        payload.put('$source', 'SFDC');
        return payload;
    }
}