/**
 * @class CleverTapDataMapper
 * @description Helper class for mapping Salesforce records to CleverTap format.
 */
public with sharing class CleverTapDataMapper {
    
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
            // Fetch the sync configuration to get the target entity type (profile or event)
            String targetEntityType = getTargetEntityType(recordType);
            if (String.isBlank(targetEntityType)) {
                return null;
            }
            
            List<CleverTap_Mapping__c> fieldMappings = getFieldMappings(recordType);
            if (fieldMappings.isEmpty()) {
                return null;
            }
            
            CleverTap_Mapping__c identityMapping = findIdentityMapping(fieldMappings);
            if (identityMapping == null) {
                return null;
            }
            
            String identityValue = getIdentityValue(record, identityMapping);
            if (String.isBlank(identityValue)) {
                return null;
            }
            
            Map<String, Object> profileData = createProfileData(record, fieldMappings);
            return createFinalPayload(identityValue, profileData, targetEntityType, record, recordType);
        } catch (Exception e) {
            //System.debug(LoggingLevel.ERROR, 'Error mapping ' + recordType + ' to CleverTap: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Gets the target entity type (profile or event) from the sync configuration
     * @param recordType The record type
     * @return The target entity type (profile or event)
     */
    private static String getTargetEntityType(String recordType) {
        // Check CRUD permissions
        if (!CleverTap_Sync_Configuration__c.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).isAccessible()) {
            return null;
        }
        
        List<CleverTap_Sync_Configuration__c> configs = [
            SELECT CleverTap_Entity__c 
            FROM CleverTap_Sync_Configuration__c 
            WHERE Salesforce_Entity__c = :recordType 
            AND Status__c = 'Active'
            LIMIT 1
        ];
        
        if (configs.isEmpty()) {
            return 'profile'; // Default to profile if no configuration found
        }
        
        return configs[0].CleverTap_Entity__c;
    }
    
    /**
     * @description Gets the field mappings for a record type
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
     * @description Gets the identity value from the record
     * @param record The Salesforce record
     * @param identityMapping The identity mapping
     * @return The identity value
     */
    private static String getIdentityValue(SObject record, CleverTap_Mapping__c identityMapping) {
        return String.valueOf(record.get(identityMapping.Salesforce_Field__c));
    }
    
    /**
     * @description Creates the profile data map - MODIFIED to only include mapped fields
     * @param record The Salesforce record
     * @param fieldMappings The field mappings
     * @return The profile data map
     */
    private static Map<String, Object> createProfileData(SObject record, List<CleverTap_Mapping__c> fieldMappings) {
        Map<String, Object> profileData = new Map<String, Object>();
        
        // Process only the explicitly mapped fields
        for (CleverTap_Mapping__c mapping : fieldMappings) {
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
        
        // Add timestamp - we'll keep this as it's essential for CleverTap
        profileData.put('Timestamp', DateTime.now().format());
        
        return profileData;
    }
    
    /**
     * @description Creates the final payload based on the target entity type
     * @param identityValue The identity value
     * @param profileData The profile data
     * @param targetEntityType The target entity type (profile or event)
     * @param record The Salesforce record
     * @param recordType The record type
     * @return The final payload
     */
    private static Map<String, Object> createFinalPayload(String identityValue, Map<String, Object> profileData, 
                                                         String targetEntityType, SObject record, String recordType) {
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('identity', identityValue);
        payload.put('$source', 'SFDC');
        
        if (targetEntityType.toLowerCase() == 'event') {
            // For event type, we need to structure the payload differently
            payload.put('type', 'event');
            
            // Create an event name based on the record type
            String eventName = 'sf_' + recordType.toLowerCase();
            
            // For opportunities, we can be more specific about the event
            if (recordType == 'Opportunity') {
                Opportunity opp = (Opportunity)record;
                eventName = 'sf_opportunity_' + opp.StageName.toLowerCase().replaceAll(' ', '_');
            }
            
            payload.put('evtName', eventName);
            payload.put('evtData', profileData);
        } else {
            // Default to profile type
            payload.put('type', 'profile');
            payload.put('profileData', profileData);
        }
        
        return payload;
    }
}