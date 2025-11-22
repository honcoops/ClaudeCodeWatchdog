<#
.SYNOPSIS
    Unit tests for Invoke-ClaudeDecision.ps1

.NOTES
    Part of WS07 - Testing & Quality Assurance
    Work Item: WI-4.2 - Unit Test Suite
#>

BeforeAll {
    # Mock dependencies
    function Get-WatchdogConfig {}
    function Get-ClaudeAPIKey {}
    function Test-APICostLimits {}
    function Invoke-SimpleDecision {}
    function Invoke-ClaudeAPI {}
    function Add-APIUsageLog {}
    function Calculate-APICost {}
}

Describe "Invoke-ClaudeDecision" {

    Context "API Availability Checks" {
        It "Should fallback to rule-based when API disabled" {
            Mock Get-WatchdogConfig {
                return @{ api = @{ enabled = $false } }
            }
            Mock Invoke-SimpleDecision {
                return @{ Action = "wait"; DecisionMethod = "rule-based" }
            } -Verifiable

            $state = @{ Status = "HasTodos"; Todos = @{ Remaining = 3 } }
            $config = @{ projectName = "Test" }

            $decision = Invoke-ClaudeDecision -SessionState $state -ProjectConfig $config

            $decision.DecisionMethod | Should -Be "rule-based"
            Assert-MockCalled Invoke-SimpleDecision -Times 1
        }

        It "Should fallback when API key not configured" {
            Mock Get-WatchdogConfig {
                return @{ api = @{ enabled = $true } }
            }
            Mock Get-ClaudeAPIKey { return $null }
            Mock Invoke-SimpleDecision {
                return @{ Action = "wait"; DecisionMethod = "rule-based" }
            } -Verifiable
            Mock Write-Warning {} -Verifiable

            $state = @{ Status = "HasTodos" }
            $config = @{ projectName = "Test" }

            $decision = Invoke-ClaudeDecision -SessionState $state -ProjectConfig $config

            Assert-MockCalled Invoke-SimpleDecision -Times 1
            Assert-MockCalled Write-Warning -ParameterFilter {
                $Message -like "*API key*"
            }
        }

        It "Should fallback when cost limit exceeded" {
            Mock Get-WatchdogConfig {
                return @{ api = @{ enabled = $true } }
            }
            Mock Get-ClaudeAPIKey { return "sk-test-key" }
            Mock Test-APICostLimits {
                return @{
                    CanProceed = $false
                    Reason = "Daily limit exceeded"
                }
            }
            Mock Invoke-SimpleDecision {
                return @{ Action = "wait"; DecisionMethod = "rule-based" }
            } -Verifiable
            Mock Write-Warning {} -Verifiable

            $state = @{ Status = "HasTodos" }
            $config = @{ projectName = "Test" }

            $decision = Invoke-ClaudeDecision -SessionState $state -ProjectConfig $config

            Assert-MockCalled Invoke-SimpleDecision -Times 1
            Assert-MockCalled Write-Warning -ParameterFilter {
                $Message -like "*cost limit*"
            }
        }
    }

    Context "API Decision Making" {
        It "Should call Claude API with proper prompt" {
            Mock Get-WatchdogConfig {
                return @{
                    api = @{
                        enabled = $true
                        model = "claude-3-5-sonnet-20241022"
                        maxTokens = 1000
                    }
                }
            }
            Mock Get-ClaudeAPIKey { return "sk-test-key" }
            Mock Test-APICostLimits { return @{ CanProceed = $true } }
            Mock Build-DecisionPrompt {
                return "Test prompt"
            } -Verifiable
            Mock Invoke-ClaudeAPI {
                return @{
                    content = @(@{ text = '{"action":"continue","command":"yes","skill_to_use":null,"reasoning":"TODOs remaining","confidence":0.9}' })
                    usage = @{ input_tokens = 100; output_tokens = 50 }
                    ResponseTime = 1.5
                }
            } -Verifiable
            Mock Add-APIUsageLog {}
            Mock Calculate-APICost { return 0.0025 }

            $state = @{
                Status = "HasTodos"
                Todos = @{ Remaining = 5 }
                Errors = @()
                IsProcessing = $false
            }
            $config = @{ projectName = "Test" }

            $decision = Invoke-ClaudeDecision -SessionState $state -ProjectConfig $config

            $decision.DecisionMethod | Should -Be "claude-api"
            $decision.Action | Should -Be "continue"
            Assert-MockCalled Build-DecisionPrompt -Times 1
            Assert-MockCalled Invoke-ClaudeAPI -Times 1
        }

        It "Should include metadata in decision" {
            Mock Get-WatchdogConfig {
                return @{
                    api = @{
                        enabled = $true
                        model = "claude-3-5-sonnet-20241022"
                    }
                }
            }
            Mock Get-ClaudeAPIKey { return "sk-test-key" }
            Mock Test-APICostLimits { return @{ CanProceed = $true } }
            Mock Invoke-ClaudeAPI {
                return @{
                    content = @(@{ text = '{"action":"wait","command":null,"skill_to_use":null,"reasoning":"Processing","confidence":0.95}' })
                    usage = @{ input_tokens = 150; output_tokens = 75 }
                    ResponseTime = 2.1
                }
            }
            Mock Add-APIUsageLog {}
            Mock Calculate-APICost { return 0.005 }

            $state = @{
                Status = "InProgress"
                IsProcessing = $true
                Todos = @{ Remaining = 3 }
                Errors = @()
            }
            $config = @{ projectName = "Test" }

            $decision = Invoke-ClaudeDecision -SessionState $state -ProjectConfig $config

            $decision.Metadata | Should -Not -BeNullOrEmpty
            $decision.Metadata.SessionStatus | Should -Be "InProgress"
            $decision.Metadata.TodosRemaining | Should -Be 3
            $decision.Metadata.ErrorCount | Should -Be 0
            $decision.Metadata.TokensUsed | Should -Be 225
            $decision.Metadata.CostEstimate | Should -Be 0.005
            $decision.Metadata.Model | Should -Be "claude-3-5-sonnet-20241022"
        }

        It "Should log API usage" {
            Mock Get-WatchdogConfig {
                return @{ api = @{ enabled = $true } }
            }
            Mock Get-ClaudeAPIKey { return "sk-test-key" }
            Mock Test-APICostLimits { return @{ CanProceed = $true } }
            Mock Invoke-ClaudeAPI {
                return @{
                    content = @(@{ text = '{"action":"notify","command":null,"skill_to_use":null,"reasoning":"Human needed","confidence":0.7}' })
                    usage = @{ input_tokens = 200; output_tokens = 100 }
                }
            }
            Mock Calculate-APICost { return 0.01 }
            Mock Add-APIUsageLog {} -Verifiable

            $state = @{ Status = "Error"; Errors = @(@{ Message = "Unknown error" }) }
            $config = @{ projectName = "TestProject"; skills = @() }

            Invoke-ClaudeDecision -SessionState $state -ProjectConfig $config

            Assert-MockCalled Add-APIUsageLog -Times 1 -ParameterFilter {
                $ProjectName -eq "TestProject"
            }
        }

        It "Should fallback to rule-based on API failure" {
            Mock Get-WatchdogConfig {
                return @{ api = @{ enabled = $true } }
            }
            Mock Get-ClaudeAPIKey { return "sk-test-key" }
            Mock Test-APICostLimits { return @{ CanProceed = $true } }
            Mock Invoke-ClaudeAPI { throw "API timeout" }
            Mock Invoke-SimpleDecision {
                return @{ Action = "wait"; DecisionMethod = "rule-based" }
            } -Verifiable
            Mock Write-Warning {} -Verifiable

            $state = @{ Status = "HasTodos" }
            $config = @{ projectName = "Test" }

            $decision = Invoke-ClaudeDecision -SessionState $state -ProjectConfig $config

            $decision.DecisionMethod | Should -Be "rule-based"
            Assert-MockCalled Invoke-SimpleDecision -Times 1
            Assert-MockCalled Write-Warning -Times 1
        }
    }

    Context "Decision Parsing and Validation" {
        It "Should parse valid JSON response" {
            $response = @{
                content = @(
                    @{ text = '{"action":"continue","command":"Continue with next TODO","skill_to_use":null,"reasoning":"Work to do","confidence":0.85}' }
                )
                usage = @{ input_tokens = 100; output_tokens = 50 }
            }

            $state = @{ Status = "HasTodos" }

            $decision = Parse-ClaudeDecisionResponse -Response $response -SessionState $state

            $decision.Action | Should -Be "continue"
            $decision.Command | Should -Be "Continue with next TODO"
            $decision.SkillToUse | Should -Be $null
            $decision.Reasoning | Should -Be "Work to do"
            $decision.Confidence | Should -Be 0.85
        }

        It "Should strip markdown code blocks from response" {
            $response = @{
                content = @(
                    @{ text = '```json
{"action":"wait","command":null,"skill_to_use":null,"reasoning":"Processing","confidence":0.9}
```' }
                )
                usage = @{ input_tokens = 100; output_tokens = 50 }
            }

            $state = @{ Status = "InProgress" }

            $decision = Parse-ClaudeDecisionResponse -Response $response -SessionState $state

            $decision.Action | Should -Be "wait"
        }

        It "Should validate action against allowed values" {
            $response = @{
                content = @(
                    @{ text = '{"action":"invalid-action","command":null,"skill_to_use":null,"reasoning":"Test","confidence":0.5}' }
                )
                usage = @{ input_tokens = 100; output_tokens = 50 }
            }

            $state = @{ Status = "Unknown" }

            $decision = Parse-ClaudeDecisionResponse -Response $response -SessionState $state

            $decision.Action | Should -Be "wait"  # Defaulted
            $decision.Confidence | Should -Be 0.50
        }

        It "Should clamp confidence to 0.0-1.0 range" {
            $response = @{
                content = @(
                    @{ text = '{"action":"wait","command":null,"skill_to_use":null,"reasoning":"Test","confidence":1.5}' }
                )
                usage = @{ input_tokens = 100; output_tokens = 50 }
            }

            $state = @{ Status = "Unknown" }

            $decision = Parse-ClaudeDecisionResponse -Response $response -SessionState $state

            $decision.Confidence | Should -Be 1.0
        }

        It "Should throw on malformed JSON" {
            $response = @{
                content = @(
                    @{ text = 'not valid json{' }
                )
                usage = @{ input_tokens = 100; output_tokens = 50 }
            }

            $state = @{ Status = "Unknown" }

            { Parse-ClaudeDecisionResponse -Response $response -SessionState $state } | Should -Throw
        }
    }
}

Describe "Build-DecisionPrompt" {

    Context "Prompt Construction" {
        It "Should include session state" {
            $state = @{
                Status = "HasTodos"
                IsProcessing = $false
                IdleTime = [TimeSpan]::FromMinutes(2)
                SessionId = "test-session-123"
                Todos = @{ Total = 10; Completed = 5; Remaining = 5; Items = @() }
                Errors = @()
            }
            $config = @{
                projectName = "TestProject"
                automation = @{
                    autoProgress = $true
                    autoCommit = $true
                    stallThreshold = "10m"
                }
                skills = @()
                humanInLoop = @{}
            }

            $prompt = Build-DecisionPrompt -SessionState $state -ProjectConfig $config

            $prompt | Should -BeLike "*HasTodos*"
            $prompt | Should -BeLike "*TestProject*"
            $prompt | Should -BeLike "*Total**: 10*"
            $prompt | Should -BeLike "*Completed**: 5*"
            $prompt | Should -BeLike "*Remaining**: 5*"
        }

        It "Should include recent decision history" {
            $state = @{
                Status = "HasTodos"
                IsProcessing = $false
                IdleTime = [TimeSpan]::Zero
                SessionId = "test"
                Todos = @{ Total = 0; Completed = 0; Remaining = 0; Items = @() }
                Errors = @()
            }
            $config = @{
                projectName = "Test"
                automation = @{}
                skills = @()
                humanInLoop = @{}
            }
            $history = @(
                @{ Timestamp = "2025-11-22T10:00:00"; Action = "continue"; Reasoning = "Work to do" },
                @{ Timestamp = "2025-11-22T10:05:00"; Action = "wait"; Reasoning = "Processing" }
            )

            $prompt = Build-DecisionPrompt -SessionState $state -ProjectConfig $config -DecisionHistory $history

            $prompt | Should -BeLike "*Recent Decisions*"
            $prompt | Should -BeLike "*continue*"
            $prompt | Should -BeLike "*wait*"
        }

        It "Should include error context" {
            $state = @{
                Status = "Error"
                IsProcessing = $false
                IdleTime = [TimeSpan]::Zero
                SessionId = "test"
                Todos = @{ Total = 0; Completed = 0; Remaining = 0; Items = @() }
                Errors = @(
                    @{ Message = "TypeError: null reference"; Severity = "High"; Category = "Runtime" },
                    @{ Message = "Compilation failed"; Severity = "Critical"; Category = "Compile" }
                )
            }
            $config = @{
                projectName = "Test"
                automation = @{}
                skills = @()
                humanInLoop = @{}
            }

            $prompt = Build-DecisionPrompt -SessionState $state -ProjectConfig $config

            $prompt | Should -BeLike "*Detected Errors*"
            $prompt | Should -BeLike "*TypeError*"
            $prompt | Should -BeLike "*Compilation failed*"
            $prompt | Should -BeLike "*High*"
            $prompt | Should -BeLike "*Critical*"
        }

        It "Should include available skills" {
            $state = @{
                Status = "Error"
                IsProcessing = $false
                IdleTime = [TimeSpan]::Zero
                SessionId = "test"
                Todos = @{ Total = 0; Completed = 0; Remaining = 0; Items = @() }
                Errors = @()
            }
            $config = @{
                projectName = "Test"
                automation = @{}
                skills = @(
                    "/path/to/type-error-resolution",
                    "/path/to/compilation-error-resolution"
                )
                humanInLoop = @{}
            }

            $prompt = Build-DecisionPrompt -SessionState $state -ProjectConfig $config

            $prompt | Should -BeLike "*Available Skills*"
            $prompt | Should -BeLike "*type-error-resolution*"
            $prompt | Should -BeLike "*compilation-error-resolution*"
        }

        It "Should include human-in-loop configuration" {
            $state = @{
                Status = "PhaseComplete"
                IsProcessing = $false
                IdleTime = [TimeSpan]::Zero
                SessionId = "test"
                Todos = @{ Total = 10; Completed = 10; Remaining = 0; Items = @() }
                Errors = @()
            }
            $config = @{
                projectName = "Test"
                automation = @{}
                skills = @()
                humanInLoop = @{
                    requiresApprovalFor = @("database-schema-changes", "API-breaking-changes")
                    requiresHumanAfter = @("compilation-errors", "test-failures")
                }
            }

            $prompt = Build-DecisionPrompt -SessionState $state -ProjectConfig $config

            $prompt | Should -BeLike "*Human-in-Loop*"
            $prompt | Should -BeLike "*database-schema-changes*"
            $prompt | Should -BeLike "*compilation-errors*"
        }
    }
}

Describe "Invoke-ClaudeAPI" {

    Context "API Call" {
        It "Should make API request with correct headers" {
            Mock Invoke-RestMethod {
                return @{
                    content = @(@{ text = "response" })
                    usage = @{ input_tokens = 100; output_tokens = 50 }
                }
            } -Verifiable

            $config = @{
                model = "claude-3-5-sonnet-20241022"
                maxTokens = 1000
                temperature = 1.0
            }

            Invoke-ClaudeAPI -Prompt "Test prompt" -APIKey "sk-test-key" -Config $config

            Assert-MockCalled Invoke-RestMethod -Times 1 -ParameterFilter {
                $Headers["x-api-key"] -eq "sk-test-key" -and
                $Headers["anthropic-version"] -eq "2023-06-01" -and
                $Headers["content-type"] -eq "application/json"
            }
        }

        It "Should include response time in result" {
            Mock Invoke-RestMethod {
                Start-Sleep -Milliseconds 100
                return @{
                    content = @(@{ text = "response" })
                    usage = @{ input_tokens = 100; output_tokens = 50 }
                }
            }

            $config = @{ model = "claude-3-5-sonnet-20241022"; maxTokens = 1000; temperature = 1.0 }

            $response = Invoke-ClaudeAPI -Prompt "Test" -APIKey "sk-test" -Config $config

            $response.ResponseTime | Should -BeGreaterThan 0
        }

        It "Should throw on API failure" {
            Mock Invoke-RestMethod { throw "Network error" }

            $config = @{ model = "claude-3-5-sonnet-20241022"; maxTokens = 1000; temperature = 1.0 }

            { Invoke-ClaudeAPI -Prompt "Test" -APIKey "sk-test" -Config $config } | Should -Throw
        }
    }
}

Describe "Test-APICostLimits" {

    Context "Cost Limit Checking" {
        It "Should allow when no costs tracked yet" {
            Mock Test-Path { return $false }

            $config = @{
                api = @{
                    dailyCostLimit = 10.0
                    weeklyCostLimit = 50.0
                }
            }

            $result = Test-APICostLimits -GlobalConfig $config

            $result.CanProceed | Should -Be $true
        }

        It "Should block when daily limit exceeded" {
            Mock Test-Path { return $true }
            Mock Get-Content {
                return @{
                    daily_costs = @{
                        "2025-11-22" = @{ total_cost = 12.0 }
                    }
                } | ConvertTo-Json -Depth 10
            }

            $config = @{
                api = @{
                    dailyCostLimit = 10.0
                    weeklyCostLimit = 50.0
                }
            }

            $result = Test-APICostLimits -GlobalConfig $config

            $result.CanProceed | Should -Be $false
            $result.Reason | Should -BeLike "*Daily cost limit*"
        }

        It "Should block when weekly limit exceeded" {
            Mock Test-Path { return $true }
            Mock Get-Content {
                $costs = @{
                    daily_costs = @{}
                }
                # Add 7 days of high costs
                0..6 | ForEach-Object {
                    $date = (Get-Date).AddDays(-$_).ToString("yyyy-MM-dd")
                    $costs.daily_costs[$date] = @{ total_cost = 10.0 }
                }
                return $costs | ConvertTo-Json -Depth 10
            }

            $config = @{
                api = @{
                    dailyCostLimit = 15.0
                    weeklyCostLimit = 50.0
                }
            }

            $result = Test-APICostLimits -GlobalConfig $config

            $result.CanProceed | Should -Be $false
            $result.Reason | Should -BeLike "*Weekly cost limit*"
        }

        It "Should allow when under limits" {
            Mock Test-Path { return $true }
            Mock Get-Content {
                return @{
                    daily_costs = @{
                        "2025-11-22" = @{ total_cost = 5.0 }
                    }
                } | ConvertTo-Json -Depth 10
            }

            $config = @{
                api = @{
                    dailyCostLimit = 10.0
                    weeklyCostLimit = 50.0
                }
            }

            $result = Test-APICostLimits -GlobalConfig $config

            $result.CanProceed | Should -Be $true
        }
    }
}

Describe "Calculate-APICost" {

    Context "Cost Calculation" {
        It "Should calculate cost for Sonnet correctly" {
            $usage = @{
                input_tokens = 1000000
                output_tokens = 1000000
            }

            $cost = Calculate-APICost -Usage $usage -Model "claude-3-5-sonnet-20241022"

            $cost | Should -Be 18.0  # $3 input + $15 output per million
        }

        It "Should calculate cost for Haiku correctly" {
            $usage = @{
                input_tokens = 1000000
                output_tokens = 1000000
            }

            $cost = Calculate-APICost -Usage $usage -Model "claude-3-haiku-20240307"

            $cost | Should -Be 1.5  # $0.25 input + $1.25 output per million
        }

        It "Should handle small token counts" {
            $usage = @{
                input_tokens = 100
                output_tokens = 50
            }

            $cost = Calculate-APICost -Usage $usage -Model "claude-3-5-sonnet-20241022"

            $cost | Should -BeLessThan 0.01
        }

        It "Should default to Sonnet pricing for unknown model" {
            Mock Write-Warning {}

            $usage = @{
                input_tokens = 100
                output_tokens = 50
            }

            $cost = Calculate-APICost -Usage $usage -Model "unknown-model"

            $cost | Should -BeGreaterThan 0
        }
    }
}
