<#
.SYNOPSIS
    API configuration management for Claude Code Watchdog

.DESCRIPTION
    Manages Claude API configuration including:
    - API key storage and retrieval
    - Cost tracking and limits
    - Model configuration
    - Usage statistics

.NOTES
    Part of the Claude Code Watchdog project
    Workstream: WS03 - Decision Engine
    Work Item: WI-2.7 - API Configuration Management
#>

function Set-ClaudeAPIKey {
    <#
    .SYNOPSIS
        Securely stores the Claude API key

    .DESCRIPTION
        Stores the Anthropic Claude API key in an encrypted file for secure access.
        The key is encrypted using Windows Data Protection API (DPAPI).

    .PARAMETER APIKey
        The Anthropic Claude API key to store

    .PARAMETER Force
        Overwrite existing API key without prompting

    .EXAMPLE
        Set-ClaudeAPIKey -APIKey "sk-ant-api03-..."

    .EXAMPLE
        Set-ClaudeAPIKey -APIKey $key -Force
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$APIKey,

        [Parameter()]
        [switch]$Force
    )

    try {
        # Validate API key format
        if ($APIKey -notmatch '^sk-ant-') {
            Write-Error "Invalid API key format. Anthropic API keys start with 'sk-ant-'"
            return $false
        }

        # Create config directory
        $configDir = Join-Path $env:USERPROFILE ".claude-automation"
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }

        $keyPath = Join-Path $configDir "api-key.encrypted"

        # Check if key already exists
        if ((Test-Path $keyPath) -and -not $Force) {
            $response = Read-Host "API key already exists. Overwrite? (y/n)"
            if ($response -ne 'y') {
                Write-Host "Operation cancelled."
                return $false
            }
        }

        # Encrypt and save the API key
        $secureString = ConvertTo-SecureString $APIKey -AsPlainText -Force
        $encryptedKey = $secureString | ConvertFrom-SecureString

        Set-Content -Path $keyPath -Value $encryptedKey -Force

        Write-Host "✅ Claude API key stored successfully." -ForegroundColor Green
        Write-Verbose "API key saved to: $keyPath"

        return $true
    }
    catch {
        Write-Error "Failed to store API key: $_"
        return $false
    }
}

function Remove-ClaudeAPIKey {
    <#
    .SYNOPSIS
        Removes the stored Claude API key

    .DESCRIPTION
        Securely deletes the encrypted API key file

    .PARAMETER Confirm
        Prompt for confirmation before deleting

    .EXAMPLE
        Remove-ClaudeAPIKey -Confirm:$false
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [bool]$Confirm = $true
    )

    try {
        $keyPath = Join-Path $env:USERPROFILE ".claude-automation/api-key.encrypted"

        if (-not (Test-Path $keyPath)) {
            Write-Host "No API key found to remove."
            return $true
        }

        if ($Confirm) {
            $response = Read-Host "Are you sure you want to remove the stored API key? (y/n)"
            if ($response -ne 'y') {
                Write-Host "Operation cancelled."
                return $false
            }
        }

        Remove-Item -Path $keyPath -Force
        Write-Host "✅ API key removed successfully." -ForegroundColor Green

        return $true
    }
    catch {
        Write-Error "Failed to remove API key: $_"
        return $false
    }
}

