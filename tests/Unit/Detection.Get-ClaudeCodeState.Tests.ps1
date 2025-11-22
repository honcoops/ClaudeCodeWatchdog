<#
.SYNOPSIS
    Unit tests for Get-ClaudeCodeState.ps1

.NOTES
    Part of WS07 - Testing & Quality Assurance
    Work Item: WI-4.2 - Unit Test Suite
#>

BeforeAll {
    # Mock dependencies
    function Invoke-WindowsMCPStateTool {}
    function Get-TodosFromUI {}
    function Get-ErrorsFromUI {}
    function Get-WarningsFromUI {}
    function Test-ProcessingIndicator {}
}

Describe "Get-ClaudeCodeState" {

    Context "Basic State Capture" {
        It "Should capture UI state using Windows MCP" {
            Mock Invoke-WindowsMCPStateTool {
                return @{
                    WindowTitle = "Claude Code - Session 01ABC"
                    InteractiveElements = @()
                    InformativeElements = @()
                }
            } -Verifiable

            Mock Get-TodosFromUI { return @{ Total = 0; Completed = 0; Remaining = 0; Items = @() } }
            Mock Get-ErrorsFromUI { return @() }
            Mock Get-WarningsFromUI { return @() }
            Mock Test-ProcessingIndicator { return $false }

            $state = Get-ClaudeCodeState -SessionWindow "test-window"

            Assert-MockCalled Invoke-WindowsMCPStateTool -Times 1
        }

        It "Should include screenshot when requested" {
            Mock Invoke-WindowsMCPStateTool {
                return @{
                    WindowTitle = "Claude Code"
                    Screenshot = "base64data"
                }
            } -Verifiable

            Mock Get-TodosFromUI { return @{ Total = 0; Completed = 0; Remaining = 0; Items = @() } }
            Mock Get-ErrorsFromUI { return @() }
            Mock Get-WarningsFromUI { return @() }
            Mock Test-ProcessingIndicator { return $false }

            $state = Get-ClaudeCodeState -SessionWindow "test" -IncludeScreenshot

            Assert-MockCalled Invoke-WindowsMCPStateTool -ParameterFilter {
                $UseVision -eq $true
            }
        }

        It "Should return structured state object" {
            Mock Invoke-WindowsMCPStateTool {
                return @{ WindowTitle = "Claude Code" }
            }
            Mock Get-TodosFromUI { return @{ Total = 5; Completed = 2; Remaining = 3; Items = @() } }
            Mock Get-ErrorsFromUI { return @() }
            Mock Get-WarningsFromUI { return @() }
            Mock Test-ProcessingIndicator { return $false }

            $state = Get-ClaudeCodeState -SessionWindow "test"

            $state | Should -Not -BeNullOrEmpty
            $state.SessionId | Should -Not -BeNullOrEmpty
            $state.Status | Should -Not -BeNullOrEmpty
            $state.Todos | Should -Not -BeNullOrEmpty
            $state.Errors | Should -Not -BeNullOrEmpty
        }
    }

    Context "Session ID Extraction" {
        It "Should extract session ID from window title" {
            Mock Invoke-WindowsMCPStateTool {
                return @{
                    WindowTitle = "Claude Code - 01WZQC04Z031XZH13HUUW7VX9A"
                }
            }
            Mock Get-TodosFromUI { return @{ Total = 0; Completed = 0; Remaining = 0; Items = @() } }
            Mock Get-ErrorsFromUI { return @() }
            Mock Get-WarningsFromUI { return @() }
            Mock Test-ProcessingIndicator { return $false }

            $state = Get-ClaudeCodeState -SessionWindow "test"

            $state.SessionId | Should -Be "01WZQC04Z031XZH13HUUW7VX9A"
        }

        It "Should extract session ID from URL bar" {
            Mock Invoke-WindowsMCPStateTool {
                return @{
                    WindowTitle = "Claude Code"
                    InteractiveElements = @(
                        @{
                            Type = "AddressBar"
                            Value = "https://claude.ai/session/01ABCDEFGHIJKLMNOPQRST"
                        }
                    )
                }
            }
            Mock Get-TodosFromUI { return @{ Total = 0; Completed = 0; Remaining = 0; Items = @() } }
            Mock Get-ErrorsFromUI { return @() }
            Mock Get-WarningsFromUI { return @() }
            Mock Test-ProcessingIndicator { return $false }

            $state = Get-ClaudeCodeState -SessionWindow "test"

            $state.SessionId | Should -Be "01ABCDEFGHIJKLMNOPQRST"
        }

        It "Should return placeholder when no session ID found" {
            Mock Invoke-WindowsMCPStateTool {
                return @{ WindowTitle = "Claude Code" }
            }
            Mock Get-TodosFromUI { return @{ Total = 0; Completed = 0; Remaining = 0; Items = @() } }
            Mock Get-ErrorsFromUI { return @() }
            Mock Get-WarningsFromUI { return @() }
            Mock Test-ProcessingIndicator { return $false }

            $state = Get-ClaudeCodeState -SessionWindow "test"

            $state.SessionId | Should -Match "unknown-session-\d{14}"
        }
    }

    Context "Reply Field Detection" {
        It "Should detect reply field by name" {
            Mock Invoke-WindowsMCPStateTool {
                return @{
                    WindowTitle = "Claude Code"
                    InteractiveElements = @(
                        @{
                            Name = "Reply to Claude"
                            Coordinates = @(100, 200)
                            Type = "textbox"
                            Enabled = $true
                        }
                    )
                }
            }
            Mock Get-TodosFromUI { return @{ Total = 0; Completed = 0; Remaining = 0; Items = @() } }
            Mock Get-ErrorsFromUI { return @() }
            Mock Get-WarningsFromUI { return @() }
            Mock Test-ProcessingIndicator { return $false }

            $state = Get-ClaudeCodeState -SessionWindow "test"

            $state.HasReplyField | Should -Be $true
            $state.ReplyFieldCoordinates | Should -Be @(100, 200)
        }

        It "Should detect reply field by placeholder" {
            Mock Invoke-WindowsMCPStateTool {
                return @{
                    WindowTitle = "Claude Code"
                    InteractiveElements = @(
                        @{
                            Name = "Input"
                            Placeholder = "Type a message..."
                            Coordinates = @(150, 250)
                            Type = "textbox"
                        }
                    )
                }
            }
            Mock Get-TodosFromUI { return @{ Total = 0; Completed = 0; Remaining = 0; Items = @() } }
            Mock Get-ErrorsFromUI { return @() }
            Mock Get-WarningsFromUI { return @() }
            Mock Test-ProcessingIndicator { return $false }

            $state = Get-ClaudeCodeState -SessionWindow "test"

            $state.HasReplyField | Should -Be $true
        }

        It "Should detect single text input as reply field" {
            Mock Invoke-WindowsMCPStateTool {
                return @{
                    WindowTitle = "Claude Code"
                    InteractiveElements = @(
                        @{
                            ControlType = "Edit"
                            Coordinates = @(100, 100)
                        }
                    )
                }
            }
            Mock Get-TodosFromUI { return @{ Total = 0; Completed = 0; Remaining = 0; Items = @() } }
            Mock Get-ErrorsFromUI { return @() }
            Mock Get-WarningsFromUI { return @() }
            Mock Test-ProcessingIndicator { return $false }

            $state = Get-ClaudeCodeState -SessionWindow "test"

            $state.HasReplyField | Should -Be $true
        }

        It "Should handle missing reply field" {
            Mock Invoke-WindowsMCPStateTool {
                return @{
                    WindowTitle = "Claude Code"
                    InteractiveElements = @()
                }
            }
            Mock Get-TodosFromUI { return @{ Total = 0; Completed = 0; Remaining = 0; Items = @() } }
            Mock Get-ErrorsFromUI { return @() }
            Mock Get-WarningsFromUI { return @() }
            Mock Test-ProcessingIndicator { return $false }

            $state = Get-ClaudeCodeState -SessionWindow "test"

            $state.HasReplyField | Should -Be $false
            $state.ReplyFieldCoordinates | Should -Be $null
        }
    }

    Context "TODO Parsing" {
        It "Should parse TODOs from UI" {
            Mock Invoke-WindowsMCPStateTool { return @{ WindowTitle = "Claude Code" } }
            Mock Get-TodosFromUI {
                return @{
                    Total = 10
                    Completed = 4
                    Remaining = 6
                    Items = @(
                        @{ Status = "pending"; Content = "Task 1" },
                        @{ Status = "pending"; Content = "Task 2" }
                    )
                }
            } -Verifiable
            Mock Get-ErrorsFromUI { return @() }
            Mock Get-WarningsFromUI { return @() }
            Mock Test-ProcessingIndicator { return $false }

            $state = Get-ClaudeCodeState -SessionWindow "test"

            $state.Todos.Total | Should -Be 10
            $state.Todos.Completed | Should -Be 4
            $state.Todos.Remaining | Should -Be 6
            $state.Todos.Items.Count | Should -Be 2

            Assert-MockCalled Get-TodosFromUI -Times 1
        }
    }

    Context "Error Detection" {
        It "Should detect errors from UI" {
            Mock Invoke-WindowsMCPStateTool { return @{ WindowTitle = "Claude Code" } }
            Mock Get-TodosFromUI { return @{ Total = 0; Completed = 0; Remaining = 0; Items = @() } }
            Mock Get-ErrorsFromUI {
                return @(
                    @{ Message = "TypeError: Cannot read property 'x' of undefined"; Severity = "High" },
                    @{ Message = "Compilation failed"; Severity = "Critical" }
                )
            } -Verifiable
            Mock Get-WarningsFromUI { return @() }
            Mock Test-ProcessingIndicator { return $false }

            $state = Get-ClaudeCodeState -SessionWindow "test"

            $state.Errors.Count | Should -Be 2
            $state.Errors[0].Message | Should -BeLike "*TypeError*"

            Assert-MockCalled Get-ErrorsFromUI -Times 1
        }

        It "Should detect warnings from UI" {
            Mock Invoke-WindowsMCPStateTool { return @{ WindowTitle = "Claude Code" } }
            Mock Get-TodosFromUI { return @{ Total = 0; Completed = 0; Remaining = 0; Items = @() } }
            Mock Get-ErrorsFromUI { return @() }
            Mock Get-WarningsFromUI {
                return @(
                    @{ Message = "Deprecated API usage"; Severity = "Low" }
                )
            } -Verifiable
            Mock Test-ProcessingIndicator { return $false }

            $state = Get-ClaudeCodeState -SessionWindow "test"

            $state.Warnings.Count | Should -Be 1

            Assert-MockCalled Get-WarningsFromUI -Times 1
        }
    }

    Context "Processing Indicator" {
        It "Should detect when Claude is processing" {
            Mock Invoke-WindowsMCPStateTool { return @{ WindowTitle = "Claude Code" } }
            Mock Get-TodosFromUI { return @{ Total = 0; Completed = 0; Remaining = 0; Items = @() } }
            Mock Get-ErrorsFromUI { return @() }
            Mock Get-WarningsFromUI { return @() }
            Mock Test-ProcessingIndicator { return $true } -Verifiable

            $state = Get-ClaudeCodeState -SessionWindow "test"

            $state.IsProcessing | Should -Be $true

            Assert-MockCalled Test-ProcessingIndicator -Times 1
        }

        It "Should detect when Claude is not processing" {
            Mock Invoke-WindowsMCPStateTool { return @{ WindowTitle = "Claude Code" } }
            Mock Get-TodosFromUI { return @{ Total = 0; Completed = 0; Remaining = 0; Items = @() } }
            Mock Get-ErrorsFromUI { return @() }
            Mock Get-WarningsFromUI { return @() }
            Mock Test-ProcessingIndicator { return $false }

            $state = Get-ClaudeCodeState -SessionWindow "test"

            $state.IsProcessing | Should -Be $false
        }
    }

    Context "Error Handling" {
        It "Should throw when Windows MCP fails" {
            Mock Invoke-WindowsMCPStateTool { throw "MCP error" }

            { Get-ClaudeCodeState -SessionWindow "test" } | Should -Throw
        }

        It "Should log error and rethrow" {
            Mock Invoke-WindowsMCPStateTool { throw "Test error" }
            Mock Write-Error {} -Verifiable

            { Get-ClaudeCodeState -SessionWindow "test" } | Should -Throw

            Assert-MockCalled Write-Error -Times 1
        }
    }
}

