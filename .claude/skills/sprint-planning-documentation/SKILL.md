---
name: sprint-planning-documentation
description: Creates structured sprint planning documentation including goals, user stories, tasks, and success criteria for agile development teams
---

# Sprint Planning Documentation Skill

This skill generates comprehensive sprint planning documentation that clearly communicates sprint goals, tasks, and expectations for development teams.

## When to Use This Skill

Use this skill when:
- Planning a new sprint
- Documenting sprint kickoff meetings
- Creating sprint backlogs
- Communicating sprint plans to stakeholders
- Tracking sprint progress
- Conducting sprint retrospectives preparation

## Sprint Planning Document Structure

### 1. Sprint Header

```markdown
# Sprint [Number]: [Sprint Name/Theme]

**Sprint Duration**: [Start Date] - [End Date] (X weeks)
**Team**: [Team Name]
**Scrum Master**: [Name]
**Product Owner**: [Name]
**Sprint Goal**: [One sentence overarching goal]

---
```

**Example:**

```markdown
# Sprint 47: Authentication Migration

**Sprint Duration**: January 15, 2024 - January 26, 2024 (2 weeks)
**Team**: Platform Engineering Team
**Scrum Master**: Sarah Johnson
**Product Owner**: Mike Chen
**Sprint Goal**: Complete migration from username/password to key pair authentication for Snowflake integration

---
```

### 2. Sprint Goal and Objectives

```markdown
## Sprint Goal

[Detailed description of what the sprint aims to achieve]

### Success Criteria

Sprint is successful if:
1. [Measurable outcome 1]
2. [Measurable outcome 2]
3. [Measurable outcome 3]

### Key Deliverables

- [Deliverable 1]
- [Deliverable 2]
- [Deliverable 3]

### Out of Scope

Items explicitly not included in this sprint:
- [Item 1]
- [Item 2]
```

**Example:**

```markdown
## Sprint Goal

Migrate Snowflake authentication from username/password to key pair authentication to improve security and comply with new organizational security requirements. All production systems must be updated with minimal downtime.

### Success Criteria

Sprint is successful if:
1. All Snowflake connections use key pair authentication
2. No authentication-related incidents during migration
3. Documentation updated with new authentication procedures
4. CAB approval obtained and deployment completed

### Key Deliverables

- Updated connection strings in all applications
- Key pair generation and secure storage implementation
- Migration playbook and rollback procedures
- Updated troubleshooting documentation
- Stakeholder communication completed

### Out of Scope

Items explicitly not included in this sprint:
- Performance optimization of existing Snowflake queries
- New data warehouse features
- Migration of non-production environments (scheduled for next sprint)
```

### 3. Team Capacity

```markdown
## Team Capacity

### Team Members

| Name | Role | Availability | Capacity (hours) | Notes |
|------|------|--------------|------------------|-------|
| [Name] | [Role] | [%] | [Hours] | [Any notes] |

**Total Sprint Capacity**: X hours
**Planned Velocity**: Y story points

### Holidays/Time Off

- [Date]: [Person] - [Reason]

### Other Commitments

- [Meeting/Event]: [Hours] - [Participants]
```

**Example:**

```markdown
## Team Capacity

### Team Members

| Name | Role | Availability | Capacity (hours) | Notes |
|------|------|--------------|------------------|-------|
| John Smith | Senior Developer | 90% | 72 | CAB presentation on 1/20 |
| Jane Doe | Developer | 100% | 80 | |
| Bob Wilson | Developer | 80% | 64 | Part-time on Project X |
| Sarah Lee | QA Engineer | 100% | 80 | |
| Mike Chen | PO | 20% | 16 | Available for reviews |

**Total Sprint Capacity**: 312 hours
**Planned Velocity**: 34 story points

### Holidays/Time Off

- Jan 18: John Smith - Half day (medical appointment)
- Jan 25: Jane Doe - Full day (personal)

### Other Commitments

- Engineering All-Hands (Jan 19): 2 hours - All team members
- Production Deployment Support: 8 hours - On-call rotation
```

### 4. User Stories and Tasks

