# Integration Tests

This directory contains integration tests for the Claude Code Watchdog project.

## Running Tests

```powershell
# Run all integration tests
Invoke-Pester -Path ./tests/Integration/

# Run specific integration test
Invoke-Pester -Path ./tests/Integration/End-to-End.Tests.ps1
```

## Test Requirements

- Requires Windows MCP to be installed and running
- Requires test project repositories
- May require Claude Code session running
- Tests may take longer to execute

## Test Coverage

Integration tests validate:
- Full watchdog workflow (detect → decide → act)
- Windows MCP integration
- Project registration and state management
- Command sending and verification
- Multi-project scenarios

## TODO

Integration test files will be added throughout sprints 1-4 (WI-1.10, WI-2.8, WI-3.8, WI-4.3)
