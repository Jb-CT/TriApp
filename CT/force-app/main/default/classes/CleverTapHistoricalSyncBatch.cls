public class CleverTapHistoricalSyncBatch implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {
    
    private String objectName;
    private String syncConfigId;
    private Integer recordsProcessed = 0;
    private Integer recordsSuccess = 0;
    private Integer recordsFailed = 0;
    private List<SerializableEventData> eventLogs = new List<SerializableEventData>();
    
    // Constants renamed to follow camelCase naming convention
    private final String profileApiPath = '/1/upload';
    private final String eventApiPath = '/1/upload';
    
    // Cache for sync configuration and mappings
    private CleverTap_Sync_Configuration__c cachedSyncConfig;
    private List<CleverTap_Mapping__c> cachedFieldMappings;
    private Map<String, CleverTap_Mapping__c> specialMappings;
    
    /**
     * @description Constructor for the batch class
     * @param objectName The name of the object to sync
     * @param syncConfigId The ID of the sync configuration
     */
    public CleverTapHistoricalSyncBatch(String objectName, String syncConfigId) {
        this.objectName = objectName;
        this.syncConfigId = syncConfigId;
        this.specialMappings = new Map<String, CleverTap_Mapping__c>();
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
            // Get field mappings once
            List<CleverTap_Mapping__c> mappings = getFieldMappings();
            
            // Add each mapped field to our set, excluding special fields
            for (CleverTap_Mapping__c mapping : mappings) {
                // Skip event name mapping - this isn't a field to query
                if (mapping.CleverTap_Field__c == 'evtName') {
                    continue;
                }
                
                // Skip if field is empty
                if (String.isBlank(mapping.Salesforce_Field__c)) {
                    continue;
                }
                
                // Check if this looks like a Salesforce field
                if (isValidField(mapping.Salesforce_Field__c, objectName)) {
                    fields.add(mapping.Salesforce_Field__c);
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error fetching field mappings: ' + e.getMessage());
        }
        
        return fields;
    }

    /**
     * @description Checks if a field name appears to be a valid Salesforce field
     * @param fieldName The field name to check
     * @param objectType The Salesforce object type
     * @return Boolean True if it appears to be a valid field
     */
    private Boolean isValidField(String fieldName, String objectType) {
        // Check custom field or relationship field
        if (fieldName.contains('__c') || fieldName.contains('.')) {
            return true;
        }
        
        // Check standard field
        return isStandardField(fieldName, objectType);
    }

    /**
     * @description Checks if a field is a known standard field for an object type
     * @param fieldName The field name to check
     * @param objectType The Salesforce object type
     * @return Boolean True if it's a standard field
     */
    private Boolean isStandardField(String fieldName, String objectType) {
        // Common standard fields for most objects
        Set<String> commonFields = new Set<String>{'Id', 'Name', 'CreatedDate', 'LastModifiedDate', 'OwnerId'};
        if (commonFields.contains(fieldName)) {
            return true;
        }
        
        // Object-specific standard fields
        Map<String, Set<String>> objectFields = getObjectSpecificFields();
        
        return objectFields.containsKey(objectType) && 
               objectFields.get(objectType).contains(fieldName);
    }
    
    /**
     * @description Returns a map of object-specific standard fields
     * @return Map<String, Set<String>> Map of object types to their standard fields
     */
    private Map<String, Set<String>> getObjectSpecificFields() {
        return new Map<String, Set<String>>{
            'Lead' => new Set<String>{'Email', 'FirstName', 'LastName', 'Company', 'Status', 'Phone'},
            'Contact' => new Set<String>{'Email', 'FirstName', 'LastName', 'AccountId', 'Phone'},
            'Account' => new Set<String>{'Industry', 'Type', 'BillingCity', 'Phone'},
            'Opportunity' => new Set<String>{'Amount', 'CloseDate', 'StageName', 'AccountId'}
        };
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
        // Get sync config outside the loop
        CleverTap_Sync_Configuration__c syncConfig = getActiveSyncConfig();
        if (syncConfig == null) {
            return;
        }
        
        // Get credentials outside the loop
        Map<String, String> credentials = getCredentials(syncConfig.ConnectionId__c);
        if (credentials == null || credentials.isEmpty()) {
            System.debug('No credentials found for connection: ' + syncConfig.ConnectionId__c);
            return;
        }
        
        for (SObject record : scope) {
            processRecord(record, syncConfig, credentials);
        }
    }
    
    /**
     * @description Process a single record
     * @param record The record to process
     * @param syncConfig The sync configuration
     * @param credentials The API credentials
     */
    private void processRecord(SObject record, CleverTap_Sync_Configuration__c syncConfig, Map<String, String> credentials) {
        try {
            recordsProcessed++;
            
            // Map the record
            Map<String, Object> payload = mapRecord(record, syncConfig);
            if (payload == null) {
                System.debug('Failed to map record: ' + record.Id);
                return;
            }
            
            // Send to CleverTap
            String requestBody = getRequestBody(payload);
            HttpResponse response = sendToCleverTap(credentials, payload, syncConfig.CleverTap_Entity__c);
            
            // Log the result
            logResult(record, response, requestBody);
        } catch (Exception e) {
            logError(record, e);
        }
    }
    
    /**
     * @description Log a successful result
     * @param record The record that was processed
     * @param response The HTTP response
     * @param requestBody The request body
     */
    private void logResult(SObject record, HttpResponse response, String requestBody) {
        if (response != null && response.getStatusCode() == 200) {
            recordsSuccess++;
        } else {
            recordsFailed++;
        }
        
        // Create serializable event data for logging
        SerializableEventData eventData = new SerializableEventData();
        eventData.recordId = record.Id;
        eventData.recordType = objectName;
        
        if (response != null) {
            eventData.statusCode = response.getStatusCode();
            eventData.responseBody = response.getBody();
        } else {
            eventData.statusCode = 0;
            eventData.responseBody = 'No response';
        }
        
        eventData.requestBody = requestBody;
        eventLogs.add(eventData);
    }
    
    /**
     * @description Log an error
     * @param record The record that failed
     * @param e The exception
     */
    private void logError(SObject record, Exception e) {
        recordsFailed++;
        System.debug(LoggingLevel.ERROR, 'Error processing record ' + record.Id + ': ' + e.getMessage());
        
        // Create serializable event data for logging
        SerializableEventData eventData = new SerializableEventData();
        eventData.recordId = record.Id;
        eventData.recordType = objectName;
        eventData.statusCode = 0;
        eventData.responseBody = 'Error: ' + e.getMessage();
        eventData.requestBody = 'Exception during processing';
        
        eventLogs.add(eventData);
    }
    
    /**
     * @description Get the active sync configuration
     * @return CleverTap_Sync_Configuration__c The sync configuration
     */
    private CleverTap_Sync_Configuration__c getActiveSyncConfig() {
        // Return cached value if available
        if (cachedSyncConfig != null) {
            return cachedSyncConfig;
        }
        
        List<CleverTap_Sync_Configuration__c> syncConfigs = [
            SELECT Id, CleverTap_Entity__c, ConnectionId__c
            FROM CleverTap_Sync_Configuration__c
            WHERE Salesforce_Entity__c = :objectName
            AND Status__c = 'Active'
            AND Id = :syncConfigId
            LIMIT 1
        ];
        
        cachedSyncConfig = syncConfigs.isEmpty() ? null : syncConfigs[0];
        return cachedSyncConfig;
    }
    
    /**
     * @description Get field mappings for the sync configuration
     * @return List<CleverTap_Mapping__c> The field mappings
     */
    private List<CleverTap_Mapping__c> getFieldMappings() {
        // Return cached mappings if available
        if (cachedFieldMappings != null) {
            return cachedFieldMappings;
        }
        
        cachedFieldMappings = [
            SELECT Id, CleverTap_Field__c, Salesforce_Field__c, 
                Data_Type__c, Is_Mandatory__c
            FROM CleverTap_Mapping__c
            WHERE Sync_Configuration__c = :syncConfigId
        ];
        
        // Cache special mappings
        for (CleverTap_Mapping__c mapping : cachedFieldMappings) {
            if (mapping.Is_Mandatory__c && mapping.CleverTap_Field__c == 'customer_id') {
                specialMappings.put('customer_id', mapping);
            } else if (mapping.CleverTap_Field__c == 'evtName') {
                specialMappings.put('evtName', mapping);
            }
        }
        
        return cachedFieldMappings;
    }
    
    /**
     * @description Maps a record to CleverTap format
     * @param record The record to map
     * @param syncConfig The sync configuration
     * @return The mapped payload
     */
    private Map<String, Object> mapRecord(SObject record, CleverTap_Sync_Configuration__c syncConfig) {
        try {
            // Make sure we have field mappings
            List<CleverTap_Mapping__c> fieldMappings = getFieldMappings();
            if (fieldMappings.isEmpty()) {
                return null;
            }
            
            // Get customer_id mapping
            CleverTap_Mapping__c identityMapping = specialMappings.get('customer_id');
            if (identityMapping == null) {
                System.debug('No customer_id mapping found');
                return null;
            }
            
            // Get identity value
            Object idValue = record.get(identityMapping.Salesforce_Field__c);
            if (idValue == null) {
                System.debug('Identity value is null for record: ' + record.Id);
                return null;
            }
            
            String identityValue = String.valueOf(idValue);
            
            // Create profile data
            Map<String, Object> profileData = createProfileData(record, fieldMappings);
            
            // Create final payload
            return createFinalPayload(identityValue, profileData, syncConfig.CleverTap_Entity__c);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error mapping record: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Creates profile data from record fields
     * @param record The Salesforce record
     * @param fieldMappings The field mappings
     * @return Map<String, Object> The profile data
     */
    private Map<String, Object> createProfileData(SObject record, List<CleverTap_Mapping__c> fieldMappings) {
        Map<String, Object> profileData = new Map<String, Object>();
        
        for (CleverTap_Mapping__c mapping : fieldMappings) {
            // Skip special mappings
            if (mapping.Is_Mandatory__c || 
                mapping.CleverTap_Field__c == 'customer_id' ||
                mapping.CleverTap_Field__c == 'evtName') {
                continue;
            }
            
            // Skip if not a valid field or if field value is null
            if (String.isBlank(mapping.Salesforce_Field__c) || 
                !record.getPopulatedFieldsAsMap().containsKey(mapping.Salesforce_Field__c)) {
                continue;
            }
            
            // Get and convert field value
            Object fieldValue = record.get(mapping.Salesforce_Field__c);
            if (fieldValue != null) {
                Object convertedValue = CleverTapDataConverter.convertFieldValue(
                    fieldValue, mapping.Data_Type__c
                );
                profileData.put(mapping.CleverTap_Field__c, convertedValue);
            }
        }
        
        return profileData;
    }
    
    /**
     * @description Creates the final payload for CleverTap
     * @param identityValue The identity value
     * @param profileData The profile data
     * @param entityType The entity type (profile/event)
     * @return Map<String, Object> The final payload
     */
    private Map<String, Object> createFinalPayload(String identityValue, Map<String, Object> profileData, String entityType) {
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('identity', identityValue);
        
        Boolean isEvent = (entityType == 'event');
        if (isEvent) {
            payload.put('type', 'event');
            
            // Get event name
            String eventName = getEventName();
            
            payload.put('evtName', eventName);
            payload.put('evtData', profileData);
        } else {
            payload.put('type', 'profile');
            payload.put('profileData', profileData);
        }
        
        payload.put('$source', 'SFDC');
        return payload;
    }
    
    /**
     * @description Gets the event name from mapping or default
     * @return String The event name
     */
    private String getEventName() {
        CleverTap_Mapping__c eventNameMapping = specialMappings.get('evtName');
        
        if (eventNameMapping != null && String.isNotBlank(eventNameMapping.Salesforce_Field__c)) {
            return eventNameMapping.Salesforce_Field__c;
        } else {
            return 'sf_' + objectName.toLowerCase();
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
            // Get the API URL
            String apiUrl = buildApiUrl(credentials.get('API_URL'), entityType);
            if (String.isBlank(apiUrl)) {
                return null;
            }
            
            // Create request
            String jsonBody = getRequestBody(payload);
            HttpRequest req = createHttpRequest(apiUrl, credentials, jsonBody);
            
            // Send request
            Http http = new Http();
            return http.send(req);
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error sending to CleverTap: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Builds the API URL based on entity type
     * @param baseUrl The base URL
     * @param entityType The entity type
     * @return String The complete API URL
     */
    private String buildApiUrl(String baseUrl, String entityType) {
        if (String.isBlank(baseUrl)) {
            return null;
        }
        
        // Remove existing path if any
        Integer pathStart = baseUrl.indexOf('/1/');
        if (pathStart > 0) {
            baseUrl = baseUrl.substring(0, pathStart);
        }
        
        // Add appropriate path based on entity type
        String apiPath = (entityType.toLowerCase() == 'event') ? eventApiPath : profileApiPath;
        return baseUrl + apiPath;
    }
    
    /**
     * @description Creates an HTTP request
     * @param apiUrl The API URL
     * @param credentials The credentials
     * @param jsonBody The request body
     * @return HttpRequest The HTTP request
     */
    private HttpRequest createHttpRequest(String apiUrl, Map<String, String> credentials, String jsonBody) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(apiUrl);
        req.setMethod('POST');
        req.setTimeout(120000); // 2-minute timeout
        
        // Set headers
        req.setHeader('X-CleverTap-Account-Id', credentials.get('ACCOUNT_ID'));
        req.setHeader('X-CleverTap-Passcode', credentials.get('PASSCODE'));
        req.setHeader('Content-Type', 'application/json');
        req.setBody(jsonBody);
        
        return req;
    }
    
    /**
     * @description Finish method to handle completion of the batch process
     * @param bc The batch context
     */
    public void finish(Database.BatchableContext bc) {
        // Create a log entry for the historical sync
        //createSummaryLog();
        
        // Create detailed logs
        createDetailedLogs();
    }
    
    /**
     * @description Creates a summary log entry
     */
    private void createSummaryLog() {
        try {
            CleverTap_Event__c syncLog = new CleverTap_Event__c(
                Status__c = (recordsFailed == 0) ? 'Success' : 'Failed',
                Response__c = buildSummaryLogMessage()
            );
            
            insert syncLog;
            System.debug('Inserted summary log: ' + syncLog.Id);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error creating summary log: ' + e.getMessage());
        }
    }
    
    /**
     * @description Builds the summary log message
     * @return String The summary message
     */
    private String buildSummaryLogMessage() {
        return 'Historical sync completed.\n' +
               'Records processed: ' + recordsProcessed + '\n' +
               'Records succeeded: ' + recordsSuccess + '\n' +
               'Records failed: ' + recordsFailed + '\n' +
               'Sync Configuration ID: ' + syncConfigId;
    }
    
    /**
     * @description Creates detailed log entries
     */
    private void createDetailedLogs() {
        if (eventLogs.isEmpty()) {
            return;
        }
        
        try {
            List<CleverTap_Event__c> detailedLogs = new List<CleverTap_Event__c>();
            
            for (SerializableEventData eventData : eventLogs) {
                // Determine success status
                Boolean isSuccess = determineSuccess(eventData);
                
                // Create log record
                CleverTap_Event__c eventLog = createDetailedLogEntry(eventData, isSuccess);
                detailedLogs.add(eventLog);
            }
            
            if (!detailedLogs.isEmpty()) {
                insert detailedLogs;
                System.debug('Inserted ' + detailedLogs.size() + ' detailed logs');
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error creating detailed logs: ' + e.getMessage());
        }
    }
    
    /**
     * @description Determines if the result was successful
     * @param eventData The event data
     * @return Boolean True if successful
     */
    private Boolean determineSuccess(SerializableEventData eventData) {
        if (eventData.statusCode != 200) {
            return false;
        }
        
        try {
            Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(eventData.responseBody);
            if (responseMap.containsKey('status')) {
                return 'success'.equalsIgnoreCase((String)responseMap.get('status'));
            }
        } catch (Exception e) {
            // If can't parse JSON, default to HTTP status
            return true;
        }
        
        return true;
    }
    
    /**
     * @description Creates a detailed log entry
     * @param eventData The event data
     * @param isSuccess Whether the operation was successful
     * @return CleverTap_Event__c The log entry
     */
    private CleverTap_Event__c createDetailedLogEntry(SerializableEventData eventData, Boolean isSuccess) {
        CleverTap_Event__c eventLog = new CleverTap_Event__c(
            Status__c = isSuccess ? 'Success' : 'Failed',
            Response__c = buildDetailedLogMessage(eventData)
        );
        
        // Add record ID to appropriate field
        setEventRecordReference(eventLog, eventData);
        
        return eventLog;
    }
    
    /**
     * @description Builds a detailed log message
     * @param eventData The event data
     * @return String The detailed message
     */
    private String buildDetailedLogMessage(SerializableEventData eventData) {
        return String.isNotBlank(eventData.responseBody) ? 
            eventData.responseBody + '\nRequest: ' + eventData.requestBody : 
            eventData.requestBody;
    }
    
    /**
     * @description Sets the record reference on the event log
     * @param eventLog The event log
     * @param eventData The event data
     */
    private void setEventRecordReference(CleverTap_Event__c eventLog, SerializableEventData eventData) {
        String fieldName = eventData.recordType + '__c';
        Map<String, Schema.SObjectField> fieldsMap = Schema.SObjectType.CleverTap_Event__c.fields.getMap();
        
        if (fieldsMap.containsKey(fieldName.toLowerCase())) {
            eventLog.put(fieldName, eventData.recordId);
        } else {
            eventLog.Response__c = eventData.recordType + ' ID: ' + eventData.recordId + '\n' + eventLog.Response__c;
        }
    }
    
    /**
     * Helper class for storing event data - simplified to reduce parameter list
     */
    public class SerializableEventData {
        public Id recordId;
        public String recordType;
        public Integer statusCode;
        public String responseBody;
        public String requestBody;
    }
}