```markdown
## User Stories

### Story 1: [Story Title]

**Story ID**: [Ticket ID from Azure DevOps/Jira]
**Priority**: High / Medium / Low
**Story Points**: X
**Assignee**: [Name]

**User Story**:
As a [role]
I want [feature]
So that [benefit]

**Acceptance Criteria**:
- [ ] [Criterion 1]
- [ ] [Criterion 2]
- [ ] [Criterion 3]

**Technical Notes**:
- [Implementation detail 1]
- [Implementation detail 2]

**Dependencies**:
- [Dependency 1]
- [Dependency 2]

**Tasks**:
- [ ] [Task 1] - [Estimated hours] - [Assignee]
- [ ] [Task 2] - [Estimated hours] - [Assignee]
- [ ] [Task 3] - [Estimated hours] - [Assignee]

**Definition of Done**:
- [ ] Code complete and reviewed
- [ ] Unit tests written and passing
- [ ] Integration tests passing
- [ ] Documentation updated
- [ ] Deployed to staging and validated
- [ ] Product Owner acceptance
```

**Example:**

```markdown
## User Stories

### Story 1: Implement Key Pair Authentication for Snowflake

**Story ID**: PBI-1234
**Priority**: High
**Story Points**: 8
**Assignee**: John Smith

**User Story**:
As a system administrator
I want to use key pair authentication for Snowflake connections
So that we have more secure authentication without managing passwords

**Acceptance Criteria**:
- [ ] Connection string updated to use key pair authentication
- [ ] Private key securely stored in Azure Key Vault
- [ ] Public key registered with Snowflake
- [ ] All existing queries work without modification
- [ ] Error handling for authentication failures implemented
- [ ] Logging includes authentication method used

**Technical Notes**:
- Use RSA 2048-bit key pair
- Store private key in Azure Key Vault with appropriate access policies
- Update connection string format: User=USERNAME;Authenticator=SNOWFLAKE_JWT
- Implement key rotation capability (not required this sprint, but design for it)

**Dependencies**:
- Azure Key Vault access provisioned
- Snowflake admin access for public key registration

**Tasks**:
- [ ] Generate RSA key pair - 2h - John Smith
- [ ] Store private key in Azure Key Vault - 2h - John Smith
- [ ] Register public key with Snowflake - 1h - John Smith (requires DBA)
- [ ] Update connection string configuration - 3h - John Smith
- [ ] Implement authentication code - 5h - John Smith
- [ ] Write unit tests - 4h - Jane Doe
- [ ] Update error handling - 3h - Jane Doe
- [ ] Integration testing - 4h - Sarah Lee
- [ ] Update documentation - 2h - John Smith

**Definition of Done**:
- [ ] Code complete and reviewed
- [ ] Unit tests written (>80% coverage) and passing
- [ ] Integration tests passing in dev environment
- [ ] Security review completed
- [ ] Documentation updated (ARCHITECTURE.md, TROUBLESHOOTING.md)
- [ ] Deployed to staging and validated
- [ ] Product Owner acceptance
- [ ] CAB presentation materials prepared
```

### 5. Technical Debt and Bugs

```markdown
## Technical Debt

Stories addressing technical debt this sprint:

| Item | Description | Priority | Effort | Assignee |
|------|-------------|----------|--------|----------|
| [ID] | [Description] | [P] | [Hours] | [Name] |

## Bugs

Critical bugs to be addressed:

| Bug ID | Description | Severity | Effort | Assignee |
|--------|-------------|----------|--------|----------|
| [ID] | [Description] | [Level] | [Hours] | [Name] |
```

### 6. Risks and Dependencies

```markdown
## Risks

| Risk | Impact | Probability | Mitigation | Owner |
|------|--------|-------------|------------|-------|
| [Risk description] | H/M/L | H/M/L | [Mitigation plan] | [Name] |

## External Dependencies

| Dependency | Required By | Status | Contact | Notes |
|------------|-------------|--------|---------|-------|
| [What's needed] | [Date] | [Status] | [Who to contact] | [Details] |
```

**Example:**

```markdown
## Risks

| Risk | Impact | Probability | Mitigation | Owner |
|------|--------|-------------|------------|-------|
| Snowflake DBA unavailable for key registration | High | Medium | Schedule key registration session in advance; identify backup DBA | John Smith |
| Key Vault access delayed | High | Low | Submit access request in Sprint Planning; escalate if needed | Mike Chen |
| Authentication changes break existing jobs | High | Medium | Thorough testing in dev/staging; maintain rollback procedure | John Smith |

## External Dependencies

| Dependency | Required By | Status | Contact | Notes |
|------------|-------------|--------|---------|-------|
| Snowflake DBA for public key registration | Jan 17 | Scheduled | dba-team@company.com | Meeting scheduled for Jan 17, 2pm |
| Azure Key Vault access approval | Jan 16 | Pending | security-team@company.com | Ticket #SEC-4567 submitted |
| CAB approval for production deployment | Jan 24 | Not started | Sarah Johnson will present | Presentation due Jan 22 |
```

