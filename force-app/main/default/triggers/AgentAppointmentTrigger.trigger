trigger AgentAppointmentTrigger on Agent_Appointment__c (after insert, after update) {
    // Call the mismatch checker logic
    AccountAgentMismatchChecker.findMismatches();
}