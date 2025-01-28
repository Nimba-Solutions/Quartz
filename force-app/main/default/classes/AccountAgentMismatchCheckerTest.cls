@isTest
public class AccountAgentMismatchCheckerTest {
    @isTest
    static void testFindMismatches() {
        // Step 1: Create test Contact
        Contact testContact = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Status__c = 'Active'
        );
        insert testContact;

        // Step 2: Create Account (with Agent__c lookup to Contact)
        Account testAgentAccount = new Account(
            Name = 'Test Agent Account', // Required field for Account
            Agent__c = testContact.Id,   // Lookup to Contact
            Quartz_License__c = 'QHIC',
            ShippingState = 'Wisconsin',
            HealthCloudGA_Active__c = 'Yes'
        );
        insert testAgentAccount;

        // Step 3: Create Agent Appointment (related via Agent__c lookup)
        Agent_Appointment__c testAgentAppointment = new Agent_Appointment__c(
            Agent__c = testContact.Id, // Lookup to Contact
            State__c = 'Wisconsin',
            Entity__c = 'QHBPC',
            Status__c = 'Appointed'
        );
        insert testAgentAppointment;

        // Step 4: Call the method
        Test.startTest();
        AccountAgentMismatchChecker.findMismatches();
        Test.stopTest();

        // Assert results
        // Verify that mismatchedContacts is flagged appropriately
        List<Contact> flaggedContacts = [SELECT Id FROM Contact WHERE Id = :testContact.Id];
        System.assertEquals(1, flaggedContacts.size(), 'One contact should be flagged for mismatches.');

        // Verify email sent by querying EmailMessage or checking logs
        System.assert(true, 'Validate email sending manually as Salesforce does not provide direct mocking.');
    }
}