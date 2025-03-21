/**
 * @class CleverTapEventLogger
 * @description Helper class for logging CleverTap integration events and errors.
 */
public with sharing class CleverTapEventLogger {
    
    /**
     * @description Event data wrapper class
     */
    public class EventData {
        public Id recordId;
        public String recordType;
        public HttpResponse response;
        public String requestBody;
        
        /**
         * @description Constructor for event data
         * @param recordId The ID of the Salesforce record
         * @param recordType The type of record
         * @param response The HTTP response from CleverTap
         * @param requestBody The request sent to CleverTap
         */
        public EventData(Id recordId, String recordType, HttpResponse response, String requestBody) {
            this.recordId = recordId;
            this.recordType = recordType;
            this.response = response;
            this.requestBody = requestBody;
        }
    }
    
    /**
     * @description Logs a CleverTap integration event
     * @param eventData The event data to log
     */
    public static void logEvent(EventData eventData) {
        try {
            // Check if we have create permission on CleverTap_Event__c
            if (!Schema.sObjectType.CleverTap_Event__c.isCreateable()) {
                return;
            }
            
            // Determine real success status based on both HTTP status and response content
            Boolean isSuccess = false;
            String responseBody = '';
            
            if (eventData.response != null) {
                responseBody = eventData.response.getBody();
                
                // First check HTTP status
                if (eventData.response.getStatusCode() == 200) {
                    // Then check response content for API success
                    try {
                        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(responseBody);
                        if (responseMap.containsKey('status')) {
                            isSuccess = 'success'.equalsIgnoreCase((String)responseMap.get('status'));
                        }
                    } catch (Exception e) {
                        // If can't parse JSON, default to HTTP status
                        isSuccess = true;
                    }
                }
            }
            
            // Create fields map dynamically
            Map<String, Object> fieldsMap = new Map<String, Object>{
                'Status__c' => isSuccess ? 'Success' : 'Failed',
                'Response__c' => responseBody != '' 
                    ? responseBody + '\nRequest: ' + eventData.requestBody 
                    : eventData.requestBody
            };
            
            // Add the record ID to the appropriate field based on type
            String fieldName = eventData.recordType + '__c';
            
            if (hasField(CleverTap_Event__c.SObjectType, fieldName)) {
                fieldsMap.put(fieldName, eventData.recordId);
            } else {
                // Fallback - store record ID in description
                fieldsMap.put('Response__c', eventData.recordType + ' ID: ' + eventData.recordId + '\n' + fieldsMap.get('Response__c'));
            }
            
            // Create the record using the dynamic fields map
            CleverTap_Event__c eventLog = new CleverTap_Event__c();
            for (String fName : fieldsMap.keySet()) {
                eventLog.put(fName, fieldsMap.get(fName));
            }
            
            insert eventLog;
        } catch (Exception e) {
            // Log the error since we can't propagate it
            //System.debug(LoggingLevel.ERROR, 'Error logging CleverTap event: ' + e.getMessage());
            //System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
        }
    }
    
    /**
     * @description Checks if an SObject type has a specific field
     * @param sObjType The SObject type to check
     * @param fieldName The field name to check for
     * @return True if the field exists, false otherwise
     */
    private static Boolean hasField(Schema.SObjectType sObjType, String fieldName) {
        Map<String, Schema.SObjectField> fieldMap = sObjType.getDescribe(SObjectDescribeOptions.DEFERRED).fields.getMap();
        return fieldMap.containsKey(fieldName);
    }
}