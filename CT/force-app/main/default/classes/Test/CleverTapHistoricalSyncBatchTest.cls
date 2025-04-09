@isTest
private class CleverTapHistoricalSyncBatchTest {
    
    // Set up test data
    @testSetup
    static void setupTestData() {
        // Enable trigger bypass to prevent infinite recursion
        CleverTapTestUtils.bypassTriggers = true;
        
        try {
            // Create test connection
            CleverTap_Config__c testConfig = new CleverTap_Config__c(
                Name = 'Test Config',
                Region__c = 'US',
                CleverTap_Account_ID__c = 'test-account-id',
                CleverTap_Passcode__c = 'test-passcode',
                CleverTap_API_URL__c = 'https://us1.api.clevertap.com/1/upload'
            );
            insert testConfig;
            
            // Create sync configuration for profile
            CleverTap_Sync_Configuration__c syncConfig = new CleverTap_Sync_Configuration__c(
                Name = 'Test Lead Sync',
                Sync_Type__c = 'salesforce_to_clevertap',
                Salesforce_Entity__c = 'Lead',
                CleverTap_Entity__c = 'profile',
                ConnectionId__c = testConfig.Id,
                Status__c = 'Active'
            );
            insert syncConfig;
            
            // Add a sync configuration for event type testing
            CleverTap_Sync_Configuration__c eventSyncConfig = new CleverTap_Sync_Configuration__c(
                Name = 'Test Lead Event Sync',
                Sync_Type__c = 'salesforce_to_clevertap',
                Salesforce_Entity__c = 'Lead',
                CleverTap_Entity__c = 'event',
                ConnectionId__c = testConfig.Id,
                Status__c = 'Active'
            );
            insert eventSyncConfig;
            
            // Create field mappings
            List<CleverTap_Mapping__c> mappings = new List<CleverTap_Mapping__c>();
            
            // Customer ID mapping for profile sync
            mappings.add(new CleverTap_Mapping__c(
                Name = 'Lead Email to Customer ID',
                Sync_Configuration__c = syncConfig.Id,
                CleverTap_Field__c = 'customer_id',
                Salesforce_Field__c = 'Email',
                Data_Type__c = 'Text',
                Is_Mandatory__c = true
            ));
            
            // Add a regular field mapping for profile sync
            mappings.add(new CleverTap_Mapping__c(
                Name = 'Lead Name to First Name',
                Sync_Configuration__c = syncConfig.Id,
                CleverTap_Field__c = 'first_name',
                Salesforce_Field__c = 'FirstName',
                Data_Type__c = 'Text',
                Is_Mandatory__c = false
            ));
            
            // Date field mapping
            mappings.add(new CleverTap_Mapping__c(
                Name = 'Last Modified Date',
                Sync_Configuration__c = syncConfig.Id,
                CleverTap_Field__c = 'last_modified',
                Salesforce_Field__c = 'LastModifiedDate',
                Data_Type__c = 'Date',
                Is_Mandatory__c = false
            ));
            

            
            // Add another regular field mapping of different type
            mappings.add(new CleverTap_Mapping__c(
                Name = 'Annual Revenue',
                Sync_Configuration__c = syncConfig.Id,
                CleverTap_Field__c = 'annual_revenue',
                Salesforce_Field__c = 'AnnualRevenue',
                Data_Type__c = 'Number',
                Is_Mandatory__c = false
            ));
            
            // Customer ID mapping for event sync
            mappings.add(new CleverTap_Mapping__c(
                Name = 'Lead Email to Customer ID (Event)',
                Sync_Configuration__c = eventSyncConfig.Id,
                CleverTap_Field__c = 'customer_id',
                Salesforce_Field__c = 'Email',
                Data_Type__c = 'Text',
                Is_Mandatory__c = true
            ));
            
            // Event name mapping
            mappings.add(new CleverTap_Mapping__c(
                Name = 'Lead Event Name',
                Sync_Configuration__c = eventSyncConfig.Id,
                CleverTap_Field__c = 'evtName',
                Salesforce_Field__c = 'sf_lead_event',
                Data_Type__c = 'Text',
                Is_Mandatory__c = true
            ));
            
            // Status field for event
            mappings.add(new CleverTap_Mapping__c(
                Name = 'Lead Status',
                Sync_Configuration__c = eventSyncConfig.Id,
                CleverTap_Field__c = 'status',
                Salesforce_Field__c = 'Status',
                Data_Type__c = 'Text',
                Is_Mandatory__c = false
            ));
            
            insert mappings;
            
            // Create test leads
            List<Lead> testLeads = new List<Lead>();
            for(Integer i = 0; i < 5; i++) {
                testLeads.add(new Lead(
                    FirstName = 'Test' + i,
                    LastName = 'Lead' + i,
                    Email = 'test' + i + '@example.com',
                    Company = 'Test Company',
                    AnnualRevenue = 10000 * (i + 1),
                    Status = 'Open'
                ));
            }
            insert testLeads;
        } finally {
            // Make sure to reset the bypass flag
            CleverTapTestUtils.bypassTriggers = false;
        }
    }
    
