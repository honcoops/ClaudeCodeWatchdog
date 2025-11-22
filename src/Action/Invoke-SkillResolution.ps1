<#
.SYNOPSIS
    Skill-based error resolution for Claude Code Watchdog

.DESCRIPTION
    Analyzes errors and invokes appropriate Claude Skills to resolve them

.NOTES
    Part of the Claude Code Watchdog project
    Workstream: WS04 - Action & Execution
    Work Item: WI-2.3 - Skill-Based Error Resolution
#>

# Import dependencies
$ScriptRoot = Split-Path -Parent $PSCommandPath
. "$ScriptRoot/Send-ClaudeCodeCommand.ps1"
. "$ScriptRoot/../Logging/Write-WatchdogLog.ps1"

function Find-SkillForError {
    <#
    .SYNOPSIS
        Finds the most appropriate skill to resolve a given error
    .DESCRIPTION
        Analyzes error messages and matches them to available Claude Skills
        based on error type, category, and severity
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Error,

        [Parameter(Mandatory)]
        [array]$AvailableSkills
    )

    Write-Verbose "Finding skill for error: $($Error.Message)"

    try {
        # Define error-to-skill mapping patterns
        $skillMappings = @{
            'type-error-resolution' = @{
                Patterns = @(
                    'type error', 'type mismatch', 'cannot convert',
                    'incompatible types', 'type.*expected',
                    'nullable reference', 'null reference'
                )
                Categories = @('TypeSystem', 'Compilation')
                Keywords = @('type', 'null', 'nullable', 'reference')
            }
            'compilation-error-resolution' = @{
                Patterns = @(
                    'compilation failed', 'syntax error', 'parse error',
                    'cannot find symbol', 'undeclared identifier',
                    'missing semicolon', 'unexpected token'
                )
                Categories = @('Compilation', 'Syntax')
                Keywords = @('compile', 'syntax', 'parse', 'symbol')
            }
            'lint-error-resolution' = @{
                Patterns = @(
                    'lint', 'linting', 'eslint', 'tslint',
                    'code style', 'formatting', 'indentation'
                )
                Categories = @('Linting', 'CodeQuality')
                Keywords = @('lint', 'style', 'format')
            }
            'test-failure-resolution' = @{
                Patterns = @(
                    'test failed', 'test failure', 'assertion failed',
                    'expected.*but got', 'test.*error'
                )
                Categories = @('Testing', 'Assertion')
                Keywords = @('test', 'assertion', 'expect')
            }
            'api-error-resolution' = @{
                Patterns = @(
                    'api error', 'http error', '404', '500',
                    'request failed', 'network error', 'timeout'
                )
                Categories = @('Network', 'API')
                Keywords = @('api', 'http', 'request', 'network')
            }
            'dependency-resolution' = @{
                Patterns = @(
                    'module not found', 'package not found',
                    'dependency', 'import error', 'cannot resolve'
                )
                Categories = @('Dependencies', 'Import')
                Keywords = @('module', 'package', 'import', 'dependency')
            }
        }

        $errorMessage = $Error.Message.ToLower()
        $errorCategory = $Error.Category
        $bestMatch = $null
        $highestScore = 0

        foreach ($skillName in $skillMappings.Keys) {
            # Check if this skill is available
            $skillPath = $AvailableSkills | Where-Object {
                $_ -match $skillName
            } | Select-Object -First 1

            if (-not $skillPath) {
                continue
            }

            $mapping = $skillMappings[$skillName]
            $score = 0

            # Check pattern matches (highest weight)
            foreach ($pattern in $mapping.Patterns) {
                if ($errorMessage -match $pattern) {
                    $score += 10
                    Write-Verbose "Pattern match for '$pattern': +10 points"
                }
            }

            # Check category matches (medium weight)
            if ($errorCategory -in $mapping.Categories) {
                $score += 5
                Write-Verbose "Category match for '$errorCategory': +5 points"
            }

            # Check keyword matches (low weight)
            foreach ($keyword in $mapping.Keywords) {
                if ($errorMessage -match "\b$keyword\b") {
                    $score += 2
                    Write-Verbose "Keyword match for '$keyword': +2 points"
                }
            }

            if ($score -gt $highestScore) {
                $highestScore = $score
                $bestMatch = @{
                    SkillName = $skillName
                    SkillPath = $skillPath
                    Score = $score
                }
            }
        }

        if ($bestMatch -and $highestScore -ge 10) {
            Write-Verbose "Best skill match: $($bestMatch.SkillName) (score: $highestScore)"
            return $bestMatch
        }
        else {
            Write-Verbose "No suitable skill found for this error (best score: $highestScore)"
            return $null
        }
    }
    catch {
        Write-Error "Error finding skill: $_"
        return $null
    }
}

