
/**
 * @author Salesforce.org
 * @date 2017
 * @group TDTM
 * @group-content ../../ApexDocContent/TDTM.htm
 * @description A Class that accesses and modifies TDTM configuration. The configuration is isolated by Namespace.
 */
public class TDTM_Manager {

    public Map<Id, Trigger_Handler__c> packageHandlers { get; set; }
    public Set<TDTM_Global_API.TdtmToken> packageTokens { get; set; }

    private Map<Id, Trigger_Handler__c> allHandlers { get; set; }
    private Set<TDTM_Global_API.TdtmToken> allTokens { get; set; }

    private List<Trigger_Handler__c> toDelete = new List<Trigger_Handler__c>();
    private List<Trigger_Handler__c> toUpsert = new List<Trigger_Handler__c>();

    /*******************************************************************************************************
    * @description Constructor. Sets namespace, packageHandlers, and packageTokens default properties.
    *********************************************************************************************************/
    public TDTM_Manager() {
        // Get all handlers from database.
        this.allHandlers = new Map<Id, Trigger_Handler__c>([
                SELECT Id, Active__c, Asynchronous__c, Object__c, Load_Order__c,
                        Class__c, Trigger_Action__c,
                        Filter_Field__c, Filter_Value__c, Usernames_to_Exclude__c
                FROM Trigger_Handler__c
                ORDER BY Load_Order__c
                LIMIT 5000
        ]);
        this.allTokens = getTokenSet(this.allHandlers);

        // Isolate the current handlers by namespace
        this.packageHandlers = new Map<Id, Trigger_Handler__c>();
        this.packageTokens = getTokenSet(this.packageHandlers);
    }

    /*******************************************************************************************************
    * @description Update the existing Trigger Handlers in the database. Will also delete Handlers not
    * included in the default configuration.
    * @param newTokenSet A set of TDTM Tokens that represent a new configuration to compare to existing
    * @return void
    *********************************************************************************************************/
    public void updateDefaultTdtmConfig(Set<TDTM_Global_API.TdtmToken> newTokenSet) {

        // Check for new items to add since these didn't match against existing items
        if (newTokenSet.size() > 0) {
            for (TDTM_Global_API.TdtmToken newToken : newTokenSet) {

                // Check to make sure we dont create duplicates by object and class
                TDTM_Global_API.TdtmToken dup = newToken.getMatch(this.allTokens);
                if (dup == null) {
                    this.toUpsert.add(mergeToken(new Trigger_Handler__c(), newToken));
                }
            }
        }

        if (this.toUpsert.size() > 0) {
            upsert this.toUpsert;

            // Update class properties because we have updates.
            this.packageHandlers = new Map<Id, Trigger_Handler__c>(this.toUpsert);
            this.packageTokens = this.getTokenSet(this.packageHandlers);
        }

        if (this.toDelete.size() > 0) {
            delete this.toDelete;
        }

        //after save the tokens into database, clear the cached tokens
        List<TDTM_Global_API.TdtmToken> cachedTokens = TDTM_Config.getTdtmConfig();
        cachedTokens.clear();
    }


    /*******************************************************************************************************
    * @description Create an Set of TDTM Tokens
    * @param hs A Map of TDTM trigger handlers representing a new default configuration.
    * @return A set of TDTM Tokens from the Trigger handlers that were passed in.
    *********************************************************************************************************/
    public Set<TDTM_Global_API.TdtmToken> getTokenSet(Map<Id, Trigger_Handler__c> hs) {
        Set<TDTM_Global_API.TdtmToken> ts = new Set<TDTM_Global_API.TdtmToken>();

        for (Trigger_Handler__c h : hs.values()) {
            TDTM_Global_API.TdtmToken newToken = new TDTM_Global_API.TdtmToken(h.Class__c, h.Object__c, h.Trigger_Action__c,
                    h.Load_Order__c, h.Active__c, h.Asynchronous__c,
                    h.Filter_Field__c, h.Filter_Value__c,
                    h.Usernames_to_Exclude__c);
            // Conditionally set Id
            if (h.Id != null) {
                newToken.handlerId = h.Id;
            }
            ts.add(newToken);
        }

        return ts;
    }

    /***
        Merge token data into Trigger Handler. Has a special case to check if the token does not contain an ID. If not, it is a new handler so it adds "classname" and "targetObject" properties.
    ***/
    private Trigger_Handler__c mergeToken(Trigger_Handler__c h, TDTM_Global_API.TdtmToken t) {
        h.Trigger_Action__c = t.actions;
        h.Active__c = t.active;
        h.Load_Order__c = t.loadOrderDec;
        h.Asynchronous__c = t.async;
        h.Filter_Field__c = t.filterField;
        h.Filter_Value__c = t.filterValue;
        h.Usernames_to_Exclude__c = t.usernamesToExclude;

        if (t.handlerId == null) {
            h.Class__c = t.className;
            h.Object__c = t.targetObject;
        }
        return h;
    }
}