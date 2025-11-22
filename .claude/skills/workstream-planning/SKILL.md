---
name: workstream-planning
description: Decomposes complex projects into parallel workstreams with dependency tracking, focused documentation, and resource allocation to maximize concurrent work execution
---

# Workstream Planning Skill

This skill analyzes projects and creates parallel workstream plans that maximize team throughput by identifying non-overlapping work that can proceed simultaneously.

## When to Use This Skill

Use this skill when:
- Planning large multi-sprint initiatives
- Managing complex system migrations
- Coordinating work across multiple team members
- Optimizing team capacity utilization
- Breaking down monolithic projects
- Identifying critical path dependencies
- Preventing team member idle time

## Workstream Planning Process

### Step 1: Analyze Project Scope

Identify all work items and understand:
- Total scope and deliverables
- Technical dependencies
- Resource requirements
- Timeline constraints
- Team size and skills

### Step 2: Identify Dependencies

Map out what must be done before other work can start:
- Technical dependencies (code, infrastructure, data)
- Knowledge dependencies (design decisions, architecture)
- Resource dependencies (shared components, environments)
- Sequential requirements (testing after development)

### Step 3: Create Workstreams

Group work into parallel streams that:
- Have minimal cross-dependencies
- Can be owned by individual developers
- Have clear boundaries and interfaces
- Include complete context for execution
- Balance workload across team

### Step 4: Document Each Workstream

Create focused documentation that includes:
- Only relevant context for that stream
- Clear acceptance criteria
- Interface contracts with other streams
- Dependencies and blockers
- Success metrics

## Workstream Plan Structure

### 1. Executive Summary

```markdown
# Project: [Project Name]
# Workstream Decomposition Plan

**Project Goal**: [One sentence goal]
**Timeline**: [Start] - [End] ([X] sprints)
**Team Size**: [N] developers
**Total Work Items**: [N] stories, [N] story points

## Optimization Summary

- **Workstreams**: [N] parallel streams identified
- **Phases**: [N] phases required due to dependencies
- **Critical Path**: [X] sprints
- **Parallelization Factor**: [N]x (N items that can be worked simultaneously)
- **Estimated Completion**: Sprint [N]

## Key Dependencies

1. [Phase 1] must complete before [Phase 2] can start
2. [Workstream A] provides interface needed by [Workstream B]
3. [Infrastructure setup] required before all development streams

## Resource Allocation

| Workstream | Owner | Duration | Can Start | Dependencies |
|------------|-------|----------|-----------|--------------|
| [Name] | [Dev] | [Sprints] | Sprint N | [List] |
```

### 2. Dependency Graph Visualization

```markdown
## Dependency Graph

```
Phase 1 (Sprint 1-2):
├─ WS1: Infrastructure Setup [2 sprints] → Blocks: WS3, WS4, WS5
├─ WS2: API Design Document [1 sprint] → Blocks: WS4, WS6
└─ (Can run in parallel)

Phase 2 (Sprint 3-4):
├─ WS3: Database Migration [2 sprints] → Blocks: WS7
├─ WS4: Core API Implementation [2 sprints] → Blocks: WS6, WS7
├─ WS5: Authentication Service [2 sprints] → Blocks: WS6
└─ (Can run in parallel, dependent on Phase 1)

Phase 3 (Sprint 5-6):
├─ WS6: Frontend Features [2 sprints] → Blocks: WS8
├─ WS7: Data Integration [2 sprints] → Blocks: WS8
└─ (Can run in parallel, dependent on Phase 2)

Phase 4 (Sprint 7):
└─ WS8: Integration Testing & Deployment [1 sprint]
    (Dependent on all previous streams)
```

**Critical Path**: WS1 → WS4 → WS6 → WS8 (7 sprints)
**Parallelization Opportunities**: Phases 1-3 each have 2-3 concurrent streams
```

### 3. Workstream Definitions

For each workstream, create a complete package:

