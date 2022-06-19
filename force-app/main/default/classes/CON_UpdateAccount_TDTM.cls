/**
 * Created by sonal on 2022-06-18.
 */

public with sharing class CON_UpdateAccount_TDTM extends TDTM_Runnable {

    public override TDTM_Runnable.DmlWrapper run(
            List<SObject> newList,
            List<SObject> oldList,
            TDTM_Runnable.Action triggerAction,
            Schema.DescribeSObjectResult objResult
    ) {
        TDTM_Runnable.DmlWrapper dmlWrapper = new TDTM_Runnable.DmlWrapper();

        if (triggerAction != TDTM_Runnable.Action.AfterUpdate) {
            return dmlWrapper;
        }

        List<Account> accounts = new List<Account>();
        Set<Id> accountIds = new Set<Id>();
        for (Contact vContact : (List<Contact>) newList) {
            if (vContact.AccountId != null) {
                accountIds.add(vContact.AccountId);
            }
        }

        for (Id accountId : accountIds) {
            Account vAccount = new Account(Id=accountId, Industry='Banking');
            accounts.add(vAccount);
        }

        update accounts;

        return dmlWrapper;
    }
}