Describe "Get-SessionStatus" {

    Context "Status Classification" {
        It "Should return 'InProgress' when processing" {
            $state = @{
                IsProcessing = $true
                Errors = @()
                Todos = @{ Remaining = 5; Total = 10 }
                HasReplyField = $true
                IdleTime = [TimeSpan]::Zero
            }

            $status = Get-SessionStatus -ParsedState $state

            $status | Should -Be "InProgress"
        }

        It "Should return 'Error' when errors detected" {
            $state = @{
                IsProcessing = $false
                Errors = @(@{ Message = "Test error" })
                Todos = @{ Remaining = 5; Total = 10 }
                HasReplyField = $true
                IdleTime = [TimeSpan]::Zero
            }

            $status = Get-SessionStatus -ParsedState $state

            $status | Should -Be "Error"
        }

        It "Should return 'HasTodos' when TODOs remaining" {
            $state = @{
                IsProcessing = $false
                Errors = @()
                Todos = @{ Remaining = 5; Total = 10 }
                HasReplyField = $true
                IdleTime = [TimeSpan]::Zero
            }

            $status = Get-SessionStatus -ParsedState $state

            $status | Should -Be "HasTodos"
        }

        It "Should return 'PhaseComplete' when all TODOs done" {
            $state = @{
                IsProcessing = $false
                Errors = @()
                Todos = @{ Remaining = 0; Total = 10 }
                HasReplyField = $true
                IdleTime = [TimeSpan]::Zero
            }

            $status = Get-SessionStatus -ParsedState $state

            $status | Should -Be "PhaseComplete"
        }

        It "Should return 'Idle' when idle time exceeds threshold" {
            $state = @{
                IsProcessing = $false
                Errors = @()
                Todos = @{ Remaining = 0; Total = 0 }
                HasReplyField = $true
                IdleTime = [TimeSpan]::FromMinutes(15)
            }

            $status = Get-SessionStatus -ParsedState $state

            $status | Should -Be "Idle"
        }

        It "Should return 'WaitingForInput' when reply field available" {
            $state = @{
                IsProcessing = $false
                Errors = @()
                Todos = @{ Remaining = 0; Total = 0 }
                HasReplyField = $true
                IdleTime = [TimeSpan]::FromMinutes(5)
            }

            $status = Get-SessionStatus -ParsedState $state

            $status | Should -Be "WaitingForInput"
        }

        It "Should return 'Unknown' when state is unclear" {
            $state = @{
                IsProcessing = $false
                Errors = @()
                Todos = @{ Remaining = 0; Total = 0 }
                HasReplyField = $false
                IdleTime = [TimeSpan]::FromMinutes(5)
            }

            $status = Get-SessionStatus -ParsedState $state

            $status | Should -Be "Unknown"
        }
    }

    Context "Priority Order" {
        It "Should prioritize InProgress over Error" {
            $state = @{
                IsProcessing = $true
                Errors = @(@{ Message = "Error" })
                Todos = @{ Remaining = 5; Total = 10 }
                HasReplyField = $true
                IdleTime = [TimeSpan]::Zero
            }

            $status = Get-SessionStatus -ParsedState $state

            $status | Should -Be "InProgress"
        }

        It "Should prioritize Error over HasTodos" {
            $state = @{
                IsProcessing = $false
                Errors = @(@{ Message = "Error" })
                Todos = @{ Remaining = 5; Total = 10 }
                HasReplyField = $true
                IdleTime = [TimeSpan]::Zero
            }

            $status = Get-SessionStatus -ParsedState $state

            $status | Should -Be "Error"
        }

        It "Should prioritize HasTodos over PhaseComplete" {
            $state = @{
                IsProcessing = $false
                Errors = @()
                Todos = @{ Remaining = 1; Total = 10 }
                HasReplyField = $true
                IdleTime = [TimeSpan]::Zero
            }

            $status = Get-SessionStatus -ParsedState $state

            $status | Should -Be "HasTodos"
        }
    }
}

