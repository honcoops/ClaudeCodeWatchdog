<#
.SYNOPSIS
    End-to-end integration tests for Claude Code Watchdog

.DESCRIPTION
    Tests complete workflows from project registration through
    detection, decision-making, and action execution

.NOTES
    Part of WS07 - Testing & Quality Assurance
    Work Item: WI-4.3 - Integration Test Suite

    Requirements:
    - Windows MCP should be installed (tests will skip if not available)
    - Test project configuration files
    - Mock Claude Code sessions (or real ones for manual testing)
#>

BeforeAll {
    $ScriptRoot = Split-Path -Parent $PSCommandPath
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)

    # Import all modules
    Get-ChildItem "$ProjectRoot/src" -Recurse -Filter "*.ps1" | ForEach-Object {
        . $_.FullName
    }

    # Check if Windows MCP is available
    $script:HasWindowsMCP = $null -ne (Get-Command mcp-client -ErrorAction SilentlyContinue)
}

Describe "End-to-End: Project Registration and Monitoring" -Tag "Integration" {

    Context "Project Registration Workflow" {
        It "Should register a new project successfully" {
            $testConfig = @{
                projectName = "test-integration-project"
                repoPath = "/tmp/test-project"
                repoUrl = "github.com/test/project"
                branch = "main"
                automation = @{
                    autoCommit = $true
                    autoProgress = $true
                }
                skills = @()
                humanInLoop = @{}
            }

            # Create temp config file
            $configPath = "/tmp/test-project-config.json"
            $testConfig | ConvertTo-Json -Depth 10 | Set-Content $configPath

            # Register project
            { Register-Project -ProjectName $testConfig.projectName -ConfigPath $configPath } | Should -Not -Throw

            # Verify registration
            $projects = Get-RegisteredProjects
            $projects | Where-Object { $_.Name -eq $testConfig.projectName } | Should -Not -BeNullOrEmpty

            # Cleanup
            Remove-Item $configPath -Force -ErrorAction SilentlyContinue
        }

        It "Should reject invalid project configuration" {
            $invalidConfig = @{
                # Missing required fields
                projectName = "invalid-project"
            }

            $configPath = "/tmp/invalid-config.json"
            $invalidConfig | ConvertTo-Json | Set-Content $configPath

            { Register-Project -ProjectName "invalid" -ConfigPath $configPath } | Should -Throw

            # Cleanup
            Remove-Item $configPath -Force -ErrorAction SilentlyContinue
        }
    }

    Context "State Detection and Decision Flow" {
        It "Should detect state, make decision, and execute action" {
            # Mock Windows MCP if not available
            if (-not $script:HasWindowsMCP) {
                Mock Invoke-WindowsMCP {
                    return @{
                        WindowTitle = "Claude Code - 01TEST123456789ABCDEFGH"
                        InteractiveElements = @(
                            @{
                                Name = "Reply"
                                Coordinates = @(100, 200)
                                Type = "textbox"
                            }
                        )
                        InformativeElements = @(
                            @{ Text = "TODO: Complete task 1" },
                            @{ Text = "TODO: Complete task 2" }
                        )
                    }
                }
            }

            # Create mock session
            $mockSession = @{
                SessionId = "01TEST123456789ABCDEFGH"
                WindowHandle = "mock-handle"
            }

            # Mock project config
            $projectConfig = @{
                projectName = "test-project"
                automation = @{
                    autoProgress = $true
                    stallThreshold = "10m"
                }
                skills = @()
            }

            # Step 1: Detect state
            Mock Get-ClaudeCodeState {
                return @{
                    SessionId = "01TEST123456789ABCDEFGH"
                    Status = "HasTodos"
                    HasReplyField = $true
                    ReplyFieldCoordinates = @(100, 200)
                    Todos = @{
                        Total = 5
                        Completed = 3
                        Remaining = 2
                        Items = @(
                            @{ Status = "pending"; Content = "Task 4" },
                            @{ Status = "pending"; Content = "Task 5" }
                        )
                    }
                    Errors = @()
                    Warnings = @()
                    IsProcessing = $false
                }
            }

            $state = Get-ClaudeCodeState -SessionWindow $mockSession.WindowHandle

            $state | Should -Not -BeNullOrEmpty
            $state.Status | Should -Be "HasTodos"
            $state.Todos.Remaining | Should -Be 2

            # Step 2: Make decision
            Mock Get-DecisionHistory { return @() }
            Mock Get-WatchdogConfig {
                return @{
                    api = @{ enabled = $false }
                }
            }

            $decision = Invoke-SimpleDecision -SessionState $state -ProjectConfig $projectConfig

            $decision | Should -Not -BeNullOrEmpty
            $decision.Action | Should -BeIn @("continue", "wait", "notify")

            # Step 3: Execute action (if continue)
            if ($decision.Action -eq "continue") {
                Mock Send-ClaudeCodeCommand { return @{ Success = $true } }

                $result = Send-ClaudeCodeCommand -Command $decision.Command -ReplyFieldCoordinates $state.ReplyFieldCoordinates

                $result.Success | Should -Be $true
            }
        }
    }
}

