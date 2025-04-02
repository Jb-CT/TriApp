@isTest
private class CleverTapDataMapperTest {
    
    @testSetup
    static void setupTestData() {
        // Create test account
        Account testAccount = new Account(
            Name = 'Test Account'
        );
        insert testAccount;
        
        // Create test contact
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = 'test.contact@example.com',
            AccountId = testAccount.Id
        );
        insert testContact;
        
        // Create test lead
        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = 'Lead',
            Email = 'test.lead@example.com',
            Company = 'Test Company'
        );
        insert testLead;
        
        // Create active sync configuration for Lead
        CleverTap_Sync_Configuration__c leadConfig = new CleverTap_Sync_Configuration__c(
            Name = 'Test Lead Config',
            Salesforce_Entity__c = 'Lead',
            CleverTap_Entity__c = 'profile',
            Status__c = 'Active',
            Sync_Type__c = 'salesforce_to_clevertap',
            ConnectionId__c = 'TEST_CONN_ID_1'
        );
        insert leadConfig;
        
        // Create field mappings for Lead
        List<CleverTap_Mapping__c> leadMappings = new List<CleverTap_Mapping__c>{
            new CleverTap_Mapping__c(
                Sync_Configuration__c = leadConfig.Id,
                CleverTap_Field__c = 'customer_id',
                Salesforce_Field__c = 'Email',
                Data_Type__c = 'Text',
                Is_Mandatory__c = true
            ),
            new CleverTap_Mapping__c(
                Sync_Configuration__c = leadConfig.Id,
                CleverTap_Field__c = 'first_name',
                Salesforce_Field__c = 'FirstName',
                Data_Type__c = 'Text',
                Is_Mandatory__c = false
            ),
            new CleverTap_Mapping__c(
                Sync_Configuration__c = leadConfig.Id,
                CleverTap_Field__c = 'last_name',
                Salesforce_Field__c = 'LastName',
                Data_Type__c = 'Text',
                Is_Mandatory__c = false
            )
        };
        insert leadMappings;
        
        // Create active sync configuration for Lead as Event
        CleverTap_Sync_Configuration__c leadEventConfig = new CleverTap_Sync_Configuration__c(
            Name = 'Test Lead Event Config',
            Salesforce_Entity__c = 'Lead',
            CleverTap_Entity__c = 'event',
            Status__c = 'Active',
            Sync_Type__c = 'salesforce_to_clevertap',
            ConnectionId__c = 'TEST_CONN_ID_2'
        );
        insert leadEventConfig;
        
        // Create field mappings for Lead Event
        List<CleverTap_Mapping__c> leadEventMappings = new List<CleverTap_Mapping__c>{
            new CleverTap_Mapping__c(
                Sync_Configuration__c = leadEventConfig.Id,
                CleverTap_Field__c = 'customer_id',
                Salesforce_Field__c = 'Email',
                Data_Type__c = 'Text',
                Is_Mandatory__c = true
            ),
            new CleverTap_Mapping__c(
                Sync_Configuration__c = leadEventConfig.Id,
                CleverTap_Field__c = 'evtName',
                Salesforce_Field__c = 'sf_lead_created',
                Data_Type__c = 'Text',
                Is_Mandatory__c = true
            ),
            new CleverTap_Mapping__c(
                Sync_Configuration__c = leadEventConfig.Id,
                CleverTap_Field__c = 'company',
                Salesforce_Field__c = 'Company',
                Data_Type__c = 'Text',
                Is_Mandatory__c = false
            )
        };
        insert leadEventMappings;
        
        // Create active sync configuration for Contact
        CleverTap_Sync_Configuration__c contactConfig = new CleverTap_Sync_Configuration__c(
            Name = 'Test Contact Config',
            Salesforce_Entity__c = 'Contact',
            CleverTap_Entity__c = 'profile',
            Status__c = 'Active',
            Sync_Type__c = 'salesforce_to_clevertap',
            ConnectionId__c = 'TEST_CONN_ID_3'
        );
        insert contactConfig;
        
        // Create field mappings for Contact
        List<CleverTap_Mapping__c> contactMappings = new List<CleverTap_Mapping__c>{
            new CleverTap_Mapping__c(
                Sync_Configuration__c = contactConfig.Id,
                CleverTap_Field__c = 'customer_id',
                Salesforce_Field__c = 'Email',
                Data_Type__c = 'Text',
                Is_Mandatory__c = true
            ),
            new CleverTap_Mapping__c(
                Sync_Configuration__c = contactConfig.Id,
                CleverTap_Field__c = 'name',
                Salesforce_Field__c = 'LastName',
                Data_Type__c = 'Text',
                Is_Mandatory__c = false
            )
        };
        insert contactMappings;
    }
    
    @isTest
    static void testMapToCleverTapWithLead() {
        // Get test Lead
        Lead testLead = [SELECT Id, FirstName, LastName, Email, Company FROM Lead LIMIT 1];
        
        // Test mapping
        Test.startTest();
        Map<String, Object> result = CleverTapDataMapper.mapToCleverTap(testLead, 'Lead');
        Test.stopTest();
        
        // Verify mapping
        System.assertNotEquals(null, result, 'Mapping result should not be null');
        System.assertEquals('profile', result.get('type'), 'Type should be profile');
        System.assertEquals(testLead.Email, result.get('identity'), 'Identity should be email');
        
        // Verify profile data
        Map<String, Object> profileData = (Map<String, Object>)result.get('profileData');
        System.assertNotEquals(null, profileData, 'Profile data should not be null');
        System.assertEquals(testLead.FirstName, profileData.get('first_name'), 'First name should be mapped');
        System.assertEquals(testLead.LastName, profileData.get('last_name'), 'Last name should be mapped');
    }
    
    @isTest
    static void testMapToCleverTapWithContact() {
        // Get test Contact
        Contact testContact = [SELECT Id, FirstName, LastName, Email FROM Contact LIMIT 1];
        
        // Test mapping
        Test.startTest();
        Map<String, Object> result = CleverTapDataMapper.mapToCleverTap(testContact, 'Contact');
        Test.stopTest();
        
        // Verify mapping
        System.assertNotEquals(null, result, 'Mapping result should not be null');
        System.assertEquals('profile', result.get('type'), 'Type should be profile');
        System.assertEquals(testContact.Email, result.get('identity'), 'Identity should be email');
        
        // Verify profile data
        Map<String, Object> profileData = (Map<String, Object>)result.get('profileData');
        System.assertNotEquals(null, profileData, 'Profile data should not be null');
        System.assertEquals(testContact.LastName, profileData.get('name'), 'Name should be mapped');
    }
    
    @isTest
    static void testMapToMultipleConnections() {
        // Get test Lead
        Lead testLead = [SELECT Id, FirstName, LastName, Email, Company FROM Lead LIMIT 1];
        
        // Test mapping to multiple connections
        Test.startTest();
        List<CleverTapDataMapper.ConnectionMapping> results = CleverTapDataMapper.mapToMultipleConnections(testLead, 'Lead');
        Test.stopTest();
        
        // Verify mappings for multiple connections
        System.assertEquals(2, results.size(), 'Should have mappings for 2 connections');
        
        // Check the profile mapping
        CleverTapDataMapper.ConnectionMapping profileMapping = null;
        CleverTapDataMapper.ConnectionMapping eventMapping = null;
        
        for (CleverTapDataMapper.ConnectionMapping mapping : results) {
            Map<String, Object> payload = mapping.payload;
            if (payload.get('type') == 'profile') {
                profileMapping = mapping;
            } else if (payload.get('type') == 'event') {
                eventMapping = mapping;
            }
        }
        
        // Verify profile mapping
        System.assertNotEquals(null, profileMapping, 'Should have a profile mapping');
        System.assertEquals('TEST_CONN_ID_1', profileMapping.connectionId, 'Connection ID should match');
        System.assertEquals('profile', profileMapping.payload.get('type'), 'Type should be profile');
        
        // Verify event mapping
        System.assertNotEquals(null, eventMapping, 'Should have an event mapping');
        System.assertEquals('TEST_CONN_ID_2', eventMapping.connectionId, 'Connection ID should match');
        System.assertEquals('event', eventMapping.payload.get('type'), 'Type should be event');
        System.assertEquals('sf_lead_created', eventMapping.payload.get('evtName'), 'Event name should be set');
    }
    
    @isTest
    static void testMapToCleverTapWithNull() {
        // Test with null record
        Test.startTest();
        Map<String, Object> result = CleverTapDataMapper.mapToCleverTap(null, 'Lead');
        Test.stopTest();
        
        // Verify result is null
        System.assertEquals(null, result, 'Result should be null for null record');
    }
    
    @isTest
    static void testMapToCleverTapWithNoConfig() {
        // Get test Account (no config exists for it)
        Account testAccount = [SELECT Id, Name FROM Account LIMIT 1];
        
        // Test mapping
        Test.startTest();
        Map<String, Object> result = CleverTapDataMapper.mapToCleverTap(testAccount, 'Account');
        Test.stopTest();
        
        // Verify result is null
        System.assertEquals(null, result, 'Result should be null when no config exists');
    }
    
    @isTest
    static void testMapToCleverTapWithNoMappings() {
        // Create config for Account but don't create mappings
        CleverTap_Sync_Configuration__c accountConfig = new CleverTap_Sync_Configuration__c(
            Name = 'Test Account Config',
            Salesforce_Entity__c = 'Account',
            CleverTap_Entity__c = 'profile',
            Status__c = 'Active',
            Sync_Type__c = 'salesforce_to_clevertap'
        );
        insert accountConfig;
        
        // Get test Account
        Account testAccount = [SELECT Id, Name FROM Account LIMIT 1];
        
        // Test mapping
        Test.startTest();
        Map<String, Object> result = CleverTapDataMapper.mapToCleverTap(testAccount, 'Account');
        Test.stopTest();
        
        // Verify result is null (no mandatory customer_id mapping exists)
        System.assertEquals(null, result, 'Result should be null when no customer_id mapping exists');
    }
    
    @isTest
    static void testMapToCleverTapWithMissingIdentityValue() {
        // Create a Lead without Email
        Lead leadWithoutEmail = new Lead(
            FirstName = 'No',
            LastName = 'Email',
            Company = 'Test Company'
        );
        insert leadWithoutEmail;
        
        // Test mapping
        Test.startTest();
        Map<String, Object> result = CleverTapDataMapper.mapToCleverTap(leadWithoutEmail, 'Lead');
        Test.stopTest();
        
        // Verify result is null
        System.assertEquals(null, result, 'Result should be null when identity value is missing');
    }
}