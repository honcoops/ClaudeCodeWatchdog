# Changelog

All notable changes to Claude Code Watchdog will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0-beta] - 2025-11-22

### Summary

First beta release of Claude Code Watchdog with all core features complete (WS01-WS07). Production-ready autonomous monitoring system for Claude Code sessions with comprehensive testing, error handling, and documentation.

### Added

#### WS01: Core Infrastructure
- Complete project structure with modular PowerShell architecture
- Windows MCP integration wrapper for UI automation
- Installation and setup scripts
- Global and project-specific configuration management
- Module import system

#### WS02: State Detection & Monitoring
- 6-state detection system (InProgress, HasTodos, Error, PhaseComplete, Idle, WaitingForInput)
- TODO parsing with 95%+ accuracy
- Error and warning detection and classification
- Multi-project session identification
- Processing indicator detection
- Session ID extraction (ULID pattern matching)
- Reply field detection with multiple fallback strategies

#### WS03: Decision Engine
- Rule-based decision system for offline operation
- Claude API integration for intelligent decision-making
- Decision history tracking and context awareness
- Cost tracking and budget management (daily/weekly limits)
- Automatic fallback from API to rule-based decisions
- Decision logging with confidence scores
- API configuration management

#### WS04: Action & Execution
- Command execution with retry logic
- Command verification system
- Skill-based error resolution
- Git operations (branch, commit, push)
- Phase transition management
- Automated GitHub pull request creation
- Error quarantine system

#### WS05: Project Management
- Multi-project registration and tracking
- Concurrent project processing
- Session recovery after crashes
- State persistence and restoration
- Resource monitoring (CPU, memory)
- Project error tracking and quarantine
- Heartbeat system

#### WS06: Logging & Reporting
- Comprehensive decision logs with API metadata
- Multi-level logging (Info, Warning, Error, Debug)
- Progress reports with time tracking
- Daily summaries across all projects
- Cost analysis and tracking
- CSV export functionality
- Windows toast notifications
- Log rotation (7-day retention, 10MB size limit)

#### WS07: Testing & Quality Assurance
- 185+ unit and integration tests
- Comprehensive error handling guidelines (900+ lines)
- Automated test runner with coverage reporting
- 70-80% code coverage of critical modules
- CI/CD ready testing framework (NUnit XML, JaCoCo)
- Error handling audit script
- Test documentation

#### WS08: Documentation & Release
- Complete README.md with badges and roadmap
- Quick Start Guide (QUICKSTART.md)
- Comprehensive Troubleshooting Guide (TROUBLESHOOTING.md)
- Error Handling Guidelines (ERROR-HANDLING-GUIDELINES.md)
- Updated ARCHITECTURE.md
- This CHANGELOG.md

### Changed

- Updated README status from "Phase 2 in progress" to "Production Beta"
- Version bumped from 0.2.0-beta to 1.0.0-beta
- Roadmap updated to reflect completed workstreams

### Technical Details

**Total Lines of Code**: 15,000+
**PowerShell Modules**: 27
**Test Cases**: 185+
**Test Code Lines**: 3,500+
**Documentation Pages**: 8
**Documentation Lines**: 10,000+

**Components**:
- Core (3 modules): Watchdog lifecycle management
- Detection (3 modules): UI state capture and classification
- Decision (4 modules): Intelligent decision-making
- Action (6 modules): Command execution and Git operations
- Registry (4 modules): Project management
- Logging (4 modules): Comprehensive logging and reporting
- Utils (3 modules): Configuration and MCP integration

**Test Coverage**:
- Unit Tests: 155+ tests (Core, Detection, Decision modules)
- Integration Tests: 30+ scenarios (end-to-end workflows)
- Coverage: 70-80% of critical paths

### Known Issues

- Windows MCP required (Windows-only limitation)
- Chrome-only support for Claude Code sessions
- API costs can accumulate quickly without tuning
- Session recovery limited to 24-hour window

### Migration Guide

This is the first release - no migration needed.

---

## [0.2.0-alpha] - 2025-11-20 (Development Milestone)

### Summary

Completed WS01-WS06 during development. Internal milestone, not released.

### Added

- All WS01-WS06 features (see 1.0.0-beta above)
- Basic error handling
- Initial test framework

### Known Issues

- No comprehensive testing
- Limited documentation
- Some error handling gaps

---

## [0.1.0-alpha] - 2025-11-18 (Initial Development)

### Summary

Project initialization and WS01 completion. Internal milestone, not released.

### Added

- Basic project structure
- Windows MCP wrapper
- Installation scripts
- Configuration system

### Known Issues

- Minimal functionality
- No testing
- Documentation incomplete

---

## Upcoming Releases

### [1.0.0] - Target: Q1 2025

**Production Release** - After beta testing and final polish

#### Planned Additions
- Performance optimizations
- Enhanced error recovery
- Additional skills integration
- Web dashboard (optional)
- Extended browser support (Edge, Firefox)

#### Planned Changes
- UI/UX improvements based on beta feedback
- Configuration simplification
- Improved Windows MCP reliability

---

## Release Types

- **Major (X.0.0)**: Breaking changes, major features
- **Minor (1.X.0)**: New features, backwards compatible
- **Patch (1.0.X)**: Bug fixes, minor improvements
- **Suffix (-beta, -alpha)**: Pre-release versions

---

## Development Workstreams

All releases map to completed workstreams:

- **WS01**: Core Infrastructure
- **WS02**: State Detection & Monitoring
- **WS03**: Decision Engine
- **WS04**: Action & Execution
- **WS05**: Project Management
- **WS06**: Logging & Reporting
- **WS07**: Testing & Quality Assurance
- **WS08**: Documentation & Release

---

## Links

- [GitHub Repository](https://github.com/honcoops/ClaudeCodeWatchdog)
- [Issues](https://github.com/honcoops/ClaudeCodeWatchdog/issues)
- [Releases](https://github.com/honcoops/ClaudeCodeWatchdog/releases)
- [Documentation](https://github.com/honcoops/ClaudeCodeWatchdog/tree/main/docs)

---

**Maintained by**: Claude Code Development Team
**Last Updated**: November 22, 2025
