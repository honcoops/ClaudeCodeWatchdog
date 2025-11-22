<#
.SYNOPSIS
    Verifies that a command was successfully sent to Claude Code

.DESCRIPTION
    Checks the UI to confirm command was received

.NOTES
    Part of the Claude Code Watchdog project
    Workstream: WS01 - Core Infrastructure
#>

# Import dependencies
$ScriptRoot = Split-Path -Parent $PSCommandPath
. "$ScriptRoot/../Utils/Invoke-WindowsMCP.ps1"

function Verify-CommandSent {
    <#
    .SYNOPSIS
        Verifies that command was successfully sent
    .DESCRIPTION
        Checks multiple indicators to confirm command was received by Claude Code:
        1. Reply field is empty (command was submitted)
        2. Processing indicator appeared
        3. Command text visible in message history
        4. Reply field is disabled (Claude is processing)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Command,

        [Parameter()]
        [int]$TimeoutSeconds = 5
    )

    Write-Verbose "Verifying command was sent: $Command"

    try {
        # Wait a moment for UI to update
        Start-Sleep -Milliseconds 500

        # Capture current UI state
        $uiState = Invoke-WindowsMCPStateTool

        if (-not $uiState) {
            Write-Warning "Could not capture UI state for verification"
            return $false
        }

        $verificationScore = 0
        $maxScore = 4

        # Check 1: Reply field is empty or disabled
        $replyFieldEmpty = Test-ReplyFieldEmpty -UIState $uiState
        if ($replyFieldEmpty) {
            Write-Verbose "✓ Reply field is empty/disabled"
            $verificationScore++
        }

        # Check 2: Processing indicator is present
        $isProcessing = Test-ProcessingIndicatorPresent -UIState $uiState
        if ($isProcessing) {
            Write-Verbose "✓ Processing indicator detected"
            $verificationScore++
        }

        # Check 3: Command appears in recent message history
        $commandInHistory = Test-CommandInHistory -UIState $uiState -Command $Command
        if ($commandInHistory) {
            Write-Verbose "✓ Command found in message history"
            $verificationScore++
        }

        # Check 4: No error indicators immediately visible
        $noErrors = -not (Test-ErrorIndicatorsPresent -UIState $uiState)
        if ($noErrors) {
            Write-Verbose "✓ No immediate errors detected"
            $verificationScore++
        }

        # Require at least 2 out of 4 checks to pass
        $threshold = 2
        $verified = $verificationScore -ge $threshold

        if ($verified) {
            Write-Verbose "Command verification passed ($verificationScore/$maxScore checks)"
        }
        else {
            Write-Warning "Command verification failed ($verificationScore/$maxScore checks, needed $threshold)"
        }

        return $verified
    }
    catch {
        Write-Error "Failed to verify command: $_"
        return $false
    }
}

function Test-ReplyFieldEmpty {
    <#
    .SYNOPSIS
        Checks if the reply field is empty (indicating command was sent)
    .DESCRIPTION
        Looks for text input fields and checks if they're empty or disabled
    #>
    param(
        [Parameter(Mandatory)]
        [object]$UIState
    )

    try {
        if (-not $UIState.elements) {
            return $false
        }

        # Find reply/message input fields
        $replyFields = $UIState.elements | Where-Object {
            $_.controlType -match 'Edit|TextBox|Input' -and
            ($_.name -match 'Reply|Message|Input|Text' -or
             $_.role -match 'textbox|searchbox')
        }

        if (-not $replyFields) {
            Write-Verbose "No reply field found in UI state"
            return $false
        }

        # Check if any reply field is empty or disabled
        foreach ($field in $replyFields) {
            # Empty if no value/text or if disabled (Claude processing)
            if (([string]::IsNullOrWhiteSpace($field.value) -and
                 [string]::IsNullOrWhiteSpace($field.text)) -or
                $field.isEnabled -eq $false -or
                $field.state -match 'disabled|readonly') {
                Write-Verbose "Reply field is empty or disabled"
                return $true
            }
        }

        return $false
    }
    catch {
        Write-Verbose "Error checking reply field: $_"
        return $false
    }
}

