public class AccountAgentMismatchChecker {
    public static void findMismatches() {
        List<Contact> mismatchedContacts = new List<Contact>();

        // Query Contacts with related Agent Accounts and Agent Appointments
        List<Contact> contacts = [SELECT Id, Name,
                                  (SELECT Id, Quartz_License__c, ShippingState FROM Agent_Accounts__r WHERE Group_Level__c = 'Corp' AND HealthCloudGA_Active__c = 'Yes'),
                                  (SELECT Id, State__c, Entity__c FROM AgentAppointments__r WHERE Status__c = 'Appointed')
                                  FROM Contact
                                  WHERE Status__c = 'Active'
                                  AND Id IN (SELECT Agent__c FROM Account WHERE Group_Level__c = 'Corp' AND HealthCloudGA_Active__c = 'Yes')];

        for (Contact contact : contacts) {
            Boolean stateMatch = false;
            Boolean licenseMatch = false;

            // Retrieve Account Data from Agent_Accounts__r
            if (contact.Agent_Accounts__r != null && !contact.Agent_Accounts__r.isEmpty()) {
                for (SObject accRecord : contact.Agent_Accounts__r) {
                    String accountLicense = (String) accRecord.get('Quartz_License__c');
                    String accountShippingState = (String) accRecord.get('ShippingState');

                    // Compare with Agent Appointments
                    if (contact.AgentAppointments__r != null && !contact.AgentAppointments__r.isEmpty()) {
                        for (SObject appt : contact.AgentAppointments__r) {
                            String appointmentState = (String) appt.get('State__c');
                            String appointmentEntity = (String) appt.get('Entity__c');

                            // Check for matches
                            if (appointmentState == accountShippingState) {
                                stateMatch = true;
                            }
                            if (accountLicense == appointmentEntity) {
                                licenseMatch = true;
                            }
                        }
                    }
                }
            }

            // If no matches for both criteria, flag this contact
            if (!stateMatch || !licenseMatch) {
                mismatchedContacts.add(contact);
            }
        }

        // Generate Report or Send Alerts
        if (!mismatchedContacts.isEmpty()) {
            // Example: Send Email Alert (you can replace this with your alerting/reporting logic)
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setSubject('Contact Agent Mismatch Detected');
            email.setToAddresses(new String[] {'apextest@sean.bingham.me'});
            email.setPlainTextBody('Mismatched Contacts:\n' + formatContactsForEmail(mismatchedContacts));
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] {email});
        }
    }

    // Helper method to format contact details for the email
    private static String formatContactsForEmail(List<Contact> contacts) {
        String formatted = '';
        for (Contact contact : contacts) {
            formatted += 'Contact Name: ' + contact.Name + '\n';
            formatted += '-----------------------\n';
        }
        return formatted;
    }
}