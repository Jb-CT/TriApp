@isTest
private class SchemaUtilityTest {
    
    @isTest
    static void testGetFieldsMap() {
        // Test getting fields map for a standard object
        Test.startTest();
        Map<String, Schema.SObjectField> leadFields = SchemaUtility.getFieldsMap('Lead');
        Test.stopTest();
        
        // Verify fields map contains expected fields
        System.assert(leadFields.containsKey('lastname'), 'Fields map should contain LastName field');
        System.assert(leadFields.containsKey('email'), 'Fields map should contain Email field');
        System.assert(leadFields.containsKey('company'), 'Fields map should contain Company field');
    }
    
    @isTest
    static void testGetFieldsMapInvalidObject() {
        // Test getting fields map for an invalid object
        Test.startTest();
        Map<String, Schema.SObjectField> invalidFields = SchemaUtility.getFieldsMap('InvalidObject');
        Test.stopTest();
        
        // Verify empty map is returned
        System.assertEquals(0, invalidFields.size(), 'Should return empty map for invalid object');
    }
    
    @isTest
    static void testGetFieldDescribe() {
        // Test getting field describe result
        Test.startTest();
        Schema.DescribeFieldResult emailField = SchemaUtility.getFieldDescribe('Lead', 'Email');
        Test.stopTest();
        
        // Verify field describe
        System.assertNotEquals(null, emailField, 'Field describe should not be null');
        System.assertEquals('Email', emailField.getName(), 'Field name should match');
        System.assertEquals(Schema.DisplayType.EMAIL, emailField.getType(), 'Field type should be EMAIL');
    }
    
    @isTest
    static void testGetFieldDescribeInvalidField() {
        // Test getting field describe for an invalid field
        Test.startTest();
        Schema.DescribeFieldResult invalidField = SchemaUtility.getFieldDescribe('Lead', 'InvalidField');
        Test.stopTest();
        
        // Verify null is returned
        System.assertEquals(null, invalidField, 'Should return null for invalid field');
    }
    
    @isTest
    static void testGetObjectDescribe() {
        // Test getting object describe result
        Test.startTest();
        Schema.DescribeSObjectResult leadDescribe = SchemaUtility.getObjectDescribe('Lead');
        Test.stopTest();
        
        // Verify object describe
        System.assertNotEquals(null, leadDescribe, 'Object describe should not be null');
        System.assertEquals('Lead', leadDescribe.getName(), 'Object name should match');
        System.assertEquals('Lead', leadDescribe.getLabel(), 'Object label should match');
    }
    
    @isTest
    static void testGetObjectDescribeInvalidObject() {
        // Test getting object describe for an invalid object
        Test.startTest();
        Schema.DescribeSObjectResult invalidDescribe = SchemaUtility.getObjectDescribe('InvalidObject');
        Test.stopTest();
        
        // Verify null is returned
        System.assertEquals(null, invalidDescribe, 'Should return null for invalid object');
    }
    
    @isTest
    static void testIsFieldAccessible() {
        // Test field accessibility
        Test.startTest();
        Boolean isAccessible = SchemaUtility.isFieldAccessible('Lead', 'Email');
        Test.stopTest();
        
        // Verify accessibility
        System.assertEquals(true, isAccessible, 'Email field should be accessible');
    }
    
    @isTest
    static void testIsFieldAccessibleInvalidField() {
        // Test accessibility for invalid field
        Test.startTest();
        Boolean isAccessible = SchemaUtility.isFieldAccessible('Lead', 'InvalidField');
        Test.stopTest();
        
        // Verify result
        System.assertEquals(false, isAccessible, 'Invalid field should not be accessible');
    }
    
    @isTest
    static void testGetPicklistValues() {
        // Test getting picklist values
        Test.startTest();
        List<Map<String, String>> leadStatusOptions = SchemaUtility.getPicklistValues('Lead', 'Status');
        Test.stopTest();
        
        // Verify picklist values
        System.assert(!leadStatusOptions.isEmpty(), 'Should return picklist values for Status field');
        
        // Check structure of picklist values
        for (Map<String, String> option : leadStatusOptions) {
            System.assert(option.containsKey('label'), 'Picklist option should have label');
            System.assert(option.containsKey('value'), 'Picklist option should have value');
        }
    }
    
    @isTest
    static void testGetPicklistValuesNonPicklistField() {
        // Test getting picklist values for a non-picklist field
        Test.startTest();
        List<Map<String, String>> emailOptions = SchemaUtility.getPicklistValues('Lead', 'Email');
        Test.stopTest();
        
        // Verify empty list is returned
        System.assertEquals(0, emailOptions.size(), 'Should return empty list for non-picklist field');
    }
    
    @isTest
    static void testGetPicklistValuesInvalidField() {
        // Test getting picklist values for an invalid field
        Test.startTest();
        List<Map<String, String>> invalidOptions = SchemaUtility.getPicklistValues('Lead', 'InvalidField');
        Test.stopTest();
        
        // Verify empty list is returned
        System.assertEquals(0, invalidOptions.size(), 'Should return empty list for invalid field');
    }
    
    @isTest
    static void testGetAccessibleFields() {
        // Test getting accessible fields
        Test.startTest();
        List<Map<String, String>> leadFields = SchemaUtility.getAccessibleFields('Lead');
        Test.stopTest();
        
        // Verify accessible fields
        System.assert(!leadFields.isEmpty(), 'Should return accessible fields for Lead');
        
        // Check structure of field info
        for (Map<String, String> field : leadFields) {
            System.assert(field.containsKey('label'), 'Field info should have label');
            System.assert(field.containsKey('value'), 'Field info should have value');
        }
    }
    
    @isTest
    static void testGetAccessibleFieldsInvalidObject() {
        // Test getting accessible fields for an invalid object
        Test.startTest();
        List<Map<String, String>> invalidFields = SchemaUtility.getAccessibleFields('InvalidObject');
        Test.stopTest();
        
        // Verify empty list is returned
        System.assertEquals(0, invalidFields.size(), 'Should return empty list for invalid object');
    }
    
    @isTest
    static void testFieldsMapCache() {
        // Test that fields map is cached
        Test.startTest();
        // First call should add to cache
        Map<String, Schema.SObjectField> firstCall = SchemaUtility.getFieldsMap('Lead');
        // Second call should use cache
        Map<String, Schema.SObjectField> secondCall = SchemaUtility.getFieldsMap('Lead');
        Test.stopTest();
        
        // Verify both calls return same result
        System.assertEquals(firstCall.size(), secondCall.size(), 'Both calls should return same number of fields');
    }
    
    @isTest
    static void testObjectDescribeCache() {
        // Test that object describe is cached
        Test.startTest();
        // First call should add to cache
        Schema.DescribeSObjectResult firstCall = SchemaUtility.getObjectDescribe('Lead');
        // Second call should use cache
        Schema.DescribeSObjectResult secondCall = SchemaUtility.getObjectDescribe('Lead');
        Test.stopTest();
        
        // Verify both calls return same result
        System.assertEquals(firstCall.getName(), secondCall.getName(), 'Both calls should return same object name');
    }
}