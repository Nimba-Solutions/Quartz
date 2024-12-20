import { LightningElement, api, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import searchUsers from "@salesforce/apex/OpportunityTeamService.searchUsers";
import addTeamMember from "@salesforce/apex/OpportunityTeamService.addTeamMember";
import getTeamMembers from "@salesforce/apex/OpportunityTeamService.getTeamMembers";
import removeTeamMember from "@salesforce/apex/OpportunityTeamService.removeTeamMember";
import getOpportunityTeamRoles from "@salesforce/apex/OpportunityTeamService.getOpportunityTeamRoles";

export default class OpportunityTeam extends LightningElement {
  @api recordId;
  searchTerm = "";
  showUserList = false;
  userResults = [];
  wiredTeamMembersResult;
  wiredRolesResult;
  userAccessLevels = new Map();

  @wire(getTeamMembers, { opportunityId: "$recordId" })
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
    return this.teamMembers.map((member) => ({
      type: "avatar",
      label: `${member.User.Name} (${member.TeamMemberRole})`,
      name: member.Id,
      fallbackIconName: "standard:user",
      variant: "circle",
      alternativeText: "User avatar",
    }));
  }

  handleKeyDown(event) {
    if (event.key === "Escape") {
      this.closeDropdown();
    }
  }

  closeDropdown() {
    this.showUserList = false;
    this.searchTerm = "";
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
    const isChecked = event.target.checked;
    this.userAccessLevels.set(userId, isChecked ? "Edit" : "Read");
    this.userResults = this.userResults.map((user) =>
      user.Id === userId ? { ...user, hasEditAccess: isChecked } : user
    );
  }

  async searchUsers() {
    try {
        const results = await searchUsers({ searchTerm: this.searchTerm });

        this.userResults = results.map((user) => {
            if (!this.userAccessLevels.has(user.Id)) {
                this.userAccessLevels.set(user.Id, "Edit");
            }
            return {
                ...user,
                hasEditAccess: this.userAccessLevels.get(user.Id) === "Edit",
            };
        });
    } catch (error) {
        console.error("Error searching users:", error);
        this.userResults = [];
    }
  }

  async handleRoleSelect(event) {
    const userId = event.currentTarget.dataset.userid;
    const teamRole = event.currentTarget.dataset.role;
    const accessLevel = this.userAccessLevels.get(userId) || "Edit";

    try {
      await addTeamMember({
        opportunityId: this.recordId,
        userId: userId,
        teamRole: teamRole,
        accessLevel: accessLevel,
      });

      // Refresh the data without clearing it first
      await refreshApex(this.wiredTeamMembersResult);

      this.dispatchEvent(
        new ShowToastEvent({
          title: "Success",
          message: "Team member added",
          variant: "success",
        })
      );

      // Clear UI state
      this.showUserList = false;
      this.searchTerm = "";
      this.userResults = [];
      this.userAccessLevels.clear();
    } catch (error) {
      console.error("Error adding team member:", error);
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: error.body?.message || "Error adding team member",
          variant: "error",
        })
      );
    }
  }

  async handleRemoveTeamMember(event) {
    const memberId = event.detail.item.name;

    try {
      await removeTeamMember({ memberId });
      
      // Refresh the data
      await refreshApex(this.wiredTeamMembersResult);

      this.dispatchEvent(
        new ShowToastEvent({
          title: "Success",
          message: "Team member removed",
          variant: "success",
        })
      );
    } catch (error) {
      console.error("Error removing team member:", error);
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: error.body?.message || "Error removing team member",
          variant: "error",
        })
      );
    }
  }
}
