<#
.SYNOPSIS
    Detects and classifies Claude Code session state

.DESCRIPTION
    Captures UI state using Windows MCP and classifies the session status

.NOTES
    Part of the Claude Code Watchdog project
    Workstream: WS01 - Core Infrastructure
#>

# Import dependencies
$ScriptRoot = Split-Path -Parent $PSCommandPath
. "$ScriptRoot/../Utils/Invoke-WindowsMCP.ps1"
. "$ScriptRoot/Parse-UIElements.ps1"

function Get-ClaudeCodeState {
    <#
    .SYNOPSIS
        Captures and analyzes Claude Code session state
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SessionWindow,

        [switch]$IncludeScreenshot
    )

    Write-Verbose "Capturing state for session: $SessionWindow"

    try {
        # Capture UI state using Windows MCP
        $uiState = Invoke-WindowsMCPStateTool -UseVision:$IncludeScreenshot

        # Initialize state object
        $state = @{
            SessionId = $null
            Status = "Unknown"
            HasReplyField = $false
            ReplyFieldCoordinates = $null
            Todos = @{
                Total = 0
                Completed = 0
                Remaining = 0
                Items = @()
            }
            Errors = @()
            Warnings = @()
            IsProcessing = $false
            LastActivity = Get-Date
            IdleTime = [TimeSpan]::Zero
            RawUIState = $uiState
        }

        # Parse session ID from URL or window title
        $state.SessionId = Get-SessionIdFromUI -UIState $uiState

        # Detect reply field
        $replyField = Find-ReplyField -UIState $uiState
        if ($replyField) {
            $state.HasReplyField = $true
            $state.ReplyFieldCoordinates = $replyField.Coordinates
        }

        # Parse TODOs
        $state.Todos = Get-TodosFromUI -UIState $uiState

        # Detect errors and warnings
        $state.Errors = Get-ErrorsFromUI -UIState $uiState
        $state.Warnings = Get-WarningsFromUI -UIState $uiState

        # Check if Claude is processing
        $state.IsProcessing = Test-ProcessingIndicator -UIState $uiState

        # Classify overall session status
        $state.Status = Get-SessionStatus -ParsedState $state

        Write-Verbose "Detected state: $($state.Status), TODOs: $($state.Todos.Remaining), Errors: $($state.Errors.Count)"

        return $state
    }
    catch {
        Write-Error "Failed to get Claude Code state: $_"
        throw
    }
}

function Get-SessionStatus {
    <#
    .SYNOPSIS
        Classifies the overall session status based on parsed state
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$ParsedState
    )

    # Priority order for status classification:
    # 1. InProgress (Claude is actively working)
    if ($ParsedState.IsProcessing) {
        return "InProgress"
    }

    # 2. Error (errors detected)
    if ($ParsedState.Errors.Count -gt 0) {
        return "Error"
    }

    # 3. HasTodos (TODOs remaining and can accept input)
    if ($ParsedState.Todos.Remaining -gt 0 -and $ParsedState.HasReplyField) {
        return "HasTodos"
    }

    # 4. PhaseComplete (all TODOs done, ready for next phase)
    if ($ParsedState.Todos.Remaining -eq 0 -and $ParsedState.Todos.Total -gt 0 -and $ParsedState.HasReplyField) {
        return "PhaseComplete"
    }

    # 5. Idle (no activity for extended period)
    if ($ParsedState.IdleTime.TotalMinutes -gt 10) {
        return "Idle"
    }

    # 6. WaitingForInput (reply field available)
    if ($ParsedState.HasReplyField) {
        return "WaitingForInput"
    }

    # Default
    return "Unknown"
}

function Get-SessionIdFromUI {
    <#
    .SYNOPSIS
        Extracts session ID from UI state
    #>
    param(
        [Parameter(Mandatory)]
        [object]$UIState
    )

    # TODO: Parse session ID from URL bar or window title
    # Look for patterns like: 01WZQC04Z031XZH13huuW7Vx

    return "unknown-session"
}

function Find-ReplyField {
    <#
    .SYNOPSIS
        Locates the reply input field in the UI
    #>
    param(
        [Parameter(Mandatory)]
        [object]$UIState
    )

    # TODO: Find interactive elements that match reply field patterns
    # Look for EditBox, TextBox, or elements with name containing "Reply"

    return $null
}

# Export functions
Export-ModuleMember -Function Get-ClaudeCodeState, Get-SessionStatus