```markdown
## Workstream [N]: [Name]

### Overview

**Purpose**: [What this workstream accomplishes]
**Owner**: [Primary developer]
**Duration**: [X] sprints (Sprint [A] to Sprint [B])
**Story Points**: [N] points
**Priority**: Critical / High / Medium / Low

### Dependencies

**Must Complete First**:
- [ ] Workstream [X]: [Specific deliverable needed]
- [ ] Workstream [Y]: [Specific deliverable needed]
- [ ] Infrastructure: [What must be ready]

**Blocks These Workstreams**:
- Workstream [A]: [What they need from this stream]
- Workstream [B]: [What they need from this stream]

**Can Start When**:
- Sprint [N] (after dependencies complete)
- [Specific condition met]

### Scope and Boundaries

**In Scope**:
- [Specific feature/component 1]
- [Specific feature/component 2]
- [Specific feature/component 3]

**Out of Scope** (handled by other streams):
- [Feature X] - See Workstream [N]
- [Component Y] - See Workstream [M]

**Interface Contracts**:
- Provides: [API/interface this stream exposes]
- Consumes: [API/interface this stream uses]

### Work Items

| Story ID | Description | Points | Sprint | Notes |
|----------|-------------|--------|--------|-------|
| PBI-1234 | [Description] | 5 | Sprint N | [Notes] |
| PBI-1235 | [Description] | 3 | Sprint N | [Notes] |
| PBI-1236 | [Description] | 8 | Sprint N+1 | Depends on PBI-1234 |

**Total**: [N] stories, [X] points

### Technical Context

**Architecture Overview**:
```
[Relevant architecture diagram or description]
Only include components this workstream touches
```

**Technology Stack**:
- Backend: [Technologies used in this stream]
- Frontend: [Technologies used in this stream]
- Database: [Databases touched by this stream]
- External Services: [APIs/services integrated]

**Key Files and Locations**:
- Main code: `/src/[path]/`
- Tests: `/tests/[path]/`
- Configuration: `/config/[file]`
- Documentation: `/docs/[file]`

### Implementation Guidelines

**Coding Standards**:
- Follow [specific guidelines relevant to this stream]
- Use [design pattern] for [specific scenario]
- Implement [error handling approach]

**Testing Requirements**:
- Unit test coverage: >80%
- Integration tests for [specific scenarios]
- Mock dependencies: [List what to mock]

**Performance Targets**:
- [Specific metric]: < [threshold]
- [Specific metric]: > [threshold]

### Interface Contracts

**APIs This Stream Provides**:

```typescript
// API that other workstreams will consume
interface UserService {
  getUser(id: string): Promise<User>;
  createUser(data: CreateUserRequest): Promise<User>;
}
```

**Expected Response Format**:
```json
{
  "id": "string",
  "name": "string",
  "email": "string",
  "createdAt": "ISO8601 datetime"
}
```

**APIs This Stream Consumes**:

```typescript
// Dependencies on other workstreams
interface AuthService {  // Provided by WS5
  validateToken(token: string): Promise<boolean>;
}

interface DataAccess {  // Provided by WS3
  query(sql: string): Promise<QueryResult>;
}
```

### Acceptance Criteria

**Definition of Done**:
- [ ] All user stories completed
- [ ] Unit tests written and passing (>80% coverage)
- [ ] Integration tests passing
- [ ] Code reviewed and merged
- [ ] Documentation updated
- [ ] Interface contract implemented and tested
- [ ] Performance targets met
- [ ] Deployed to staging environment
- [ ] Dependent workstreams notified of completion

**Deliverables**:
1. [Specific deliverable 1]
2. [Specific deliverable 2]
3. Documentation: [What docs to produce]

### Risk Mitigation

**Risks**:
| Risk | Impact | Mitigation |
|------|--------|------------|
| [Risk description] | High/Med/Low | [How to address] |

**Blockers**:
- Potential blocker: [Description]
- Resolution: [How to handle if occurs]

### Relevant Documentation

**Required Reading** (focused context only):
- [Architecture doc section relevant to this stream]
- [API design doc for interfaces]
- [Database schema for tables touched]

**NOT Needed for This Stream**:
- [Irrelevant doc 1] - Only relevant to WS[N]
- [Irrelevant doc 2] - Only relevant to WS[M]

### Communication Plan

**Status Updates**:
- Frequency: [Daily/Weekly]
- Channel: [Slack/Email/Standup]
- Format: [Brief update on progress and blockers]

**Handoff Points**:
- When [milestone] complete: Notify [Workstream/Person]
- When interface ready: Provide [Documentation/Examples]

### Example Work

**Reference Implementation**:
```typescript
// Example showing expected patterns
class ExampleImplementation {
  // Show coding style and patterns
}
```

**Test Examples**:
```typescript
// Example test showing approach
describe('ExampleImplementation', () => {
  it('should follow expected pattern', () => {
    // Test structure
  });
});
```
```

