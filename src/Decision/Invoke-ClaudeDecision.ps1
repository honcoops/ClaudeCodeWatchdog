<#
.SYNOPSIS
    Claude API-powered decision engine for Claude Code Watchdog

.DESCRIPTION
    Makes intelligent decisions about what action to take using the Claude API.
    Falls back to rule-based decisions if API is unavailable or over budget.

.NOTES
    Part of the Claude Code Watchdog project
    Workstream: WS03 - Decision Engine
    Work Items: WI-2.1 (Claude API Integration), WI-2.2 (Advanced Decision Engine)
#>

function Invoke-ClaudeDecision {
    <#
    .SYNOPSIS
        Makes an API-powered intelligent decision about what action to take

    .DESCRIPTION
        Uses the Claude API to make context-aware decisions about:
        - Whether to continue with TODOs
        - Which skill to use for errors
        - When to transition phases
        - When to request human intervention

        Falls back to rule-based decisions if:
        - API is disabled
        - API key not configured
        - Daily/weekly cost limit exceeded
        - API request fails

    .PARAMETER SessionState
        The current state of the Claude Code session (from Get-ClaudeCodeState)

    .PARAMETER ProjectConfig
        The project configuration object (from Get-RegisteredProjects)

    .PARAMETER DecisionHistory
        Array of recent decisions for context

    .PARAMETER GlobalConfig
        Global watchdog configuration (contains API settings)

    .OUTPUTS
        Hashtable containing:
        - Action: The action to take
        - Command: The specific command to send
        - Reasoning: Claude's explanation
        - Confidence: Float 0.0-1.0
        - Timestamp: ISO 8601 timestamp
        - DecisionMethod: "claude-api" or "rule-based" (if fallback)
        - SkillToUse: Skill path if applicable
        - Metadata: API usage stats, cost, etc.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$SessionState,

        [Parameter(Mandatory)]
        [object]$ProjectConfig,

        [Parameter()]
        [array]$DecisionHistory = @(),

        [Parameter()]
        [object]$GlobalConfig = $null
    )

    Write-Verbose "Attempting Claude API decision for status: $($SessionState.Status)"

    # Load global config if not provided
    if (-not $GlobalConfig) {
        $GlobalConfig = Get-WatchdogConfig
    }

    # Check if API is enabled
    if (-not $GlobalConfig.api.enabled) {
        Write-Verbose "Claude API disabled. Falling back to rule-based decision."
        return Invoke-SimpleDecision -SessionState $SessionState -ProjectConfig $ProjectConfig -DecisionHistory $DecisionHistory -GlobalConfig $GlobalConfig
    }

    # Check API key
    $apiKey = Get-ClaudeAPIKey
    if (-not $apiKey) {
        Write-Warning "Claude API key not configured. Falling back to rule-based decision."
        return Invoke-SimpleDecision -SessionState $SessionState -ProjectConfig $ProjectConfig -DecisionHistory $DecisionHistory -GlobalConfig $GlobalConfig
    }

    # Check cost limits
    $costCheck = Test-APICostLimits -GlobalConfig $GlobalConfig
    if (-not $costCheck.CanProceed) {
        Write-Warning "API cost limit exceeded: $($costCheck.Reason). Falling back to rule-based decision."
        return Invoke-SimpleDecision -SessionState $SessionState -ProjectConfig $ProjectConfig -DecisionHistory $DecisionHistory -GlobalConfig $GlobalConfig
    }

    # Build the decision prompt
    $prompt = Build-DecisionPrompt -SessionState $SessionState -ProjectConfig $ProjectConfig -DecisionHistory $DecisionHistory

    try {
        # Call Claude API
        Write-Verbose "Calling Claude API for decision..."
        $apiResponse = Invoke-ClaudeAPI -Prompt $prompt -APIKey $apiKey -Config $GlobalConfig.api

        # Parse and validate the response
        $decision = Parse-ClaudeDecisionResponse -Response $apiResponse -SessionState $SessionState

        # Add metadata
        $decision.DecisionMethod = "claude-api"
        $decision.Metadata = @{
            SessionStatus = $SessionState.Status
            TodosRemaining = $SessionState.Todos.Remaining
            ErrorCount = $SessionState.Errors.Count
            IsProcessing = $SessionState.IsProcessing
            TokensUsed = $apiResponse.usage.input_tokens + $apiResponse.usage.output_tokens
            CostEstimate = Calculate-APICost -Usage $apiResponse.usage -Model $GlobalConfig.api.model
            Model = $GlobalConfig.api.model
            APIResponseTime = $apiResponse.ResponseTime
        }

        # Log the API usage
        Add-APIUsageLog -Decision $decision -ProjectName $ProjectConfig.projectName

        Write-Verbose "Claude API decision: Action='$($decision.Action)', Confidence=$($decision.Confidence), Cost=$($decision.Metadata.CostEstimate)"

        return $decision
    }
    catch {
        Write-Warning "Claude API call failed: $_. Falling back to rule-based decision."
        return Invoke-SimpleDecision -SessionState $SessionState -ProjectConfig $ProjectConfig -DecisionHistory $DecisionHistory -GlobalConfig $GlobalConfig
    }
}