function Test-ProcessingIndicatorPresent {
    <#
    .SYNOPSIS
        Checks if Claude Code is showing processing indicators
    #>
    param(
        [Parameter(Mandatory)]
        [object]$UIState
    )

    try {
        if (-not $UIState.elements) {
            return $false
        }

        # Check for processing indicators
        $processingPatterns = @(
            'thinking', 'processing', 'working', 'executing',
            'running', 'analyzing', 'generating', 'streaming',
            'tool use in progress', 'invoking tool'
        )

        foreach ($element in $UIState.elements) {
            $text = "$($element.name) $($element.value) $($element.text)".ToLower()

            foreach ($pattern in $processingPatterns) {
                if ($text -match $pattern) {
                    Write-Verbose "Processing indicator found: $pattern"
                    return $true
                }
            }

            # Check for progress bars or spinners
            if ($element.controlType -match 'ProgressBar|Spinner' -or
                $element.className -match 'spinner|loader|progress') {
                Write-Verbose "Visual processing indicator found"
                return $true
            }
        }

        return $false
    }
    catch {
        Write-Verbose "Error checking processing indicators: $_"
        return $false
    }
}

function Test-CommandInHistory {
    <#
    .SYNOPSIS
        Checks if the command text appears in the recent message history
    #>
    param(
        [Parameter(Mandatory)]
        [object]$UIState,

        [Parameter(Mandatory)]
        [string]$Command
    )

    try {
        if (-not $UIState.elements) {
            return $false
        }

        # Normalize command for comparison
        $normalizedCommand = $Command.Trim().ToLower()

        # Check text elements for command content
        foreach ($element in $UIState.elements) {
            if ($element.controlType -match 'Text|Document|Pane') {
                $text = "$($element.name) $($element.value) $($element.text)".ToLower()

                # Check if command text appears in the element
                if ($text -match [regex]::Escape($normalizedCommand)) {
                    Write-Verbose "Command found in UI element: $($element.name)"
                    return $true
                }

                # Also check for partial matches (first 20 chars)
                if ($normalizedCommand.Length -gt 20) {
                    $commandPrefix = $normalizedCommand.Substring(0, 20)
                    if ($text -match [regex]::Escape($commandPrefix)) {
                        Write-Verbose "Command prefix found in UI"
                        return $true
                    }
                }
            }
        }

        return $false
    }
    catch {
        Write-Verbose "Error checking command in history: $_"
        return $false
    }
}

function Test-ErrorIndicatorsPresent {
    <#
    .SYNOPSIS
        Checks if error indicators are immediately visible after command send
    #>
    param(
        [Parameter(Mandatory)]
        [object]$UIState
    )

    try {
        if (-not $UIState.elements) {
            return $false
        }

        # Check for immediate error patterns
        $errorPatterns = @(
            'command failed', 'failed to send', 'network error',
            'connection lost', 'timeout', 'rate limit'
        )

        foreach ($element in $UIState.elements) {
            $text = "$($element.name) $($element.value) $($element.text)".ToLower()

            foreach ($pattern in $errorPatterns) {
                if ($text -match $pattern) {
                    Write-Warning "Error indicator found: $pattern"
                    return $true
                }
            }

            # Check for error styling
            if ($element.className -match 'error|alert|danger' -and
                $element.isVisible -eq $true) {
                Write-Warning "Visual error indicator found"
                return $true
            }
        }

        return $false
    }
    catch {
        Write-Verbose "Error checking error indicators: $_"
        return $false
    }
}

# Export functions
Export-ModuleMember -Function Verify-CommandSent, Test-ReplyFieldEmpty,
    Test-ProcessingIndicatorPresent, Test-CommandInHistory, Test-ErrorIndicatorsPresent
