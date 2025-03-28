public class CleverTapHistoricalSyncBatch implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {
    
    private String objectName;
    private String syncConfigId;
    private Integer recordsProcessed = 0;
    private Integer recordsSuccess = 0;
    private Integer recordsFailed = 0;
    private List<SerializableEventData> eventLogs = new List<SerializableEventData>();
    
    // Constants
    private final String PROFILE_API_PATH = '/1/upload';
    private final String EVENT_API_PATH = '/1/upload';
    
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
        for (SObject record : scope) {
            try {
                recordsProcessed++;
                
                // Process a single record
                System.debug('Processing record: ' + record.Id);
                
                // Get all active sync configurations for this record type
                List<CleverTap_Sync_Configuration__c> syncConfigs = [
                    SELECT Id, CleverTap_Entity__c, ConnectionId__c
                    FROM CleverTap_Sync_Configuration__c
                    WHERE Salesforce_Entity__c = :objectName
                    AND Status__c = 'Active'
                    AND Id = :syncConfigId
                ];
                
                if (syncConfigs.isEmpty()) {
                    continue;
                }
                
                // Get the config
                CleverTap_Sync_Configuration__c syncConfig = syncConfigs[0];
                
                // Get credentials
                Map<String, String> credentials = getCredentials(syncConfig.ConnectionId__c);
                
                if (credentials == null || credentials.isEmpty()) {
                    System.debug('No credentials found for connection: ' + syncConfig.ConnectionId__c);
                    continue;
                }
                
                // Map the record
                Map<String, Object> payload = mapRecord(record, syncConfig);
                
                if (payload == null) {
                    System.debug('Failed to map record: ' + record.Id);
                    continue;
                }
                
                // Send to CleverTap
                String requestBody = getRequestBody(payload);
                HttpResponse response = sendToCleverTap(credentials, payload, syncConfig.CleverTap_Entity__c);
                
                // Record success/failure
                if (response != null && response.getStatusCode() == 200) {
                    recordsSuccess++;
                    
                    // Store response for logging in finish method
                    eventLogs.add(new SerializableEventData(
                        record.Id, 
                        objectName, 
                        response.getStatusCode(),
                        response.getBody(),
                        requestBody
                    ));
                } else {
                    recordsFailed++;
                    
                    // Store error for logging
                    String responseBody = response != null ? response.getBody() : 'No response';
                    Integer statusCode = response != null ? response.getStatusCode() : 0;
                    
                    eventLogs.add(new SerializableEventData(
                        record.Id, 
                        objectName, 
                        statusCode,
                        responseBody,
                        requestBody
                    ));
                }
                
            } catch (Exception e) {
                recordsFailed++;
                System.debug(LoggingLevel.ERROR, 'Error processing record ' + record.Id + ': ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
                
                // Log the error
                eventLogs.add(new SerializableEventData(
                    record.Id, 
                    objectName, 
                    0,
                    'Error: ' + e.getMessage(),
                    'Exception during processing'
                ));
            }
        }
    }
    
    /**
     * @description Maps a record to CleverTap format
     * @param record The record to map
     * @param syncConfig The sync configuration
     * @return The mapped payload
     */
    private Map<String, Object> mapRecord(SObject record, CleverTap_Sync_Configuration__c syncConfig) {
        try {
            // Get field mappings
            List<CleverTap_Mapping__c> fieldMappings = [
                SELECT Id, CleverTap_Field__c, Salesforce_Field__c, 
                       Data_Type__c, Is_Mandatory__c
                FROM CleverTap_Mapping__c
                WHERE Sync_Configuration__c = :syncConfig.Id
            ];
            
            if (fieldMappings.isEmpty()) {
                return null;
            }
            
            // Find identity mapping
            CleverTap_Mapping__c identityMapping = null;
            for (CleverTap_Mapping__c mapping : fieldMappings) {
                if (mapping.Is_Mandatory__c && mapping.CleverTap_Field__c == 'customer_id') {
                    identityMapping = mapping;
                    break;
                }
            }
            
            if (identityMapping == null) {
                return null;
            }
            
            // Get identity value
            Object idValue = record.get(identityMapping.Salesforce_Field__c);
            if (idValue == null) {
                return null;
            }
            
            String identityValue = String.valueOf(idValue);
            
            // Create profile data
            Map<String, Object> profileData = new Map<String, Object>();
            for (CleverTap_Mapping__c mapping : fieldMappings) {
                if (mapping.Is_Mandatory__c || mapping.CleverTap_Field__c == 'customer_id') {
                    continue;
                }
                
                Object fieldValue = record.get(mapping.Salesforce_Field__c);
                if (fieldValue != null) {
                    profileData.put(mapping.CleverTap_Field__c, fieldValue);
                }
            }
            
            // Create final payload
            Map<String, Object> payload = new Map<String, Object>();
            payload.put('identity', identityValue);
            
            Boolean isEvent = (syncConfig.CleverTap_Entity__c == 'event');
            if (isEvent) {
                payload.put('type', 'event');
                payload.put('evtName', 'sf_' + objectName.toLowerCase());
                payload.put('evtData', profileData);
            } else {
                payload.put('type', 'profile');
                payload.put('profileData', profileData);
            }
            
            payload.put('$source', 'SFDC');
            return payload;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error mapping record: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Gets credentials for a connection ID
     * @param connectionId The connection ID
     * @return Map of credentials
     */
    private Map<String, String> getCredentials(String connectionId) {
        try {
            if (String.isBlank(connectionId)) {
                return null;
            }
            
            List<CleverTap_Config__c> configs = [
                SELECT Name, CleverTap_API_URL__c, CleverTap_Account_ID__c, 
                       CleverTap_Passcode__c, Region__c
                FROM CleverTap_Config__c
                WHERE Id = :connectionId OR Name = :connectionId
                LIMIT 1
            ];
            
            if (configs.isEmpty()) {
                return null;
            }
            
            CleverTap_Config__c config = configs[0];
            
            return new Map<String, String>{
                'NAME' => config.Name,
                'DEV_NAME' => config.Name,
                'API_URL' => config.CleverTap_API_URL__c,
                'ACCOUNT_ID' => config.CleverTap_Account_ID__c,
                'PASSCODE' => config.CleverTap_Passcode__c,
                'REGION' => config.Region__c
            };
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error getting credentials: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Creates the request body
     * @param payload The payload to send
     * @return The JSON request body
     */
    private String getRequestBody(Map<String, Object> payload) {
        Map<String, Object> requestPayload = new Map<String, Object>{
            'd' => new List<Map<String, Object>>{payload}
        };
        
        return JSON.serialize(requestPayload);
    }
    
    /**
     * @description Sends the request to CleverTap
     * @param credentials The credentials
     * @param payload The payload
     * @param entityType The entity type
     * @return The HTTP response
     */
    private HttpResponse sendToCleverTap(Map<String, String> credentials, Map<String, Object> payload, String entityType) {
        try {
            // Adjust endpoint based on entity type
            String baseUrl = credentials.get('API_URL');
            if (String.isBlank(baseUrl)) {
                return null;
            }
            
            // Remove existing path if any
            Integer pathStart = baseUrl.indexOf('/1/');
            if (pathStart > 0) {
                baseUrl = baseUrl.substring(0, pathStart);
            }
            
            // Add appropriate path based on entity type
            String apiPath = (entityType.toLowerCase() == 'event') ? EVENT_API_PATH : PROFILE_API_PATH;
            String apiUrl = baseUrl + apiPath;
            
            // Create request
            String jsonBody = getRequestBody(payload);
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(apiUrl);
            req.setMethod('POST');
            req.setTimeout(120000); // 2-minute timeout
            
            // Set headers
            req.setHeader('X-CleverTap-Account-Id', credentials.get('ACCOUNT_ID'));
            req.setHeader('X-CleverTap-Passcode', credentials.get('PASSCODE'));
            req.setHeader('Content-Type', 'application/json');
            req.setBody(jsonBody);
            
            // Send request
            Http http = new Http();
            return http.send(req);
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error sending to CleverTap: ' + e.getMessage());
            return null;
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
            System.debug('Inserted summary log: ' + syncLog.Id);
            
            // Now insert detailed logs
            if (!eventLogs.isEmpty()) {
                List<CleverTap_Event__c> detailedLogs = new List<CleverTap_Event__c>();
                
                for (SerializableEventData eventData : eventLogs) {
                    // Determine success status
                    Boolean isSuccess = false;
                    
                    if (eventData.statusCode == 200) {
                        try {
                            Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(eventData.responseBody);
                            if (responseMap.containsKey('status')) {
                                isSuccess = 'success'.equalsIgnoreCase((String)responseMap.get('status'));
                            }
                        } catch (Exception e) {
                            isSuccess = true; // Default to HTTP status
                        }
                    }
                    
                    // Create log record
                    CleverTap_Event__c eventLog = new CleverTap_Event__c(
                        Status__c = isSuccess ? 'Success' : 'Failed',
                        Response__c = String.isNotBlank(eventData.responseBody) ? 
                            eventData.responseBody + '\nRequest: ' + eventData.requestBody : 
                            eventData.requestBody
                    );
                    
                    // Add record ID to appropriate field
                    String fieldName = eventData.recordType + '__c';
                    if (Schema.SObjectType.CleverTap_Event__c.fields.getMap().containsKey(fieldName.toLowerCase())) {
                        eventLog.put(fieldName, eventData.recordId);
                    } else {
                        eventLog.Response__c = eventData.recordType + ' ID: ' + eventData.recordId + '\n' + eventLog.Response__c;
                    }
                    
                    detailedLogs.add(eventLog);
                }
                
                if (!detailedLogs.isEmpty()) {
                    insert detailedLogs;
                    System.debug('Inserted ' + detailedLogs.size() + ' detailed logs');
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error creating sync log: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
        }
    }
    
    /**
     * Helper class for storing event data
     */
    public class SerializableEventData {
        public Id recordId { get; set; }
        public String recordType { get; set; }
        public Integer statusCode { get; set; }
        public String responseBody { get; set; }
        public String requestBody { get; set; }
        
        public SerializableEventData(Id recordId, String recordType, Integer statusCode, String responseBody, String requestBody) {
            this.recordId = recordId;
            this.recordType = recordType;
            this.statusCode = statusCode;
            this.responseBody = responseBody;
            this.requestBody = requestBody;
        }
    }
}