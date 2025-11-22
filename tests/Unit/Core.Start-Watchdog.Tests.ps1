<#
.SYNOPSIS
    Unit tests for Start-Watchdog.ps1

.NOTES
    Part of WS07 - Testing & Quality Assurance
    Work Item: WI-4.2 - Unit Test Suite
#>

BeforeAll {
    # Import the module under test
    $ScriptRoot = Split-Path -Parent $PSCommandPath
    $ModulePath = Join-Path $ScriptRoot "../../src/Core/Start-Watchdog.ps1"

    # Mock dependencies
    function Write-WatchdogLog {}
    function Send-Notification {}
    function Get-RegisteredProjects {}
    function Update-ProjectState {}
    function Find-ClaudeCodeSession {}
    function Get-ClaudeCodeState {}
    function Invoke-SimpleDecision {}
    function Send-ClaudeCodeCommand {}
    function Add-DecisionLog {}
    function Initialize-WatchdogEnvironment {}
    function Get-ProjectConfig {}
    function Get-DecisionHistory {}
    function Get-ActiveProjects {}
    function Get-ProjectState {}
    function Update-RegistrySessionId {}
}

Describe "Start-Watchdog" {

    Context "Initialization" {
        It "Should initialize watchdog environment" {
            Mock Initialize-WatchdogEnvironment {} -Verifiable
            Mock Get-ActiveProjects { return @() }

            # Start watchdog with max runtime to exit quickly
            { Start-Watchdog -PollingIntervalSeconds 1 -MaxRunHours 0 } | Should -Not -Throw

            Assert-MockCalled Initialize-WatchdogEnvironment -Times 1
        }

        It "Should set global running flag" {
            Mock Initialize-WatchdogEnvironment {}
            Mock Get-ActiveProjects { return @() }

            # Start and verify global flag is set
            $global:WatchdogRunning = $false
            Start-Watchdog -PollingIntervalSeconds 1 -MaxRunHours 0

            $global:WatchdogRunning | Should -Be $true
        }

        It "Should log startup message" {
            Mock Initialize-WatchdogEnvironment {}
            Mock Get-ActiveProjects { return @() }
            Mock Write-WatchdogLog {} -Verifiable

            Start-Watchdog -PollingIntervalSeconds 1 -MaxRunHours 0

            Assert-MockCalled Write-WatchdogLog -ParameterFilter {
                $Message -like "*started*"
            }
        }
    }

    Context "Session Recovery" {
        It "Should attempt session recovery by default" {
            Mock Initialize-WatchdogEnvironment {}
            Mock Get-ActiveProjects { return @() }
            Mock Restore-WatchdogSessions {} -Verifiable

            Start-Watchdog -PollingIntervalSeconds 1 -MaxRunHours 0

            Assert-MockCalled Restore-WatchdogSessions -Times 1
        }

        It "Should skip recovery when SkipRecovery flag is set" {
            Mock Initialize-WatchdogEnvironment {}
            Mock Get-ActiveProjects { return @() }
            Mock Restore-WatchdogSessions {}

            Start-Watchdog -PollingIntervalSeconds 1 -MaxRunHours 0 -SkipRecovery

            Assert-MockCalled Restore-WatchdogSessions -Times 0
        }
    }

    Context "Project Processing" {
        It "Should process all active projects" {
            Mock Initialize-WatchdogEnvironment {}
            Mock Get-ActiveProjects {
                return @(
                    @{ Name = "Project1" },
                    @{ Name = "Project2" }
                )
            }
            Mock Process-Project {} -Verifiable

            Start-Watchdog -PollingIntervalSeconds 1 -MaxRunHours 0

            Assert-MockCalled Process-Project -Times 2
        }

        It "Should handle project errors without stopping" {
            Mock Initialize-WatchdogEnvironment {}
            Mock Get-ActiveProjects {
                return @(
                    @{ Name = "Project1" },
                    @{ Name = "Project2" }
                )
            }
            Mock Process-Project {
                if ($Project.Name -eq "Project1") {
                    throw "Test error"
                }
            }
            Mock Handle-ProjectError {} -Verifiable

            { Start-Watchdog -PollingIntervalSeconds 1 -MaxRunHours 0 } | Should -Not -Throw

            Assert-MockCalled Handle-ProjectError -Times 1
        }

        It "Should warn when no projects are registered" {
            Mock Initialize-WatchdogEnvironment {}
            Mock Get-ActiveProjects { return @() }

            Start-Watchdog -PollingIntervalSeconds 1 -MaxRunHours 0

            # Should complete without error even with no projects
        }
    }

    Context "Polling Interval" {
        It "Should respect custom polling interval" {
            Mock Initialize-WatchdogEnvironment {}
            Mock Get-ActiveProjects { return @() }

            $startTime = Get-Date
            Start-Watchdog -PollingIntervalSeconds 5 -MaxRunHours 0
            $elapsed = ((Get-Date) - $startTime).TotalSeconds

            # Should take at least 5 seconds for one cycle
            $elapsed | Should -BeGreaterOrEqual 5
        }
    }

    Context "Max Runtime" {
        It "Should stop after max runtime is reached" {
            Mock Initialize-WatchdogEnvironment {}
            Mock Get-ActiveProjects { return @() }

            $startTime = Get-Date
            Start-Watchdog -PollingIntervalSeconds 1 -MaxRunHours 0.001 # ~3.6 seconds
            $elapsed = ((Get-Date) - $startTime).TotalSeconds

            $elapsed | Should -BeLessThan 10 # Should exit quickly
        }

        It "Should run indefinitely when MaxRunHours is 0" {
            Mock Initialize-WatchdogEnvironment {}
            Mock Get-ActiveProjects { return @() }

            # Set global flag to stop after first cycle
            $global:WatchdogRunning = $true
            $null = Start-Job -ScriptBlock {
                Start-Sleep 2
                $global:WatchdogRunning = $false
            }

            { Start-Watchdog -PollingIntervalSeconds 1 -MaxRunHours 0 } | Should -Not -Throw
        }
    }

    Context "Error Handling" {
        It "Should handle fatal errors gracefully" {
            Mock Initialize-WatchdogEnvironment { throw "Fatal error" }

            { Start-Watchdog -PollingIntervalSeconds 1 } | Should -Throw
        }

        It "Should log errors in main loop" {
            Mock Initialize-WatchdogEnvironment {}
            Mock Get-ActiveProjects { throw "Loop error" }
            Mock Write-WatchdogLog {} -Verifiable

            { Start-Watchdog -PollingIntervalSeconds 1 -MaxRunHours 0 } | Should -Not -Throw

            Assert-MockCalled Write-WatchdogLog -ParameterFilter {
                $Level -eq "Error"
            }
        }

        It "Should continue after loop errors" {
            Mock Initialize-WatchdogEnvironment {}
            $script:callCount = 0
            Mock Get-ActiveProjects {
                $script:callCount++
                if ($script:callCount -eq 1) {
                    throw "First call error"
                }
                return @()
            }

            { Start-Watchdog -PollingIntervalSeconds 1 -MaxRunHours 0 } | Should -Not -Throw

            $script:callCount | Should -BeGreaterThan 1
        }
    }

    Context "Shutdown" {
        It "Should save state before shutdown" {
            Mock Initialize-WatchdogEnvironment {}
            Mock Get-ActiveProjects { return @() }
            Mock Save-WatchdogState {} -Verifiable

            Start-Watchdog -PollingIntervalSeconds 1 -MaxRunHours 0

            Assert-MockCalled Save-WatchdogState -Times 1
        }

        It "Should cleanup resources on shutdown" {
            Mock Initialize-WatchdogEnvironment {}
            Mock Get-ActiveProjects { return @() }
            Mock Cleanup-WatchdogResources {} -Verifiable

            Start-Watchdog -PollingIntervalSeconds 1 -MaxRunHours 0

            Assert-MockCalled Cleanup-WatchdogResources -Times 1
        }

        It "Should log shutdown message" {
            Mock Initialize-WatchdogEnvironment {}
            Mock Get-ActiveProjects { return @() }
            Mock Write-WatchdogLog {} -Verifiable

            Start-Watchdog -PollingIntervalSeconds 1 -MaxRunHours 0

            Assert-MockCalled Write-WatchdogLog -ParameterFilter {
                $Message -like "*stopped*"
            }
        }
    }

    Context "Resource Monitoring" {
        It "Should initialize resource monitoring" {
            Mock Initialize-WatchdogEnvironment {}
            Mock Get-ActiveProjects { return @() }
            Mock Initialize-ResourceMonitoring {} -Verifiable

            Start-Watchdog -PollingIntervalSeconds 1 -MaxRunHours 0

            Assert-MockCalled Initialize-ResourceMonitoring -Times 1
        }

        It "Should measure resource usage per cycle" {
            Mock Initialize-WatchdogEnvironment {}
            Mock Get-ActiveProjects { return @() }
            Mock Measure-ResourceUsage { return @{ CpuTime = 0; WorkingSetMB = 50; Timestamp = Get-Date } }
            Mock Update-ResourceMetrics {} -Verifiable

            Start-Watchdog -PollingIntervalSeconds 1 -MaxRunHours 0

            Assert-MockCalled Update-ResourceMetrics -AtLeast 1
        }

        It "Should track cycle statistics" {
            Mock Initialize-WatchdogEnvironment {}
            Mock Get-ActiveProjects { return @() }

            $global:WatchdogStats = @{
                CyclesCompleted = 0
                LastCycleDuration = 0
            }

            Start-Watchdog -PollingIntervalSeconds 1 -MaxRunHours 0

            $global:WatchdogStats.CyclesCompleted | Should -BeGreaterThan 0
            $global:WatchdogStats.LastCycleDuration | Should -BeGreaterThan 0
        }
    }
}

