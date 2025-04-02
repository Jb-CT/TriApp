@isTest
private class CleverTapEventLoggerTest {
    
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

        // Create test opportunity
        Opportunity testOpportunity = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = testAccount.Id
        );
        insert testOpportunity;
    }
    
    @isTest
    static void testLogEventSuccess() {
        // Create a mock HTTP response
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(200);
        mockResponse.setBody('{"status":"success"}');
        
        // Get a test record
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        
        // Create event data
        CleverTapEventLogger.EventData eventData = new CleverTapEventLogger.EventData(
            testLead.Id, 'Lead', mockResponse, '{"test":"request"}'
        );
        
        // Log the event
        Test.startTest();
        CleverTapEventLogger.logEvent(eventData);
        Test.stopTest();
        
        // Verify log was created
        List<CleverTap_Event__c> logs = [SELECT Id, Status__c FROM CleverTap_Event__c];
        System.assertEquals(1, logs.size(), 'One event log should be created');
        System.assertEquals('Success', logs[0].Status__c, 'Status should be Success');
    }
    
    @isTest
    static void testLogEventFailure() {
        // Create a mock HTTP response
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(400);
        mockResponse.setBody('{"status":"error"}');
        
        // Get a test record
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        
        // Create event data
        CleverTapEventLogger.EventData eventData = new CleverTapEventLogger.EventData(
            testLead.Id, 'Lead', mockResponse, '{"test":"request"}'
        );
        
        // Log the event
        Test.startTest();
        CleverTapEventLogger.logEvent(eventData);
        Test.stopTest();
        
        // Verify log was created
        List<CleverTap_Event__c> logs = [SELECT Id, Status__c FROM CleverTap_Event__c];
        System.assertEquals(1, logs.size(), 'One event log should be created');
        System.assertEquals('Failed', logs[0].Status__c, 'Status should be Failed');
    }
    
    @isTest
    static void testLogEventWithContact() {
        // Create a mock HTTP response
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(200);
        mockResponse.setBody('{"status":"success"}');
        
        // Get a test record
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        
        // Create event data
        CleverTapEventLogger.EventData eventData = new CleverTapEventLogger.EventData(
            testContact.Id, 'Contact', mockResponse, '{"test":"request"}'
        );
        
        // Log the event
        Test.startTest();
        CleverTapEventLogger.logEvent(eventData);
        Test.stopTest();
        
        // Verify log was created with the right relationship
        List<CleverTap_Event__c> logs = [SELECT Id, Contact__c FROM CleverTap_Event__c];
        System.assertEquals(1, logs.size(), 'One event log should be created');
        System.assertEquals(testContact.Id, logs[0].Contact__c, 'Contact ID should be set');
    }
    
    @isTest
    static void testLogEventWithOpportunity() {
        // Create a mock HTTP response
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(200);
        mockResponse.setBody('{"status":"success"}');
        
        // Get a test record
        Opportunity testOpportunity = [SELECT Id FROM Opportunity LIMIT 1];
        
        // Create event data
        CleverTapEventLogger.EventData eventData = new CleverTapEventLogger.EventData(
            testOpportunity.Id, 'Opportunity', mockResponse, '{"test":"request"}'
        );
        
        // Log the event
        Test.startTest();
        CleverTapEventLogger.logEvent(eventData);
        Test.stopTest();
        
        // Verify log was created with information in response field
        List<CleverTap_Event__c> logs = [SELECT Id, Response__c FROM CleverTap_Event__c];
        System.assertEquals(1, logs.size(), 'One event log should be created');
        System.assert(logs[0].Response__c.contains('Request:'), 'Response should contain request data');
    }
    
    @isTest
    static void testLogEventWithNonExistentObjectType() {
        // Create a mock HTTP response
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(200);
        mockResponse.setBody('{"status":"success"}');
        
        // Get a test record
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create event data with a non-existent object type relation
        CleverTapEventLogger.EventData eventData = new CleverTapEventLogger.EventData(
            testAccount.Id, 'CustomObject', mockResponse, '{"test":"request"}'
        );
        
        // Log the event
        Test.startTest();
        CleverTapEventLogger.logEvent(eventData);
        Test.stopTest();
        
        // Verify log was created with information in response field
        List<CleverTap_Event__c> logs = [SELECT Id, Response__c FROM CleverTap_Event__c];
        System.assertEquals(1, logs.size(), 'One event log should be created');
        System.assert(logs[0].Response__c.contains('CustomObject ID:'), 'Response should contain object ID');
    }
}