Describe "Get-SessionIdFromUI" {

    Context "ULID Pattern Matching" {
        It "Should match 26-character ULID" {
            $uiState = @{
                WindowTitle = "Session: 01WZQC04Z031XZH13HUUW7VX9A"
            }

            $sessionId = Get-SessionIdFromUI -UIState $uiState

            $sessionId | Should -Be "01WZQC04Z031XZH13HUUW7VX9A"
        }

        It "Should extract ULID from mixed text" {
            $uiState = @{
                WindowTitle = "Claude Code - Session 01ABCDEFGHIJKLMNOPQRSTUVWX - Active"
            }

            $sessionId = Get-SessionIdFromUI -UIState $uiState

            $sessionId | Should -Be "01ABCDEFGHIJKLMNOPQRSTUVWX"
        }

        It "Should handle case-insensitive ULID" {
            $uiState = @{
                WindowTitle = "01abcdefghijklmnopqrstuvwx"
            }

            $sessionId = Get-SessionIdFromUI -UIState $uiState

            $sessionId.Length | Should -Be 26
        }
    }

    Context "Multiple Sources" {
        It "Should prefer window title over URL" {
            $uiState = @{
                WindowTitle = "01AAAAAAAAAAAAAAAAAAAAAAAA"
                InteractiveElements = @(
                    @{
                        Type = "AddressBar"
                        Value = "https://claude.ai/01BBBBBBBBBBBBBBBBBBBBBBBB"
                    }
                )
            }

            $sessionId = Get-SessionIdFromUI -UIState $uiState

            $sessionId | Should -Be "01AAAAAAAAAAAAAAAAAAAAAAAA"
        }

        It "Should fallback to URL when title has no ID" {
            $uiState = @{
                WindowTitle = "Claude Code"
                InteractiveElements = @(
                    @{
                        Type = "AddressBar"
                        Value = "https://claude.ai/session/01BBBBBBBBBBBBBBBBBBBBBBBB"
                    }
                )
            }

            $sessionId = Get-SessionIdFromUI -UIState $uiState

            $sessionId | Should -Be "01BBBBBBBBBBBBBBBBBBBBBBBB"
        }

        It "Should search informative elements as fallback" {
            $uiState = @{
                WindowTitle = "Claude Code"
                InteractiveElements = @()
                InformativeElements = @(
                    @{ Text = "Session: 01CCCCCCCCCCCCCCCCCCCCCCCC" }
                )
            }

            $sessionId = Get-SessionIdFromUI -UIState $uiState

            $sessionId | Should -Be "01CCCCCCCCCCCCCCCCCCCCCCCC"
        }
    }

    Context "Error Handling" {
        It "Should return placeholder when no ID found" {
            $uiState = @{
                WindowTitle = "Claude Code"
            }

            $sessionId = Get-SessionIdFromUI -UIState $uiState

            $sessionId | Should -Match "unknown-session-\d{14}"
        }

        It "Should return error placeholder on exception" {
            $uiState = $null

            $sessionId = Get-SessionIdFromUI -UIState $uiState

            $sessionId | Should -Be "unknown-session-error"
        }
    }
}