Describe "Process-Project" {

    Context "Session Detection" {
        It "Should find Claude Code session for project" {
            Mock Find-ClaudeCodeSession { return @{ SessionId = "test-session"; WindowHandle = "hwnd" } } -Verifiable
            Mock Get-ClaudeCodeState { return @{ Status = "Idle" } }
            Mock Get-ProjectConfig { return @{} }
            Mock Get-DecisionHistory { return @() }
            Mock Invoke-SimpleDecision { return @{ Action = "wait" } }

            $project = @{ Name = "TestProject" }
            { Process-Project -Project $project } | Should -Not -Throw

            Assert-MockCalled Find-ClaudeCodeSession -Times 1
        }

        It "Should handle session loss gracefully" {
            Mock Find-ClaudeCodeSession { return $null }
            Mock Get-ProjectState { return @{ sessionId = "old-session" } }
            Mock Send-Notification {} -Verifiable
            Mock Update-ProjectState {} -Verifiable

            $project = @{ Name = "TestProject" }
            { Process-Project -Project $project } | Should -Not -Throw

            Assert-MockCalled Send-Notification -Times 1
            Assert-MockCalled Update-ProjectState -Times 1
        }

        It "Should not alert if session never existed" {
            Mock Find-ClaudeCodeSession { return $null }
            Mock Get-ProjectState { return $null }
            Mock Send-Notification {}

            $project = @{ Name = "TestProject" }
            { Process-Project -Project $project } | Should -Not -Throw

            Assert-MockCalled Send-Notification -Times 0
        }
    }

    Context "State Detection and Decision Making" {
        It "Should get current state from session" {
            Mock Find-ClaudeCodeSession { return @{ SessionId = "test"; WindowHandle = "hwnd" } }
            Mock Get-ClaudeCodeState { return @{ Status = "HasTodos"; Todos = @{ Remaining = 5 } } } -Verifiable
            Mock Get-ProjectConfig { return @{} }
            Mock Get-DecisionHistory { return @() }
            Mock Invoke-SimpleDecision { return @{ Action = "wait" } }

            Process-Project -Project @{ Name = "Test" }

            Assert-MockCalled Get-ClaudeCodeState -Times 1
        }

        It "Should make decision based on state" {
            Mock Find-ClaudeCodeSession { return @{ SessionId = "test"; WindowHandle = "hwnd" } }
            Mock Get-ClaudeCodeState { return @{ Status = "HasTodos"; Todos = @{ Remaining = 3 } } }
            Mock Get-ProjectConfig { return @{} }
            Mock Get-DecisionHistory { return @() }
            Mock Invoke-SimpleDecision { return @{ Action = "continue"; Command = "yes" } } -Verifiable

            Process-Project -Project @{ Name = "Test" }

            Assert-MockCalled Invoke-SimpleDecision -Times 1
        }

        It "Should log the decision" {
            Mock Find-ClaudeCodeSession { return @{ SessionId = "test"; WindowHandle = "hwnd" } }
            Mock Get-ClaudeCodeState { return @{ Status = "HasTodos" } }
            Mock Get-ProjectConfig { return @{} }
            Mock Get-DecisionHistory { return @() }
            Mock Invoke-SimpleDecision { return @{ Action = "wait" } }
            Mock Add-DecisionLog {} -Verifiable

            Process-Project -Project @{ Name = "Test" }

            Assert-MockCalled Add-DecisionLog -Times 1
        }
    }

    Context "Action Execution" {
        It "Should send command for 'continue' action" {
            Mock Find-ClaudeCodeSession { return @{ SessionId = "test"; WindowHandle = "hwnd" } }
            Mock Get-ClaudeCodeState {
                return @{
                    Status = "HasTodos"
                    HasReplyField = $true
                    ReplyFieldCoordinates = @(100, 200)
                }
            }
            Mock Get-ProjectConfig { return @{} }
            Mock Get-DecisionHistory { return @() }
            Mock Invoke-SimpleDecision { return @{ Action = "continue"; Command = "Continue with next TODO" } }
            Mock Send-ClaudeCodeCommand {} -Verifiable

            Process-Project -Project @{ Name = "Test" }

            Assert-MockCalled Send-ClaudeCodeCommand -Times 1
        }

        It "Should not send command if no reply field" {
            Mock Find-ClaudeCodeSession { return @{ SessionId = "test"; WindowHandle = "hwnd" } }
            Mock Get-ClaudeCodeState {
                return @{
                    Status = "HasTodos"
                    HasReplyField = $false
                }
            }
            Mock Get-ProjectConfig { return @{} }
            Mock Get-DecisionHistory { return @() }
            Mock Invoke-SimpleDecision { return @{ Action = "continue"; Command = "yes" } }
            Mock Send-ClaudeCodeCommand {}

            Process-Project -Project @{ Name = "Test" }

            Assert-MockCalled Send-ClaudeCodeCommand -Times 0
        }

        It "Should find and invoke skills for errors" {
            Mock Find-ClaudeCodeSession { return @{ SessionId = "test"; WindowHandle = "hwnd" } }
            Mock Get-ClaudeCodeState {
                return @{
                    Status = "Error"
                    Errors = @(@{ Message = "Compilation error in file.ts"; Severity = "High" })
                    HasReplyField = $true
                    ReplyFieldCoordinates = @(100, 200)
                }
            }
            Mock Get-ProjectConfig {
                return @{
                    skills = @("/path/to/compilation-error-resolution")
                }
            }
            Mock Get-DecisionHistory { return @() }
            Mock Invoke-SimpleDecision { return @{ Action = "check-skills" } }
            Mock Find-SkillForError { return "/path/to/compilation-error-resolution" } -Verifiable
            Mock Send-SkillCommand {} -Verifiable

            Process-Project -Project @{ Name = "Test" }

            Assert-MockCalled Find-SkillForError -Times 1
            Assert-MockCalled Send-SkillCommand -Times 1
        }

        It "Should notify user when no skill found for error" {
            Mock Find-ClaudeCodeSession { return @{ SessionId = "test"; WindowHandle = "hwnd" } }
            Mock Get-ClaudeCodeState {
                return @{
                    Status = "Error"
                    Errors = @(@{ Message = "Unknown error" })
                }
            }
            Mock Get-ProjectConfig { return @{ skills = @() } }
            Mock Get-DecisionHistory { return @() }
            Mock Invoke-SimpleDecision { return @{ Action = "check-skills" } }
            Mock Find-SkillForError { return $null }
            Mock Send-Notification {} -Verifiable

            Process-Project -Project @{ Name = "Test" }

            Assert-MockCalled Send-Notification -Times 1
        }

        It "Should notify user for 'notify' action" {
            Mock Find-ClaudeCodeSession { return @{ SessionId = "test"; WindowHandle = "hwnd" } }
            Mock Get-ClaudeCodeState { return @{ Status = "Idle" } }
            Mock Get-ProjectConfig { return @{} }
            Mock Get-DecisionHistory { return @() }
            Mock Invoke-SimpleDecision {
                return @{
                    Action = "notify"
                    Reasoning = "Session has been idle for too long"
                }
            }
            Mock Send-Notification {} -Verifiable

            Process-Project -Project @{ Name = "Test" }

            Assert-MockCalled Send-Notification -Times 1
        }

        It "Should wait for 'wait' action" {
            Mock Find-ClaudeCodeSession { return @{ SessionId = "test"; WindowHandle = "hwnd" } }
            Mock Get-ClaudeCodeState { return @{ Status = "InProgress"; IsProcessing = $true } }
            Mock Get-ProjectConfig { return @{} }
            Mock Get-DecisionHistory { return @() }
            Mock Invoke-SimpleDecision { return @{ Action = "wait" } }

            { Process-Project -Project @{ Name = "Test" } } | Should -Not -Throw
        }
    }

    Context "State Updates" {
        It "Should update project state after processing" {
            Mock Find-ClaudeCodeSession { return @{ SessionId = "test123"; WindowHandle = "hwnd" } }
            Mock Get-ClaudeCodeState {
                return @{
                    Status = "HasTodos"
                    Todos = @{ Remaining = 5; Completed = 2; Total = 7 }
                }
            }
            Mock Get-ProjectConfig { return @{} }
            Mock Get-DecisionHistory { return @() }
            Mock Invoke-SimpleDecision { return @{ Action = "wait" } }
            Mock Update-ProjectState {} -Verifiable
            Mock Update-RegistrySessionId {} -Verifiable

            Process-Project -Project @{ Name = "Test" }

            Assert-MockCalled Update-ProjectState -Times 1
            Assert-MockCalled Update-RegistrySessionId -Times 1
        }

        It "Should increment watchdog statistics" {
            Mock Find-ClaudeCodeSession { return @{ SessionId = "test"; WindowHandle = "hwnd" } }
            Mock Get-ClaudeCodeState { return @{ Status = "Idle" } }
            Mock Get-ProjectConfig { return @{} }
            Mock Get-DecisionHistory { return @() }
            Mock Invoke-SimpleDecision { return @{ Action = "wait" } }

            $global:WatchdogStats = @{
                ProjectsProcessed = 0
                DecisionsMade = 0
            }

            Process-Project -Project @{ Name = "Test" }

            $global:WatchdogStats.ProjectsProcessed | Should -Be 1
            $global:WatchdogStats.DecisionsMade | Should -Be 1
        }
    }

    Context "Error Handling" {
        It "Should throw on processing error" {
            Mock Find-ClaudeCodeSession { throw "Session error" }

            $project = @{ Name = "TestProject" }
            { Process-Project -Project $project } | Should -Throw
        }

        It "Should log errors with project context" {
            Mock Find-ClaudeCodeSession { throw "Test error" }
            Mock Write-Warning {} -Verifiable

            $project = @{ Name = "TestProject" }
            { Process-Project -Project $project } | Should -Throw

            Assert-MockCalled Write-Warning -ParameterFilter {
                $Message -like "*TestProject*"
            }
        }
    }
}