function Build-DecisionPrompt {
    <#
    .SYNOPSIS
        Builds the prompt for Claude API decision-making
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$SessionState,

        [Parameter(Mandatory)]
        [object]$ProjectConfig,

        [Parameter()]
        [array]$DecisionHistory = @()
    )

    # Build context from recent decisions
    $recentDecisionsText = ""
    if ($DecisionHistory.Count -gt 0) {
        $recentDecisionsText = "`n## Recent Decisions (last 5)`n"
        $last5 = $DecisionHistory | Select-Object -Last 5
        foreach ($dec in $last5) {
            $recentDecisionsText += "- $($dec.Timestamp): $($dec.Action) - $($dec.Reasoning)`n"
        }
    }

    # Build error context
    $errorContext = ""
    if ($SessionState.Errors.Count -gt 0) {
        $errorContext = "`n## Detected Errors`n"
        foreach ($error in $SessionState.Errors) {
            $errorContext += "- **Severity**: $($error.Severity), **Category**: $($error.Category)`n"
            $errorContext += "  **Message**: $($error.Message)`n"
        }
    }

    # Build TODO context
    $todoContext = "`n## TODOs`n"
    $todoContext += "- **Total**: $($SessionState.Todos.Total)`n"
    $todoContext += "- **Completed**: $($SessionState.Todos.Completed)`n"
    $todoContext += "- **Remaining**: $($SessionState.Todos.Remaining)`n"
    if ($SessionState.Todos.Items.Count -gt 0) {
        $todoContext += "`n**Next TODOs**:`n"
        $nextTodos = $SessionState.Todos.Items | Where-Object { $_.Status -ne "completed" } | Select-Object -First 3
        foreach ($todo in $nextTodos) {
            $todoContext += "- [$($todo.Status)] $($todo.Content)`n"
        }
    }

    # Build available skills context
    $skillsContext = "`n## Available Skills`n"
    if ($ProjectConfig.skills -and $ProjectConfig.skills.Count -gt 0) {
        foreach ($skill in $ProjectConfig.skills) {
            $skillName = Split-Path $skill -Leaf
            $skillsContext += "- `$skill` - Path: $skill`n"
        }
    }
    else {
        $skillsContext += "- No skills configured`n"
    }

    # Build human-in-loop context
    $humanLoopContext = "`n## Human-in-Loop Configuration`n"
    if ($ProjectConfig.humanInLoop.requiresApprovalFor) {
        $humanLoopContext += "**Requires approval for**: " + ($ProjectConfig.humanInLoop.requiresApprovalFor -join ", ") + "`n"
    }
    if ($ProjectConfig.humanInLoop.requiresHumanAfter) {
        $humanLoopContext += "**Requires human after**: " + ($ProjectConfig.humanInLoop.requiresHumanAfter -join ", ") + "`n"
    }

    # Build the prompt
    $prompt = @"
You are the decision engine for Claude Code Watchdog, an autonomous monitoring system for Claude Code sessions.

Your job is to decide what action to take based on the current state of a Claude Code session.

# Current Session State

