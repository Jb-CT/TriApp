/**
 * @class CleverTapService
 * @description Service class for handling integration between Salesforce and CleverTap.
 * Provides methods for sending Salesforce records to CleverTap and processing the data transformation.
 */
public with sharing class CleverTapService {
    
    // API endpoints
    private static final String PROFILE_API_PATH = '/1/upload';
    private static final String EVENT_API_PATH = '/1/upload';
    
    /**
     * @description Sends a Salesforce record to CleverTap.
     * @param record The Salesforce record to be sent.
     * @param recordType The type of record being sent ('Lead', 'Contact', 'Account', 'Opportunity').
     */
    public static void sendToCleverTap(SObject record, String recordType) {
        if (record == null) {
            return;
        }
        
        try {
            // Check access and configurations
            if (!isConfigurationAccessible()) {
                return;
            }
            
            // Get all connection mappings for this record
            List<CleverTapDataMapper.ConnectionMapping> connectionMappings = 
                CleverTapDataMapper.mapToMultipleConnections(record, recordType);
            
            if (connectionMappings.isEmpty()) {
                return;
            }
            
            // Process each connection mapping
            for (CleverTapDataMapper.ConnectionMapping mapping : connectionMappings) {
                // Get credentials for this connection
                Map<String, String> credentials = getCredentialsForConnection(mapping.connectionId);
                if (!areCredentialsValid(credentials)) {
                    continue;
                }
                
                // Get the target entity type (profile or event)
                Boolean isEvent = (mapping.payload.get('type') == 'event');
                
                // Set the correct API endpoint
                credentials = adjustApiEndpoint(credentials, isEvent ? 'event' : 'profile');
                
                // Send to CleverTap
                HttpResponse response = sendRequest(credentials, mapping.payload);
                
                
                // Log the event
                String requestBody = getRequestBody(mapping.payload);
                CleverTapEventLogger.EventData eventData = new CleverTapEventLogger.EventData(
                    record.Id, recordType, response, requestBody
                );
                CleverTapEventLogger.logEvent(eventData);
                
            }
            
        } catch (Exception e) {
            // Log error event
            logErrorEvent(record.Id, recordType, e);
        }
    }
    
    /**
     * @description Gets the target entity type from the sync configuration
     * @param recordType The record type
     * @return The target entity type (profile or event)
     */
    private static String getTargetEntityType(String recordType) {
        if (!CleverTap_Sync_Configuration__c.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).isAccessible()) {
            return 'profile'; // Default to profile if no access
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
     * @description Adjusts the API endpoint in credentials based on target entity type
     * @param credentials The original credentials
     * @param targetEntityType The target entity type
     * @return Updated credentials with correct API endpoint
     */
    private static Map<String, String> adjustApiEndpoint(Map<String, String> credentials, String targetEntityType) {
        Map<String, String> adjustedCredentials = new Map<String, String>(credentials);
        
        // Base URL without path
        String baseUrl = credentials.get('API_URL');
        if (String.isBlank(baseUrl)) {
            return adjustedCredentials;
        }
        
        // Remove existing path if any
        Integer pathStart = baseUrl.indexOf('/1/');
        if (pathStart > 0) {
            baseUrl = baseUrl.substring(0, pathStart);
        }
        
        // Add appropriate path based on entity type
        String apiPath = (targetEntityType.toLowerCase() == 'event') ? EVENT_API_PATH : PROFILE_API_PATH;
        
        // Update the API URL
        adjustedCredentials.put('API_URL', baseUrl + apiPath);
        
        return adjustedCredentials;
    }
    
    /**
     * @description Wrapper method for sending Lead records to CleverTap.
     * @param lead The Lead record to be sent to CleverTap.
     */
    public static void sendLeadToCleverTap(Lead lead) {
        sendToCleverTap(lead, 'Lead');
    }
    
    /**
     * @description Wrapper method for sending Contact records to CleverTap.
     * @param contact The Contact record to be sent to CleverTap.
     */
    public static void sendContactToCleverTap(Contact contact) {
        sendToCleverTap(contact, 'Contact');
    }
    
    /**
     * @description Wrapper method for sending Account records to CleverTap.
     * @param account The Account record to be sent to CleverTap.
     */
    public static void sendAccountToCleverTap(Account account) {
        sendToCleverTap(account, 'Account');
    }
    
    /**
     * @description Wrapper method for sending Opportunity records to CleverTap.
     * @param opportunity The Opportunity record to be sent to CleverTap.
     */
    public static void sendOpportunityToCleverTap(Opportunity opportunity) {
        sendToCleverTap(opportunity, 'Opportunity');
    }
    
    /**
     * @description Checks if the configuration object is accessible
     * @return True if accessible, false otherwise
     * This method checks whether the CleverTap Sync Configuration object (CleverTap_Sync_Configuration__c) 
     * is accessible to the current Salesforce user.
     */
    private static Boolean isConfigurationAccessible() {
        return CleverTap_Sync_Configuration__c.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).isAccessible();
    }
    
    /**
     * @description Checks if a sync configuration exists for the record type
     * @param recordType The record type to check
     * @return True if configuration exists, false otherwise
     */
    private static Boolean hasSyncConfiguration(String recordType) {
        // Validate CRUD permission before SOQL operation
        if (!CleverTap_Sync_Configuration__c.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).isAccessible()) {
            return false;
        }
        
        List<CleverTap_Sync_Configuration__c> syncConfigs = [
            SELECT Id FROM CleverTap_Sync_Configuration__c 
            WHERE Salesforce_Entity__c = :recordType 
            AND Status__c = 'Active' 
            LIMIT 1
        ];
        return !syncConfigs.isEmpty();
    }
    
    /**
     * @description Checks if the credentials are valid
     * @param credentials The credentials to check
     * @return True if valid, false otherwise
     */
    private static Boolean areCredentialsValid(Map<String, String> credentials) {
        return (credentials != null && !credentials.isEmpty());
    }
    
    /**
     * @description Gets the request body as JSON
     * @param mappedRecord The mapped record
     * @return The JSON request body
     */
    private static String getRequestBody(Map<String, Object> mappedRecord) {
        Map<String, Object> payload = new Map<String, Object>{
            'd' => new List<Map<String, Object>>{mappedRecord}
        };
        return JSON.serialize(payload);
    }
    
    /**
     * @description Sends the HTTP request to CleverTap
     * @param credentials The API credentials
     * @param mappedRecord The record to send
     * @return The HTTP response
     */
    private static HttpResponse sendRequest(Map<String, String> credentials, Map<String, Object> mappedRecord) {
        String jsonBody = getRequestBody(mappedRecord);
        
        // Create and validate request
        ApiRequest request = new ApiRequest(credentials, jsonBody);
        if (request.hasMissingCredentials()) {
            return null;
        }
        
        // Prepare and send HTTP request
        HttpRequest req = prepareHttpRequest(request);
        Http http = new Http();
        return http.send(req);
    }
    
    /**
     * @description Prepares the HTTP request
     * @param request The API request
     * @return The prepared HTTP request
     */
    private static HttpRequest prepareHttpRequest(ApiRequest request) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(request.apiUrl);
        req.setMethod('POST');
        req.setTimeout(120000); // Set timeout to 120 seconds
        
        // Set headers
        for (String headerKey : request.headers.keySet()) {
            req.setHeader(headerKey, request.headers.get(headerKey));
        }
        req.setBody(request.jsonBody);
        
        return req;
    }
    
    /**
     * @description Logs an error event
     * @param recordId The record ID
     * @param recordType The record type
     * @param e The exception
     */
    private static void logErrorEvent(Id recordId, String recordType, Exception e) {
        
        CleverTapEventLogger.EventData eventData = new CleverTapEventLogger.EventData(
            recordId, recordType, null, 'Error: ' + e.getMessage()
        );
        CleverTapEventLogger.logEvent(eventData);
    }

    /**
     * @description Gets credentials for a specific connection
     * @param connectionId The connection ID
     * @return The API credentials
     */
    private static Map<String, String> getCredentialsForConnection(String connectionId) {
        // Query the specific connection by ID or developer name
        if (String.isBlank(connectionId)) {
            return CleverTapConfig.getCredentials(); // Fallback to default method
        }
        
        // Check CRUD permissions
        if (!CleverTap_Config__c.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).isAccessible()) {
            return null;
        }
        
        // Query the connection by ID
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
        
        // Build credentials map
        Map<String, String> credentials = new Map<String, String>{
            'NAME' => config.Name,
            'DEV_NAME' => config.Name,
            'API_URL' => config.CleverTap_API_URL__c,
            'ACCOUNT_ID' => config.CleverTap_Account_ID__c,
            'PASSCODE' => config.CleverTap_Passcode__c,
            'REGION' => config.Region__c
        };
        
        return credentials;
    }
}