function Test-ClaudeAPIKey {
    <#
    .SYNOPSIS
        Tests if the Claude API key is valid

    .DESCRIPTION
        Makes a test API call to verify the key works

    .EXAMPLE
        Test-ClaudeAPIKey

    .OUTPUTS
        Boolean indicating if the API key is valid
    #>
    [CmdletBinding()]
    param()

    try {
        $apiKey = Get-ClaudeAPIKey
        if (-not $apiKey) {
            Write-Host "❌ No API key configured." -ForegroundColor Red
            return $false
        }

        Write-Host "Testing API key..." -ForegroundColor Cyan

        $headers = @{
            "x-api-key" = $apiKey
            "anthropic-version" = "2023-06-01"
            "content-type" = "application/json"
        }

        $body = @{
            model = "claude-3-haiku-20240307"  # Use cheapest model for testing
            max_tokens = 10
            messages = @(
                @{
                    role = "user"
                    content = "Say 'test'"
                }
            )
        } | ConvertTo-Json -Depth 10

        $response = Invoke-RestMethod -Uri "https://api.anthropic.com/v1/messages" `
            -Method Post `
            -Headers $headers `
            -Body $body `
            -TimeoutSec 10

        if ($response.content) {
            Write-Host "✅ API key is valid!" -ForegroundColor Green
            Write-Verbose "API response: $($response.content[0].text)"
            return $true
        }
        else {
            Write-Host "❌ Unexpected API response." -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "❌ API key validation failed: $_" -ForegroundColor Red
        return $false
    }
}

function Get-APICostSummary {
    <#
    .SYNOPSIS
        Retrieves API cost summary

    .DESCRIPTION
        Gets daily, weekly, and monthly API costs with breakdown by project

    .PARAMETER Days
        Number of days to include in summary (default: 7)

    .EXAMPLE
        Get-APICostSummary -Days 30
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$Days = 7
    )

    try {
        $costsPath = Join-Path $env:USERPROFILE ".claude-automation/api-costs.json"

        if (-not (Test-Path $costsPath)) {
            Write-Host "No API costs recorded yet." -ForegroundColor Yellow
            return @{
                TotalCost = 0.0
                TotalTokens = 0
                TotalDecisions = 0
                DailyCosts = @{}
            }
        }

        $costs = Get-Content $costsPath -Raw | ConvertFrom-Json -AsHashtable

        # Calculate totals for the period
        $cutoffDate = (Get-Date).AddDays(-$Days).ToString("yyyy-MM-dd")
        $totalCost = 0.0
        $totalTokens = 0
        $totalDecisions = 0
        $projectCosts = @{}

        foreach ($day in $costs.daily_costs.Keys) {
            if ($day -ge $cutoffDate) {
                $dailyData = $costs.daily_costs[$day]
                $totalCost += $dailyData.total_cost
                $totalTokens += $dailyData.total_tokens
                $totalDecisions += $dailyData.decision_count

                # Aggregate by project
                foreach ($project in $dailyData.projects.Keys) {
                    if (-not $projectCosts.ContainsKey($project)) {
                        $projectCosts[$project] = @{
                            Cost = 0.0
                            Tokens = 0
                            Decisions = 0
                        }
                    }
                    $projectCosts[$project].Cost += $dailyData.projects[$project].cost
                    $projectCosts[$project].Tokens += $dailyData.projects[$project].tokens
                    $projectCosts[$project].Decisions += $dailyData.projects[$project].decisions
                }
            }
        }

        $summary = @{
            Period = "$Days days"
            TotalCost = [math]::Round($totalCost, 4)
            TotalTokens = $totalTokens
            TotalDecisions = $totalDecisions
            AverageCostPerDecision = if ($totalDecisions -gt 0) { [math]::Round($totalCost / $totalDecisions, 4) } else { 0.0 }
            ProjectBreakdown = $projectCosts
            DailyCosts = $costs.daily_costs
        }

        return $summary
    }
    catch {
        Write-Error "Failed to get cost summary: $_"
        return $null
    }
}

function Show-APICostSummary {
    <#
    .SYNOPSIS
        Displays API cost summary in a formatted table

    .PARAMETER Days
        Number of days to include in summary (default: 7)

    .EXAMPLE
        Show-APICostSummary -Days 30
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$Days = 7
    )

    $summary = Get-APICostSummary -Days $Days

    if (-not $summary) {
        return
    }

    Write-Host "`n=== Claude API Cost Summary ($($summary.Period)) ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Total Cost:                 `$$($summary.TotalCost)" -ForegroundColor Green
    Write-Host "Total Tokens:               $($summary.TotalTokens)" -ForegroundColor White
    Write-Host "Total Decisions:            $($summary.TotalDecisions)" -ForegroundColor White
    Write-Host "Avg Cost per Decision:      `$$($summary.AverageCostPerDecision)" -ForegroundColor Yellow
    Write-Host ""

    if ($summary.ProjectBreakdown.Count -gt 0) {
        Write-Host "=== Cost by Project ===" -ForegroundColor Cyan
        $projectTable = $summary.ProjectBreakdown.GetEnumerator() | ForEach-Object {
            [PSCustomObject]@{
                Project = $_.Key
                Cost = "`$$([math]::Round($_.Value.Cost, 4))"
                Tokens = $_.Value.Tokens
                Decisions = $_.Value.Decisions
            }
        } | Sort-Object { [double]($_.Cost -replace '\$', '') } -Descending

        $projectTable | Format-Table -AutoSize
    }

    # Load config to show limits
    $config = Get-WatchdogConfig
    if ($config -and $config.api) {
        Write-Host "=== API Limits ===" -ForegroundColor Cyan
        Write-Host "Daily Limit:                `$$($config.api.dailyCostLimit)" -ForegroundColor White
        Write-Host "Weekly Limit:               `$$($config.api.weeklyCostLimit)" -ForegroundColor White

        # Calculate daily average
        $today = Get-Date -Format "yyyy-MM-dd"
        $todayCost = if ($summary.DailyCosts.$today) { $summary.DailyCosts.$today.total_cost } else { 0.0 }

        if ($todayCost -ge $config.api.dailyCostLimit) {
            Write-Host "⚠ WARNING: Daily limit reached!" -ForegroundColor Red
        }
        Write-Host "Today's Cost:               `$$([math]::Round($todayCost, 4))" -ForegroundColor $(if ($todayCost -ge $config.api.dailyCostLimit) { "Red" } else { "Green" })
    }
}