function Invoke-SkillResolution {
    <#
    .SYNOPSIS
        Invokes a Claude skill to resolve an error
    .DESCRIPTION
        Constructs and sends a skill invocation command to Claude Code
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Error,

        [Parameter(Mandatory)]
        [string]$SkillPath,

        [Parameter(Mandatory)]
        [array]$ReplyFieldCoordinates,

        [Parameter()]
        [hashtable]$ProjectConfig
    )

    Write-Host "🔧 Invoking skill to resolve error..." -ForegroundColor Cyan

    try {
        # Build context for the skill
        $context = Build-SkillContext -Error $Error -ProjectConfig $ProjectConfig

        # Construct skill command
        $skillCommand = Build-SkillCommand -SkillPath $SkillPath -Context $context

        # Log skill invocation
        Write-WatchdogLog -Message "Invoking skill: $SkillPath for error: $($Error.Message)" -Level "Info"

        # Send the skill command
        $result = Send-ClaudeCodeCommand -Command $skillCommand -ReplyFieldCoordinates $ReplyFieldCoordinates

        if ($result) {
            Write-Host "✅ Skill invocation command sent successfully" -ForegroundColor Green

            # Track skill usage
            Track-SkillUsage -SkillPath $SkillPath -Error $Error -ProjectConfig $ProjectConfig

            return @{
                Success = $true
                SkillPath = $SkillPath
                Command = $skillCommand
                Timestamp = Get-Date
            }
        }
        else {
            Write-Warning "Failed to send skill invocation command"
            return @{
                Success = $false
                SkillPath = $SkillPath
                Error = "Command send failed"
            }
        }
    }
    catch {
        Write-Error "Error invoking skill: $_"
        Write-WatchdogLog -Message "Skill invocation failed: $_" -Level "Error"

        return @{
            Success = $false
            SkillPath = $SkillPath
            Error = $_.Exception.Message
        }
    }
}

function Build-SkillContext {
    <#
    .SYNOPSIS
        Builds context information to pass to the skill
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Error,

        [Parameter()]
        [hashtable]$ProjectConfig
    )

    $contextParts = @()

    # Add error message
    $contextParts += "Error: $($Error.Message)"

    # Add error category if available
    if ($Error.Category) {
        $contextParts += "Category: $($Error.Category)"
    }

    # Add severity if available
    if ($Error.Severity) {
        $contextParts += "Severity: $($Error.Severity)"
    }

    # Add file location if available
    if ($Error.Location) {
        $contextParts += "Location: $($Error.Location)"
    }

    # Add project-specific context
    if ($ProjectConfig -and $ProjectConfig.repoPath) {
        $contextParts += "Project: $($ProjectConfig.projectName)"
    }

    return $contextParts -join "; "
}

function Build-SkillCommand {
    <#
    .SYNOPSIS
        Builds the skill invocation command
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SkillPath,

        [Parameter()]
        [string]$Context
    )

    # Extract skill name from path
    $skillName = Split-Path -Leaf $SkillPath

    if ($Context) {
        return "/skill $skillName - $Context"
    }
    else {
        return "/skill $skillName"
    }
}

function Track-SkillUsage {
    <#
    .SYNOPSIS
        Tracks skill usage statistics
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SkillPath,

        [Parameter(Mandatory)]
        [hashtable]$Error,

        [Parameter()]
        [hashtable]$ProjectConfig
    )

    try {
        # Define skill usage log path
        $logPath = if ($ProjectConfig -and $ProjectConfig.repoPath) {
            Join-Path $ProjectConfig.repoPath ".claude-automation/skill-usage.json"
        }
        else {
            Join-Path $env:USERPROFILE ".claude-automation/skill-usage.json"
        }

        # Ensure directory exists
        $logDir = Split-Path -Parent $logPath
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }

        # Load existing usage data
        $usageData = if (Test-Path $logPath) {
            Get-Content $logPath -Raw | ConvertFrom-Json
        }
        else {
            @{
                Skills = @{}
                TotalInvocations = 0
            }
        }

        # Extract skill name
        $skillName = Split-Path -Leaf $SkillPath

        # Update usage statistics
        if (-not $usageData.Skills.$skillName) {
            $usageData.Skills.$skillName = @{
                Path = $SkillPath
                Invocations = 0
                LastUsed = $null
                Errors = @()
            }
        }

        $usageData.Skills.$skillName.Invocations++
        $usageData.Skills.$skillName.LastUsed = (Get-Date).ToString('o')
        $usageData.TotalInvocations++

        # Add error to history (keep last 10)
        if ($usageData.Skills.$skillName.Errors.Count -ge 10) {
            $usageData.Skills.$skillName.Errors = $usageData.Skills.$skillName.Errors[-9..-1]
        }
        $usageData.Skills.$skillName.Errors += @{
            Message = $Error.Message
            Category = $Error.Category
            Timestamp = (Get-Date).ToString('o')
        }

        # Save updated usage data
        $usageData | ConvertTo-Json -Depth 10 | Set-Content $logPath

        Write-Verbose "Skill usage tracked: $skillName"
    }
    catch {
        Write-Verbose "Failed to track skill usage: $_"
    }
}

function Get-SkillUsageStats {
    <#
    .SYNOPSIS
        Retrieves skill usage statistics
    #>
    param(
        [Parameter()]
        [string]$ProjectPath
    )

    try {
        $logPath = if ($ProjectPath) {
            Join-Path $ProjectPath ".claude-automation/skill-usage.json"
        }
        else {
            Join-Path $env:USERPROFILE ".claude-automation/skill-usage.json"
        }

        if (Test-Path $logPath) {
            return Get-Content $logPath -Raw | ConvertFrom-Json
        }
        else {
            return @{
                Skills = @{}
                TotalInvocations = 0
            }
        }
    }
    catch {
        Write-Warning "Failed to retrieve skill usage stats: $_"
        return $null
    }
}

# Export functions
Export-ModuleMember -Function Find-SkillForError, Invoke-SkillResolution,
    Build-SkillContext, Build-SkillCommand, Track-SkillUsage, Get-SkillUsageStats
