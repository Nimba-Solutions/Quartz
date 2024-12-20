public without sharing class OpportunityTeamService {
    // Map of Permission Set Group DeveloperName to the role it can see
    private static final Map<String, String> PSG_TO_ROLE_MAP = new Map<String, String>{
        'Underwriting' => 'Underwriter',
        'Group_Enrollments' => 'Group Records',
        'Benefit_Configuration' => 'Benefit Config',
        'Enrollments' => 'Enrollment Team',
        'Quality_Audit' => 'Quality Audit'
    };

    private static final Set<String> ALL_ROLES = new Set<String>{
        'Underwriter',
        'Peer Reviewer',
        'Group Records',
        'Benefit Config',
        'Enrollment Team',
        'Quality Audit'
    };

    @AuraEnabled
    public static List<User> searchUsers(String searchTerm) {
        String searchKey = '%' + searchTerm + '%';
        return [
            SELECT Id, Name
            FROM User 
            WHERE Name LIKE :searchKey 
            OR Email LIKE :searchKey
            LIMIT 5
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<OpportunityTeamMember> getTeamMembers(Id opportunityId) {
        return [
            SELECT 
                Id,
                UserId,
                User.Name,
                TeamMemberRole,
                OpportunityAccessLevel
            FROM OpportunityTeamMember 
            WHERE OpportunityId = :opportunityId
            WITH SECURITY_ENFORCED
        ];
    }
    
    @AuraEnabled
    public static void removeTeamMember(Id memberId) {
        OpportunityTeamMember member = [SELECT Id FROM OpportunityTeamMember WHERE Id = :memberId WITH SECURITY_ENFORCED];
        delete member;
    }
    
    @AuraEnabled
    public static void addTeamMember(Id opportunityId, Id userId, String teamRole, String accessLevel) {
        OpportunityTeamMember member = new OpportunityTeamMember(
            OpportunityId = opportunityId,
            UserId = userId,
            TeamMemberRole = teamRole,
            OpportunityAccessLevel = accessLevel
        );
        
        insert member;
    }

    private static Set<String> getUserAssignedRoles() {
        // If user is an admin, return all roles
        if (hasAdminProfile()) {
            return ALL_ROLES;
        }

        Set<String> assignedRoles = new Set<String>();

        // Special handling for Peer Reviewer role - available to users with Underwriting PSG
        if (hasPermissionSetGroup('Underwriting')) {
            assignedRoles.add('Peer Reviewer');
        }

        // Query user's Permission Set Group assignments
        List<PermissionSetAssignment> assignments = [
            SELECT PermissionSetGroup.DeveloperName 
            FROM PermissionSetAssignment 
            WHERE AssigneeId = :UserInfo.getUserId()
            AND PermissionSetGroup.DeveloperName IN :PSG_TO_ROLE_MAP.keySet()
        ];

        // Add corresponding roles based on PSG assignments
        for (PermissionSetAssignment psa : assignments) {
            String role = PSG_TO_ROLE_MAP.get(psa.PermissionSetGroup.DeveloperName);
            if (role != null) {
                assignedRoles.add(role);
            }
        }

        return assignedRoles;
    }

    private static Boolean hasPermissionSetGroup(String psgName) {
        List<PermissionSetAssignment> assignments = [
            SELECT Id 
            FROM PermissionSetAssignment 
            WHERE AssigneeId = :UserInfo.getUserId()
            AND PermissionSetGroup.DeveloperName = :psgName
            LIMIT 1
        ];
        return !assignments.isEmpty();
    }

    private static Boolean hasAdminProfile() {
        return [
            SELECT Id 
            FROM Profile 
            WHERE Id = :UserInfo.getProfileId() 
            AND Name LIKE '%Admin%'
            LIMIT 1
        ].size() > 0;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getOpportunityTeamRoles() {
        List<Map<String, String>> roles = new List<Map<String, String>>();
        Schema.DescribeFieldResult fieldResult = OpportunityTeamMember.TeamMemberRole.getDescribe();
        List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
        
        Set<String> assignedRoles = getUserAssignedRoles();
        
        // If user has no assigned roles through PSGs and is not admin, return empty list
        if (assignedRoles.isEmpty()) {
            return roles;
        }
        
        for (Schema.PicklistEntry entry : picklistValues) {
            if (entry.isActive() && assignedRoles.contains(entry.getValue())) {
                roles.add(new Map<String, String>{
                    'Id' => entry.getValue(),
                    'Name' => entry.getLabel()
                });
            }
        }
        
        return roles;
    }
}