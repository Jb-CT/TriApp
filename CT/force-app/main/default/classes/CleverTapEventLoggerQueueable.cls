public class CleverTapEventLoggerQueueable implements Queueable {
    private List<EventDataWrapper> eventDataList;
    
    // Serializable wrapper class that doesn't contain HttpResponse
    public class EventDataWrapper {
        public Id recordId;
        public String recordType;
        public Integer statusCode;
        public String responseBody;
        public String requestBody;
        
        public EventDataWrapper(Id recordId, String recordType, HttpResponse response, String requestBody) {
            this.recordId = recordId;
            this.recordType = recordType;
            this.requestBody = requestBody;
            
            // Extract only what we need from HttpResponse
            if (response != null) {
                this.statusCode = response.getStatusCode();
                this.responseBody = response.getBody();
            }
        }
    }
    
    public CleverTapEventLoggerQueueable(List<CleverTapEventLogger.EventData> originalEventDataList) {
        this.eventDataList = new List<EventDataWrapper>();
        
        // Convert non-serializable EventData to serializable EventDataWrapper
        for (CleverTapEventLogger.EventData data : originalEventDataList) {
            HttpResponse response = data.response;
            EventDataWrapper wrapper = new EventDataWrapper(
                data.recordId,
                data.recordType,
                response,  // Will be extracted, not stored directly
                data.requestBody
            );
            this.eventDataList.add(wrapper);
        }
    }
    
    public void execute(QueueableContext context) {
        try {
            List<CleverTap_Event__c> logsToInsert = new List<CleverTap_Event__c>();
            
            for (EventDataWrapper eventData : eventDataList) {
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
                
                // Create event log record
                CleverTap_Event__c eventLog = new CleverTap_Event__c(
                    Status__c = isSuccess ? 'Success' : 'Failed',
                    Response__c = (String.isNotBlank(eventData.responseBody) ? 
                        eventData.responseBody + '\nRequest: ' + eventData.requestBody : 
                        eventData.requestBody)
                );
                
                // Add the record ID to the appropriate field based on type
                String fieldName = eventData.recordType + '__c';
                
                // Check if field exists before setting it
                if (Schema.SObjectType.CleverTap_Event__c.fields.getMap().containsKey(fieldName.toLowerCase())) {
                    eventLog.put(fieldName, eventData.recordId);
                } else {
                    eventLog.Response__c = eventData.recordType + ' ID: ' + eventData.recordId + '\n' + eventLog.Response__c;
                }
                
                logsToInsert.add(eventLog);
            }
            
            if (!logsToInsert.isEmpty()) {
                insert logsToInsert;
                System.debug('Successfully inserted ' + logsToInsert.size() + ' CleverTap event logs');
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in CleverTapEventLoggerQueueable: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
        }
    }
}