Describe "Find-ReplyField" {

    Context "Field Detection Strategies" {
        It "Should find field by explicit Reply name" {
            $uiState = @{
                InteractiveElements = @(
                    @{
                        Name = "Reply to Claude"
                        Coordinates = @(100, 200)
                        Type = "textbox"
                        Enabled = $true
                    }
                )
            }

            $field = Find-ReplyField -UIState $uiState

            $field | Should -Not -BeNullOrEmpty
            $field.Name | Should -Be "Reply to Claude"
        }

        It "Should find field by Message name" {
            $uiState = @{
                InteractiveElements = @(
                    @{
                        Name = "Message Input"
                        Coordinates = @(150, 250)
                        Type = "textbox"
                    }
                )
            }

            $field = Find-ReplyField -UIState $uiState

            $field | Should -Not -BeNullOrEmpty
        }

        It "Should find field by placeholder text" {
            $uiState = @{
                InteractiveElements = @(
                    @{
                        Name = "Input"
                        Placeholder = "Reply to continue..."
                        Coordinates = @(100, 300)
                    }
                )
            }

            $field = Find-ReplyField -UIState $uiState

            $field | Should -Not -BeNullOrEmpty
        }

        It "Should find single text input" {
            $uiState = @{
                InteractiveElements = @(
                    @{
                        ControlType = "Edit"
                        Coordinates = @(50, 100)
                        State = "Enabled"
                    }
                )
            }

            $field = Find-ReplyField -UIState $uiState

            $field | Should -Not -BeNullOrEmpty
        }

        It "Should select largest text input when multiple exist" {
            $uiState = @{
                InteractiveElements = @(
                    @{
                        ControlType = "Edit"
                        BoundingRectangle = @{ Width = 100; Height = 50 }
                        Coordinates = @(50, 100)
                    },
                    @{
                        ControlType = "Edit"
                        BoundingRectangle = @{ Width = 500; Height = 100 }
                        Coordinates = @(100, 200)
                    }
                )
            }

            $field = Find-ReplyField -UIState $uiState

            $field.Coordinates | Should -Be @(100, 200)
        }

        It "Should find field by bottom position" {
            $uiState = @{
                InteractiveElements = @(
                    @{
                        ControlType = "Edit"
                        Coordinates = @(100, 800)
                    }
                )
            }

            $field = Find-ReplyField -UIState $uiState

            $field | Should -Not -BeNullOrEmpty
        }

        It "Should return null when no field found" {
            $uiState = @{
                InteractiveElements = @()
            }

            $field = Find-ReplyField -UIState $uiState

            $field | Should -Be $null
        }
    }

    Context "Error Handling" {
        It "Should return null when UI state has no interactive elements" {
            $uiState = @{}

            $field = Find-ReplyField -UIState $uiState

            $field | Should -Be $null
        }

        It "Should handle exceptions gracefully" {
            $uiState = $null

            $field = Find-ReplyField -UIState $uiState

            $field | Should -Be $null
        }
    }
}