**Status**: $($SessionState.Status)
**Is Processing**: $($SessionState.IsProcessing)
**Idle Time**: $([math]::Round($SessionState.IdleTime.TotalMinutes, 1)) minutes
**Session ID**: $($SessionState.SessionId)

$todoContext
$errorContext
$skillsContext
$humanLoopContext
$recentDecisionsText

# Project Configuration

**Project**: $($ProjectConfig.projectName)
**Auto-Progress**: $($ProjectConfig.automation.autoProgress)
**Auto-Commit**: $($ProjectConfig.automation.autoCommit)
**Stall Threshold**: $($ProjectConfig.automation.stallThreshold)

# Your Task

Analyze the current state and decide what action to take. You must respond with ONLY a valid JSON object (no markdown, no code blocks) in this exact format:

{
  "action": "one of: continue, wait, notify, use-skill, phase-transition",
  "command": "the exact command to send to Claude Code (null if action is wait or notify)",
  "skill_to_use": "full path to skill if action is use-skill, otherwise null",
  "reasoning": "clear explanation of why you chose this action (1-2 sentences)",
  "confidence": 0.85
}

# Action Definitions

- **continue**: Send a command to Claude Code to continue with the next TODO
- **wait**: Do nothing, Claude is processing or state is unclear
- **notify**: Alert the human that intervention is needed
- **use-skill**: Invoke a specific Claude Skill to handle an error or task
- **phase-transition**: Commit current work and move to next phase

# Decision Guidelines

1. If IsProcessing is true, always choose "wait"
2. If there are high-severity errors and no matching skill, choose "notify"
3. If there's a single error and a skill matches, choose "use-skill"
4. If TODOs remain and autoProgress is true, choose "continue"
5. If session is Idle beyond stall threshold, choose "notify"
6. If PhaseComplete and autoCommit is true, choose "phase-transition"
7. Avoid loops - if recent decisions show repeated "continue" actions, choose "notify" instead

# Important Rules