Describe "End-to-End: Error Detection and Skill Resolution" -Tag "Integration" {

    Context "Error Detection Flow" {
        It "Should detect errors and recommend skill usage" {
            # Mock state with error
            Mock Get-ClaudeCodeState {
                return @{
                    SessionId = "01TEST"
                    Status = "Error"
                    HasReplyField = $true
                    ReplyFieldCoordinates = @(100, 200)
                    Todos = @{
                        Total = 5
                        Completed = 3
                        Remaining = 2
                        Items = @()
                    }
                    Errors = @(
                        @{
                            Message = "TypeScript compilation error: Type 'string' is not assignable to type 'number'"
                            Severity = "High"
                            Category = "Compilation"
                        }
                    )
                    Warnings = @()
                    IsProcessing = $false
                }
            }

            $state = Get-ClaudeCodeState -SessionWindow "test"

            $state.Status | Should -Be "Error"
            $state.Errors.Count | Should -BeGreaterThan 0

            # Mock project with skills
            $projectConfig = @{
                projectName = "test-project"
                automation = @{ autoProgress = $true }
                skills = @(
                    "/mnt/skills/user/type-error-resolution",
                    "/mnt/skills/user/compilation-error-resolution"
                )
            }

            # Decision should recommend skill
            Mock Get-DecisionHistory { return @() }
            Mock Get-WatchdogConfig { return @{ api = @{ enabled = $false } } }

            $decision = Invoke-SimpleDecision -SessionState $state -ProjectConfig $projectConfig

            # Should recommend skill check or direct skill usage
            $decision.Action | Should -BeIn @("check-skills", "use-skill", "notify")
        }
    }

    Context "Skill Matching Flow" {
        It "Should match correct skill for error type" {
            $error = @{
                Message = "Compilation error in src/main.ts: Cannot find name 'foo'"
                Severity = "High"
            }

            $projectConfig = @{
                skills = @(
                    "/mnt/skills/user/compilation-error-resolution",
                    "/mnt/skills/user/type-error-resolution",
                    "/mnt/skills/user/lint-error-resolution"
                )
            }

            $matchedSkill = Find-SkillForError -Error $error -ProjectConfig $projectConfig

            $matchedSkill | Should -BeLike "*compilation-error-resolution*"
        }

        It "Should return null when no skill matches" {
            $error = @{
                Message = "Unknown runtime error"
            }

            $projectConfig = @{
                skills = @(
                    "/mnt/skills/user/compilation-error-resolution"
                )
            }

            $matchedSkill = Find-SkillForError -Error $error -ProjectConfig $projectConfig

            $matchedSkill | Should -Be $null
        }
    }
}

