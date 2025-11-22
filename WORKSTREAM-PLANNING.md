# Workstream Planning - Claude Code Watchdog

## Overview
This document organizes the Claude Code Watchdog project into parallel workstreams to maximize development velocity and enable concurrent work across multiple tracks.

**Project Duration**: 4 weeks
**Team Size**: 1-2 developers
**Parallel Workstreams**: 8

---

## Workstream Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     WORKSTREAM DEPENDENCIES                      │
└─────────────────────────────────────────────────────────────────┘

Phase 1 (Week 1):
┌──────────────────┐
│ WS1: Core Infra  │ (CRITICAL PATH)
└────────┬─────────┘
         │
    ┌────┴────┬──────────┬──────────┐
    │         │          │          │
┌───▼──┐  ┌──▼──┐   ┌───▼───┐  ┌──▼──────┐
│ WS2  │  │ WS3 │   │  WS4  │  │  WS5    │ (PARALLEL)
│State │  │Dec. │   │Action │  │Project  │
└───┬──┘  └──┬──┘   └───┬───┘  └──┬──────┘
    │        │          │         │
    └────┬───┴──────────┴─────────┘
         │
    ┌────▼────┐
    │   WS6   │
    │Logging  │
    └─────────┘

Phase 2 (Week 2):
    WS3 (continues) - Add API intelligence
    WS4 (continues) - Add skills

Phase 3 (Week 3):
    WS5 (continues) - Multi-project
    WS4 (continues) - Git operations