- Respond with ONLY the JSON object, no extra text
- Do not use markdown code blocks (\`\`\`json)
- Confidence should be 0.0 to 1.0
- Command must be actionable text that can be sent to Claude Code
- If using a skill, the command should instruct Claude Code to use that skill

Now, make your decision based on the current state above.
"@

    return $prompt
}

function Invoke-ClaudeAPI {
    <#
    .SYNOPSIS
        Calls the Claude API with a prompt
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [Parameter(Mandatory)]
        [string]$APIKey,

        [Parameter(Mandatory)]
        [object]$Config
    )

    $startTime = Get-Date

    $headers = @{
        "x-api-key" = $APIKey
        "anthropic-version" = "2023-06-01"
        "content-type" = "application/json"
    }

    $body = @{
        model = $Config.model
        max_tokens = $Config.maxTokens
        temperature = $Config.temperature
        messages = @(
            @{
                role = "user"
                content = $Prompt
            }
        )
    } | ConvertTo-Json -Depth 10

    Write-Verbose "Calling Claude API: Model=$($Config.model), MaxTokens=$($Config.maxTokens)"

    try {
        $response = Invoke-RestMethod -Uri "https://api.anthropic.com/v1/messages" `
            -Method Post `
            -Headers $headers `
            -Body $body `
            -TimeoutSec 30

        $endTime = Get-Date
        $responseTime = ($endTime - $startTime).TotalSeconds

        # Add response time to the response object
        $response | Add-Member -NotePropertyName "ResponseTime" -NotePropertyValue $responseTime -Force

        Write-Verbose "API call successful. Response time: $([math]::Round($responseTime, 2))s"

        return $response
    }
    catch {
        Write-Error "Claude API call failed: $_"
        throw
    }
}

function Parse-ClaudeDecisionResponse {
    <#
    .SYNOPSIS
        Parses Claude API response into a decision object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Response,

        [Parameter(Mandatory)]
        [hashtable]$SessionState
    )

    try {
        # Extract the text response
        $content = $Response.content[0].text

        # Clean up any markdown code blocks if present
        $content = $content -replace '```json\s*', '' -replace '```\s*$', ''
        $content = $content.Trim()

        Write-Verbose "Parsing API response: $content"

        # Parse JSON
        $apiDecision = $content | ConvertFrom-Json

        # Build decision object
        $decision = @{
            Action = $apiDecision.action
            Command = $apiDecision.command
            SkillToUse = $apiDecision.skill_to_use
            Reasoning = $apiDecision.reasoning
            Confidence = [double]$apiDecision.confidence
            Timestamp = Get-Date -Format "o"
            DecisionMethod = "claude-api"
        }

        # Validate action
        $validActions = @("continue", "wait", "notify", "use-skill", "phase-transition")
        if ($validActions -notcontains $decision.Action) {
            Write-Warning "Invalid action '$($decision.Action)' from API. Defaulting to 'wait'."
            $decision.Action = "wait"
            $decision.Confidence = 0.50
        }

        # Validate confidence
        if ($decision.Confidence -lt 0.0 -or $decision.Confidence -gt 1.0) {
            Write-Warning "Invalid confidence $($decision.Confidence). Clamping to 0.0-1.0 range."
            $decision.Confidence = [Math]::Max(0.0, [Math]::Min(1.0, $decision.Confidence))
        }

        Write-Verbose "Parsed decision: Action=$($decision.Action), Confidence=$($decision.Confidence)"

        return $decision
    }
    catch {
        Write-Error "Failed to parse Claude API response: $_"
        throw
    }
}

function Get-ClaudeAPIKey {
    <#
    .SYNOPSIS
        Retrieves the Claude API key from Windows Credential Manager
    #>
    [CmdletBinding()]
    param()

    try {
        # Try to get from environment variable first (for testing)
        $apiKey = $env:ANTHROPIC_API_KEY
        if ($apiKey) {
            Write-Verbose "Using API key from environment variable"
            return $apiKey
        }

        # Try to get from Windows Credential Manager
        $credTarget = "ClaudeCodeWatchdog:APIKey"

        # Use cmdkey to check if credential exists (PowerShell 7 compatible)
        $credCheck = & cmdkey /list:$credTarget 2>&1

        if ($LASTEXITCODE -eq 0) {
            # Credential exists - try to read it
            # Note: This is a simplified version. In production, use a proper credential manager
            Write-Verbose "API key found in credential store"

            # For now, return a placeholder that indicates credential exists
            # Real implementation would use Windows Credential Manager API
            # This requires the stored password to be retrieved, which needs native calls

            # Alternative: Read from a secure file
            $securePath = Join-Path $env:USERPROFILE ".claude-automation/api-key.encrypted"
            if (Test-Path $securePath) {
                $secureString = Get-Content $securePath | ConvertTo-SecureString
                $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString)
                $apiKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
                return $apiKey
            }
        }

        Write-Verbose "No API key found"
        return $null
    }
    catch {
        Write-Warning "Failed to retrieve API key: $_"
        return $null
    }
}

function Test-APICostLimits {
    <#
    .SYNOPSIS
        Checks if API cost limits have been exceeded
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$GlobalConfig
    )

    try {
        # Load current API costs
        $costsPath = Join-Path $env:USERPROFILE ".claude-automation/api-costs.json"

        if (-not (Test-Path $costsPath)) {
            # No costs tracked yet - allow
            return @{
                CanProceed = $true
                Reason = $null
            }
        }

        $costs = Get-Content $costsPath -Raw | ConvertFrom-Json

        $today = Get-Date -Format "yyyy-MM-dd"
        $dailyCost = 0.0

        if ($costs.daily_costs.$today) {
            $dailyCost = $costs.daily_costs.$today.total_cost
        }

        # Check daily limit
        if ($dailyCost -ge $GlobalConfig.api.dailyCostLimit) {
            return @{
                CanProceed = $false
                Reason = "Daily cost limit exceeded ($dailyCost >= $($GlobalConfig.api.dailyCostLimit))"
            }
        }

        # Check weekly limit
        $weekStart = (Get-Date).AddDays(-7).ToString("yyyy-MM-dd")
        $weeklyCost = 0.0

        foreach ($day in $costs.daily_costs.PSObject.Properties.Name) {
            if ($day -ge $weekStart) {
                $weeklyCost += $costs.daily_costs.$day.total_cost
            }
        }

        if ($weeklyCost -ge $GlobalConfig.api.weeklyCostLimit) {
            return @{
                CanProceed = $false
                Reason = "Weekly cost limit exceeded ($weeklyCost >= $($GlobalConfig.api.weeklyCostLimit))"
            }
        }

        return @{
            CanProceed = $true
            Reason = $null
            DailyCost = $dailyCost
            WeeklyCost = $weeklyCost
        }
    }
    catch {
        Write-Warning "Failed to check cost limits: $_. Allowing API call."
        return @{
            CanProceed = $true
            Reason = $null
        }
    }
}

function Calculate-APICost {
    <#
    .SYNOPSIS
        Calculates the cost of an API call based on token usage
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Usage,

        [Parameter(Mandatory)]
        [string]$Model
    )

    # Pricing as of 2024 (per million tokens)
    # These should be moved to configuration in production
    $pricing = @{
        "claude-3-5-sonnet-20241022" = @{
            input = 3.00    # $3 per million input tokens
            output = 15.00  # $15 per million output tokens
        }
        "claude-3-5-sonnet-20240620" = @{
            input = 3.00
            output = 15.00
        }
        "claude-3-haiku-20240307" = @{
            input = 0.25
            output = 1.25
        }
    }

    if (-not $pricing.ContainsKey($Model)) {
        Write-Warning "Unknown model pricing: $Model. Using Sonnet pricing."
        $Model = "claude-3-5-sonnet-20241022"
    }

    $inputCost = ($Usage.input_tokens / 1000000.0) * $pricing[$Model].input
    $outputCost = ($Usage.output_tokens / 1000000.0) * $pricing[$Model].output
    $totalCost = $inputCost + $outputCost

    return [math]::Round($totalCost, 6)
}

function Add-APIUsageLog {
    <#
    .SYNOPSIS
        Logs API usage and costs
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Decision,

        [Parameter(Mandatory)]
        [string]$ProjectName
    )

    try {
        $costsPath = Join-Path $env:USERPROFILE ".claude-automation/api-costs.json"
        $costsDir = Split-Path $costsPath -Parent

        if (-not (Test-Path $costsDir)) {
            New-Item -ItemType Directory -Path $costsDir -Force | Out-Null
        }

        # Load existing costs or create new
        if (Test-Path $costsPath) {
            $costs = Get-Content $costsPath -Raw | ConvertFrom-Json -AsHashtable
        }
        else {
            $costs = @{
                daily_costs = @{}
                project_costs = @{}
            }
        }

        $today = Get-Date -Format "yyyy-MM-dd"

        # Initialize today if needed
        if (-not $costs.daily_costs.$today) {
            $costs.daily_costs.$today = @{
                total_cost = 0.0
                total_tokens = 0
                decision_count = 0
                projects = @{}
            }
        }

        # Add to daily total
        $costs.daily_costs.$today.total_cost += $Decision.Metadata.CostEstimate
        $costs.daily_costs.$today.total_tokens += $Decision.Metadata.TokensUsed
        $costs.daily_costs.$today.decision_count += 1

        # Add to project-specific tracking
        if (-not $costs.daily_costs.$today.projects.$ProjectName) {
            $costs.daily_costs.$today.projects.$ProjectName = @{
                cost = 0.0
                tokens = 0
                decisions = 0
            }
        }
        $costs.daily_costs.$today.projects.$ProjectName.cost += $Decision.Metadata.CostEstimate
        $costs.daily_costs.$today.projects.$ProjectName.tokens += $Decision.Metadata.TokensUsed
        $costs.daily_costs.$today.projects.$ProjectName.decisions += 1

        # Save
        $costs | ConvertTo-Json -Depth 10 | Set-Content $costsPath

        Write-Verbose "Logged API usage: Cost=$($Decision.Metadata.CostEstimate), Tokens=$($Decision.Metadata.TokensUsed)"
    }
    catch {
        Write-Warning "Failed to log API usage: $_"
    }
}

# Export functions
Export-ModuleMember -Function Invoke-ClaudeDecision