### 4. Phase Planning

```markdown
## Phase Breakdown

### Phase 1: Foundation (Sprint 1-2)

**Objective**: Establish infrastructure and design foundations
**Parallelization**: 2 concurrent workstreams
**Team Allocation**: 2 developers

| Workstream | Owner | Work Items | Dependencies | Deliverable |
|------------|-------|------------|--------------|-------------|
| WS1: Infrastructure | Dev A | 5 stories (21 pts) | None | Deployed environments |
| WS2: API Design | Dev B | 3 stories (13 pts) | None | API specification doc |

**Phase Success Criteria**:
- [ ] All environments deployed and accessible
- [ ] API design document approved
- [ ] Interface contracts defined
- [ ] Phase 2 can begin

**Phase Risks**:
- Infrastructure delays could block all Phase 2 work
- Mitigation: Start infrastructure work in Sprint 0 if possible

---

### Phase 2: Core Development (Sprint 3-4)

**Objective**: Implement core platform features
**Parallelization**: 3 concurrent workstreams
**Team Allocation**: 3 developers

| Workstream | Owner | Work Items | Dependencies | Deliverable |
|------------|-------|------------|--------------|-------------|
| WS3: Database | Dev A | 6 stories (25 pts) | WS1 | Migrated schema |
| WS4: Core API | Dev B | 8 stories (34 pts) | WS1, WS2 | REST endpoints |
| WS5: Auth Service | Dev C | 5 stories (21 pts) | WS1 | Auth service |

**Phase Success Criteria**:
- [ ] Database migration complete
- [ ] Core API endpoints functional
- [ ] Authentication working
- [ ] Integration tests passing
- [ ] Phase 3 can begin

**Inter-Workstream Coordination**:
- Weekly sync: All Phase 2 developers
- Interface freeze: End of Sprint 3
- Integration testing: Sprint 4

---

### Phase 3: Features (Sprint 5-6)

**Objective**: Build user-facing features
**Parallelization**: 2 concurrent workstreams
**Team Allocation**: 3 developers (1 supporting both)

| Workstream | Owner | Work Items | Dependencies | Deliverable |
|------------|-------|------------|--------------|-------------|
| WS6: Frontend | Dev B | 10 stories (42 pts) | WS4, WS5 | UI features |
| WS7: Data Integration | Dev C | 7 stories (29 pts) | WS3, WS4 | Data pipelines |

**Support Role**: Dev A provides support for both streams

**Phase Success Criteria**:
- [ ] All frontend features complete
- [ ] Data integration working
- [ ] E2E tests passing
- [ ] Ready for integration phase

---

### Phase 4: Integration (Sprint 7)

**Objective**: Integration testing and deployment
**Parallelization**: 1 workstream (all team)
**Team Allocation**: All 3 developers

| Workstream | Owner | Work Items | Dependencies | Deliverable |
|------------|-------|------------|--------------|-------------|
| WS8: Integration | All team | 4 stories (17 pts) | All previous | Production deploy |

**Phase Success Criteria**:
- [ ] All integration tests passing
- [ ] Performance benchmarks met
- [ ] Documentation complete
- [ ] Deployed to production
```

### 5. Resource Optimization Analysis

```markdown
## Capacity Planning

### Team Utilization

**Sprint-by-Sprint Allocation**:

| Sprint | Dev A | Dev B | Dev C | Total Capacity | Work Planned |
|--------|-------|-------|-------|----------------|--------------|
| 1 | WS1 | WS2 | Available | 240h | 200h (83%) |
| 2 | WS1 | WS2 | Available | 240h | 180h (75%) |
| 3 | WS3 | WS4 | WS5 | 240h | 235h (98%) |
| 4 | WS3 | WS4 | WS5 | 240h | 230h (96%) |
| 5 | Support | WS6 | WS7 | 240h | 225h (94%) |
| 6 | Support | WS6 | WS7 | 240h | 220h (92%) |
| 7 | WS8 | WS8 | WS8 | 240h | 180h (75%) |

**Analysis**:
- **Optimal Utilization**: Sprints 3-6 (94-98%)
- **Under-Utilization**: Sprint 1-2, 7 (75-83%)
- **Opportunity**: Could add scope to Sprints 1-2, 7

### Parallelization Efficiency

**Without Workstreams** (Sequential):
- Total Duration: ~21 sprints (7 streams × 3 sprints avg)
- Team Utilization: 33% (1 of 3 devs working)

**With Workstreams** (Parallel):
- Total Duration: 7 sprints
- Team Utilization: 88% average
- **Speedup**: 3x faster delivery

**Critical Path**:
- WS1 → WS4 → WS6 → WS8 (7 sprints)
- Cannot be parallelized further
- Represents minimum possible timeline

### Bottleneck Analysis

**Identified Bottlenecks**:
1. **WS4 (Core API)**: Blocks WS6 and WS7
   - Mitigation: Complete interface contract early (Sprint 3)
   - Provide mock implementations for parallel development

2. **Single Developer Skills**: Dev B is bottleneck for API work
   - Mitigation: Pair programming in Sprint 3
   - Knowledge transfer to Dev A

3. **Environment Access**: All streams need infrastructure
   - Mitigation: Complete WS1 before Sprint 3
   - Provide access documentation early
```

