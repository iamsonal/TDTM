/**
 * Created by sonal on 2022-06-18.
 */

public with sharing class CON_UpdateContactDescription_TDTM extends TDTM_Runnable {

    public override TDTM_Runnable.DmlWrapper run(
            List<SObject> newList,
            List<SObject> oldList,
            TDTM_Runnable.Action triggerAction,
            Schema.DescribeSObjectResult objResult
    ) {
        TDTM_Runnable.DmlWrapper dmlWrapper = new TDTM_Runnable.DmlWrapper();

        if (triggerAction != TDTM_Runnable.Action.BeforeUpdate) {
            return dmlWrapper;
        }

        for (Contact vContact : (List<Contact>) newList) {
            vContact.Description = vContact.Description + ' updated';
        }

        return dmlWrapper;
    }
}