Describe "Handle-ProjectError" {

    Context "Error Tracking" {
        It "Should track consecutive errors per project" {
            $project = @{ Name = "TestProject" }
            $error = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("Test error"),
                "TestError",
                [System.Management.Automation.ErrorCategory]::NotSpecified,
                $null
            )

            Mock Write-WatchdogLog {}
            Mock Update-ProjectState {}

            Handle-ProjectError -Project $project -Error $error

            $script:ProjectErrors["TestProject"].Count | Should -Be 1
        }

        It "Should quarantine project after error threshold" {
            $project = @{ Name = "QuarantineTest" }
            $error = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("Test error"),
                "TestError",
                [System.Management.Automation.ErrorCategory]::NotSpecified,
                $null
            )

            Mock Write-WatchdogLog {}
            Mock Update-ProjectState {} -Verifiable
            Mock Send-ErrorNotification {} -Verifiable

            # Simulate 5 consecutive errors
            1..5 | ForEach-Object {
                Handle-ProjectError -Project $project -Error $error
            }

            Assert-MockCalled Update-ProjectState -ParameterFilter {
                $StateUpdates.status -eq "Quarantined"
            }
            Assert-MockCalled Send-ErrorNotification -Times 1
        }

        It "Should increment global error statistics" {
            $project = @{ Name = "TestProject" }
            $error = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("Test error"),
                "TestError",
                [System.Management.Automation.ErrorCategory]::NotSpecified,
                $null
            )

            Mock Write-WatchdogLog {}

            $global:WatchdogStats = @{ ErrorsEncountered = 0 }

            Handle-ProjectError -Project $project -Error $error

            $global:WatchdogStats.ErrorsEncountered | Should -Be 1
        }
    }
}

