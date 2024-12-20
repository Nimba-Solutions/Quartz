@IsTest
private class OpportunityTeamServiceTest {
    @TestSetup
    static void setup() {
        // Create test user
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
        User testUser = new User(
            Alias = 'tuser',
            Email = 'testuser@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Testing',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'testuser@test.com' + System.currentTimeMillis()
        );
        insert testUser;

        // Create admin user
        Profile adminProfile = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        User adminUser = new User(
            Alias = 'admin',
            Email = 'admin@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Admin',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = adminProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'admin@test.com' + System.currentTimeMillis()
        );
        insert adminUser;

        // Create test opportunity
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert testOpp;
    }

    @IsTest
    static void testSearchUsers() {
        User testUser = [SELECT Id FROM User WHERE Email = 'testuser@test.com'];
        Test.startTest();
        List<User> results = OpportunityTeamService.searchUsers('test');
        Test.stopTest();
        System.assert(!results.isEmpty(), 'Should find at least one user');
    }

    @IsTest
    static void testGetTeamMembers() {
        User testUser = [SELECT Id FROM User WHERE Email = 'testuser@test.com'];
        Opportunity testOpp = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity'];

        OpportunityTeamMember member = new OpportunityTeamMember(
            OpportunityId = testOpp.Id,
            UserId = testUser.Id,
            TeamMemberRole = 'Sales Rep',
            OpportunityAccessLevel = 'Read'
        );
        insert member;

        Test.startTest();
        List<OpportunityTeamMember> members = OpportunityTeamService.getTeamMembers(testOpp.Id);
        Test.stopTest();

        System.assertEquals(1, members.size(), 'Should return one team member');
    }

    @IsTest
    static void testAddTeamMember() {
        User testUser = [SELECT Id FROM User WHERE Email = 'testuser@test.com'];
        Opportunity testOpp = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity'];
        
        System.runAs(testUser) {
            Test.startTest();
            OpportunityTeamService.addTeamMember(testOpp.Id, testUser.Id, 'Sales Rep', 'Read');
            Test.stopTest();
        }

        List<OpportunityTeamMember> members = [SELECT Id FROM OpportunityTeamMember WHERE OpportunityId = :testOpp.Id];
        System.assertEquals(1, members.size(), 'Should create one team member');
    }

    @IsTest
    static void testRemoveTeamMember() {
        User testUser = [SELECT Id FROM User WHERE Email = 'testuser@test.com'];
        Opportunity testOpp = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity'];

        OpportunityTeamMember member = new OpportunityTeamMember(
            OpportunityId = testOpp.Id,
            UserId = testUser.Id,
            TeamMemberRole = 'Sales Rep',
            OpportunityAccessLevel = 'Read'
        );
        insert member;

        System.runAs(testUser) {
            Test.startTest();
            OpportunityTeamService.removeTeamMember(member.Id);
            Test.stopTest();
        }

        List<OpportunityTeamMember> members = [SELECT Id FROM OpportunityTeamMember WHERE Id = :member.Id];
        System.assertEquals(0, members.size(), 'Should remove the team member');
    }

    @IsTest
    static void testGetOpportunityTeamRolesWithoutPermissionSet() {
        User testUser = [SELECT Id FROM User WHERE Email = 'testuser@test.com'];
        
        System.runAs(testUser) {
            Test.startTest();
            List<Map<String, String>> roles = OpportunityTeamService.getOpportunityTeamRoles();
            Test.stopTest();

            System.assertEquals(0, roles.size(), 'Should return no roles for user without permission sets');
        }
    }

    @IsTest
    static void testGetRolesAsAdmin() {
        User adminUser = [SELECT Id FROM User WHERE Email = 'admin@test.com'];
        
        System.runAs(adminUser) {
            Test.startTest();
            List<Map<String, String>> roles = OpportunityTeamService.getOpportunityTeamRoles();
            Test.stopTest();
            
            System.assert(!roles.isEmpty(), 'Admin should have access to roles');
            System.assert(roles.size() >= 6, 'Admin should have access to all roles');
        }
    }

    @IsTest
    static void testNegativeScenarios() {
        Test.startTest();

        // Test invalid search
        List<User> emptyResults = OpportunityTeamService.searchUsers('xxxxx');
        System.assertEquals(0, emptyResults.size(), 'Should return no results for invalid search');

        // Test invalid opportunity
        List<OpportunityTeamMember> noMembers = OpportunityTeamService.getTeamMembers('006000000000000');
        System.assertEquals(0, noMembers.size(), 'Should return no members for invalid opportunity');

        // Test invalid member removal
        try {
            OpportunityTeamService.removeTeamMember('00G000000000000');
            System.assert(false, 'Should throw exception for invalid member id');
        } catch (Exception e) {
            System.assert(true, 'Expected exception thrown');
        }

        Test.stopTest();
    }
}