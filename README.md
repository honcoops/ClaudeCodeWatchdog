# Claude Code Watchdog 🤖🔍

**Autonomous monitoring and management system for Claude Code sessions**

Stop babysitting your AI coding agents. Let the Watchdog keep them productive while you focus on higher-value work.

---

## 📋 Table of Contents

- [Overview](#overview)
- [The Problem](#the-problem)
- [The Solution](#the-solution)
- [Key Features](#key-features)
- [How It Works](#how-it-works)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Configuration](#configuration)
- [Usage Examples](#usage-examples)
- [Architecture](#architecture)
- [Development](#development)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

Claude Code Watchdog is a PowerShell-based automation system that monitors Claude Code sessions and intelligently manages their progression. It detects when sessions are waiting for input, makes decisions about how to proceed, and executes actions automatically - enabling true end-to-end autonomous development workflows.

**Perfect for:**
- Engineering managers overseeing multiple AI-assisted projects
- Developers running long-running refactoring or cleanup tasks
- Teams implementing AI-driven development pipelines
- Anyone tired of checking Claude Code every 10 minutes

---

## The Problem

Claude Code is powerful, but sessions frequently stall:

❌ **"Continue with next TODO?"** - Waiting for you to tell it to keep going  
❌ **"Phase complete"** - Needs approval to commit and move forward  
❌ **Error encountered** - Unsure how to proceed without guidance  
❌ **Ambiguous requirements** - Pauses for clarification  

**Result:** You spend your day monitoring AI agents instead of doing strategic work.

---

## The Solution

The Watchdog sits between you and Claude Code, acting as an intelligent intermediary:

✅ **Continuous Monitoring** - Polls Claude Code sessions every 2 minutes  
✅ **Smart Decision-Making** - Uses Claude API + rules to decide next steps  
✅ **Autonomous Execution** - Sends commands, makes commits, creates PRs  
✅ **Human-in-the-Loop** - Pauses for your approval when configured  
✅ **Skill Integration** - Leverages your Claude Skills for error resolution  
✅ **Multi-Project Support** - Manages parallel workstreams simultaneously  

**Result:** Set it and forget it. Get notified only when human judgment is needed.

---

## Key Features

### 🎯 Intelligent Monitoring
- Detects 6 distinct Claude Code states (InProgress, HasTodos, Error, PhaseComplete, Idle, WaitingForInput)
- Identifies TODOs, errors, and completion indicators
- Tracks idle time and session health

### 🧠 Smart Decision Engine
- **API-Powered:** Uses Claude API to make contextual decisions
- **Rule-Based Fallback:** Works without API for cost control
- **Skill-Aware:** Automatically invokes appropriate Claude Skills for errors
- **Configuration-Driven:** Respects project-specific approval requirements

### ⚙️ Flexible Automation
- **Auto-Continue:** Progresses through TODOs automatically
- **Phase-Based Commits:** Batches work into logical checkpoints
- **PR Creation:** Generates pull requests at phase boundaries
- **Cost Management:** Tracks API usage and enforces budgets

### 🔔 Notifications & Logging
- Windows toast notifications for urgent items
- Comprehensive markdown decision logs
- Activity tracking per project
- Daily progress summaries

### 🛡️ Production-Ready
- Graceful error handling and retries
- Session recovery after crashes
- Secure credential storage
- Resource-efficient polling

---

## How It Works

```
┌─────────────────────────────────────────────┐
│  1. You register a project with the         │
│     Watchdog and start a Claude Code        │
│     session                                  │
└─────────────────┬───────────────────────────┘
                  │
                  v
┌─────────────────────────────────────────────┐
│  2. Watchdog monitors the Claude Code UI    │
│     every 2 minutes using Windows MCP       │
└─────────────────┬───────────────────────────┘
                  │
                  v
┌─────────────────────────────────────────────┐
│  3. Detects state: "Has 5 TODOs remaining"  │
│     Checks project config: autoProgress=true│
└─────────────────┬───────────────────────────┘
                  │
                  v
┌─────────────────────────────────────────────┐
│  4. Calls Claude API: "Should I continue    │
│     with next TODO or use a skill?"         │
└─────────────────┬───────────────────────────┘
                  │
                  v
┌─────────────────────────────────────────────┐
│  5. API responds: {action: "continue",      │
│     command: "Continue with next TODO"}     │
└─────────────────┬───────────────────────────┘
                  │
                  v
┌─────────────────────────────────────────────┐
│  6. Watchdog sends command to Claude Code   │
│     via Windows MCP (click, type, enter)    │
└─────────────────┬───────────────────────────┘
                  │
                  v
┌─────────────────────────────────────────────┐
│  7. Logs decision and continues monitoring  │
│     Repeats until project complete          │
└─────────────────────────────────────────────┘
```

---

## Quick Start

### Prerequisites

- **Windows 10/11** (required for Windows MCP)
- **PowerShell 7.0+** ([Download](https://github.com/PowerShell/PowerShell))
- **Windows MCP Server** configured and running
- **Claude API Key** ([Get one](https://console.anthropic.com/))
- **Git** with SSH configured
- **BurntToast Module:** `Install-Module BurntToast -Scope CurrentUser`

### Installation

1. **Clone this repository:**
   ```powershell
   git clone https://github.com/yourusername/claude-code-watchdog.git
   cd claude-code-watchdog
   ```

2. **Run the installation script:**
   ```powershell
   .\Install-Watchdog.ps1
   ```

3. **Set your Claude API key:**
   ```powershell
   .\Set-WatchdogAPIKey.ps1 -APIKey "your-api-key-here"
   ```

4. **Register your first project:**
   ```powershell
   .\Register-Project.ps1 `
       -ProjectName "my-project" `
       -ConfigPath "C:\repos\my-project\.claude-automation\project-config.json"
   ```

5. **Start the Watchdog:**
   ```powershell
   .\Start-Watchdog.ps1
   ```

6. **Open Claude Code and start working on your project**

The Watchdog will automatically detect your session and begin monitoring!

---

## Project Structure

```
claude-code-watchdog/
├── src/
│   ├── Core/
│   │   ├── Start-Watchdog.ps1          # Main entry point
│   │   ├── Initialize-Watchdog.ps1     # Setup
│   │   └── Stop-Watchdog.ps1           # Shutdown
│   ├── Registry/
│   │   ├── Register-Project.ps1        # Project registration
│   │   ├── Get-RegisteredProjects.ps1  # Load projects
│   │   └── Update-ProjectState.ps1     # State management
│   ├── Detection/
│   │   ├── Get-ClaudeCodeState.ps1     # State detection
│   │   └── Find-ClaudeCodeSession.ps1  # Session location
│   ├── Decision/
│   │   ├── Invoke-ClaudeDecision.ps1   # API-based decisions
│   │   └── Invoke-SimpleDecision.ps1   # Rule-based decisions
│   ├── Action/
│   │   ├── Send-ClaudeCodeCommand.ps1  # Execute commands
│   │   └── Invoke-PhaseTransition.ps1  # Phase management
│   ├── Logging/
│   │   ├── Write-WatchdogLog.ps1       # Logging
│   │   └── Send-Notification.ps1       # Notifications
│   └── Utils/
│       └── Invoke-WindowsMCP.ps1       # MCP wrapper
├── config/
│   └── watchdog-config.json            # Global settings
├── docs/
│   ├── REQUIREMENTS.md                 # Detailed requirements
│   ├── ARCHITECTURE.md                 # Technical architecture
│   ├── IMPLEMENTATION-GUIDE.md         # Development guide
│   └── TROUBLESHOOTING.md              # Common issues
├── tests/
│   ├── Unit/                           # Unit tests
│   └── Integration/                    # Integration tests
├── examples/
│   └── example-project-config.json     # Sample config
├── README.md                           # This file
├── Install-Watchdog.ps1                # Installation script
├── Register-Project.ps1                # Project registration
├── Set-WatchdogAPIKey.ps1              # API key setup
└── Start-Watchdog.ps1                  # Start monitoring
```

---

## Configuration

### Project Configuration

Create a `.claude-automation/project-config.json` in your project repository:

```json
{
  "projectName": "my-awesome-project",
  "repoPath": "C:/repos/my-awesome-project",
  "repoUrl": "github.com/user/my-awesome-project",
  "branch": "main",
  
  "automation": {
    "autoCommit": true,
    "autoProgress": true,
    "maxRunDuration": "8h",
    "stallThreshold": "10m"
  },
  
  "humanInLoop": {
    "requiresApprovalFor": [
      "database-schema-changes",
      "API-breaking-changes"
    ],
    "requiresHumanAfter": [
      "compilation-errors",
      "test-failures"
    ]
  },
  
  "skills": [
    "/mnt/skills/user/type-error-resolution",
    "/mnt/skills/user/compilation-error-resolution",
    "/mnt/skills/user/lint-error-resolution"
  ],
  
  "phases": [
    {
      "name": "requirements-analysis",
      "autoProgress": false,
      "estimatedDuration": "1h"
    },
    {
      "name": "implementation",
      "autoProgress": true,
      "estimatedDuration": "6h"
    },
    {
      "name": "testing",
      "autoProgress": false,
      "estimatedDuration": "2h"
    }
  ],
  
  "commitStrategy": {
    "frequency": "phase-completion",
    "branchNaming": "claude/{phase-name}-{timestamp}",
    "prCreation": "phase-completion"
  },
  
  "notifications": {
    "onError": true,
    "onPhaseComplete": true,
    "onHumanNeeded": true
  }
}
```

See [example-project-config.json](examples/example-project-config.json) for a fully annotated example.

---

## Usage Examples

### Basic Usage: Single Project

```powershell
# Register and start monitoring
.\Register-Project.ps1 -ProjectName "lint-cleanup" -ConfigPath "C:\repos\myapp\.claude-automation\project-config.json"
.\Start-Watchdog.ps1

# In another window, start Claude Code on your project
# The Watchdog automatically detects and manages it
```

### Multi-Project Monitoring

```powershell
# Register multiple projects
.\Register-Project.ps1 -ProjectName "frontend-refactor" -ConfigPath "C:\repos\frontend\.claude-automation\project-config.json"
.\Register-Project.ps1 -ProjectName "api-migration" -ConfigPath "C:\repos\api\.claude-automation\project-config.json"
.\Register-Project.ps1 -ProjectName "docs-update" -ConfigPath "C:\repos\docs\.claude-automation\project-config.json"

# Start Watchdog - monitors all three simultaneously
.\Start-Watchdog.ps1
```

### Check Project Status

```powershell
# List all registered projects
.\Get-RegisteredProjects.ps1

# Get detailed status for a project
.\Get-ProjectStatus.ps1 -ProjectName "frontend-refactor"

# View decision log
Get-Content "C:\repos\frontend\.claude-automation\decision-log.md"
```

### Pause/Resume Projects

```powershell
# Pause a project (stop monitoring)
.\Set-ProjectStatus.ps1 -ProjectName "api-migration" -Status "Paused"

# Resume monitoring
.\Set-ProjectStatus.ps1 -ProjectName "api-migration" -Status "Active"
```

### Cost Management

```powershell
# Check API costs
.\Get-APICosts.ps1

# Set cost limits
.\Set-CostLimits.ps1 -DailyLimit 10.00 -WeeklyLimit 50.00

# Export cost report
.\Export-CostReport.ps1 -OutputPath "costs-november.csv"
```

---

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────┐
│      Watchdog Process (PowerShell)   │
│  ┌────────────────────────────────┐ │
│  │   Project Registry             │ │
│  │   - Multi-project tracking     │ │
│  └────────────────────────────────┘ │
│  ┌────────────────────────────────┐ │
│  │   State Detection              │ │
│  │   - Windows MCP integration    │ │
│  └────────────────────────────────┘ │
│  ┌────────────────────────────────┐ │
│  │   Decision Engine              │ │
│  │   - Claude API / Rule-based    │ │
│  └────────────────────────────────┘ │
│  ┌────────────────────────────────┐ │
│  │   Action Executor              │ │
│  │   - Commands, Git, PRs         │ │
│  └────────────────────────────────┘ │
└──────────────┬──────────────────────┘
               │
               ├──> Windows MCP ──> Claude Code (Chrome)
               ├──> Claude API ──> Decision-making
               └──> Git/GitHub ──> Version control
```

### Key Components

1. **State Detection:** Uses Windows MCP to capture and parse Claude Code UI
2. **Decision Engine:** Claude API or rules determine next action
3. **Action Executor:** Sends commands, performs Git operations
4. **Project Registry:** Manages multiple projects and their state
5. **Logging System:** Comprehensive audit trail and notifications

See [ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed technical documentation.

---

## Development

### Setting Up Development Environment

```powershell
# Clone the repository
git clone https://github.com/yourusername/claude-code-watchdog.git
cd claude-code-watchdog

# Install development dependencies
.\Install-DevDependencies.ps1

# Run tests
.\Run-Tests.ps1
```

### Running Tests

```powershell
# Unit tests
Invoke-Pester -Path .\tests\Unit\

# Integration tests (requires Windows MCP)
Invoke-Pester -Path .\tests\Integration\

# All tests
.\Run-Tests.ps1 -All
```

### Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

**Areas we'd love help with:**
- Additional Claude Skills integration
- Support for other browsers (Edge, Firefox)
- Azure DevOps integration
- Web dashboard for monitoring
- Mobile notifications
- Cost optimization strategies

---

## Roadmap

### ✅ Phase 1: Core Watchdog (Completed)
- Single process monitoring
- Basic state detection
- Rule-based decisions
- Simple auto-continue

### 🚧 Phase 2: Smart Decisions (In Progress)
- Claude API integration
- Skill-based error resolution
- Cost tracking and management
- Enhanced decision logic

### 📋 Phase 3: Multi-Project & Git (Planned)
- Concurrent project monitoring
- Git operations (commit, push, PR)
- Phase-based workflows
- Session recovery

### 💭 Phase 4: Polish & Scale (Future)
- Web dashboard
- Slack/Teams integration
- Azure DevOps support
- Cloud deployment options
- Team collaboration features

---

## FAQ

**Q: Does this work with any Claude Code session?**  
A: Yes, as long as it's running in Chrome and accessible via Windows MCP.

**Q: What if Claude Code crashes or I close the browser?**  
A: The Watchdog detects the session is gone and pauses monitoring. You'll get a notification. When you restart Claude Code, the Watchdog resumes automatically.

**Q: How much does the API cost?**  
A: Depends on usage, but typically $1-5 per day for a single active project. The Watchdog tracks costs and can fall back to rule-based decisions to stay within budget.

**Q: Can I use this without the Claude API?**  
A: Yes! Phase 1 uses rule-based decisions only. The API is optional (added in Phase 2) for smarter decisions.

**Q: Is my code safe?**  
A: The Watchdog only reads Claude Code's UI and sends text commands. It doesn't access your code directly. All Git operations use your configured credentials.

**Q: Can I run this on a remote server?**  
A: Currently, it requires Windows with desktop access for Windows MCP. Cloud deployment is planned for Phase 4.

**Q: What about macOS/Linux?**  
A: Windows MCP is Windows-only. We're exploring cross-platform alternatives for future versions.

---

## Troubleshooting

### Watchdog Not Detecting Session

**Check:**
- Windows MCP server is running
- Chrome window title contains "Claude Code"
- Project is registered: `.\Get-RegisteredProjects.ps1`

**Solution:** Restart Windows MCP, verify Chrome window title format

### Commands Not Sending

**Check:**
- Reply field coordinates are correct
- No popup dialogs blocking UI
- Claude Code session is responsive

**Solution:** Capture screenshot with `Get-ClaudeCodeState -IncludeScreenshot`, adjust coordinates if needed

### API Costs Too High

**Check:**
- Daily limit set: `.\Get-CostLimits.ps1`
- Decision frequency: reduce polling interval

**Solution:** Increase polling interval to 5 minutes, enable rule-based fallback

### Session Recovery Failing

**Check:**
- State files exist in `.claude-automation/`
- No file permission issues

**Solution:** Manually restart Claude Code, Watchdog will reconnect automatically

For more issues, see [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

---

## License

MIT License - see [LICENSE](LICENSE) file for details

---

## Acknowledgments

- **Anthropic** for Claude and Claude Code
- **Windows MCP** for making UI automation possible
- The PowerShell community for excellent modules and tools

---

## Support

- **Issues:** [GitHub Issues](https://github.com/yourusername/claude-code-watchdog/issues)
- **Discussions:** [GitHub Discussions](https://github.com/yourusername/claude-code-watchdog/discussions)
- **Email:** your-email@example.com

---

## Status

🚧 **Active Development** - Phase 1 complete, Phase 2 in progress

Current Version: **0.2.0-beta**

Last Updated: November 2024

---

**Built with ❤️ for engineering teams who want AI to work for them, not the other way around.**

---

## Quick Links

- [Requirements](docs/REQUIREMENTS.md)
- [Architecture](docs/ARCHITECTURE.md)  
- [Implementation Guide](docs/IMPLEMENTATION-GUIDE.md)
- [Example Config](examples/example-project-config.json)
- [Changelog](CHANGELOG.md)
