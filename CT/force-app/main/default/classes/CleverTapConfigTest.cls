@isTest
private class CleverTapConfigTest {
    
    @isTest
    static void testGetCredentials() {
        // Create test data
        CleverTap_Config__c testConfig = new CleverTap_Config__c(
            Name = 'Test Config',
            Region__c = 'US',
            CleverTap_Account_ID__c = 'test-account-id',
            CleverTap_Passcode__c = 'test-passcode',
            CleverTap_API_URL__c = 'https://us1.api.clevertap.com/1/upload'
        );
        insert testConfig;
        
        // Test
        Test.startTest();
        Map<String, String> credentials = CleverTapConfig.getCredentials();
        Test.stopTest();
        
        // Verify
        System.assertNotEquals(null, credentials, 'Credentials should not be null');
        System.assertEquals('test-account-id', credentials.get('ACCOUNT_ID'), 'Account ID should match');
        System.assertEquals('test-passcode', credentials.get('PASSCODE'), 'Passcode should match');
        System.assertEquals('https://us1.api.clevertap.com/1/upload', credentials.get('API_URL'), 'API URL should match');
    }
    
    @isTest
    static void testGetCredentialsNoData() {
        // Test with no data
        Test.startTest();
        Map<String, String> credentials = CleverTapConfig.getCredentials();
        Test.stopTest();
        
        // Verify
        System.assertEquals(null, credentials, 'Credentials should be null when no config exists');
    }
}