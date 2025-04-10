/**
 * @class CleverTapDataConverter
 * @description Helper class for converting Salesforce data to CleverTap format.
 */
public with sharing class CleverTapDataConverter {
    
    private static final String DATE_PREFIX = '$D_';
    /**
     * @description Converts a field value to the appropriate data type for CleverTap
     * @param value The value to convert
     * @param dataType The target data type
     * @return The converted value
     */
    public static Object convertFieldValue(Object value, String dataType) {
        if (value == null) {
            return null;
        }
        
        String dataTypeLower = String.isBlank(dataType) ? 'text' : dataType.toLowerCase();
        
        switch on dataTypeLower {
            when 'number' {
                return convertToNumber(value);
            }
            when 'boolean' {
                return convertToBoolean(value);
            }
            when 'date' {
                return convertToDate(value);
            }
            when else {
                return String.valueOf(value);
            }
        }
    }
    
    /**
     * @description Converts a value to a number
     * @param value The value to convert
     * @return The numeric value
     */
    private static Decimal convertToNumber(Object value) {
        try {
            return Decimal.valueOf(String.valueOf(value));
        } catch (Exception e) {
            return 0;
        }
    }
    
    /**
     * @description Converts a value to a boolean
     * @param value The value to convert
     * @return The boolean value
     */
    private static Boolean convertToBoolean(Object value) {
        return Boolean.valueOf(value);
    }
    
    /**
     * @description Converts a value to a CleverTap date format
     * @param value The value to convert
     * @return The formatted date value
     */
    private static String convertToDate(Object value) {
        if (value instanceof DateTime) {
            DateTime dt = (DateTime)value;
            // Convert to epoch seconds for CleverTap
            Long v = dt.getTime() / 1000;
            return DATE_PREFIX + v;
        } else if (value instanceof Date) {
            Date dateValue = (Date)value;
            // Convert Date to DateTime at midnight, then to epoch seconds
            DateTime dt = DateTime.newInstance(
                dateValue.year(), 
                dateValue.month(), 
                dateValue.day()
            );
            Long v = dt.getTime() / 1000;
            return DATE_PREFIX + v;
        }
        return String.valueOf(value);
    }    
}