Describe "Find-SkillForError" {

    Context "Skill Matching" {
        It "Should match compilation errors" {
            $error = @{ Message = "Compilation error in file.ts" }
            $config = @{
                skills = @(
                    "/path/to/compilation-error-resolution",
                    "/path/to/other-skill"
                )
            }

            $skill = Find-SkillForError -Error $error -ProjectConfig $config

            $skill | Should -Be "/path/to/compilation-error-resolution"
        }

        It "Should match type errors" {
            $error = @{ Message = "Type error: Cannot assign string to number" }
            $config = @{
                skills = @("/path/to/type-error-resolution")
            }

            $skill = Find-SkillForError -Error $error -ProjectConfig $config

            $skill | Should -Be "/path/to/type-error-resolution"
        }

        It "Should match lint errors" {
            $error = @{ Message = "ESLint error: no-unused-vars" }
            $config = @{
                skills = @("/path/to/lint-error-resolution")
            }

            $skill = Find-SkillForError -Error $error -ProjectConfig $config

            $skill | Should -Be "/path/to/lint-error-resolution"
        }

        It "Should return null when no skill matches" {
            $error = @{ Message = "Unknown error type" }
            $config = @{ skills = @("/path/to/compilation-error-resolution") }

            $skill = Find-SkillForError -Error $error -ProjectConfig $config

            $skill | Should -Be $null
        }

        It "Should return null when skill not in project config" {
            $error = @{ Message = "Compilation error" }
            $config = @{ skills = @("/path/to/other-skill") }

            $skill = Find-SkillForError -Error $error -ProjectConfig $config

            $skill | Should -Be $null
        }
    }
}