Phase 4 (Week 4):
┌─────────┐  ┌──────────┐
│  WS7    │  │   WS8    │ (PARALLEL)
│ Testing │  │   Docs   │
└─────────┘  └──────────┘
```

---

## Workstream 1: Core Infrastructure
**Owner**: Developer 1
**Priority**: P0 (Critical)
**Duration**: Week 1
**Total Effort**: 7 hours

### Objective
Establish the foundational project structure, module system, and Windows MCP integration layer.

### Work Items
- **WI-1.1**: Project Structure Setup (2h)
- **WI-1.2**: Windows MCP Integration Wrapper (3h)
- **WI-1.9**: Installation Script (2h)

### Dependencies
- None (First workstream to start)

### Deliverables
- [ ] Complete directory structure
- [ ] All module files with function signatures
- [ ] Windows MCP wrapper functions (State, Click, Type, Key)
- [ ] Basic installation script
- [ ] Module import system working

### Success Criteria
- All modules can be imported without errors
- Windows MCP tools callable from PowerShell
- Directory structure matches architecture
- Installation script runs on clean system

### Parallelization Opportunities
- Can work independently from other workstreams initially
- Must complete before WS2, WS3, WS4, WS5 can start core implementation

---

## Workstream 2: State Detection & Monitoring
**Owner**: Developer 1 or 2
**Priority**: P0 (Critical)
**Duration**: Week 1 (4h) + Week 3 (3h)
**Total Effort**: 7 hours

### Objective
Build robust UI state detection and classification system for Claude Code sessions.

### Work Items
**Week 1**:
- **WI-1.3**: State Detection Engine (4h)

**Week 3**:
- **WI-3.1**: Multi-Project Session Detection (4h)
- **WI-2.5**: Enhanced State Detection (3h) - moved from week 2

### Dependencies
- **Requires**: WS1 (Windows MCP wrapper)
- **Blocks**: WS3 (Decision Engine needs state classification)

### Deliverables
- [ ] State detection for 6 primary states
- [ ] TODO parsing with accuracy >95%
- [ ] Error detection and classification
- [ ] Processing indicator detection
- [ ] Multi-project session identification
- [ ] Enhanced error severity classification

### Success Criteria
- 98%+ accuracy on state classification
- Detects all active Claude Code sessions
- Correctly maps sessions to projects
- Handles edge cases gracefully

### Parallelization Opportunities
- Week 1: Can develop in parallel with WS4 (Action)
- Week 3: Can develop in parallel with WS4 (Git operations)
- Testing can happen in parallel with WS7

---

## Workstream 3: Decision Engine
**Owner**: Developer 1
**Priority**: P0 (Critical)
**Duration**: Week 1 (3h) + Week 2 (11h)
**Total Effort**: 14 hours

### Objective
Create intelligent decision-making system with both rule-based and AI-powered capabilities.

### Work Items
**Week 1**:
- **WI-1.4**: Rule-Based Decision Engine (3h)

**Week 2**:
- **WI-2.1**: Claude API Integration (4h)
- **WI-2.2**: Advanced Decision Engine (5h)
- **WI-2.7**: API Configuration Management (2h)

### Dependencies
- **Requires**: WS2 (State Detection for input)
- **Requires**: WS1 (Core infrastructure)
- **Blocks**: WS4 (Action Executor needs decisions)

### Deliverables
- [ ] Rule-based decision logic for all states
- [ ] Claude API integration with secure key storage
- [ ] Advanced decision engine with full context
- [ ] Decision history tracking
- [ ] Fallback from API to rules
- [ ] API configuration system

### Success Criteria
- Decisions make logical sense for each state
- API decisions more accurate than rule-based
- Confidence scores reflect decision quality
- Fallback works when API unavailable
- API costs within budget

### Parallelization Opportunities
- Week 1: Rule-based can develop in parallel with WS4 (Command Execution)
- Week 2: API integration can develop in parallel with WS4 (Skill resolution)
- Decision logging integrates with WS6

---

## Workstream 4: Action & Execution
**Owner**: Developer 1 or 2
**Priority**: P0 (Critical)
**Duration**: Week 1 (4h) + Week 2 (4h) + Week 3 (13h)
**Total Effort**: 21 hours

### Objective
Execute decisions through UI commands, skill invocations, and Git operations.

### Work Items
**Week 1**:
- **WI-1.5**: Command Execution Module (4h)

**Week 2**:
- **WI-2.3**: Skill-Based Error Resolution (4h)

**Week 3**:
- **WI-3.3**: Git Integration Module (5h)
- **WI-3.4**: Phase Transition Logic (4h)
- **WI-3.5**: GitHub Pull Request Creation (4h)

### Dependencies
- **Requires**: WS1 (Windows MCP wrapper)
- **Requires**: WS3 (Decisions to execute)

### Deliverables
- [ ] Command sending with retry logic
- [ ] Command verification
- [ ] Skill invocation system
- [ ] Git wrapper functions (branch, commit, push)
- [ ] Phase transition management
- [ ] Automated PR creation

### Success Criteria
- Commands sent successfully >95% of time
- Skills invoked correctly
- Git operations complete without errors
- PRs created with proper formatting
- Phase transitions work seamlessly

### Parallelization Opportunities
- Week 1: Can develop in parallel with WS2 (State Detection)
- Week 2: Can develop in parallel with WS3 (API integration)
- Week 3: Git operations can develop in parallel with WS2 (Multi-project detection)

---

## Workstream 5: Project Management
**Owner**: Developer 1 or 2
**Priority**: P0 (Critical)
**Duration**: Week 1 (7h) + Week 3 (7h)
**Total Effort**: 14 hours

### Objective
Build project registration, configuration, and multi-project orchestration systems.

### Work Items
**Week 1**:
- **WI-1.6**: Project Registration System (3h)
- **WI-1.7**: Main Watchdog Loop (4h)

**Week 3**:
- **WI-3.2**: Concurrent Project Processing (3h)
- **WI-3.6**: Session Recovery System (4h)

### Dependencies
- **Requires**: WS1 (Core infrastructure)
- **Integrates with**: WS2, WS3, WS4 (orchestrates all)

### Deliverables
- [ ] Project registration and validation
- [ ] Central registry management
- [ ] Main watchdog polling loop
- [ ] Multi-project processing
- [ ] Session recovery system
- [ ] State persistence

### Success Criteria
- Can register and manage 5+ projects
- Main loop runs continuously without crashes
- Projects isolated from each other
- Recovery works after interruptions
- Loop stops gracefully on Ctrl+C

### Parallelization Opportunities
- Week 1: Registration can develop while other workstreams build components
- Week 1: Main loop integrates components as they become available
- Week 3: Can develop in parallel with WS4 (Git operations)

---

## Workstream 6: Logging & Reporting
**Owner**: Developer 2
**Priority**: P1 (High)
**Duration**: Week 1 (2h) + Week 2 (2h) + Week 3 (3h)
**Total Effort**: 7 hours

### Objective
Provide comprehensive logging, notifications, and progress reporting.

### Work Items
**Week 1**:
- **WI-1.8**: Logging Infrastructure (2h)

**Week 2**:
- **WI-2.6**: Decision Log Enhancements (2h)

**Week 3**:
- **WI-3.7**: Progress Reporting (3h)

### Dependencies
- **Requires**: WS1 (Core infrastructure for file I/O)
- **Integrates with**: All workstreams (provides logging)

### Deliverables
- [ ] Markdown decision logs
- [ ] Console output with colors
- [ ] Windows toast notifications
- [ ] API metadata in logs
- [ ] Progress reports
- [ ] Daily summaries

### Success Criteria
- All decisions logged with context
- Notifications arrive when expected
- Logs readable and useful
- Reports provide actionable insights

### Parallelization Opportunities
- Can develop largely in parallel with all other workstreams
- Integrates incrementally as other features added
- Week 1-3: Can develop continuously alongside core features

---

## Workstream 7: Testing & Quality Assurance
**Owner**: Developer 1 & 2 (shared)
**Priority**: P0 (Critical)
**Duration**: Week 1 (3h) + Week 2 (3h) + Week 3 (4h) + Week 4 (14h)
**Total Effort**: 24 hours

### Objective
Ensure code quality through comprehensive unit and integration testing.

### Work Items
**Week 1**:
- **WI-1.10**: Integration Testing - Phase 1 (3h)

**Week 2**:
- **WI-2.8**: Integration Testing - Phase 2 (3h)

**Week 3**:
- **WI-3.8**: Integration Testing - Phase 3 (4h)

**Week 4**:
- **WI-4.1**: Comprehensive Error Handling (4h)
- **WI-4.2**: Unit Test Suite (6h)
- **WI-4.3**: Integration Test Suite (4h)

### Dependencies
- **Requires**: Features from all workstreams to test

### Deliverables
- [ ] Unit tests for all modules (80%+ coverage)
- [ ] Integration test suite
- [ ] Error handling audit
- [ ] Test automation
- [ ] Continuous testing framework

### Success Criteria
- 80%+ code coverage
- All critical paths tested
- No unhandled exceptions
- Tests run automatically
- All tests passing

### Parallelization Opportunities
- Week 1-3: Integration testing happens at end of each sprint
- Week 4: Unit tests can be developed in parallel with documentation
- Can split: Developer 1 on unit tests, Developer 2 on integration tests

---

## Workstream 8: Documentation & Release
**Owner**: Developer 1 or 2
**Priority**: P0 (Critical)
**Duration**: Week 2 (2h) + Week 4 (16h)
**Total Effort**: 18 hours

### Objective
Create comprehensive documentation and prepare production release.

### Work Items
**Week 2**:
- **WI-2.4**: Cost Tracking System (includes docs) (3h)

**Week 4**:
- **WI-4.4**: Performance Optimization (3h)
- **WI-4.5**: User Documentation (4h)
- **WI-4.6**: Developer Documentation (3h)
- **WI-4.7**: Troubleshooting Guide (2h)
- **WI-4.8**: Installation Wizard Enhancement (3h)
- **WI-4.9**: Production Deployment Testing (4h)
- **WI-4.10**: Release Preparation (2h)

### Dependencies
- **Requires**: All features complete before docs finalized

### Deliverables
- [ ] README.md complete
- [ ] QUICKSTART.md
- [ ] ARCHITECTURE.md updated
- [ ] API-REFERENCE.md
- [ ] TROUBLESHOOTING.md
- [ ] Installation wizard
- [ ] v1.0 release package

### Success Criteria
- Documentation accurate and complete
- New user can install and use within 30 minutes
- Developers can understand architecture
- All issues have documented solutions
- Release package works on clean system

### Parallelization Opportunities
- Week 4: Documentation can be split between 2 developers
- User docs and developer docs can be written in parallel
- Testing and documentation can overlap
- One developer on docs, one on optimization

---

## Resource Allocation

### Single Developer Scenario
If working alone, follow this critical path:

**Week 1** (Focus: Foundation):
1. WS1: Core Infrastructure (Day 1-2)
2. WS2: State Detection (Day 2-3)
3. WS4: Command Execution (Day 3)
4. WS3: Rule-Based Decisions (Day 4)
5. WS5: Registration + Main Loop (Day 4-5)
6. WS6: Logging (Day 5)
7. WS7: Integration Test (Day 5)

**Week 2** (Focus: Intelligence):
1. WS3: API Integration (Day 1)
2. WS3: Advanced Decisions (Day 2)
3. WS4: Skill Resolution (Day 3)
4. WS8: Cost Tracking (Day 3)
5. WS2: Enhanced State Detection (Day 4)
6. WS6: Decision Log Enhancements (Day 4)
7. WS7: Integration Test (Day 5)

**Week 3** (Focus: Scale):
1. WS2: Multi-Project Detection (Day 1)
2. WS5: Concurrent Processing (Day 1)
3. WS4: Git Integration (Day 2)
4. WS4: Phase Transitions (Day 3)
5. WS4: PR Creation (Day 3-4)
6. WS5: Session Recovery (Day 4)
7. WS6: Progress Reporting (Day 5)
8. WS7: Integration Test (Day 5)

**Week 4** (Focus: Polish):
1. WS7: Error Handling (Day 1)
2. WS7: Unit Tests (Day 1-2)
3. WS7: Integration Tests (Day 3)
4. WS8: User Docs (Day 3)
5. WS8: Developer Docs (Day 4)
6. WS8: Troubleshooting Guide (Day 4)
7. WS8: Production Testing (Day 5)
8. WS8: Release Prep (Day 5)

### Two Developer Scenario
Optimal parallel work distribution:

**Developer 1** (Lead - Architecture & Core):
- Week 1: WS1, WS3, WS5 (Infrastructure, Decisions, Orchestration)
- Week 2: WS3 (API), WS8 (Cost Tracking)
- Week 3: WS4 (Git), WS5 (Multi-project)
- Week 4: WS7 (Unit Tests), WS8 (Developer Docs)

**Developer 2** (Integration & Quality):
- Week 1: WS2, WS4, WS6 (State, Actions, Logging)
- Week 2: WS4 (Skills), WS2 (Enhanced State), WS6 (Logging)
- Week 3: WS2 (Multi-session), WS6 (Reporting), WS7 (Integration Tests)
- Week 4: WS7 (Integration Tests), WS8 (User Docs, Optimization)

---

## Workstream Dependencies Matrix

| Workstream | Depends On | Blocks | Can Parallel With |
|------------|------------|--------|-------------------|
| WS1: Core Infra | None | All | None (first) |
| WS2: State Detection | WS1 | WS3 | WS4, WS5, WS6 |
| WS3: Decision Engine | WS1, WS2 | WS4 | WS6 |
| WS4: Action & Execution | WS1, WS3 | WS5 | WS2 (Week 1), WS6 |
| WS5: Project Mgmt | WS1 | None | WS2, WS3, WS4, WS6 |
| WS6: Logging | WS1 | None | All others |
| WS7: Testing | All features | None | WS8 (Week 4) |
| WS8: Documentation | All features | None | WS7 (Week 4) |

---

## Integration Points

### Weekly Integration Milestones

**End of Week 1**:
- **Integration Point**: Basic watchdog works end-to-end
- **Components**: WS1 + WS2 + WS3 + WS4 + WS5 + WS6
- **Validation**: Can monitor 1 project and auto-continue on TODOs

**End of Week 2**:
- **Integration Point**: AI-powered decisions operational
- **Components**: WS3 (enhanced) + WS4 (skills) + WS8 (costs)
- **Validation**: Makes smart decisions using API and invokes skills

**End of Week 3**:
- **Integration Point**: Multi-project with Git operations
- **Components**: WS2 (multi-session) + WS4 (git) + WS5 (concurrent)
- **Validation**: Monitors 3+ projects, creates commits and PRs

**End of Week 4**:
- **Integration Point**: Production-ready release
- **Components**: WS7 (all tests) + WS8 (all docs)
- **Validation**: Can be deployed by any user, runs 24+ hours

---

## Risk Management by Workstream

### WS1: Core Infrastructure
**Risk**: Windows MCP unreliable
**Mitigation**: Comprehensive error handling, retry logic, fallback mechanisms

### WS2: State Detection
**Risk**: UI state detection inaccurate
**Mitigation**: Extensive testing with various scenarios, screenshot debugging

### WS3: Decision Engine
**Risk**: API costs too high
**Mitigation**: Strict budget limits, fallback to rules, cost tracking

### WS4: Action & Execution
**Risk**: Commands fail to send
**Mitigation**: Multiple retries, verification, detailed logging

### WS5: Project Management
**Risk**: Projects interfere with each other
**Mitigation**: Strong isolation, separate state files, error quarantine

### WS6: Logging
**Risk**: Logs grow too large
**Mitigation**: Log rotation, size limits, archival strategy

### WS7: Testing
**Risk**: Insufficient test coverage
**Mitigation**: 80% coverage target, code review, integration tests

### WS8: Documentation
**Risk**: Documentation becomes outdated
**Mitigation**: Write docs incrementally, review at end of each sprint

---

## Communication & Coordination

### Daily Sync (15 minutes)
- What did you complete yesterday?
- What will you work on today?
- Any blockers or dependencies?
- Any integration points needed?

### Weekly Integration (Friday)
- Merge all workstream branches
- Run full integration tests
- Review progress against sprint goals
- Plan next week's parallelization

### Key Handoff Points

**WS1 → All**: Must complete before any major work starts
**WS2 → WS3**: State classification needed for decisions
**WS3 → WS4**: Decisions needed before execution
**WS4 → WS5**: Actions needed for orchestration
**All → WS7**: Features needed for testing
**All → WS8**: Complete system needed for documentation

---

## Workstream Velocity Tracking

### Expected Velocity by Week

| Week | WS1 | WS2 | WS3 | WS4 | WS5 | WS6 | WS7 | WS8 | Total |
|------|-----|-----|-----|-----|-----|-----|-----|-----|-------|
| 1    | 7h  | 4h  | 3h  | 4h  | 7h  | 2h  | 3h  | 0h  | 30h   |
| 2    | 0h  | 3h  | 11h | 4h  | 0h  | 2h  | 3h  | 3h  | 26h   |
| 3    | 0h  | 4h  | 0h  | 13h | 7h  | 3h  | 4h  | 0h  | 31h   |
| 4    | 0h  | 0h  | 0h  | 0h  | 0h  | 0h  | 14h | 16h | 30h   |
| **Total** | **7h** | **11h** | **14h** | **21h** | **14h** | **7h** | **24h** | **19h** | **117h** |

### Burndown Tracking
Track completion daily:
- [ ] Green: On track
- [ ] Yellow: Slight delay (<1 day)
- [ ] Red: Blocked or >1 day delayed

---

## Success Metrics by Workstream

### WS1: Core Infrastructure
- [ ] All modules importable
- [ ] Windows MCP calls successful
- [ ] Installation works on clean system

### WS2: State Detection
- [ ] 98%+ state classification accuracy
- [ ] Detects all active sessions
- [ ] Handles edge cases

### WS3: Decision Engine
- [ ] API decisions work correctly
- [ ] Fallback to rules works
- [ ] Costs within budget

### WS4: Action & Execution
- [ ] 95%+ command send success
- [ ] Skills invoked correctly
- [ ] Git operations complete

### WS5: Project Management
- [ ] Manages 5+ projects simultaneously
- [ ] Recovery works after crashes
- [ ] Loop runs 24+ hours

### WS6: Logging
- [ ] All decisions logged
- [ ] Notifications arrive
- [ ] Logs readable and useful

### WS7: Testing
- [ ] 80%+ code coverage
- [ ] All integration tests pass
- [ ] No critical bugs

### WS8: Documentation
- [ ] User can install in <30 min
- [ ] Developers understand architecture
- [ ] Release package complete

---

## Workstream Retrospectives

At end of each sprint, review:
1. What went well in each workstream?
2. What blockers occurred?
3. How well did parallel work work?
4. What would we change next time?
5. Any technical debt created?

---

**Created**: 2024-11-22
**Last Updated**: 2024-11-22
**Version**: 1.0
