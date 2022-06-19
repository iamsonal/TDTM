
public class UTIL_Describe {
    // throw custom exceptions when a bogus object or field is provided.
    public class SchemaDescribeException extends Exception {
    }

    //maps to hold the describe info
    private static Map<String, Schema.SObjectType> gd;
    private static Map<String, Schema.DescribeSObjectResult> objectDescribes = new Map<String, Schema.DescribeSObjectResult>();

    /*******************************************
     * Gets describe maps for a new object
     ********************************************/
    static void fillMapsForObject(string objectName) {
        // get the object map the first time
        if (gd == null) {
            gd = Schema.getGlobalDescribe();
        }

        // get the object description
        if (gd.containsKey(objectName)) {
            if (!objectDescribes.containsKey(objectName)) {
                objectDescribes.put(objectName, gd.get(objectName).getDescribe());
            }
        } else {
            throw new SchemaDescribeException('Invalid object name \'' + objectName + '\'');
        }
    }

    /*******************************************************************************************************
     * @description Returns object describe data.
     * @param objectName the name of the object to lookup
     * @return Schema.DescribeSObjectResult of the object
     */
    public static Schema.DescribeSObjectResult getObjectDescribe(String objectName) {
        // make sure we have this object's schema mapped
        if (!objectDescribes.containsKey(objectName)) {
            fillMapsForObject(objectName);
        }

        return objectDescribes.get(objectName);
    }
}