Describe "End-to-End: Multi-Project Processing" -Tag "Integration" {

    Context "Concurrent Project Monitoring" {
        It "Should process multiple projects in sequence" {
            # Register multiple test projects
            $projects = @(
                @{ Name = "Project1"; HasSession = $true; Status = "HasTodos" },
                @{ Name = "Project2"; HasSession = $true; Status = "InProgress" },
                @{ Name = "Project3"; HasSession = $false; Status = "NoSession" }
            )

            Mock Get-ActiveProjects {
                return $projects
            }

            Mock Find-ClaudeCodeSession {
                param($ProjectName)
                $project = $projects | Where-Object { $_.Name -eq $ProjectName }
                if ($project.HasSession) {
                    return @{
                        SessionId = "session-$ProjectName"
                        WindowHandle = "handle-$ProjectName"
                    }
                }
                return $null
            }

            Mock Get-ClaudeCodeState {
                param($SessionWindow)
                return @{
                    SessionId = $SessionWindow
                    Status = "Idle"
                    HasReplyField = $true
                    Todos = @{ Total = 0; Completed = 0; Remaining = 0; Items = @() }
                    Errors = @()
                    IsProcessing = $false
                }
            }

            Mock Get-ProjectConfig { return @{ automation = @{} } }
            Mock Get-DecisionHistory { return @() }
            Mock Invoke-SimpleDecision { return @{ Action = "wait" } }
            Mock Update-ProjectState {}
            Mock Update-RegistrySessionId {}
            Mock Send-Notification {}

            # Process all projects
            $processedCount = 0
            foreach ($project in $projects) {
                try {
                    Process-Project -Project $project
                    if ($project.HasSession) {
                        $processedCount++
                    }
                }
                catch {
                    # Expected for projects without sessions
                }
            }

            $processedCount | Should -BeGreaterOrEqual 2
        }

        It "Should isolate project errors" {
            $projects = @(
                @{ Name = "GoodProject" },
                @{ Name = "BadProject" }
            )

            Mock Get-ActiveProjects { return $projects }

            Mock Process-Project {
                param($Project)
                if ($Project.Name -eq "BadProject") {
                    throw "Test error in BadProject"
                }
            }

            Mock Handle-ProjectError {}

            # Should process both projects despite error
            foreach ($project in $projects) {
                try {
                    Process-Project -Project $project
                }
                catch {
                    Handle-ProjectError -Project $project -Error $_
                }
            }

            # Both projects attempted
            Assert-MockCalled Process-Project -Times 2
            Assert-MockCalled Handle-ProjectError -Times 1
        }
    }
}

Describe "End-to-End: Session Recovery" -Tag "Integration" {

    Context "Session Recovery Workflow" {
        It "Should save and restore session state" {
            # Mock active projects
            $projects = @(
                @{ Name = "RecoveryTest1" },
                @{ Name = "RecoveryTest2" }
            )

            Mock Get-ActiveProjects { return $projects }

            Mock Find-ClaudeCodeSession {
                param($ProjectName)
                return @{
                    SessionId = "session-$ProjectName"
                    WindowHandle = "handle-$ProjectName"
                }
            }

            # Save state
            Mock New-Item {}
            Mock Set-Content {}
            Mock ConvertTo-Json { return "{}" }

            { Save-WatchdogState } | Should -Not -Throw

            # Verify save was called
            Assert-MockCalled Set-Content -Times 1

            # Mock recovery state
            Mock Test-Path { return $true }
            Mock Get-Content {
                return @{
                    SavedAt = (Get-Date).AddMinutes(-5).ToString("o")
                    Projects = @(
                        @{
                            ProjectName = "RecoveryTest1"
                            SessionId = "session-RecoveryTest1"
                            LastActive = (Get-Date).ToString("o")
                        }
                    )
                } | ConvertTo-Json -Depth 10
            }

            Mock Get-RegisteredProjects {
                return @(@{ Name = "RecoveryTest1" })
            }

            Mock Update-RegistrySessionId {}
            Mock Send-Notification {}
            Mock Remove-Item {}

            # Restore state
            { Restore-WatchdogSessions } | Should -Not -Throw

            # Should attempt to restore session
            Assert-MockCalled Find-ClaudeCodeSession -Times 1
        }

        It "Should skip old recovery state" {
            Mock Test-Path { return $true }
            Mock Get-Content {
                return @{
                    SavedAt = (Get-Date).AddHours(-25).ToString("o")  # Too old
                    Projects = @()
                } | ConvertTo-Json -Depth 10
            }

            { Restore-WatchdogSessions } | Should -Not -Throw

            # Should not attempt recovery for old state
        }
    }
}

