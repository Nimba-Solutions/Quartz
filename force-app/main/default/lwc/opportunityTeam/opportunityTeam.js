import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchUsers from '@salesforce/apex/OpportunityTeamService.searchUsers';
import addTeamMember from '@salesforce/apex/OpportunityTeamService.addTeamMember';
import getTeamMembers from '@salesforce/apex/OpportunityTeamService.getTeamMembers';
import removeTeamMember from '@salesforce/apex/OpportunityTeamService.removeTeamMember';
import getOpportunityTeamRoles from '@salesforce/apex/OpportunityTeamService.getOpportunityTeamRoles';

export default class OpportunityTeam extends LightningElement {
    @api recordId;
    searchTerm = '';
    showUserList = false;
    userResults = [];
    wiredTeamMembersResult;
    wiredRolesResult;
    userAccessLevels = new Map();

    @wire(getTeamMembers, { opportunityId: '$recordId' })
    wiredTeamMembers(result) {
        this.wiredTeamMembersResult = result;
    }

    @wire(getOpportunityTeamRoles)
    wiredRoles(result) {
        this.wiredRolesResult = result;
    }

    get teamMembers() {
        return this.wiredTeamMembersResult?.data || [];
    }

    get roles() {
        return this.wiredRolesResult?.data || [];
    }

    get teamMemberPills() {
        return this.teamMembers.map(member => ({
            type: 'avatar',
            label: `${member.User.Name} (${member.TeamMemberRole})`,
            name: member.Id,
            src: member.User.SmallPhotoUrl,
            fallbackIconName: 'standard:user',
            variant: 'circle',
            alternativeText: 'User avatar'
        }));
    }

    connectedCallback() {
        this.handleClickOutsideBound = this.handleClickOutside.bind(this);
        this.handleKeyDownBound = this.handleKeyDown.bind(this);
        document.addEventListener('click', this.handleClickOutsideBound);
        document.addEventListener('keydown', this.handleKeyDownBound);
    }

    disconnectedCallback() {
        document.removeEventListener('click', this.handleClickOutsideBound);
        document.removeEventListener('keydown', this.handleKeyDownBound);
    }

    handleKeyDown(event) {
        if (event.key === 'Escape') {
            this.closeDropdown();
        }
    }

    handleClickOutside(event) {
        const dropdownContainer = this.template.querySelector('.dropdown-container');
        const searchInput = this.template.querySelector('lightning-input');
        
        if (!dropdownContainer?.contains(event.target) && !searchInput?.contains(event.target)) {
            this.closeDropdown();
        }
    }

    closeDropdown() {
        this.showUserList = false;
        this.searchTerm = '';
        this.userResults = [];
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        if (this.searchTerm.length >= 2) {
            this.searchUsers();
            this.showUserList = true;
        } else {
            this.showUserList = false;
            this.userResults = [];
        }
    }

    handleAccessChange(event) {
        const userId = event.target.dataset.userid;
        this.userAccessLevels.set(userId, event.target.checked ? 'Edit' : 'Read');
    }

    async searchUsers() {
        try {
            this.userResults = await searchUsers({ searchTerm: this.searchTerm });
        } catch (error) {
            console.error('Error searching users:', error);
            this.userResults = [];
        }
    }

    async handleRoleSelect(event) {
        const userId = event.currentTarget.dataset.userid;
        const teamRole = event.currentTarget.dataset.role;
        const accessLevel = this.userAccessLevels.get(userId) || 'Read';

        if (this.teamMembers.length >= 2) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Maximum team members limit reached (2)',
                    variant: 'error'
                })
            );
            return;
        }

        const existingRole = this.teamMembers.find(member => member.TeamMemberRole === teamRole);
        if (existingRole) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'This role is already assigned to another team member',
                    variant: 'error'
                })
            );
            return;
        }
        
        try {
            await addTeamMember({ 
                opportunityId: this.recordId, 
                userId: userId,
                teamRole: teamRole,
                accessLevel: accessLevel
            });
            
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Team member added',
                    variant: 'success'
                })
            );
            
            await refreshApex(this.wiredTeamMembersResult);
            this.showUserList = false;
            this.searchTerm = '';
            this.userResults = [];
            this.userAccessLevels.clear();
            
        } catch (error) {
            console.error('Error adding team member:', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body?.message || 'Error adding team member',
                    variant: 'error'
                })
            );
        }
    }

    async handleRemoveTeamMember(event) {
        const memberId = event.detail.item.name;
        
        try {
            await removeTeamMember({ memberId });
            await refreshApex(this.wiredTeamMembersResult);
            
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Team member removed',
                    variant: 'success'
                })
            );
        } catch (error) {
            console.error('Error removing team member:', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body?.message || 'Error removing team member',
                    variant: 'error'
                })
            );
        }
    }
}