@isTest
private class CleverTapHistoricalSyncBatchTest {

    @testSetup
    static void setupTestData() {
        // Insert test data that matches the objectName used (e.g., Lead, Contact)
        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = 'User',
            Company = 'TestCorp',
            Email = 'testuser@example.com'
        );
        insert testLead;

        // Create a dummy sync config record if needed
        // Assuming there's a Custom Setting or Custom Metadata named CleverTapSyncConfig__c
        // Insert appropriate dummy config if required for your logic
    }

    @isTest
    static void testBatchExecution() {
        Test.startTest();

        // Create instance of batch with object name 'Lead' and dummy syncConfigId
        CleverTapHistoricalSyncBatch batch = new CleverTapHistoricalSyncBatch('Lead', 'dummySyncConfigId');

        // Run batch job with small batch size
        ID batchId = Database.executeBatch(batch, 1);

        Test.stopTest();

        // Add asserts based on expected outcomes (processed, success/failure counters, etc.)
        // For example:
        System.assertNotEquals(null, batchId);
    }
}