function Reset-APICosts {
    <#
    .SYNOPSIS
        Resets API cost tracking

    .DESCRIPTION
        Clears all recorded API costs. Use with caution.

    .PARAMETER Confirm
        Prompt for confirmation before resetting

    .EXAMPLE
        Reset-APICosts
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [bool]$Confirm = $true
    )

    try {
        if ($Confirm) {
            $response = Read-Host "Are you sure you want to reset all API cost tracking? (y/n)"
            if ($response -ne 'y') {
                Write-Host "Operation cancelled."
                return $false
            }
        }

        $costsPath = Join-Path $env:USERPROFILE ".claude-automation/api-costs.json"

        if (Test-Path $costsPath) {
            Remove-Item -Path $costsPath -Force
        }

        Write-Host "✅ API costs reset successfully." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to reset API costs: $_"
        return $false
    }
}

function Set-APICostLimits {
    <#
    .SYNOPSIS
        Updates API cost limits in the global configuration

    .PARAMETER DailyLimit
        Daily cost limit in USD

    .PARAMETER WeeklyLimit
        Weekly cost limit in USD

    .EXAMPLE
        Set-APICostLimits -DailyLimit 10.00 -WeeklyLimit 50.00
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [double]$DailyLimit,

        [Parameter()]
        [double]$WeeklyLimit
    )

    try {
        $configPath = Join-Path (Split-Path $PSScriptRoot -Parent) "../config/watchdog-config.json"

        if (-not (Test-Path $configPath)) {
            Write-Error "Watchdog configuration file not found: $configPath"
            return $false
        }

        $config = Get-Content $configPath -Raw | ConvertFrom-Json -AsHashtable

        if ($PSBoundParameters.ContainsKey('DailyLimit')) {
            $config.api.dailyCostLimit = $DailyLimit
            Write-Host "Daily cost limit updated to: `$$DailyLimit" -ForegroundColor Green
        }

        if ($PSBoundParameters.ContainsKey('WeeklyLimit')) {
            $config.api.weeklyCostLimit = $WeeklyLimit
            Write-Host "Weekly cost limit updated to: `$$WeeklyLimit" -ForegroundColor Green
        }

        # Save updated config
        $config | ConvertTo-Json -Depth 10 | Set-Content $configPath

        Write-Host "✅ Cost limits updated successfully." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to update cost limits: $_"
        return $false
    }
}

function Enable-ClaudeAPI {
    <#
    .SYNOPSIS
        Enables Claude API usage in the global configuration

    .EXAMPLE
        Enable-ClaudeAPI
    #>
    [CmdletBinding()]
    param()

    try {
        $configPath = Join-Path (Split-Path $PSScriptRoot -Parent) "../config/watchdog-config.json"
        $config = Get-Content $configPath -Raw | ConvertFrom-Json -AsHashtable

        $config.api.enabled = $true

        $config | ConvertTo-Json -Depth 10 | Set-Content $configPath

        Write-Host "✅ Claude API enabled." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to enable API: $_"
        return $false
    }
}

function Disable-ClaudeAPI {
    <#
    .SYNOPSIS
        Disables Claude API usage (falls back to rule-based decisions)

    .EXAMPLE
        Disable-ClaudeAPI
    #>
    [CmdletBinding()]
    param()

    try {
        $configPath = Join-Path (Split-Path $PSScriptRoot -Parent) "../config/watchdog-config.json"
        $config = Get-Content $configPath -Raw | ConvertFrom-Json -AsHashtable

        $config.api.enabled = $false

        $config | ConvertTo-Json -Depth 10 | Set-Content $configPath

        Write-Host "✅ Claude API disabled. Will use rule-based decisions." -ForegroundColor Yellow
        return $true
    }
    catch {
        Write-Error "Failed to disable API: $_"
        return $false
    }
}

# Export functions
Export-ModuleMember -Function Set-ClaudeAPIKey, Remove-ClaudeAPIKey, Test-ClaudeAPIKey, `
    Get-APICostSummary, Show-APICostSummary, Reset-APICosts, Set-APICostLimits, `
    Enable-ClaudeAPI, Disable-ClaudeAPI