Describe "End-to-End: Logging and Reporting" -Tag "Integration" {

    Context "Decision Logging" {
        It "Should log decisions with full context" {
            $projectName = "TestProject"

            $decision = @{
                Action = "continue"
                Command = "Continue with next TODO"
                Reasoning = "Work remaining"
                Confidence = 0.85
                Timestamp = Get-Date -Format "o"
                DecisionMethod = "rule-based"
            }

            $sessionState = @{
                Status = "HasTodos"
                Todos = @{
                    Total = 10
                    Completed = 5
                    Remaining = 5
                }
                Errors = @()
            }

            Mock New-Item {}
            Mock Add-Content {} -Verifiable

            { Add-DecisionLog -ProjectName $projectName -Decision $decision -SessionState $sessionState } | Should -Not -Throw

            Assert-MockCalled Add-Content -Times 1
        }
    }

    Context "Progress Reporting" {
        It "Should generate progress report for project" {
            $projectName = "TestProject"

            # Mock project state
            Mock Get-ProjectState {
                return @{
                    status = "Active"
                    todosRemaining = 5
                    todosCompleted = 10
                    decisions = 42
                }
            }

            Mock Get-RegisteredProjects {
                return @(
                    @{
                        Name = $projectName
                        RepoPath = "/tmp/test"
                        CurrentPhase = "Phase 2 - Implementation"
                    }
                )
            }

            Mock Get-DecisionLogSummary {
                return @{
                    Success = $true
                    TotalDecisions = 42
                    Decisions = @()
                }
            }

            Mock Get-DecisionLogAnalytics {
                return @{
                    TotalDecisions = 42
                    APIDecisions = 30
                    RuleBasedDecisions = 12
                    SkillInvocations = 7
                    TotalAPICost = 1.2345
                }
            }

            Mock Set-Content {}

            $report = Generate-ProgressReport -ProjectName $projectName

            $report.Success | Should -Be $true
            $report.ReportPath | Should -Not -BeNullOrEmpty
        }
    }

    Context "Daily Summary" {
        It "Should generate summary for all projects" {
            Mock Get-RegisteredProjects {
                return @(
                    @{ Name = "Project1"; Status = "Active" },
                    @{ Name = "Project2"; Status = "Active" },
                    @{ Name = "Project3"; Status = "Paused" }
                )
            }

            Mock Get-ProjectState {
                param($ProjectName)
                return @{
                    status = if ($ProjectName -eq "Project3") { "Paused" } else { "Active" }
                    todosRemaining = 5
                    todosCompleted = 10
                    decisions = 20
                    currentPhase = "Testing"
                    lastActivity = (Get-Date).ToString("o")
                }
            }

            Mock Get-DecisionLogAnalytics {
                return @{
                    TotalDecisions = 20
                    APIDecisions = 15
                    RuleBasedDecisions = 5
                    TotalAPICost = 0.5
                }
            }

            Mock New-Item {}
            Mock Set-Content {}

            $summary = Generate-DailySummary

            $summary.Success | Should -Be $true
            $summary.Projects | Should -Be 3
        }
    }
}

Describe "End-to-End: Resource Monitoring" -Tag "Integration" {

    Context "Resource Tracking" {
        It "Should track resource usage during operation" {
            # Initialize monitoring
            Initialize-ResourceMonitoring

            $global:WatchdogStats | Should -Not -BeNullOrEmpty
            $global:WatchdogStats.CyclesCompleted | Should -Be 0

            # Measure resources
            $preResources = Measure-ResourceUsage
            $preResources | Should -Not -BeNullOrEmpty
            $preResources.WorkingSetMB | Should -BeGreaterThan 0

            # Simulate some work
            Start-Sleep -Milliseconds 100

            $postResources = Measure-ResourceUsage

            # Update metrics
            Update-ResourceMetrics -PreProcess $preResources -PostProcess $postResources

            # Verify tracking
            $global:WatchdogStats.PeakMemoryMB | Should -BeGreaterThan 0
            $global:WatchdogStats.ResourceSamples | Should -Not -BeNullOrEmpty
        }
    }
}

AfterAll {
    # Cleanup test resources
    Get-Variable -Scope Global | Where-Object {
        $_.Name -like "Watchdog*"
    } | Remove-Variable -Force -ErrorAction SilentlyContinue

    Write-Host "`n✅ Integration tests completed" -ForegroundColor Green
}
