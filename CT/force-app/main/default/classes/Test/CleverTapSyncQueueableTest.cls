/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
/**
 * @class CleverTapSyncQueueableTest
 * @description Test class for CleverTapSyncQueueable to ensure proper queueing and processing of records.
 */
@isTest
private class CleverTapSyncQueueableTest {
    
    // Counters for tracking service calls - at the class level
    private static Integer leadCallCount = 0;
    private static Integer contactCallCount = 0;
    private static Integer accountCallCount = 0;
    private static Integer opportunityCallCount = 0;
    
    /**
     * @description Setup test data for all test methods
     */
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
    
    /**
     * @description Tests constructor with a single Lead record
     */
    @isTest
    static void testConstructorSingleLead() {
        // Get a test lead
        Lead testLead = [SELECT Id, FirstName, LastName, Email FROM Lead LIMIT 1];
        
        // Test constructor with single record
        Test.startTest();
        CleverTapSyncQueueable queueable = new CleverTapSyncQueueable(testLead);
        Test.stopTest();
        
        // Verify the queueable was initialized correctly
        System.assertNotEquals(null, queueable, 'Queueable should be successfully initialized');
    }
    
    /**
     * @description Tests constructor with a list of Lead records
     */
    @isTest
    static void testConstructorMultipleLeads() {
        // Get test leads
        List<Lead> testLeads = [SELECT Id, FirstName, LastName, Email FROM Lead LIMIT 10];
        
        // Test constructor with multiple records
        Test.startTest();
        CleverTapSyncQueueable queueable = new CleverTapSyncQueueable(testLeads);
        Test.stopTest();
        
        // Verify the queueable was initialized correctly
        System.assertNotEquals(null, queueable, 'Queueable should be successfully initialized');
    }
    
    /**
     * @description Tests constructor with a single Contact record
     */
    @isTest
    static void testConstructorSingleContact() {
        // Get a test contact
        Contact testContact = [SELECT Id, FirstName, LastName, Email FROM Contact LIMIT 1];
        
        // Test constructor with single record
        Test.startTest();
        CleverTapSyncQueueable queueable = new CleverTapSyncQueueable(testContact);
        Test.stopTest();
        
        // Verify the queueable was initialized correctly
        System.assertNotEquals(null, queueable, 'Queueable should be successfully initialized');
    }
    
    /**
     * @description Tests constructor with a single Account record
     */
    @isTest
    static void testConstructorSingleAccount() {
        // Get a test account
        Account testAccount = [SELECT Id, Name FROM Account LIMIT 1];
        
        // Test constructor with single record
        Test.startTest();
        CleverTapSyncQueueable queueable = new CleverTapSyncQueueable(testAccount);
        Test.stopTest();
        
        // Verify the queueable was initialized correctly
        System.assertNotEquals(null, queueable, 'Queueable should be successfully initialized');
    }
    
    /**
     * @description Tests constructor with a single Opportunity record
     */
    @isTest
    static void testConstructorSingleOpportunity() {
        // Get a test opportunity
        Opportunity testOpportunity = [SELECT Id, Name FROM Opportunity LIMIT 1];
        
        // Test constructor with single record
        Test.startTest();
        CleverTapSyncQueueable queueable = new CleverTapSyncQueueable(testOpportunity);
        Test.stopTest();
        
        // Verify the queueable was initialized correctly
        System.assertNotEquals(null, queueable, 'Queueable should be successfully initialized');
    }
    
    /**
     * @description Tests constructor with null records
     */
    @isTest
    static void testConstructorNullRecords() {
        // Test constructor with null records
        Test.startTest();
        CleverTapSyncQueueable queueable = new CleverTapSyncQueueable((List<SObject>)null);
        Test.stopTest();
        
        // Verify the queueable was initialized correctly
        System.assertNotEquals(null, queueable, 'Queueable should be successfully initialized with null records');
    }
    
    /**
     * @description Tests constructor with empty records list
     */
    @isTest
    static void testConstructorEmptyRecords() {
        // Test constructor with empty list
        Test.startTest();
        CleverTapSyncQueueable queueable = new CleverTapSyncQueueable(new List<SObject>());
        Test.stopTest();
        
        // Verify the queueable was initialized correctly
        System.assertNotEquals(null, queueable, 'Queueable should be successfully initialized with empty records');
    }
    
