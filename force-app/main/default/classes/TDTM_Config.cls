
/**
 * @author Salesforce.org
 * @date 2014
 * @group TDTM
 * @group-content ../../ApexDocContent/TDTM.htm
 * @description A Class to retreive, cache and interact with the Org wide TDTM configurtaion
 */
public class TDTM_Config {

    /*******************************************************************************************************
    * @description Holds the trigger handlers cached in a list, to avoid repetitive soql calls.
    *********************************************************************************************************/
    @TestVisible
    private static List<TDTM_Global_API.TdtmToken> tdtmTokensCache;

    /*******************************************************************************************************
    * @description Number of trigger handlers records that currently exist in the system.
    *********************************************************************************************************/
    private static Integer rowCount;

    /********************************************************************************************************
    * @description Returns the TDTM configuration. If no configuration is currently set, it will return
    * the default configuration without setting it. The configuration returned has not yet been inserted in the
    * database. It can be manipulated, if necessary, then set.
    * If no configuration exists, the application will insert the defaults when any of the triggers run.
    * @return List<TDTM_Global_API.TdtmToken> List of trigger handler tokens with the default values.
    *********************************************************************************************************/
    public static List<TDTM_Global_API.TdtmToken> getTdtmConfig() {
        if(tdtmTokensCache != null && tdtmTokensCache.size() > 0) {
            return tdtmTokensCache;
        }

        List<TDTM_Global_API.TdtmToken> tokens  = new List<TDTM_Global_API.TdtmToken>();

        List<Trigger_Handler__c> tdtmConfig = [select Class__c, Object__c, Trigger_Action__c, Load_Order__c, Active__c,
                Asynchronous__c, Filter_Field__c, Filter_Value__c, Usernames_to_Exclude__c
        FROM Trigger_Handler__c];

        for(Trigger_Handler__c handler : tdtmConfig) {
            tokens.add(new TDTM_Global_API.TdtmToken(handler.Class__c, handler.Object__c, handler.Trigger_Action__c,
                    handler.Load_Order__c, handler.Active__c, handler.Asynchronous__c,
                    handler.Filter_Field__c, handler.Filter_Value__c,
                    handler.Usernames_to_Exclude__c));
        }

        tdtmTokensCache = tokens;
        return tokens;
    }

    /*******************************************************************************************************
    * @description Returns the classes that will be called for the specified object and action. Returned list
    *              is sorted by load order.
    * @param objectName The name of the object.
    * @param action The action (before insert, after insert,...).
    * @return List<DTM_Global_API.TdtmToken> List of trigger handlers to call, sorted by load order.
    *********************************************************************************************************/
    public static List<TDTM_Global_API.TdtmToken> getClassesToCallForObject(String objectName, TDTM_Runnable.Action action) {

        //Getting the TDTM configuration and storing it in the cache.
        List<TDTM_Global_API.TdtmToken> tdtmTokens = getTdtmConfig();
        List<TDTM_Global_API.TdtmToken> objectTokens = new List<TDTM_Global_API.TdtmToken>();
        //Get current username
        String currUserName = UserInfo.getUserName();

        for(TDTM_Global_API.TdtmToken token : tdtmTokens) {
            
            //Get a list of excluded usernames in lowercase
            Set<String> excludedUserNamesLowercase = userNamesToExclude(token);
            
            //Filtering those active by object and action.
            //Actions should not be null, otherwise it will throw null pointer exception. We might need to create a WI to do more validation on insert/update Trigger Handler
            if(token.active && token.targetObject == objectName
                    && token.actions != null
                    && token.actions.contains(action.Name())
                    && !excludedUserNamesLowercase.contains(currUsername)) {
                objectTokens.add(token);
            }
        }

        // Order by loadOrder
        objectTokens.sort();

        return objectTokens;
    }

    private static Set<String> userNamesToExclude(TDTM_Global_API.TdtmToken token) {

        //Get a list of excluded usernames in lowercase
        Set<String> excludedUserNamesLowercase = new Set<String>();
        Set<String> excludedUserNames = (token.usernamesToExclude != null ?
                new Set<String>(token.usernamesToExclude.split('\\s*;\\s*')) : new Set<String>());
        for (String username : excludedUserNames) {
            excludedUserNamesLowercase.add(username.toLowerCase());
        }

        return excludedUserNamesLowercase;
    }
}