### 7. Sprint Schedule

```markdown
## Sprint Schedule

### Key Dates

- **Sprint Planning**: [Date/Time]
- **Daily Standups**: [Days/Time]
- **Mid-Sprint Check-in**: [Date/Time]
- **Sprint Review**: [Date/Time]
- **Sprint Retrospective**: [Date/Time]

### Deployment Windows

- **Staging Deployment**: [Date/Time]
- **Production Deployment**: [Date/Time]

### Important Meetings

- [Meeting Name]: [Date/Time] - [Attendees]
```

### 8. Communication Plan

```markdown
## Communication Plan

### Stakeholder Updates

- **Frequency**: [Daily/Weekly]
- **Method**: [Email/Slack/Meeting]
- **Recipients**: [List]

### Key Messages

- [Message 1]
- [Message 2]

### Demo Preparation

- **Demo Date**: [Date]
- **Demo Content**: [What to show]
- **Demo Owner**: [Name]
```

**Example:**

```markdown
## Communication Plan

### Stakeholder Updates

- **Frequency**: Weekly on Fridays
- **Method**: Email summary to stakeholder list
- **Recipients**: 
  - Solutions Delivery Directors
  - Enterprise Architecture team
  - Database team leads

### Key Messages

- Authentication migration improves security posture
- Minimal user impact expected (transparent change)
- Enhanced monitoring capabilities post-migration
- Rollback procedure in place if needed

### Demo Preparation

- **Demo Date**: January 26, 2pm
- **Demo Content**: 
  - Show successful Snowflake connection with key pair auth
  - Demonstrate error handling and logging
  - Walk through updated documentation
- **Demo Owner**: John Smith
- **Demo Environment**: Staging
```

### 9. Sprint Metrics

```markdown
## Sprint Metrics

### Baseline Metrics

- **Starting Velocity**: X story points
- **Team Capacity**: Y hours
- **Commitment**: Z story points

### Target Metrics

- **Velocity Goal**: X story points
- **Completed Stories**: Y of Z
- **Defect Rate**: < X bugs per story
- **Code Coverage**: > X%
- **Sprint Goal Achievement**: 100%

### Tracking

Daily burndown chart and velocity tracking in [Azure DevOps/Jira]
```

### 10. Notes and Action Items

```markdown
## Sprint Planning Notes

### Key Decisions

- [Decision 1]
- [Decision 2]

### Questions Raised

- [ ] [Question 1] - Owner: [Name] - Due: [Date]
- [ ] [Question 2] - Owner: [Name] - Due: [Date]

### Action Items from Planning

- [ ] [Action 1] - Owner: [Name] - Due: [Date]
- [ ] [Action 2] - Owner: [Name] - Due: [Date]

### Follow-ups Needed

- [Item to follow up on]
```

## Quality Checklist

Before finalizing sprint planning documentation:

- [ ] Sprint goal is clear and measurable
- [ ] Success criteria are specific
- [ ] All user stories have acceptance criteria
- [ ] Story points and effort estimates provided
- [ ] Team capacity calculated accurately
- [ ] Dependencies identified and tracked
- [ ] Risks assessed with mitigation plans
- [ ] Communication plan established
- [ ] Sprint schedule includes all ceremonies
- [ ] Stakeholders notified of sprint plan
- [ ] Definition of Done agreed upon
- [ ] Technical debt allocation reasonable
- [ ] Deployment windows confirmed

## Best Practices

1. **Keep Goal Focused**: One clear, achievable sprint goal
2. **Realistic Capacity**: Plan for 70-80% of available hours
3. **Buffer Time**: Include time for unplanned work
4. **Clear Ownership**: Every story has an assignee
5. **Document Decisions**: Capture "why" not just "what"
6. **Update Regularly**: Keep document current throughout sprint
7. **Reference Actual Tickets**: Link to Azure DevOps/Jira
8. **Include Metrics**: Track velocity and progress
9. **Plan Communication**: Don't forget stakeholder updates
10. **Review Previous Sprints**: Learn from past velocity and challenges
