public with sharing class IntegrationConfigController {
    
    private static Map<String, String> regionToUrl = new Map<String, String>{
        'US' => 'https://us1.api.clevertap.com/1/upload',
        'IN' => 'https://in1.api.clevertap.com/1/upload',
        'EU' => 'https://eu1.api.clevertap.com/1/upload',
        'SG' => 'https://sg1.api.clevertap.com/1/upload',
        'UAE' => 'https://mec1.api.clevertap.com/1/upload',
        'ID' => 'https://aps3.api.clevertap.com/1/upload'
    };
    
    @AuraEnabled(cacheable=true)
    public static List<CleverTap_Config__c> getConfigurations() {
        try {
            if (!Schema.SObjectType.CleverTap_Config__c.isAccessible()) {
                throw new AuraHandledException('You do not have access to integration configurations');
            }

            List<CleverTap_Config__c> configs = [
                SELECT Id, Name, CleverTap_Account_ID__c, 
                       CleverTap_Passcode__c, Region__c, CleverTap_API_URL__c
                FROM CleverTap_Config__c
                WHERE Name != '[Deleted]%'
                ORDER BY Name
            ];
            
            return configs;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching configurations: ' + e.getMessage());
        }
    }

    /**
     * @description Validates CleverTap credentials before saving them
     * @param region The CleverTap region
     * @param accountId The CleverTap Account ID
     * @param passcode The CleverTap Passcode
     * @return ValidationResult with status and message
     */
    @AuraEnabled
    public static CleverTapCredentialValidator.ValidationResult validateCredentials(
        String region, String accountId, String passcode
    ) {
        return CleverTapCredentialValidator.validateCredentials(region, accountId, passcode);
    }

    @AuraEnabled
    public static String saveConfiguration(Map<String, Object> config) {
        try {
            // Validation
            validateConfigData(config);

            CleverTap_Config__c newConfig;
            
            // Check if this is an update (has ID) or a new record
            if (config.containsKey('id') && String.isNotBlank((String)config.get('id'))) {
                // Update existing record
                newConfig = [SELECT Id FROM CleverTap_Config__c WHERE Id = :(String)config.get('id') LIMIT 1];
            } else {
                // Create new record
                newConfig = new CleverTap_Config__c();
            }
            
            // Set the fields
            newConfig.Name = (String)config.get('name');
            newConfig.Region__c = (String)config.get('region');
            newConfig.CleverTap_Account_ID__c = (String)config.get('accountId');
            newConfig.CleverTap_Passcode__c = (String)config.get('passcode');
            newConfig.CleverTap_API_URL__c = regionToUrl.get(((String)config.get('region')).toUpperCase());
            
            // Save the record
            upsert newConfig;
            
            return 'Success';
        } catch (Exception e) {
            throw new AuraHandledException('Error saving configuration: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String deleteConfiguration(String configId) {
        try {
            if (String.isBlank(configId)) {
                throw new AuraHandledException('Configuration ID is required for deletion');
            }
            
            // Find the record
            CleverTap_Config__c config = [SELECT Id FROM CleverTap_Config__c WHERE Id = :configId LIMIT 1];
            
            if (config == null) {
                throw new AuraHandledException('Configuration not found');
            }
            
            // Perform hard delete
            delete config;
            
            return 'Success';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    private static void validateConfigData(Map<String, Object> config) {
        if (!config.containsKey('name') || String.isBlank((String)config.get('name'))) {
            throw new AuraHandledException('Connection name is required');
        }

        String region = (String)config.get('region');
        if (String.isBlank(region)) {
            throw new AuraHandledException('Region is required');
        }
    }
}