    // Mock HTTP callout class for successful responses
    private class MockHttpResponseSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"success","processed":1}');
            res.setStatusCode(200);
            return res;
        }
    }
    
    // Mock HTTP callout class for error responses
    private class MockHttpResponseError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"error","message":"Invalid request"}');
            res.setStatusCode(400);
            return res;
        }
    }
    
    // This helper method accesses private methods via reflection
    private static Object invokePrivateMethod(Object obj, String methodName, List<Type> paramTypes, List<Object> params) {
        // This method doesn't actually work in Apex, but we're using it 
        // as a placeholder to indicate the intent of testing private methods
        return null;
    }
    
    /**
     * Test the start method of the batch class
     */
    @isTest
    static void testStartMethod() {
        // Get sync config ID for use in test
        CleverTap_Sync_Configuration__c syncConfig = [
            SELECT Id FROM CleverTap_Sync_Configuration__c 
            WHERE Name = 'Test Lead Sync' LIMIT 1
        ];
        
        Test.startTest();
        
        // Create batch instance
        CleverTapHistoricalSyncBatch batchInstance = new CleverTapHistoricalSyncBatch('Lead', syncConfig.Id);
        
        // Execute the start method
        Database.QueryLocator queryLocator = batchInstance.start(null);
        
        // Execute the query locator to verify it works
        Database.QueryLocatorIterator iterator = queryLocator.iterator();
        
        // Count the records
        Integer recordCount = 0;
        while (iterator.hasNext()) {
            SObject record = iterator.next();
            recordCount++;
        }
        
        Test.stopTest();
        
        // Assert that the query returned the expected number of records
        System.assertEquals(5, recordCount, 'Query should return 5 lead records');
    }
    
    /**
     * Test the execute method with the execute-only mode to directly hit the batch process
     */
    @isTest
    static void testExecuteWithDirectAccess() {
        // Get sync config ID
        CleverTap_Sync_Configuration__c syncConfig = [
            SELECT Id, CleverTap_Entity__c FROM CleverTap_Sync_Configuration__c 
            WHERE Name = 'Test Lead Sync' LIMIT 1
        ];
        
        // Set mock response
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseSuccess());
        
        // Get a lead to use for testing
        List<Lead> leads = [SELECT Id, FirstName, LastName, Email, Company, Status, 
                           AnnualRevenue, LastModifiedDate 
                           FROM Lead LIMIT 1];
        
        Test.startTest();
        
        // Create the batch instance
        CleverTapHistoricalSyncBatch batchInstance = new CleverTapHistoricalSyncBatch('Lead', syncConfig.Id);
        
        // Execute the batch with the lead records
        batchInstance.execute(null, leads);
        
        // Call finish
        batchInstance.finish(null);
        
        Test.stopTest();
        
        // Verify log creation
        List<CleverTap_Event__c> logs = [SELECT Id, Status__c FROM CleverTap_Event__c];
        System.assertNotEquals(0, logs.size(), 'Should create logs');
    }
    
    /**
     * Test the event entity type
     */
    @isTest
    static void testEventEntityExecution() {
        // Get sync config ID for event
        CleverTap_Sync_Configuration__c eventSyncConfig = [
            SELECT Id FROM CleverTap_Sync_Configuration__c 
            WHERE Name = 'Test Lead Event Sync' LIMIT 1
        ];
        
        // Set mock response
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseSuccess());
        
        // Get test lead
        List<Lead> leads = [SELECT Id, FirstName, LastName, Email, Company, Status, 
                           AnnualRevenue,  LastModifiedDate 
                           FROM Lead LIMIT 1];
        
        Test.startTest();
        
        // Create batch instance for event sync
        CleverTapHistoricalSyncBatch batchInstance = new CleverTapHistoricalSyncBatch('Lead', eventSyncConfig.Id);
        
        // Execute with the lead
        batchInstance.execute(null, leads);
        
        // Call finish
        batchInstance.finish(null);
        
        Test.stopTest();
        
        // Verify log creation
        List<CleverTap_Event__c> logs = [SELECT Id FROM CleverTap_Event__c];
        System.assertNotEquals(0, logs.size(), 'Should create logs for event entity');
    }
    
    /**
     * Test the execute method with error response
     */
    @isTest
    static void testExecuteWithError() {
        // Get sync config ID
        CleverTap_Sync_Configuration__c syncConfig = [
            SELECT Id FROM CleverTap_Sync_Configuration__c 
            WHERE Name = 'Test Lead Sync' LIMIT 1
        ];
        
        // Set mock error response
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseError());
        
        // Get test leads
        List<Lead> leads = [SELECT Id, FirstName, LastName, Email, Company, Status, 
                           AnnualRevenue,  LastModifiedDate 
                           FROM Lead LIMIT 1];
        
        Test.startTest();
        
        // Create batch instance
        CleverTapHistoricalSyncBatch batchInstance = new CleverTapHistoricalSyncBatch('Lead', syncConfig.Id);
        
        // Execute with the lead
        batchInstance.execute(null, leads);
        
        // Call finish
        batchInstance.finish(null);
        
        Test.stopTest();
        
        // Verify log creation with error status
        List<CleverTap_Event__c> logs = [SELECT Id, Status__c FROM CleverTap_Event__c];
        System.assertNotEquals(0, logs.size(), 'Should create logs for error case');
    }
    
    // /**
    //  * Test with an invalid sync configuration
    //  */
    // @isTest
    // static void testWithInvalidSyncConfig() {
    //     // Set mock response
    //     Test.setMock(HttpCalloutMock.class, new MockHttpResponseSuccess());
        
    //     // Get test leads
    //     List<Lead> leads = [SELECT Id, FirstName, LastName, Email, Company, Status, 
    //                        AnnualRevenue,  LastModifiedDate 
    //                        FROM Lead LIMIT 1];
        
    //     Test.startTest();
        
    //     // Create batch instance with invalid ID
    //     CleverTapHistoricalSyncBatch batchInstance = new CleverTapHistoricalSyncBatch('Lead', 'INVALID_ID');
        
    //     // Execute with the lead
    //     batchInstance.execute(null, leads);
        
    //     // Call finish
    //     batchInstance.finish(null);
        
    //     Test.stopTest();
        
    //     // Verify log creation
    //     List<CleverTap_Event__c> logs = [SELECT Id FROM CleverTap_Event__c];
    //     System.assertNotEquals(0, logs.size(), 'Should create logs even with invalid sync config');
    // }
    
    // /**
    //  * Test with a lead missing critical fields
    //  */
    // @isTest
    // static void testWithIncompleteData() {
    //     // Get sync config ID
    //     CleverTap_Sync_Configuration__c syncConfig = [
    //         SELECT Id FROM CleverTap_Sync_Configuration__c 
    //         WHERE Name = 'Test Lead Sync' LIMIT 1
    //     ];
        
    //     // Set mock response
    //     Test.setMock(HttpCalloutMock.class, new MockHttpResponseSuccess());
        
    //     // Create a lead with missing email (identity field)
    //     Lead incompleteLead = new Lead(
    //         FirstName = 'Incomplete',
    //         LastName = 'Lead',
    //         // Missing Email field
    //         Company = 'Test Company'
    //     );
    //     insert incompleteLead;
        
    //     // Query the lead back
    //     List<Lead> leads = [SELECT Id, FirstName, LastName, Company FROM Lead WHERE LastName = 'Lead' LIMIT 1];
        
    //     Test.startTest();
        
    //     // Create batch instance
    //     CleverTapHistoricalSyncBatch batchInstance = new CleverTapHistoricalSyncBatch('Lead', syncConfig.Id);
        
    //     // Execute with the incomplete lead
    //     batchInstance.execute(null, leads);
        
    //     // Call finish
    //     batchInstance.finish(null);
        
    //     Test.stopTest();
        
    //     // Verify log creation
    //     List<CleverTap_Event__c> logs = [SELECT Id FROM CleverTap_Event__c];
    //     System.assertNotEquals(0, logs.size(), 'Should create logs even with incomplete data');
    // }
    
    /**
     * Test with multiple records in a batch
     */
    @isTest
    static void testWithMultipleRecords() {
        // Get sync config ID
        CleverTap_Sync_Configuration__c syncConfig = [
            SELECT Id FROM CleverTap_Sync_Configuration__c 
            WHERE Name = 'Test Lead Sync' LIMIT 1
        ];
        
        // Set mock response
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseSuccess());
        
        // Get all test leads
        List<Lead> leads = [SELECT Id, FirstName, LastName, Email, Company, Status, 
                           AnnualRevenue,  LastModifiedDate 
                           FROM Lead LIMIT 5];
        
        Test.startTest();
        
        // Create batch instance
        CleverTapHistoricalSyncBatch batchInstance = new CleverTapHistoricalSyncBatch('Lead', syncConfig.Id);
        
        // Execute with multiple leads
        batchInstance.execute(null, leads);
        
        // Call finish
        batchInstance.finish(null);
        
        Test.stopTest();
        
        // Verify log creation
        List<CleverTap_Event__c> logs = [SELECT Id FROM CleverTap_Event__c];
        System.assertNotEquals(0, logs.size(), 'Should create logs for multiple records');
    }
    
    /**
     * Test the full batch process
     */
    @isTest
    static void testFullBatchProcess() {
        // Get sync config ID
        CleverTap_Sync_Configuration__c syncConfig = [
            SELECT Id FROM CleverTap_Sync_Configuration__c 
            WHERE Name = 'Test Lead Sync' LIMIT 1
        ];
        
        // Set mock response
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseSuccess());
        
        Test.startTest();
        
        // Create and execute the batch
        CleverTapHistoricalSyncBatch batchInstance = new CleverTapHistoricalSyncBatch('Lead', syncConfig.Id);
        Id batchId = Database.executeBatch(batchInstance, 5);
        
        Test.stopTest();
        
        // Verify logs were created
        List<CleverTap_Event__c> logs = [SELECT Id FROM CleverTap_Event__c];
        System.assertNotEquals(0, logs.size(), 'Should create logs for full batch process');
    }
    
    // /**
    //  * Test with different data types
    //  */
    // @isTest
    // static void testDataTypeHandling() {
    //     // Get sync config ID
    //     CleverTap_Sync_Configuration__c syncConfig = [
    //         SELECT Id FROM CleverTap_Sync_Configuration__c 
    //         WHERE Name = 'Test Lead Sync' LIMIT 1
    //     ];
        
    //     // Set mock response
    //     Test.setMock(HttpCalloutMock.class, new MockHttpResponseSuccess());
        
    //     // Update a lead with various data types
    //     Lead testLead = [SELECT Id FROM Lead LIMIT 1];
    //     testLead.AnnualRevenue = 1000000;
    //     update testLead;
        
    //     // Query the updated lead
    //     List<Lead> leads = [SELECT Id, FirstName, LastName, Email, Company, Status, 
    //                        AnnualRevenue,  LastModifiedDate 
    //                        FROM Lead WHERE Id = :testLead.Id];
        
    //     Test.startTest();
        
    //     // Create batch instance
    //     CleverTapHistoricalSyncBatch batchInstance = new CleverTapHistoricalSyncBatch('Lead', syncConfig.Id);
        
    //     // Execute with the lead with various data types
    //     batchInstance.execute(null, leads);
        
    //     // Call finish
    //     batchInstance.finish(null);
        
    //     Test.stopTest();
        
    //     // Verify log creation
    //     List<CleverTap_Event__c> logs = [SELECT Id FROM CleverTap_Event__c];
    //     System.assertNotEquals(0, logs.size(), 'Should create logs for data type handling');
    // }
}