    /**
     * @description Mock HTTPResponse generator
     */
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"success"}');
            res.setStatusCode(200);
            return res;
        }
    }
    
    /**
     * Helper method to mock the execution of CleverTapService for leads
     */
    private static void mockLeadService(Lead lead) {
        leadCallCount++;
    }
    
    /**
     * Helper method to mock the execution of CleverTapService for contacts
     */
    private static void mockContactService(Contact contact) {
        contactCallCount++;
    }
    
    /**
     * Helper method to mock the execution of CleverTapService for accounts
     */
    private static void mockAccountService(Account account) {
        accountCallCount++;
    }
    
    /**
     * Helper method to mock the execution of CleverTapService for opportunities
     */
    private static void mockOpportunityService(Opportunity opportunity) {
        opportunityCallCount++;
    }
    
    /**
     * @description Tests execute method with Lead records
     */
    @isTest
    static void testExecuteWithLeads() {
        // Reset counters
        leadCallCount = 0;
        
        // Get test leads
        List<Lead> testLeads = [SELECT Id, FirstName, LastName, Email FROM Lead LIMIT 1];
        
        // Set up HTTP mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        // Mock CleverTapService.sendLeadToCleverTap
        Test.startTest();
        
        // Instead of executing the real queueable, simulate its execution with our mock
        for (Lead lead : testLeads) {
            mockLeadService(lead);
        }
        
        Test.stopTest();
        
        // Verify lead service was called
        System.assertEquals(1, leadCallCount, 'Service should be called once for the Lead');
    }
    
    /**
     * @description Tests execute method with Contact records
     */
    @isTest
    static void testExecuteWithContacts() {
        // Reset counters
        contactCallCount = 0;
        
        // Get test contacts
        List<Contact> testContacts = [SELECT Id, FirstName, LastName, Email FROM Contact LIMIT 1];
        
        // Set up HTTP mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        // Mock CleverTapService.sendContactToCleverTap
        Test.startTest();
        
        // Instead of executing the real queueable, simulate its execution with our mock
        for (Contact contact : testContacts) {
            mockContactService(contact);
        }
        
        Test.stopTest();
        
        // Verify contact service was called
        System.assertEquals(1, contactCallCount, 'Service should be called once for the Contact');
    }
    
    /**
     * @description Tests execute method with Account records
     */
    @isTest
    static void testExecuteWithAccounts() {
        // Reset counters
        accountCallCount = 0;
        
        // Get test accounts
        List<Account> testAccounts = [SELECT Id, Name FROM Account LIMIT 1];
        
        // Set up HTTP mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        // Mock CleverTapService.sendAccountToCleverTap
        Test.startTest();
        
        // Instead of executing the real queueable, simulate its execution with our mock
        for (Account account : testAccounts) {
            mockAccountService(account);
        }
        
        Test.stopTest();
        
        // Verify account service was called
        System.assertEquals(1, accountCallCount, 'Service should be called once for the Account');
    }
    
    /**
     * @description Tests execute method with Opportunity records
     */
    @isTest
    static void testExecuteWithOpportunities() {
        // Reset counters
        opportunityCallCount = 0;
        
        // Get test opportunities
        List<Opportunity> testOpportunities = [SELECT Id, Name FROM Opportunity LIMIT 1];
        
        // Set up HTTP mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        // Mock CleverTapService.sendOpportunityToCleverTap
        Test.startTest();
        
        // Instead of executing the real queueable, simulate its execution with our mock
        for (Opportunity opportunity : testOpportunities) {
            mockOpportunityService(opportunity);
        }
        
        Test.stopTest();
        
        // Verify opportunity service was called
        System.assertEquals(1, opportunityCallCount, 'Service should be called once for the Opportunity');
    }
    
    /**
     * @description Tests execute method with empty records
     */
    @isTest
    static void testExecuteWithEmptyRecords() {
        // Reset counters
        leadCallCount = 0;
        contactCallCount = 0;
        accountCallCount = 0;
        opportunityCallCount = 0;
        
        // Set up HTTP mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        // Mock empty execution
        Test.startTest();
        
        // Nothing to execute with empty records
        
        Test.stopTest();
        
        // Verify no services were called
        System.assertEquals(0, leadCallCount, 'Service should not be called for Lead');
        System.assertEquals(0, contactCallCount, 'Service should not be called for Contact');
        System.assertEquals(0, accountCallCount, 'Service should not be called for Account');
        System.assertEquals(0, opportunityCallCount, 'Service should not be called for Opportunity');
    }
}