<#
.SYNOPSIS
    Sends commands to Claude Code sessions

.DESCRIPTION
    Executes commands in Claude Code using Windows MCP with retry logic

.NOTES
    Part of the Claude Code Watchdog project
    Workstream: WS01 - Core Infrastructure
#>

# Import dependencies
$ScriptRoot = Split-Path -Parent $PSCommandPath
. "$ScriptRoot/../Utils/Invoke-WindowsMCP.ps1"
. "$ScriptRoot/Verify-CommandSent.ps1"
. "$ScriptRoot/../Logging/Write-WatchdogLog.ps1"

function Send-ClaudeCodeCommand {
    <#
    .SYNOPSIS
        Sends a command to Claude Code session with retry logic
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Command,

        [Parameter(Mandatory)]
        [array]$ReplyFieldCoordinates,

        [Parameter()]
        [int]$MaxRetries = 3,

        [Parameter()]
        [int]$RetryDelaySeconds = 2
    )

    Write-Verbose "Sending command to Claude Code: $Command"

    $attempt = 0
    $success = $false

    while ($attempt -lt $MaxRetries -and -not $success) {
        $attempt++

        try {
            Write-Verbose "Attempt $attempt of $MaxRetries"

            # Step 1: Click on reply field
            Write-Verbose "Clicking reply field at coordinates: $ReplyFieldCoordinates"
            Invoke-WindowsMCPClick -Coordinates $ReplyFieldCoordinates -Button "left" -Clicks 1

            Start-Sleep -Milliseconds 500

            # Step 2: Clear any existing text (Ctrl+A, Delete)
            Invoke-WindowsMCPKey -Key "ctrl+a"
            Start-Sleep -Milliseconds 200
            Invoke-WindowsMCPKey -Key "delete"
            Start-Sleep -Milliseconds 200

            # Step 3: Type the command
            Write-Verbose "Typing command text"
            Invoke-WindowsMCPType -Coordinates $ReplyFieldCoordinates -Text $Command -Clear $false

            Start-Sleep -Milliseconds 500

            # Step 4: Press Enter to send
            Write-Verbose "Pressing Enter to send"
            Invoke-WindowsMCPKey -Key "enter"

            Start-Sleep -Milliseconds 1000

            # Step 5: Verify command was sent
            $verified = Verify-CommandSent -Command $Command

            if ($verified) {
                $success = $true
                Write-Host "✅ Command sent successfully: $Command" -ForegroundColor Green
                Write-WatchdogLog -Message "Command sent: $Command" -Level "Info"
            }
            else {
                Write-Warning "Command verification failed on attempt $attempt"

                if ($attempt -lt $MaxRetries) {
                    Write-Verbose "Retrying in $RetryDelaySeconds seconds..."
                    Start-Sleep -Seconds $RetryDelaySeconds
                    $RetryDelaySeconds *= 2  # Exponential backoff
                }
            }
        }
        catch {
            Write-Warning "Error sending command on attempt $attempt : $_"

            if ($attempt -lt $MaxRetries) {
                Write-Verbose "Retrying in $RetryDelaySeconds seconds..."
                Start-Sleep -Seconds $RetryDelaySeconds
                $RetryDelaySeconds *= 2
            }
        }
    }

    if (-not $success) {
        $errorMsg = "Failed to send command after $MaxRetries attempts: $Command"
        Write-Error $errorMsg
        Write-WatchdogLog -Message $errorMsg -Level "Error"
        throw $errorMsg
    }

    return $success
}

function Send-SkillCommand {
    <#
    .SYNOPSIS
        Sends a skill invocation command to Claude Code
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SkillPath,

        [Parameter(Mandatory)]
        [array]$ReplyFieldCoordinates,

        [Parameter()]
        [string]$Context = ""
    )

    # Construct skill command
    $command = if ($Context) {
        "Use skill: $SkillPath with context: $Context"
    }
    else {
        "Use skill: $SkillPath"
    }

    return Send-ClaudeCodeCommand -Command $command -ReplyFieldCoordinates $ReplyFieldCoordinates
}

# Export functions
Export-ModuleMember -Function Send-ClaudeCodeCommand, Send-SkillCommand