### 6. Synchronization Points

```markdown
## Coordination Schedule

### Interface Freeze Dates

| Date | What Freezes | Affected Streams | Reason |
|------|--------------|------------------|--------|
| End Sprint 2 | API Design Document | WS4, WS6 | Allow parallel dev |
| End Sprint 3 | Core API Interfaces | WS6, WS7 | Frontend can start |
| End Sprint 4 | Database Schema | WS7 | Data integration |

### Integration Points

**Weekly Sync Meetings**:
- **Attendees**: All workstream owners
- **Duration**: 30 minutes
- **Agenda**:
  - Dependency status updates
  - Interface changes
  - Blockers and risks
  - Next week's handoffs

**Daily Standups** (within phases):
- Phase 2: All three developers sync daily
- Phase 3: Frontend and Data teams sync daily
- Phase 4: Entire team syncs daily

### Handoff Documentation

When completing a dependency:

1. **Notify Dependent Streams**:
   - Post in #project-channel
   - Tag downstream workstream owners
   - Provide completion evidence

2. **Provide Integration Guide**:
   - How to consume the interface
   - Example usage code
   - Test data/mocks available

3. **Demo When Possible**:
   - Quick 15-min demo of functionality
   - Q&A for dependent teams

### Code Freeze Schedule

| Sprint | Code Freeze | Purpose | Affected Streams |
|--------|-------------|---------|------------------|
| 2 | Friday 5pm | Phase 1 integration | WS1, WS2 |
| 4 | Friday 5pm | Phase 2 integration | WS3, WS4, WS5 |
| 6 | Friday 5pm | Phase 3 integration | WS6, WS7 |
| 7 | Wednesday 5pm | Production release | All |
```

### 7. Risk Management

```markdown
## Workstream Risks

### Dependency Risks

| Risk | Streams Affected | Impact | Probability | Mitigation |
|------|------------------|--------|-------------|------------|
| WS1 delayed | All Phase 2 | Critical | Medium | Start early, daily check-ins |
| WS4 API changes | WS6, WS7 | High | Low | Interface freeze Sprint 3 |
| Dev B unavailable | WS4, WS6 | Critical | Low | Cross-train Dev A |
| Integration issues | WS8 | Medium | Medium | Weekly integration tests |

### Critical Path Risks

**If Critical Path Delayed**:
- Each sprint delay = 1 sprint project delay
- Affects: WS1 → WS4 → WS6 → WS8

**Mitigation Strategies**:
1. **WS1 Buffer**: Add 20% time buffer (start in Sprint 0)
2. **WS4 Parallel Tracks**: Split into smaller deliverables
3. **WS6 Early Start**: Use mocks to start before WS4 complete
4. **WS8 Preparation**: Prepare deployment scripts in Sprint 6

### Contingency Plans

**If Workstream Delayed by 1 Sprint**:

| Delayed Stream | Impact | Response |
|----------------|--------|----------|
| WS1 | Phase 2 delayed | All devs help complete WS1 |
| WS2 | WS4 delayed | WS4 starts with draft API design |
| WS3 | WS7 delayed | WS7 uses test database |
| WS4 | WS6, WS7 delayed | Extend Sprint 4, use mocks |
| WS5 | WS6 delayed | Use stub auth temporarily |
| WS6 | WS8 delayed | Extend Sprint 6 |
| WS7 | WS8 delayed | Reduce WS7 scope if needed |

**Scope Reduction Options** (if timeline critical):
1. Move WS7 scope to post-launch (if not MVP critical)
2. Reduce WS6 scope to core features only
3. Accept technical debt in WS8 testing coverage
```

