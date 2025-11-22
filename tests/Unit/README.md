# Unit Tests

This directory contains unit tests for the Claude Code Watchdog project.

## Running Tests

```powershell
# Run all unit tests
Invoke-Pester -Path ./tests/Unit/

# Run specific test file
Invoke-Pester -Path ./tests/Unit/State-Detection.Tests.ps1
```

## Test Structure

- Each module should have a corresponding `.Tests.ps1` file
- Tests should use Pester framework
- Mock external dependencies (Windows MCP, API calls, etc.)
- Aim for 80%+ code coverage

## TODO

Unit test files will be added in Sprint 4 (WI-4.2)
