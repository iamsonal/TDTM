/**
 * Created by sonal on 2022-06-18.
 */
@IsTest
public with sharing class CON_UpdateContact_TEST {

    @IsTest
    public static void testUpdateContactFilterTrue() {
        List<TDTM_Global_API.TdtmToken> tokens = TDTM_Global_API.getTdtmConfig();
        tokens.add(
                new TDTM_Global_API.TdtmToken(
                        'CON_UpdateContactDescription_TDTM',
                        'Contact',
                        'BeforeUpdate',
                        1.00
                )
        );
        tokens.add(
                new TDTM_Global_API.TdtmToken(
                        'CON_UpdateAccount_TDTM',
                        'Contact',
                        'BeforeUpdate',
                        2.00, true, false, 'Account.AccountNumber', '12345', null
                )
        );
        TDTM_Global_API.setTdtmConfig(tokens);

        Account account1 = new Account(Name = 'Demo Account 1');
        Account account2 = new Account(Name = 'Demo Account 2', AccountNumber = '12345');
        List<Account> accounts = new List<Account>{account1, account2};
        insert accounts;

        Contact contact1 = new Contact(LastName = 'Doe', AccountId = account1.Id);
        Contact contact2 = new Contact(LastName = 'Jane', AccountId = account2.Id);
        List<Contact> contacts = new List<Contact>{contact1, contact2};
        insert contacts;

        contact1.FirstName = 'John';
        contact2.FirstName = 'Mary';
        update contacts;
    }

    @IsTest
    public static void testUpdateContactFilterFalse() {
        List<TDTM_Global_API.TdtmToken> tokens = TDTM_Global_API.getTdtmConfig();
        tokens.add(
                new TDTM_Global_API.TdtmToken(
                        'CON_UpdateContactDescription_TDTM',
                        'Contact',
                        'BeforeUpdate',
                        1.00
                )
        );
        tokens.add(
                new TDTM_Global_API.TdtmToken(
                        'CON_UpdateAccount_TDTM',
                        'Contact',
                        'BeforeUpdate',
                        2.00, true, false, 'Account.AccountNumber', '12345', null
                )
        );
        TDTM_Global_API.setTdtmConfig(tokens);

        Account account1 = new Account(Name = 'Demo Account 1');
        Account account2 = new Account(Name = 'Demo Account 2', AccountNumber = '6789');
        List<Account> accounts = new List<Account>{account1, account2};
        insert accounts;

        Contact contact1 = new Contact(LastName = 'Doe', AccountId = account1.Id);
        Contact contact2 = new Contact(LastName = 'Jane', AccountId = account2.Id);
        List<Contact> contacts = new List<Contact>{contact1, contact2};
        insert contacts;

        contact1.FirstName = 'John';
        contact2.FirstName = 'Mary';
        update contacts;
    }

    @IsTest
    public static void testUpdateContactAsync() {
        List<TDTM_Global_API.TdtmToken> tokens = TDTM_Global_API.getTdtmConfig();
        tokens.add(
                new TDTM_Global_API.TdtmToken(
                        'CON_UpdateContactDescription_TDTM',
                        'Contact',
                        'BeforeUpdate',
                        1.00
                )
        );
        tokens.add(
                new TDTM_Global_API.TdtmToken(
                        'CON_UpdateAccount_TDTM',
                        'Contact',
                        'BeforeUpdate',
                        2.00, true, true, 'Account.AccountNumber', '12345', null
                )
        );
        TDTM_Global_API.setTdtmConfig(tokens);

        Account account1 = new Account(Name = 'Demo Account 1');
        Account account2 = new Account(Name = 'Demo Account 2', AccountNumber = '6789');
        List<Account> accounts = new List<Account>{account1, account2};
        insert accounts;

        Contact contact1 = new Contact(LastName = 'Doe', AccountId = account1.Id);
        Contact contact2 = new Contact(LastName = 'Jane', AccountId = account2.Id);
        List<Contact> contacts = new List<Contact>{contact1, contact2};
        insert contacts;

        contact1.FirstName = 'John';
        contact2.FirstName = 'Mary';
        Test.startTest();
        update contacts;
        Test.stopTest();
    }
}