## Quality Checklist

Before finalizing workstream plan:

- [ ] All work items assigned to workstreams
- [ ] Dependencies clearly identified
- [ ] Critical path calculated
- [ ] Parallelization maximized where possible
- [ ] Each workstream has single owner
- [ ] Interface contracts defined
- [ ] Phase boundaries clear
- [ ] Synchronization points scheduled
- [ ] Documentation focused (no irrelevant info)
- [ ] Acceptance criteria specific
- [ ] Risk mitigation planned
- [ ] Resource utilization optimized (>80%)
- [ ] Communication plan established
- [ ] Handoff procedures defined

## Best Practices

### Workstream Design

1. **Clear Boundaries**: Each workstream has distinct, non-overlapping scope
2. **Single Owner**: One primary developer per workstream
3. **Complete Context**: Include everything needed, nothing extra
4. **Interface First**: Define contracts before implementation
5. **Test Independence**: Each stream can test without others

### Dependency Management

1. **Minimize Dependencies**: Reduce coupling between streams
2. **Early Contracts**: Define interfaces early in dependencies
3. **Mock Interfaces**: Provide mocks for parallel development
4. **Explicit Handoffs**: Clear notification when dependencies complete
5. **Version Contracts**: Track interface versions if changes needed

### Documentation Strategy

1. **Focused Content**: Only include relevant information
2. **Just-in-Time**: Provide docs when needed, not before
3. **Examples Over Explanation**: Show don't tell
4. **Living Documents**: Update as work progresses
5. **Clear Ownership**: Each doc has a maintainer

### Communication Patterns

1. **Async First**: Use written updates (Slack, docs)
2. **Sync When Needed**: Meetings for complex coordination
3. **Status Transparency**: Regular progress updates
4. **Problem Escalation**: Clear escalation path for blockers
5. **Celebrate Milestones**: Acknowledge completed phases

### Optimization Techniques

1. **Start Non-Dependent Work First**: Begin foundational work early
2. **Parallelize Aggressively**: Look for any concurrent opportunities
3. **Reduce Critical Path**: Break up sequential dependencies
4. **Balance Load**: Distribute work evenly across team
5. **Buffer Critical Path**: Add time buffer to critical items

## Common Patterns

### Pattern 1: Infrastructure First

```
Phase 1: Infrastructure (1-2 sprints)
  WS: Set up environments, CI/CD, shared services
  Blocks: All other development

Phase 2-N: Parallel feature development
  Multiple WS: Can work concurrently
```

**Use When**: Greenfield projects, new infrastructure needed

### Pattern 2: Layer by Layer

```
Phase 1: Data Layer (Backend team)
Phase 2: Business Logic (Backend team) 
Phase 3: API Layer (Backend team)
Phase 4: Frontend (Frontend team)
```

**Use When**: Clear architectural layers, specialized teams

### Pattern 3: Vertical Slices

```
Multiple Parallel WS: Each implements complete feature top-to-bottom
  WS1: User Management (DB → API → UI)
  WS2: Orders (DB → API → UI)
  WS3: Reporting (DB → API → UI)
```

**Use When**: Features are independent, full-stack developers

### Pattern 4: Core + Extensions

```
Phase 1: Core Platform (Critical path)
  WS: Minimal viable platform

Phase 2: Extensions (Parallel)
  WS1: Feature A
  WS2: Feature B  
  WS3: Feature C
```

**Use When**: Core platform needed first, extensions can be parallel

## Output Format

The workstream plan should produce:

1. **Executive Summary** - One page overview
2. **Dependency Graph** - Visual representation
3. **Individual Workstream Packages** - One per stream with focused docs
4. **Phase Plans** - Detailed phase breakdowns
5. **Resource Allocation** - Sprint-by-sprint assignments
6. **Synchronization Schedule** - Meetings and handoffs
7. **Risk Register** - Risks and mitigations

Each developer should receive:
- Their workstream package (focused docs only)
- Project executive summary
- Dependency graph
- Communication schedule

They should NOT receive:
- Other workstreams' implementation details
- Irrelevant architecture documentation
- Unrelated technical specifications
