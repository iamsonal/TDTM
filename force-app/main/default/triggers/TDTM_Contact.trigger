/**
 * Created by sonal on 2022-06-18.
 */

trigger TDTM_Contact on Contact(
        before insert,
        before update,
        before delete,
        after insert,
        after update,
        after delete,
        after undelete
) {
    TDTM_Global_API.run(
            Trigger.isBefore,
            Trigger.isAfter,
            Trigger.isInsert,
            Trigger.isUpdate,
            Trigger.isDelete,
            Trigger.isUndelete,
            Trigger.new,
            Trigger.old,
            Schema.SObjectType.Contact
    );
}