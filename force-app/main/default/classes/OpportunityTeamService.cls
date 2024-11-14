public with sharing class OpportunityTeamService {
    @AuraEnabled
    public static List<User> searchUsers(String searchTerm) {
        String searchKey = '%' + searchTerm + '%';
        return [
            SELECT Id, Name, SmallPhotoUrl 
            FROM User 
            WHERE IsActive = true 
            AND (Name LIKE :searchKey OR Email LIKE :searchKey)
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
                User.SmallPhotoUrl,
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
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getOpportunityTeamRoles() {
        List<Map<String, String>> roles = new List<Map<String, String>>();
        
        Schema.DescribeFieldResult fieldResult = OpportunityTeamMember.TeamMemberRole.getDescribe();
        List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
        
        for(Schema.PicklistEntry entry : picklistValues) {
            if(entry.isActive()) {
                roles.add(new Map<String, String>{
                    'Id' => entry.getValue(),
                    'Name' => entry.getLabel()
                });
            }
        }
        
        return roles;
    }
}